import 'dart:io';
import 'dart:convert';

/// Script to fix Spine JSON animation timelines
///
/// **VẤN ĐỀ:** Unity tự động fix animation, Flutter thì không.
/// Script này tự động fix các vấn đề mà Unity runtime tự động xử lý:
///
/// Fixes (Unity-like auto-fixes):
/// 1. Translate timelines ending without explicit (0,0) - ensures seamless loop
/// 2. Rotate timelines ending without explicit angle - ensures seamless loop
/// 3. Scale timelines ending without explicit values - ensures seamless loop
/// 4. First keyframes missing explicit time: 0
/// 5. Ensures first and last keyframes match for seamless looping
/// 6. Missing bone timelines (Unity auto-resets, Flutter doesn't)
/// 7. Skill bones with extreme setup poses (Unity clamps, Flutter doesn't)
/// 8. Attachment offsets in skins (Unity normalizes, Flutter doesn't)
///
/// **KẾT QUẢ:** Animation sẽ chạy mượt trên Flutter như trên Unity.
///
/// Usage: dart fix_spine_json.dart
void main() async {
  final file = File('assets/spine/alien-pro.json');
  if (!await file.exists()) {
    print('Error: File not found: ${file.path}');
    return;
  }

  final content = await file.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;

  final animations = json['animations'] as Map<String, dynamic>;
  int fixedCount = 0;

  print('Found ${animations.length} animations to process...');
  print('Processing animations...\n');

  animations.forEach((animName, animData) {
    int animFixedCount = 0; // Count fixes per animation
    // Find animation duration (max time across all timelines)
    double animDuration = 0;
    final animMap = animData as Map<String, dynamic>;
    Map<String, dynamic>? bones = animMap['bones'] as Map<String, dynamic>?;
    final slots = animMap['slots'] as Map<String, dynamic>?;

    // Find max time in all timelines
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
        if (bone.containsKey('translate')) {
          findMaxTime(bone['translate'] as List<dynamic>);
        }
        if (bone.containsKey('rotate')) {
          findMaxTime(bone['rotate'] as List<dynamic>);
        }
        if (bone.containsKey('scale')) {
          findMaxTime(bone['scale'] as List<dynamic>);
        }
      });
    }

    if (slots != null) {
      slots.forEach((_, slotData) {
        final slot = slotData as Map<String, dynamic>;
        if (slot.containsKey('attachment')) {
          findMaxTime(slot['attachment'] as List<dynamic>);
        }
      });
    }

    if (animDuration == 0) animDuration = 1.0; // Default

    // Initialize bones map if null
    Map<String, dynamic> bonesMap;
    if (bones == null) {
      animMap['bones'] = <String, dynamic>{};
      bonesMap = animMap['bones'] as Map<String, dynamic>;
    } else {
      bonesMap = bones;
    }

    // Get all bones from skeleton data to check which ones are missing
    final skeletonBones = json['bones'] as List<dynamic>;
    final boneNames = skeletonBones
        .map((b) => (b as Map<String, dynamic>)['name'] as String)
        .toSet();

    // Add missing bone timelines (bones that exist in skeleton but not in animation)
    // This ensures all bones have transforms, preventing attachments from drifting
    // Special handling for skill bones - they often have extreme setup poses that need to be reset
    boneNames.forEach((boneName) {
      if (!bonesMap.containsKey(boneName)) {
        // Find bone in skeleton to get setup pose
        final skeletonBone = skeletonBones.firstWhere(
          (b) => (b as Map<String, dynamic>)['name'] == boneName,
          orElse: () => null,
        );

        double setupX = 0;
        double setupY = 0;

        if (skeletonBone != null) {
          final bone = skeletonBone as Map<String, dynamic>;
          setupX = (bone['x'] as num?)?.toDouble() ?? 0;
          setupY = (bone['y'] as num?)?.toDouble() ?? 0;
        }

        // For skill bones with extreme positions, reset to (0,0) relative to parent
        // IMPORTANT: Translate is ADDITIVE (setupPose + translate)
        // To reset to (0,0), we need translate = -setupPose
        final isSkillBone =
            boneName.contains('skill') &&
            (setupX.abs() > 100 || setupY.abs() > 100);

        // If skill bone, use -setupPose to reset to (0,0)
        // Otherwise, use 0 to keep setup pose
        final resetX = isSkillBone ? -setupX : 0.0;
        final resetY = isSkillBone ? -setupY : 0.0;

        // Add timeline to ensure bone gets transform
        // For skill bones, translate = -setupPose to reset to (0,0)
        bonesMap[boneName] = {
          'rotate': [
            {'time': 0, 'angle': 0}, // Reset rotation to 0
            {'time': animDuration, 'angle': 0},
          ],
          'translate': [
            {'time': 0, 'x': resetX, 'y': resetY},
            {'time': animDuration, 'x': resetX, 'y': resetY},
          ],
          'scale': [
            {'time': 0, 'x': 1, 'y': 1}, // Reset scale to 1
            {'time': animDuration, 'x': 1, 'y': 1},
          ],
        };
        animFixedCount += 6; // 3 timelines * 2 keyframes each
        fixedCount += 6;
        if (isSkillBone) {
          print(
            '  [Animation "$animName"] Added missing bone timeline (RESET): "$boneName" (was x=$setupX, y=$setupY)',
          );
        } else {
          print(
            '  [Animation "$animName"] Added missing bone timeline: "$boneName"',
          );
        }
      }
    });

    bonesMap.forEach((boneName, boneData) {
      final bone = boneData as Map<String, dynamic>;

      // Fix translate timeline
      if (bone.containsKey('translate')) {
        final translate = bone['translate'] as List<dynamic>;
        if (translate.isNotEmpty) {
          // Fix first keyframe
          final first = translate[0] as Map<String, dynamic>;
          if (!first.containsKey('time')) {
            first['time'] = 0;
            animFixedCount++;
            fixedCount++;
          }
          // For skill bones with extreme setup poses, translate should be -setupPose to reset to (0,0)
          final skeletonBone = skeletonBones.firstWhere(
            (b) => (b as Map<String, dynamic>)['name'] == boneName,
            orElse: () => null,
          );

          double expectedX = 0;
          double expectedY = 0;

          if (skeletonBone != null && boneName.contains('skill')) {
            final bone = skeletonBone as Map<String, dynamic>;
            final setupX = (bone['x'] as num?)?.toDouble() ?? 0;
            final setupY = (bone['y'] as num?)?.toDouble() ?? 0;

            // If setup pose is extreme, reset to (0,0) = translate = -setupPose
            if (setupX.abs() > 100 || setupY.abs() > 100) {
              expectedX = -setupX;
              expectedY = -setupY;
            }
          }

          final currentX = (first['x'] as num?)?.toDouble();
          final currentY = (first['y'] as num?)?.toDouble();

          if (!first.containsKey('x') ||
              currentX == null ||
              currentX != expectedX) {
            first['x'] = expectedX;
            animFixedCount++;
            fixedCount++;
            if (boneName.contains('skill') && expectedX != 0) {
              print(
                '  [Animation "$animName"] Fixed translate X for "$boneName": $currentX -> $expectedX',
              );
            }
          }
          if (!first.containsKey('y') ||
              currentY == null ||
              currentY != expectedY) {
            first['y'] = expectedY;
            animFixedCount++;
            fixedCount++;
            if (boneName.contains('skill') && expectedY != 0) {
              print(
                '  [Animation "$animName"] Fixed translate Y for "$boneName": $currentY -> $expectedY',
              );
            }
          }

          // Fix last keyframe - ensure it matches first for seamless loop
          // Unity behavior: Last frame must equal first frame for seamless loop
          final last = translate.last as Map<String, dynamic>;
          final lastTime = (last['time'] as num?)?.toDouble();

          // If last keyframe is at animation end (or close to it), ensure it matches first
          if (lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0)) {
            final firstX = (first['x'] as num?)?.toDouble() ?? expectedX;
            final firstY = (first['y'] as num?)?.toDouble() ?? expectedY;

            if (!last.containsKey('x') ||
                (last['x'] as num?)?.toDouble() != firstX) {
              last['x'] = firstX;
              animFixedCount++;
              fixedCount++;
            }
            if (!last.containsKey('y') ||
                (last['y'] as num?)?.toDouble() != firstY) {
              last['y'] = firstY;
              animFixedCount++;
              fixedCount++;
            }
          } else if (lastTime != null && lastTime < animDuration * 0.99) {
            // Unity behavior: Add explicit keyframe at animation end if missing
            final firstX = (first['x'] as num?)?.toDouble() ?? expectedX;
            final firstY = (first['y'] as num?)?.toDouble() ?? expectedY;
            translate.add({'time': animDuration, 'x': firstX, 'y': firstY});
            animFixedCount++;
            fixedCount++;
          }
        }
      }

      // Fix rotate timeline
      if (bone.containsKey('rotate')) {
        final rotate = bone['rotate'] as List<dynamic>;
        if (rotate.isNotEmpty) {
          // Fix first keyframe
          final first = rotate[0] as Map<String, dynamic>;
          if (!first.containsKey('time')) {
            first['time'] = 0;
            fixedCount++;
          }
          if (!first.containsKey('angle')) {
            first['angle'] = 0;
            fixedCount++;
          }

          // Fix last keyframe - ensure it matches first for seamless loop
          final last = rotate.last as Map<String, dynamic>;
          final lastTime = (last['time'] as num?)?.toDouble();

          // If last keyframe is at animation end (or close to it), ensure it matches first
          if (lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0)) {
            final firstAngle = (first['angle'] as num?)?.toDouble() ?? 0;

            if (!last.containsKey('angle') ||
                (last['angle'] as num?)?.toDouble() != firstAngle) {
              last['angle'] = firstAngle;
              fixedCount++;
            }
          }
        }
      }

      // Fix scale timeline
      if (bone.containsKey('scale')) {
        final scale = bone['scale'] as List<dynamic>;
        if (scale.isNotEmpty) {
          // Fix first keyframe
          final first = scale[0] as Map<String, dynamic>;
          if (!first.containsKey('time')) {
            first['time'] = 0;
            fixedCount++;
          }
          if (!first.containsKey('x')) {
            first['x'] = 1;
            fixedCount++;
          }
          if (!first.containsKey('y')) {
            first['y'] = 1;
            fixedCount++;
          }

          // Fix last keyframe - ensure it matches first for seamless loop
          final last = scale.last as Map<String, dynamic>;
          final lastTime = (last['time'] as num?)?.toDouble();

          // If last keyframe is at animation end (or close to it), ensure it matches first
          if (lastTime != null &&
              (lastTime >= animDuration * 0.99 ||
                  lastTime == 1 ||
                  lastTime == 1.0)) {
            final firstX = (first['x'] as num?)?.toDouble() ?? 1;
            final firstY = (first['y'] as num?)?.toDouble() ?? 1;

            if (!last.containsKey('x') ||
                (last['x'] as num?)?.toDouble() != firstX) {
              last['x'] = firstX;
              fixedCount++;
            }
            if (!last.containsKey('y') ||
                (last['y'] as num?)?.toDouble() != firstY) {
              last['y'] = firstY;
              fixedCount++;
            }
          }
        }
      }
    });

    // Fix attachment timelines
    if (slots != null) {
      slots.forEach((slotName, slotData) {
        final slot = slotData as Map<String, dynamic>;
        if (slot.containsKey('attachment')) {
          final attachment = slot['attachment'] as List<dynamic>;
          if (attachment.isNotEmpty) {
            final first = attachment[0] as Map<String, dynamic>;
            if (!first.containsKey('time')) {
              first['time'] = 0;
              fixedCount++;
            }

            // Ensure last attachment matches first for seamless loop
            final last = attachment.last as Map<String, dynamic>;
            final lastTime = (last['time'] as num?)?.toDouble();
            if (lastTime != null &&
                (lastTime >= animDuration * 0.99 ||
                    lastTime == 1 ||
                    lastTime == 1.0)) {
              final firstName = first['name'];
              if (!last.containsKey('name') || last['name'] != firstName) {
                last['name'] = firstName;
                fixedCount++;
              }
            }
          }
        }
      });
    }

    if (animFixedCount > 0) {
      print(
        'Animation "$animName": duration=$animDuration, fixed $animFixedCount issues',
      );
    } else {
      // Debug: show animation info even if no fixes
      print(
        'Animation "$animName": duration=$animDuration, bones=${bonesMap.length}, no fixes needed',
      );
    }
  });

  // Fix attachment offsets in skin data
  // Attachments with extreme x/y offsets in skin can cause misalignment
  // Fix ALL attachments with extreme offsets, not just skill ones
  final skins = json['skins'] as List<dynamic>?;
  if (skins != null) {
    print('\nFixing attachment offsets in skins...');
    int skinFixedCount = 0;
    skins.forEach((skinData) {
      final skin = skinData as Map<String, dynamic>;
      final skinName = skin['name'] as String? ?? 'unknown';
      final attachments = skin['attachments'] as Map<String, dynamic>?;
      if (attachments != null) {
        attachments.forEach((slotName, slotAttachments) {
          final slotAtts = slotAttachments as Map<String, dynamic>;
          slotAtts.forEach((attName, attData) {
            final att = attData as Map<String, dynamic>;
            final attX = (att['x'] as num?)?.toDouble() ?? 0;
            final attY = (att['y'] as num?)?.toDouble() ?? 0;

            // Reset extreme x/y offsets (for all attachments, not just skill)
            // Extreme offsets can cause attachments to appear disconnected
            if (attX.abs() > 100 || attY.abs() > 100) {
              att['x'] = 0;
              att['y'] = 0;
              fixedCount += 2;
              print(
                '  [Skin "$skinName"] Reset attachment offset: "$slotName/$attName" (was x=$attX, y=$attY)',
              );
            }
          });
        });
      }
    });
    if (skinFixedCount == 0) {
      print('  No attachment offsets to fix in skins.');
    } else {
      print('  Fixed $skinFixedCount attachment offset issues in skins.');
    }
  } else {
    print('\nNo skins found in JSON.');
  }

  // Write fixed JSON
  // Always write, even if no fixes (to ensure formatting is consistent)
  final encoder = JsonEncoder.withIndent('    ');
  final fixedJson = encoder.convert(json);
  await file.writeAsString(fixedJson);

  print('\n=== SUMMARY ===');
  if (fixedCount > 0) {
    print('Fixed $fixedCount issues in ${file.path}');
  } else {
    print('No issues found to fix in ${file.path}');
    print('(File may already be fixed, or animation data is clean)');
  }
  print('File saved to: ${file.path}');
}
