import 'dart:io';
import 'dart:convert';

/// Fix animation "death" để self-contained
/// 
/// Sửa 2 lỗi:
/// 1. Bone "eye-veins-controller": Thêm keyframe cuối = frame 0
/// 2. Draw order: Reset về default ở frame cuối
/// 
/// Usage: dart fix_death_animation.dart
void main() async {
  final file = File('assets/spine/alien-pro.json');
  if (!await file.exists()) {
    print('Error: File not found: ${file.path}');
    return;
  }

  print('=== FIX DEATH ANIMATION ===\n');
  print('File: ${file.path}\n');

  final content = await file.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;

  final animations = json['animations'] as Map<String, dynamic>;
  
  if (!animations.containsKey('death')) {
    print('❌ Error: Animation "death" not found!');
    return;
  }

  final deathAnim = animations['death'] as Map<String, dynamic>;
  final bones = deathAnim['bones'] as Map<String, dynamic>?;
  final drawOrderTimeline = deathAnim['drawOrder'] as List<dynamic>?;

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
      if (bone.containsKey('translate')) findMaxTime(bone['translate'] as List<dynamic>);
      if (bone.containsKey('rotate')) findMaxTime(bone['rotate'] as List<dynamic>);
      if (bone.containsKey('scale')) findMaxTime(bone['scale'] as List<dynamic>);
    });
  }
  if (drawOrderTimeline != null) {
    findMaxTime(drawOrderTimeline);
  }

  if (animDuration == 0) animDuration = 1.0;

  print('Animation duration: $animDuration\n');

  int fixCount = 0;

  // FIX 1: Bone "eye-veins-controller" - thêm keyframe cuối
  if (bones != null && bones.containsKey('eye-veins-controller')) {
    final eyeVeinsBone = bones['eye-veins-controller'] as Map<String, dynamic>;
    
    // Check translate timeline
    if (eyeVeinsBone.containsKey('translate')) {
      final translate = eyeVeinsBone['translate'] as List<dynamic>;
      if (translate.isNotEmpty) {
        final first = translate[0] as Map<String, dynamic>;
        final last = translate.last as Map<String, dynamic>;
        final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

        final firstX = (first['x'] as num?)?.toDouble() ?? 0;
        final firstY = (first['y'] as num?)?.toDouble() ?? 0;

        // Check if last frame is at end
        if (lastTime < animDuration * 0.99) {
          // Add keyframe at end
          translate.add({
            'time': animDuration,
            'x': firstX,
            'y': firstY,
          });
          fixCount++;
          print('✅ Fixed: Added keyframe at end for bone "eye-veins-controller" translate');
          print('   Time: $animDuration, x: $firstX, y: $firstY');
        } else {
          // Last frame exists but might not match first
          final lastX = (last['x'] as num?)?.toDouble();
          final lastY = (last['y'] as num?)?.toDouble();
          if (lastX == null || lastX != firstX || lastY == null || lastY != firstY) {
            last['x'] = firstX;
            last['y'] = firstY;
            fixCount++;
            print('✅ Fixed: Updated last frame for bone "eye-veins-controller" translate');
            print('   Last frame now: x=$firstX, y=$firstY');
          }
        }
      }
    }

    // Check rotate timeline
    if (eyeVeinsBone.containsKey('rotate')) {
      final rotate = eyeVeinsBone['rotate'] as List<dynamic>;
      if (rotate.isNotEmpty) {
        final first = rotate[0] as Map<String, dynamic>;
        final last = rotate.last as Map<String, dynamic>;
        final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

        final firstAngle = (first['angle'] as num?)?.toDouble() ?? 0;

        if (lastTime < animDuration * 0.99) {
          rotate.add({
            'time': animDuration,
            'angle': firstAngle,
          });
          fixCount++;
          print('✅ Fixed: Added keyframe at end for bone "eye-veins-controller" rotate');
          print('   Time: $animDuration, angle: $firstAngle');
        } else {
          final lastAngle = (last['angle'] as num?)?.toDouble();
          if (lastAngle == null || lastAngle != firstAngle) {
            last['angle'] = firstAngle;
            fixCount++;
            print('✅ Fixed: Updated last frame for bone "eye-veins-controller" rotate');
            print('   Last frame now: angle=$firstAngle');
          }
        }
      }
    }

    // Check scale timeline
    if (eyeVeinsBone.containsKey('scale')) {
      final scale = eyeVeinsBone['scale'] as List<dynamic>;
      if (scale.isNotEmpty) {
        final first = scale[0] as Map<String, dynamic>;
        final last = scale.last as Map<String, dynamic>;
        final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

        final firstX = (first['x'] as num?)?.toDouble() ?? 1;
        final firstY = (first['y'] as num?)?.toDouble() ?? 1;

        if (lastTime < animDuration * 0.99) {
          scale.add({
            'time': animDuration,
            'x': firstX,
            'y': firstY,
          });
          fixCount++;
          print('✅ Fixed: Added keyframe at end for bone "eye-veins-controller" scale');
          print('   Time: $animDuration, x: $firstX, y: $firstY');
        } else {
          final lastX = (last['x'] as num?)?.toDouble();
          final lastY = (last['y'] as num?)?.toDouble();
          if (lastX == null || lastX != firstX || lastY == null || lastY != firstY) {
            last['x'] = firstX;
            last['y'] = firstY;
            fixCount++;
            print('✅ Fixed: Updated last frame for bone "eye-veins-controller" scale');
            print('   Last frame now: x=$firstX, y=$firstY');
          }
        }
      }
    }
  } else {
    print('⚠️  Warning: Bone "eye-veins-controller" not found in death animation');
  }

  // FIX 2: Draw order - reset về default ở frame cuối
  if (drawOrderTimeline != null && drawOrderTimeline.isNotEmpty) {
    final first = drawOrderTimeline[0] as Map<String, dynamic>;
    final last = drawOrderTimeline.last as Map<String, dynamic>;
    final lastTime = (last['time'] as num?)?.toDouble() ?? 0;

    final firstOffsets = first['offsets'];

    // Check if last frame is at end
    if (lastTime < animDuration * 0.99) {
      // Add keyframe at end with default order
      drawOrderTimeline.add({
        'time': animDuration,
        'offsets': firstOffsets,
      });
      fixCount++;
      print('✅ Fixed: Added keyframe at end for draw order');
      print('   Time: $animDuration, reset to default order');
    } else {
      // Last frame exists, check if it matches first
      final lastOffsets = last['offsets'];
      if (lastOffsets != firstOffsets) {
        last['offsets'] = firstOffsets;
        fixCount++;
        print('✅ Fixed: Reset draw order at last frame to match first frame');
      }
    }
  } else {
    print('⚠️  Warning: Draw order timeline not found in death animation');
  }

  // Write fixed JSON
  if (fixCount > 0) {
    final encoder = JsonEncoder.withIndent('    ');
    final fixedJson = encoder.convert(json);
    await file.writeAsString(fixedJson);

    print('\n=== SUMMARY ===');
    print('✅ Fixed $fixCount issues in animation "death"');
    print('📄 File saved to: ${file.path}');
    print('\n💡 Animation "death" is now self-contained!');
  } else {
    print('\n=== SUMMARY ===');
    print('✅ No issues found to fix (animation may already be fixed)');
  }
}

