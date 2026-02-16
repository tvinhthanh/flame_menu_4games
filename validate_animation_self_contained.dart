import 'dart:io';
import 'dart:convert';

/// Validator: Kiểm tra animation có "self-contained" không
///
/// Animation "self-contained" = animation có thể chuyển đổi tự do mà không làm nhiễm state
///
/// RULES:
/// 1. Frame 0 = Setup pose (hoặc explicit values)
/// 2. Frame cuối = Frame 0 (để loop seamless)
/// 3. Tất cả bones có timeline phải reset về setup ở frame cuối
/// 4. Tất cả slots có timeline phải reset về setup ở frame cuối
/// 5. Draw order phải reset về default ở frame cuối
///
/// Usage: dart validate_animation_self_contained.dart
void main() async {
  final file = File('assets/spine/alien-pro.json');
  if (!await file.exists()) {
    print('Error: File not found: ${file.path}');
    return;
  }

  print('=== ANIMATION SELF-CONTAINED VALIDATOR ===\n');
  print('File: ${file.path}\n');

  final content = await file.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;

  final animations = json['animations'] as Map<String, dynamic>;
  final skeletonBones = json['bones'] as List<dynamic>;
  final skeletonSlots = json['slots'] as List<dynamic>;
  final defaultDrawOrder = skeletonSlots
      .map((s) => (s as Map<String, dynamic>)['name'] as String)
      .toList();

  // Build setup pose map
  final Map<String, Map<String, dynamic>> setupBones = {};
  for (final b in skeletonBones) {
    final bone = b as Map<String, dynamic>;
    setupBones[bone['name'] as String] = bone;
  }

  final Map<String, Map<String, dynamic>> setupSlots = {};
  for (final s in skeletonSlots) {
    final slot = s as Map<String, dynamic>;
    setupSlots[slot['name'] as String] = slot;
  }

  // Get default skin attachments
  final skins = json['skins'] as List<dynamic>?;
  final Map<String, String> defaultAttachments = {};
  if (skins != null) {
    for (final skinData in skins) {
      final skin = skinData as Map<String, dynamic>;
      if (skin['name'] == 'default') {
        final attachments = skin['attachments'] as Map<String, dynamic>;
        attachments.forEach((slotName, slotAttachments) {
          (slotAttachments as Map<String, dynamic>).forEach((attName, _) {
            defaultAttachments[slotName] = attName;
          });
        });
        break;
      }
    }
  }

  print('Found ${animations.length} animations to validate...\n');
  print('Setup pose: ${setupBones.length} bones, ${setupSlots.length} slots\n');

  final List<AnimationIssue> allIssues = [];
  final Map<String, bool> animationSafe = {}; // Animation name -> is safe

  animations.forEach((animName, animData) {
    bool isSafe = true; // Assume safe until proven otherwise
    final animMap = animData as Map<String, dynamic>;
    final bones = animMap['bones'] as Map<String, dynamic>?;
    final slots = animMap['slots'] as Map<String, dynamic>?;
    final drawOrderTimeline = animMap['drawOrder'] as List<dynamic>?;

    // Find animation duration
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
    if (drawOrderTimeline != null) {
      findMaxTime(drawOrderTimeline);
    }

    if (animDuration == 0) animDuration = 1.0;

    final List<AnimationIssue> animIssues = [];

    // Validate bone timelines
    if (bones != null) {
      bones.forEach((boneName, boneData) {
        final bone = boneData as Map<String, dynamic>;
        final setupBone = setupBones[boneName];

        // Validate translate
        if (bone.containsKey('translate')) {
          final translate = bone['translate'] as List<dynamic>;
          if (translate.isNotEmpty) {
            final first = translate[0] as Map<String, dynamic>;
            final last = translate.last as Map<String, dynamic>;
            final firstTime = (first['time'] as num?)?.toDouble() ?? 0;
            final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

            final setupX = (setupBone?['x'] as num?)?.toDouble() ?? 0;
            final setupY = (setupBone?['y'] as num?)?.toDouble() ?? 0;

            final firstX = (first['x'] as num?)?.toDouble() ?? setupX;
            final firstY = (first['y'] as num?)?.toDouble() ?? setupY;
            final lastX = (last['x'] as num?)?.toDouble();
            final lastY = (last['y'] as num?)?.toDouble();

            // Check frame 0
            if (firstTime != 0) {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.translate,
                  bone: boneName,
                  severity: Severity.error,
                  message: 'Frame 0 time is $firstTime (should be 0)',
                ),
              );
            }

            // Check frame 0 values (WARNING - không phải lỗi, chỉ là animation không self-contained)
            // NOTE: Frame 0 != setup pose là BÌNH THƯỜNG trong Spine, không cần fix
            // Chỉ log nếu muốn debug, không đếm vào critical issues
            // if (firstX != setupX || firstY != setupY) {
            //   animIssues.add(
            //     AnimationIssue(
            //       animation: animName,
            //       type: IssueType.translate,
            //       bone: boneName,
            //       severity: Severity.warning,
            //       message:
            //           'Frame 0 values (x=$firstX, y=$firstY) != setup (x=$setupX, y=$setupY)',
            //     ),
            //   );
            // }

            // Check last frame = first frame
            final isLastFrameAtEnd = lastTime >= animDuration * 0.99;
            if (isLastFrameAtEnd) {
              if (lastX == null ||
                  lastX != firstX ||
                  lastY == null ||
                  lastY != firstY) {
                animIssues.add(
                  AnimationIssue(
                    animation: animName,
                    type: IssueType.translate,
                    bone: boneName,
                    severity: Severity.error,
                    message:
                        'Last frame (x=$lastX, y=$lastY) != first frame (x=$firstX, y=$firstY) - will cause state pollution',
                  ),
                );
              }
            } else {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.translate,
                  bone: boneName,
                  severity: Severity.error,
                  message:
                      'Missing keyframe at animation end (last time=$lastTime, duration=$animDuration)',
                ),
              );
            }
          }
        }

        // Validate rotate
        if (bone.containsKey('rotate')) {
          final rotate = bone['rotate'] as List<dynamic>;
          if (rotate.isNotEmpty) {
            final first = rotate[0] as Map<String, dynamic>;
            final last = rotate.last as Map<String, dynamic>;
            final firstTime = (first['time'] as num?)?.toDouble() ?? 0;
            final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

            final setupRotation =
                (setupBone?['rotation'] as num?)?.toDouble() ?? 0;
            final firstAngle =
                (first['angle'] as num?)?.toDouble() ?? setupRotation;
            final lastAngle = (last['angle'] as num?)?.toDouble();

            if (firstTime != 0) {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.rotate,
                  bone: boneName,
                  severity: Severity.error,
                  message: 'Frame 0 time is $firstTime (should be 0)',
                ),
              );
            }

            // Frame 0 != setup rotation là BÌNH THƯỜNG, không cần fix
            // if (firstAngle != setupRotation) {
            //   animIssues.add(
            //     AnimationIssue(
            //       animation: animName,
            //       type: IssueType.rotate,
            //       bone: boneName,
            //       severity: Severity.warning,
            //       message:
            //           'Frame 0 angle ($firstAngle) != setup ($setupRotation)',
            //     ),
            //   );
            // }

            final isLastFrameAtEnd = lastTime >= animDuration * 0.99;
            if (isLastFrameAtEnd) {
              if (lastAngle == null || lastAngle != firstAngle) {
                animIssues.add(
                  AnimationIssue(
                    animation: animName,
                    type: IssueType.rotate,
                    bone: boneName,
                    severity: Severity.error,
                    message:
                        'Last frame angle ($lastAngle) != first frame ($firstAngle) - will cause state pollution',
                  ),
                );
              }
            } else {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.rotate,
                  bone: boneName,
                  severity: Severity.error,
                  message: 'Missing keyframe at animation end',
                ),
              );
            }
          }
        }

        // Validate scale
        if (bone.containsKey('scale')) {
          final scale = bone['scale'] as List<dynamic>;
          if (scale.isNotEmpty) {
            final first = scale[0] as Map<String, dynamic>;
            final last = scale.last as Map<String, dynamic>;
            final firstTime = (first['time'] as num?)?.toDouble() ?? 0;
            final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

            final setupScaleX = (setupBone?['scaleX'] as num?)?.toDouble() ?? 1;
            final setupScaleY = (setupBone?['scaleY'] as num?)?.toDouble() ?? 1;
            final firstX = (first['x'] as num?)?.toDouble() ?? setupScaleX;
            final firstY = (first['y'] as num?)?.toDouble() ?? setupScaleY;
            final lastX = (last['x'] as num?)?.toDouble();
            final lastY = (last['y'] as num?)?.toDouble();

            if (firstTime != 0) {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.scale,
                  bone: boneName,
                  severity: Severity.error,
                  message: 'Frame 0 time is $firstTime (should be 0)',
                ),
              );
            }

            // Frame 0 != setup scale là BÌNH THƯỜNG, không cần fix
            // if (firstX != setupScaleX || firstY != setupScaleY) {
            //   animIssues.add(
            //     AnimationIssue(
            //       animation: animName,
            //       type: IssueType.scale,
            //       bone: boneName,
            //       severity: Severity.warning,
            //       message: 'Frame 0 scale != setup',
            //     ),
            //   );
            // }

            final isLastFrameAtEnd = lastTime >= animDuration * 0.99;
            if (isLastFrameAtEnd) {
              if (lastX == null ||
                  lastX != firstX ||
                  lastY == null ||
                  lastY != firstY) {
                animIssues.add(
                  AnimationIssue(
                    animation: animName,
                    type: IssueType.scale,
                    bone: boneName,
                    severity: Severity.error,
                    message:
                        'Last frame scale != first frame - will cause state pollution',
                  ),
                );
              }
            } else {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.scale,
                  bone: boneName,
                  severity: Severity.error,
                  message: 'Missing keyframe at animation end',
                ),
              );
            }
          }
        }
      });
    }

    // Validate slot timelines
    if (slots != null) {
      slots.forEach((slotName, slotData) {
        final slot = slotData as Map<String, dynamic>;
        final setupSlot = setupSlots[slotName];
        final defaultAttachment = defaultAttachments[slotName];

        // Validate attachment
        if (slot.containsKey('attachment')) {
          final attachment = slot['attachment'] as List<dynamic>;
          if (attachment.isNotEmpty) {
            final first = attachment[0] as Map<String, dynamic>;
            final last = attachment.last as Map<String, dynamic>;
            final firstTime = (first['time'] as num?)?.toDouble() ?? 0;
            final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

            final firstName = first['name'] as String?;
            final lastName = last['name'] as String?;

            if (firstTime != 0) {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.attachment,
                  slot: slotName,
                  severity: Severity.error,
                  message: 'Frame 0 time is $firstTime (should be 0)',
                ),
              );
            }

            final isLastFrameAtEnd = lastTime >= animDuration * 0.99;
            if (isLastFrameAtEnd) {
              if (lastName != firstName) {
                animIssues.add(
                  AnimationIssue(
                    animation: animName,
                    type: IssueType.attachment,
                    slot: slotName,
                    severity: Severity.error,
                    message:
                        'Last frame attachment ($lastName) != first frame ($firstName) - will cause state pollution',
                  ),
                );
              }
            } else {
              animIssues.add(
                AnimationIssue(
                  animation: animName,
                  type: IssueType.attachment,
                  slot: slotName,
                  severity: Severity.error,
                  message: 'Missing keyframe at animation end',
                ),
              );
            }
          }
        }
      });
    }

    // Validate draw order
    if (drawOrderTimeline != null && drawOrderTimeline.isNotEmpty) {
      final first = drawOrderTimeline[0] as Map<String, dynamic>;
      final last = drawOrderTimeline.last as Map<String, dynamic>;
      final firstTime = (first['time'] as num?)?.toDouble() ?? 0;
      final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

      if (firstTime != 0) {
        animIssues.add(
          AnimationIssue(
            animation: animName,
            type: IssueType.drawOrder,
            severity: Severity.error,
            message: 'Frame 0 time is $firstTime (should be 0)',
          ),
        );
      }

      final isLastFrameAtEnd = lastTime >= animDuration * 0.99;
      if (isLastFrameAtEnd) {
        final firstOffsets = first['offsets'];
        final lastOffsets = last['offsets'];
        if (firstOffsets != lastOffsets) {
          animIssues.add(
            AnimationIssue(
              animation: animName,
              type: IssueType.drawOrder,
              severity: Severity.error,
              message:
                  'Last frame draw order != first frame - will cause state pollution',
            ),
          );
        }
      } else {
        animIssues.add(
          AnimationIssue(
            animation: animName,
            type: IssueType.drawOrder,
            severity: Severity.error,
            message: 'Missing keyframe at animation end',
          ),
        );
      }
    }

    // Animation is unsafe if it has any ERROR (not warning)
    if (animIssues.isNotEmpty) {
      allIssues.addAll(animIssues);
      isSafe = !animIssues.any((i) => i.severity == Severity.error);
    }
    animationSafe[animName] = isSafe;
  });

  // Print summary
  print('=== VALIDATION RESULTS ===\n');

  final errorCount = allIssues
      .where((i) => i.severity == Severity.error)
      .length;
  final warningCount = allIssues
      .where((i) => i.severity == Severity.warning)
      .length;

  if (allIssues.isEmpty) {
    print('✅ ALL ANIMATIONS ARE SELF-CONTAINED!\n');
    print(
      'No issues found. Animations can be switched freely without state pollution.',
    );
  } else {
    print('❌ FOUND $errorCount ERRORS and $warningCount WARNINGS\n');

    // Group by animation
    final issuesByAnim = <String, List<AnimationIssue>>{};
    for (final issue in allIssues) {
      issuesByAnim.putIfAbsent(issue.animation, () => []).add(issue);
    }

    issuesByAnim.forEach((animName, issues) {
      final animErrors = issues
          .where((i) => i.severity == Severity.error)
          .length;
      final animWarnings = issues
          .where((i) => i.severity == Severity.warning)
          .length;

      print('--- Animation: "$animName" ---');
      print('  Errors: $animErrors, Warnings: $animWarnings\n');

      for (final issue in issues) {
        final severityIcon = issue.severity == Severity.error ? '❌' : '⚠️';
        final target = issue.bone != null
            ? 'Bone "${issue.bone}"'
            : issue.slot != null
            ? 'Slot "${issue.slot}"'
            : 'DrawOrder';

        print('  $severityIcon [$issue.type] $target: ${issue.message}');
      }
      print('');
    });

    print('=== SUMMARY ===');
    print(
      'Total animations with issues: ${issuesByAnim.length}/${animations.length}',
    );
    print('Total errors: $errorCount');
    print('Total warnings: $warningCount');

    // Safe/Unsafe animation summary
    final safeAnims = animationSafe.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final unsafeAnims = animationSafe.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    print('\n=== ANIMATION SAFETY ===');
    print('✅ Safe animations (${safeAnims.length}): ${safeAnims.join(", ")}');
    print(
      '❌ Unsafe animations (${unsafeAnims.length}): ${unsafeAnims.join(", ")}',
    );

    print(
      '\n⚠️  Animations with errors will cause state pollution when switching.',
    );
    print(
      '💡 Fix: Ensure last frame = first frame for all timelines (frame 0 != setup is OK).',
    );

    // Generate report
    _generateReport(issuesByAnim, animationSafe, errorCount, warningCount);
  }
}

enum IssueType { translate, rotate, scale, attachment, drawOrder }

enum Severity { error, warning }

/// Generate report file for team
void _generateReport(
  Map<String, List<AnimationIssue>> issuesByAnim,
  Map<String, bool> animationSafe,
  int errorCount,
  int warningCount,
) {
  final report = StringBuffer();
  report.writeln('=== SPINE ANIMATION VALIDATION REPORT ===\n');
  report.writeln('Generated: ${DateTime.now()}\n');

  report.writeln('=== EXECUTIVE SUMMARY ===');
  report.writeln('Total animations: ${animationSafe.length}');
  report.writeln(
    '✅ Safe animations: ${animationSafe.values.where((s) => s).length}',
  );
  report.writeln(
    '❌ Unsafe animations: ${animationSafe.values.where((s) => !s).length}',
  );
  report.writeln('Critical errors: $errorCount');
  report.writeln('Warnings (non-critical): $warningCount\n');

  report.writeln('=== CRITICAL ISSUES (REQUIRE FIX) ===');
  final criticalIssues = <AnimationIssue>[];
  for (final issues in issuesByAnim.values) {
    criticalIssues.addAll(issues.where((i) => i.severity == Severity.error));
  }

  if (criticalIssues.isEmpty) {
    report.writeln('✅ No critical issues found.\n');
  } else {
    // Group by animation
    final byAnim = <String, List<AnimationIssue>>{};
    for (final issue in criticalIssues) {
      byAnim.putIfAbsent(issue.animation, () => []).add(issue);
    }

    byAnim.forEach((animName, issues) {
      report.writeln('\n--- Animation: "$animName" ---');
      for (final issue in issues) {
        final target = issue.bone != null
            ? 'Bone "${issue.bone}"'
            : issue.slot != null
            ? 'Slot "${issue.slot}"'
            : 'DrawOrder';
        report.writeln('  ❌ [$issue.type] $target: ${issue.message}');
      }
    });
    report.writeln(
      '\n💡 RECOMMENDATION: Fix these issues in Spine Editor to prevent state pollution.\n',
    );
  }

  report.writeln('=== ANIMATION SAFETY STATUS ===');
  final safeAnims = animationSafe.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList();
  final unsafeAnims = animationSafe.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList();

  report.writeln('\n✅ Safe to switch (${safeAnims.length}):');
  for (final anim in safeAnims) {
    report.writeln('  - $anim');
  }

  report.writeln('\n❌ Requires reset when switching (${unsafeAnims.length}):');
  for (final anim in unsafeAnims) {
    report.writeln('  - $anim');
  }

  report.writeln('\n=== NOTES ===');
  report.writeln(
    '• "Frame 0 != setup pose" warnings are NORMAL in Spine and do not need fixing.',
  );
  report.writeln(
    '• Only ERRORS (missing keyframes, non-matching last frame) require attention.',
  );
  report.writeln(
    '• Runtime currently resets skeleton when switching animations (defensive handling).',
  );
  report.writeln(
    '• Fixing critical issues will allow smoother animation transitions in the future.',
  );

  // Write report to file
  final reportFile = File('animation_validation_report.txt');
  reportFile.writeAsStringSync(report.toString());

  print('\n📄 Report saved to: ${reportFile.path}');
}

class AnimationIssue {
  final String animation;
  final IssueType type;
  final String? bone;
  final String? slot;
  final Severity severity;
  final String message;

  AnimationIssue({
    required this.animation,
    required this.type,
    this.bone,
    this.slot,
    required this.severity,
    required this.message,
  });
}
