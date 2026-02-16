import 'dart:io';
import 'dart:convert';

/// STRICT Spine JSON Animation Data Fixer
///
/// ROOT CAUSE: Animation timelines NOT returning to setup pose
/// - Translate timelines end without explicit reset values
/// - Frame 0 ≠ frame end (loop mismatch)
/// - Attachment timelines not explicitly reset
/// - Draw order timelines not reset
/// - FX / skill bones drifting due to additive translate
///
/// This script fixes ONLY REAL DATA ISSUES.
/// NO hacks, NO visual tweaks, ONLY data fixes.
///
/// Usage: dart fix_spine_json_strict.dart
void main() async {
  final file = File('assets/spine/alien-pro.json');
  if (!await file.exists()) {
    print('Error: File not found: ${file.path}');
    return;
  }

  print('=== SPINE JSON ANIMATION DATA FIXER ===');
  print('File: ${file.path}\n');

  final content = await file.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;

  final animations = json['animations'] as Map<String, dynamic>;
  int totalFixedCount = 0;
  final List<String> fixLog = [];

  print('Found ${animations.length} animations to process...\n');

  animations.forEach((animName, animData) {
    print('--- Processing animation: "$animName" ---');

    int animFixedCount = 0;
    final animMap = animData as Map<String, dynamic>;
    Map<String, dynamic>? bones = animMap['bones'] as Map<String, dynamic>?;
    final slots = animMap['slots'] as Map<String, dynamic>?;
    final drawOrder = animMap['drawOrder'] as List<dynamic>?;

    // STEP 1: Determine animation duration (max keyframe time)
    double animDuration = 0;

    void findMaxTime(List<dynamic> timeline) {
      for (final kf in timeline) {
        final key = kf as Map<String, dynamic>;
        final time = (key['time'] as num?)?.toDouble();
        if (time != null && time > animDuration) {
          animDuration = time;
        }
      }
    }

    if (bones != null) {
      bones.forEach((_, boneData) {
        final bone = boneData as Map<String, dynamic>;
        if (bone.containsKey('translate'))
          findMaxTime(bone['translate'] as List<dynamic>);
        if (bone.containsKey('rotate'))
          findMaxTime(bone['rotate'] as List<dynamic>);
        if (bone.containsKey('scale'))
          findMaxTime(bone['scale'] as List<dynamic>);
      });
    }

    if (slots != null) {
      slots.forEach((_, slotData) {
        final slot = slotData as Map<String, dynamic>;
        if (slot.containsKey('attachment'))
          findMaxTime(slot['attachment'] as List<dynamic>);
        if (slot.containsKey('color'))
          findMaxTime(slot['color'] as List<dynamic>);
      });
    }

    if (drawOrder != null) {
      findMaxTime(drawOrder);
    }

    if (animDuration == 0) animDuration = 1.0; // Default

    print('  Duration: $animDuration seconds');

    // Initialize bones map if null
    Map<String, dynamic> bonesMap;
    if (bones == null) {
      animMap['bones'] = <String, dynamic>{};
      bonesMap = animMap['bones'] as Map<String, dynamic>;
    } else {
      bonesMap = bones;
    }

    // Get skeleton bones for setup pose reference
    final skeletonBones = json['bones'] as List<dynamic>;
    final skeletonBoneMap = <String, Map<String, dynamic>>{};
    for (final b in skeletonBones) {
      final bone = b as Map<String, dynamic>;
      skeletonBoneMap[bone['name'] as String] = bone;
    }

    // STEP 2: Fix bone timelines
    bonesMap.forEach((boneName, boneData) {
      final bone = boneData as Map<String, dynamic>;

      // === TRANSLATE TIMELINE (CRITICAL) ===
      if (bone.containsKey('translate')) {
        final translate = bone['translate'] as List<dynamic>;
        if (translate.isNotEmpty) {
          final first = translate[0] as Map<String, dynamic>;
          final last = translate.last as Map<String, dynamic>;

          // Get setup pose (for reference, not used in strict fix)
          // final skeletonBone = skeletonBoneMap[boneName];

          // Rule: Frame 0 MUST have explicit x,y
          double firstX = (first['x'] as num?)?.toDouble() ?? 0;
          double firstY = (first['y'] as num?)?.toDouble() ?? 0;

          if (!first.containsKey('x')) {
            first['x'] = firstX;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [TRANSLATE] "$boneName": Added missing x at frame 0 (value: $firstX)',
            );
          }
          if (!first.containsKey('y')) {
            first['y'] = firstY;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [TRANSLATE] "$boneName": Added missing y at frame 0 (value: $firstY)',
            );
          }

          // Rule: Frame 0 MUST have time: 0
          if (!first.containsKey('time') ||
              (first['time'] as num?)?.toDouble() != 0) {
            first['time'] = 0;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add('  [TRANSLATE] "$boneName": Set frame 0 time to 0');
          }

          // Rule: Last frame MUST have explicit x,y
          // Rule: Last frame values MUST MATCH frame 0 values
          final lastTime = (last['time'] as num?)?.toDouble();
          final isAtEnd =
              lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0);

          if (isAtEnd) {
            final lastX = (last['x'] as num?)?.toDouble();
            final lastY = (last['y'] as num?)?.toDouble();

            if (!last.containsKey('x') || lastX == null || lastX != firstX) {
              final before = lastX ?? 'missing';
              last['x'] = firstX;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [TRANSLATE] "$boneName": Fixed last frame x ($before → $firstX)',
              );
            }
            if (!last.containsKey('y') || lastY == null || lastY != firstY) {
              final before = lastY ?? 'missing';
              last['y'] = firstY;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [TRANSLATE] "$boneName": Fixed last frame y ($before → $firstY)',
              );
            }
          } else if (lastTime != null && lastTime < animDuration * 0.99) {
            // Add explicit keyframe at animation end
            translate.add({'time': animDuration, 'x': firstX, 'y': firstY});
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [TRANSLATE] "$boneName": Added keyframe at end (time: $animDuration, x: $firstX, y: $firstY)',
            );
          }
        }
      }

      // === ROTATE TIMELINE ===
      if (bone.containsKey('rotate')) {
        final rotate = bone['rotate'] as List<dynamic>;
        if (rotate.isNotEmpty) {
          final first = rotate[0] as Map<String, dynamic>;
          final last = rotate.last as Map<String, dynamic>;

          // Rule: Frame 0 MUST have explicit angle
          double firstAngle = (first['angle'] as num?)?.toDouble() ?? 0;

          if (!first.containsKey('angle')) {
            first['angle'] = firstAngle;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [ROTATE] "$boneName": Added missing angle at frame 0 (value: $firstAngle)',
            );
          }

          // Rule: Frame 0 MUST have time: 0
          if (!first.containsKey('time') ||
              (first['time'] as num?)?.toDouble() != 0) {
            first['time'] = 0;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add('  [ROTATE] "$boneName": Set frame 0 time to 0');
          }

          // Rule: Last frame MUST match frame 0 angle
          final lastTime = (last['time'] as num?)?.toDouble();
          final isAtEnd =
              lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0);

          if (isAtEnd) {
            final lastAngle = (last['angle'] as num?)?.toDouble();
            if (!last.containsKey('angle') ||
                lastAngle == null ||
                lastAngle != firstAngle) {
              final before = lastAngle ?? 'missing';
              last['angle'] = firstAngle;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [ROTATE] "$boneName": Fixed last frame angle ($before → $firstAngle)',
              );
            }
          } else if (lastTime != null && lastTime < animDuration * 0.99) {
            rotate.add({'time': animDuration, 'angle': firstAngle});
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [ROTATE] "$boneName": Added keyframe at end (time: $animDuration, angle: $firstAngle)',
            );
          }
        }
      }

      // === SCALE TIMELINE ===
      if (bone.containsKey('scale')) {
        final scale = bone['scale'] as List<dynamic>;
        if (scale.isNotEmpty) {
          final first = scale[0] as Map<String, dynamic>;
          final last = scale.last as Map<String, dynamic>;

          // Rule: Frame 0 MUST have x=1,y=1 (or setup)
          double firstX = (first['x'] as num?)?.toDouble() ?? 1;
          double firstY = (first['y'] as num?)?.toDouble() ?? 1;

          if (!first.containsKey('x')) {
            first['x'] = firstX;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [SCALE] "$boneName": Added missing x at frame 0 (value: $firstX)',
            );
          }
          if (!first.containsKey('y')) {
            first['y'] = firstY;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [SCALE] "$boneName": Added missing y at frame 0 (value: $firstY)',
            );
          }

          // Rule: Frame 0 MUST have time: 0
          if (!first.containsKey('time') ||
              (first['time'] as num?)?.toDouble() != 0) {
            first['time'] = 0;
            animFixedCount++;
            totalFixedCount++;
            fixLog.add('  [SCALE] "$boneName": Set frame 0 time to 0');
          }

          // Rule: Last frame MUST match frame 0
          final lastTime = (last['time'] as num?)?.toDouble();
          final isAtEnd =
              lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0);

          if (isAtEnd) {
            final lastX = (last['x'] as num?)?.toDouble();
            final lastY = (last['y'] as num?)?.toDouble();

            if (!last.containsKey('x') || lastX == null || lastX != firstX) {
              final before = lastX ?? 'missing';
              last['x'] = firstX;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [SCALE] "$boneName": Fixed last frame x ($before → $firstX)',
              );
            }
            if (!last.containsKey('y') || lastY == null || lastY != firstY) {
              final before = lastY ?? 'missing';
              last['y'] = firstY;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [SCALE] "$boneName": Fixed last frame y ($before → $firstY)',
              );
            }
          } else if (lastTime != null && lastTime < animDuration * 0.99) {
            scale.add({'time': animDuration, 'x': firstX, 'y': firstY});
            animFixedCount++;
            totalFixedCount++;
            fixLog.add(
              '  [SCALE] "$boneName": Added keyframe at end (time: $animDuration, x: $firstX, y: $firstY)',
            );
          }
        }
      }
    });

    // STEP 3: Fix attachment timelines
    if (slots != null) {
      slots.forEach((slotName, slotData) {
        final slot = slotData as Map<String, dynamic>;

        if (slot.containsKey('attachment')) {
          final attachment = slot['attachment'] as List<dynamic>;
          if (attachment.isNotEmpty) {
            final first = attachment[0] as Map<String, dynamic>;
            final last = attachment.last as Map<String, dynamic>;

            // Rule: Must explicitly set attachment state at time 0
            if (!first.containsKey('time') ||
                (first['time'] as num?)?.toDouble() != 0) {
              first['time'] = 0;
              animFixedCount++;
              totalFixedCount++;
              fixLog.add('  [ATTACHMENT] "$slotName": Set frame 0 time to 0');
            }

            // Rule: Last attachment MUST equal first attachment
            final lastTime = (last['time'] as num?)?.toDouble();
            final isAtEnd =
                lastTime != null &&
                (lastTime >= animDuration * 0.99 ||
                    lastTime == 1 ||
                    lastTime == 1.0);

            if (isAtEnd) {
              final firstName = first['name'];
              final lastName = last['name'];

              if (!last.containsKey('name') || lastName != firstName) {
                final before = lastName ?? 'missing';
                last['name'] = firstName;
                animFixedCount++;
                totalFixedCount++;
                fixLog.add(
                  '  [ATTACHMENT] "$slotName": Fixed last frame name ($before → $firstName)',
                );
              }
            } else if (lastTime != null && lastTime < animDuration * 0.99) {
              final firstName = first['name'];
              attachment.add({'time': animDuration, 'name': firstName});
              animFixedCount++;
              totalFixedCount++;
              fixLog.add(
                '  [ATTACHMENT] "$slotName": Added keyframe at end (time: $animDuration, name: $firstName)',
              );
            }
          }
        }
      });
    }

    // STEP 4: Fix draw order timelines
    if (drawOrder != null && drawOrder.isNotEmpty) {
      final first = drawOrder[0] as Map<String, dynamic>;
      final last = drawOrder.last as Map<String, dynamic>;

      // Rule: Frame 0 = default order
      // Rule: Last frame = default order
      // Rule: If last draw order ≠ first → RESET

      final firstTime = (first['time'] as num?)?.toDouble();
      final lastTime = (last['time'] as num?)?.toDouble();

      // Ensure frame 0 exists
      if (firstTime == null || firstTime != 0) {
        // Insert frame 0 if missing
        final defaultOrder = first['offsets'] ?? [];
        drawOrder.insert(0, {'time': 0, 'offsets': defaultOrder});
        animFixedCount++;
        totalFixedCount++;
        fixLog.add('  [DRAWORDER]: Added frame 0 with default order');
      }

      // Ensure last frame matches first
      final isAtEnd =
          lastTime != null &&
          (lastTime >= animDuration * 0.99 || lastTime == 1 || lastTime == 1.0);

      if (isAtEnd) {
        final firstOffsets = first['offsets'];
        final lastOffsets = last['offsets'];

        // Compare offsets (simplified - check if they're equal)
        if (lastOffsets != firstOffsets) {
          last['offsets'] = firstOffsets;
          animFixedCount++;
          totalFixedCount++;
          fixLog.add('  [DRAWORDER]: Fixed last frame to match first');
        }
      } else if (lastTime != null && lastTime < animDuration * 0.99) {
        final firstOffsets = first['offsets'] ?? [];
        drawOrder.add({'time': animDuration, 'offsets': firstOffsets});
        animFixedCount++;
        totalFixedCount++;
        fixLog.add(
          '  [DRAWORDER]: Added keyframe at end (time: $animDuration)',
        );
      }
    }

    // Output results
    if (animFixedCount > 0) {
      print('  ✓ Fixed $animFixedCount issues');
      for (final log in fixLog) {
        print(log);
      }
    } else {
      print('  ✓ No issues found (animation data is clean)');
    }
    print('');

    fixLog.clear();
  });

  // Write fixed JSON
  final encoder = JsonEncoder.withIndent('    ');
  final fixedJson = encoder.convert(json);
  await file.writeAsString(fixedJson);

  print('=== SUMMARY ===');
  if (totalFixedCount > 0) {
    print('Fixed $totalFixedCount total issues in ${file.path}');
  } else {
    print('No issues found in ${file.path}');
    print('(All animations are loop-safe)');
  }
  print('File saved to: ${file.path}');
}
