import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:spine38_runtime/spine38.dart';
import 'spine_animation_controller.dart';

class AtlasGame extends FlameGame {
  SpineComponent? spine;
  SpineAnimationController? _animationController;
  static const double downPx = 60;
  bool _showAnimation =
      true; // Tùy chọn hiển thị animation (true) hoặc setup pose (false)

  bool get showAnimation => _showAnimation;

  /// Get animation controller (safe animation switching)
  SpineAnimationController? get animationController => _animationController;

  /// Toggle hiển thị animation hoặc setup pose
  void toggleAnimation() {
    _showAnimation = !_showAnimation;
    if (_animationController != null) {
      if (_showAnimation) {
        // Bật lại animation
        final availableAnims = spine!.animationNames;
        if (availableAnims.isNotEmpty) {
          final defaultAnim = availableAnims.contains('walking')
              ? 'walking'
              : availableAnims.contains('run')
              ? 'run'
              : availableAnims.first;
          _animationController!.playAnimation(defaultAnim, loop: true);
          debugPrint('[AtlasGame] Animation enabled: $defaultAnim');
        }
      } else {
        // Tắt animation, chỉ hiển thị setup pose
        _animationController!.stopAnimation();
        debugPrint('[AtlasGame] Animation disabled, showing setup pose');
      }
    }
  }

  /// Set animation ở frame đầu tiên (không loop) - dùng cho chế độ Pose
  void setAnimationPose(String animationName) {
    if (_animationController != null) {
      // Set animation nhưng không loop - sẽ hiển thị frame đầu tiên
      // Không reset để giữ pose của animation
      _animationController!.playAnimation(
        animationName,
        loop: false,
        resetBeforePlay: false,
      );
      debugPrint(
        '[AtlasGame] Set animation pose: $animationName (frame 0, no loop)',
      );
    }
  }

  /// Play animation an toàn (dùng controller)
  void playAnimationSafe(String name, {bool loop = false}) {
    _animationController?.playAnimation(name, loop: loop);
  }

  @override
  bool get debugMode => false; // Tắt debug mode để xóa khung vàng và xanh

  // ========== CODE CŨ: CHẠY ĐỒNG THỜI (ĐANG DÙNG) ==========

  // ========== CODE MỚI: CHẠY LUÂN PHIÊN (TEST) ==========
  // Danh sách animation để chạy luân phiên
  // Mỗi animation có: name, loop, và duration (giây) - nếu null thì dùng duration của animation
  // final List<Map<String, dynamic>> _animations = [
  //   {'name': 'run', 'loop': false, 'duration': 2.0},  // Chạy 2 giây
  //   {'name': 'jump', 'loop': false, 'duration': 1.5}, // Chạy 1.5 giây
  //   {'name': 'hit', 'loop': false, 'duration': 1.0}, // Chạy 1 giây
  //   {'name': 'death', 'loop': false, 'duration': 2.0}, // Chạy 2 giây
  // ];
  // int _currentAnimationIndex = 0;
  // bool _isTransitioning = false;

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Safety: ensure camera is neutral
    camera.viewfinder.zoom = 1.0;

    try {
      debugPrint('[AtlasGame] Loading Spine 3.8 component...');

      spine = await SpineComponent.fromFiles(
        atlas: 'assets/spine/alien-pro.atlas',
        skeleton: 'assets/spine/alien-pro.json',
        scale: 1.0, // real visual scale handled by Flame below
      );

      // ========== CẤU HÌNH HIỆN TẠI ==========
      // - Anchor: center (căn giữa)
      // - Scale: 0.5 (50% kích thước gốc - đã giảm để render nhỏ hơn)
      // - Angle: 0.0 (không lật, hướng ban đầu)
      // - Position: center screen (căn giữa màn hình)
      //
      // LƯU Ý: Để điều chỉnh vị trí/hiển thị:
      // - Chỉnh skeleton bounds (x, y, width, height) trong JSON
      // - Atlas chỉ ảnh hưởng texture mapping, KHÔNG ảnh hưởng vị trí skeleton
      spine!
        ..anchor = Anchor
            .center // Use center anchor since skeleton origin is at (0,0) after translate
        ..scale =
            Vector2.all(0.5) // Scale nhỏ lại 50% để render nhỏ hơn
        ..angle = 0.0; // Không lật (0 độ) - lật ngược từ 180 độ
      // ..angle = 0.0; // Quay phải: tăng góc (dương = quay ngược chiều kim đồng hồ)
      // ..angle = 1.5708; // 90 độ = quay phải

      // Position once size is known - center skeleton on screen
      // Skeleton draws from (0,0) in component space after translate(-skeletonX, -skeletonY)
      // Component size = skeletonWidth x skeletonHeight
      // With center anchor, position directly at screen center
      // Wait for component size to be calculated first
      Future.microtask(() {
        if (spine != null && spine!.isMounted) {
          final skeletonX = spine!.skeletonData?.skeletonX ?? 0;
          final skeletonY = spine!.skeletonData?.skeletonY ?? 0;
          final skeletonW = spine!.skeletonData?.skeletonWidth ?? 0;
          final skeletonH = spine!.skeletonData?.skeletonHeight ?? 0;

          debugPrint(
            '[AtlasGame] Skeleton bounds: x=$skeletonX, y=$skeletonY, w=$skeletonW, h=$skeletonH',
          );
          debugPrint('[AtlasGame] Component size: ${spine!.size}');
          debugPrint('[AtlasGame] Screen size: $size');

          // Center on screen, accounting for skeleton offset
          final targetPos = size / 2;
          spine!.position = targetPos;
          debugPrint('[AtlasGame] Set position to: $targetPos');
        }
      });

      add(spine!);

      // Initialize animation controller (safe animation switching)
      _animationController = SpineAnimationController(spine!);
      debugPrint('[AtlasGame] Animation controller initialized');

      debugPrint('[AtlasGame] Spine added');
      debugPrint('[AtlasGame] size=${spine!.size}');
      debugPrint('[AtlasGame] position=${spine!.position}');
      debugPrint('[AtlasGame] anchor=${spine!.anchor}');
      debugPrint(
        '[AtlasGame] skeleton bounds: x=${spine!.skeletonData?.skeletonX}, y=${spine!.skeletonData?.skeletonY}, w=${spine!.skeletonData?.skeletonWidth}, h=${spine!.skeletonData?.skeletonHeight}',
      );
      debugPrint(
        '[AtlasGame] component position: ${spine!.position}, size: ${spine!.size}, anchor: ${spine!.anchor}',
      );
      debugPrint(
        '[AtlasGame] available animations: ${spine!.animationNames.join(", ")}',
      );

      // ========== ANIMATION CONTROL (Game-level logic) ==========
      // Animation control should be here in AtlasGame, not in SpineComponent
      // SpineComponent only handles rendering based on animation state

      // Set initial animation (chỉ nếu _showAnimation = true)
      if (_showAnimation) {
        final availableAnims = spine!.animationNames;
        if (availableAnims.isNotEmpty) {
          // Try to find a good default animation
          final defaultAnim = availableAnims.contains('walking')
              ? 'walking'
              : availableAnims.contains('run')
              ? 'run'
              : availableAnims.first;
          _animationController?.playAnimation(defaultAnim, loop: true);
          debugPrint('[AtlasGame] Started animation: $defaultAnim');
        }
      } else {
        // Hiển thị pose của animation "run" (frame đầu tiên, không loop)
        final availableAnims = spine!.animationNames;
        if (availableAnims.contains('run')) {
          setAnimationPose('run');
          debugPrint('[AtlasGame] Showing run pose (frame 0, no loop)');
        } else if (availableAnims.isNotEmpty) {
          setAnimationPose(availableAnims.first);
          debugPrint(
            '[AtlasGame] Showing ${availableAnims.first} pose (frame 0, no loop)',
          );
        } else {
          spine!.setToSetupPose();
          debugPrint('[AtlasGame] Showing setup pose (no animation)');
        }
      }

      // ========== CODE MỚI: CHẠY LUÂN PHIÊN (TEST) ==========
      // Bắt đầu animation đầu tiên
      // _startNextAnimation();

      debugPrint('[AtlasGame] Animation requested');
    } catch (e, stackTrace) {
      debugPrint('[AtlasGame] ERROR: $e');
      debugPrint(stackTrace.toString());

      add(
        TextComponent(
          text: 'Spine load error:\n$e',
          textRenderer: TextPaint(
            style: const TextStyle(color: Colors.red, fontSize: 18),
          ),
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ========== CODE MỚI: CHẠY LUÂN PHIÊN (TEST) ==========
    // Kiểm tra và chuyển animation luân phiên
    // if (spine != null && spine!.isMounted && !_isTransitioning) {
    //   final currentAnim = _animations[_currentAnimationIndex];
    //   final animName = currentAnim['name'] as String;
    //
    //   // Kiểm tra nếu đang chạy animation hiện tại
    //   if (spine!.currentAnimation == animName) {
    //     // Lấy duration từ config hoặc từ animation data
    //     final configDuration = currentAnim['duration'] as double?;
    //     final animDuration = configDuration ??
    //         (spine!.skeletonData?.findAnimation(animName)?.duration ?? 0);
    //
    //     final elapsed = spine!.animationTime;
    //
    //     // Nếu đã chạy đủ thời gian, chuyển sang animation tiếp theo
    //     if (elapsed >= animDuration) {
    //       _switchToNextAnimation();
    //     }
    //   }
    // }
  }

  // ========== CODE MỚI: CHẠY LUÂN PHIÊN (TEST) ==========
  /// Bắt đầu animation tiếp theo trong danh sách
  // void _startNextAnimation() {
  //   if (_animations.isEmpty || spine == null) return;
  //
  //   final anim = _animations[_currentAnimationIndex];
  //   final animName = anim['name'] as String;
  //   final loop = anim['loop'] as bool? ?? false;
  //
  //   spine!.setAnimation(track: 0, name: animName, loop: loop);
  //   _isTransitioning = false;
  //
  //   debugPrint('[AtlasGame] Started animation: $animName (index: $_currentAnimationIndex/${_animations.length - 1})');
  // }

  /// Chuyển sang animation tiếp theo
  // void _switchToNextAnimation() {
  //   if (_isTransitioning) return;
  //
  //   _isTransitioning = true;
  //   _currentAnimationIndex = (_currentAnimationIndex + 1) % _animations.length;
  //
  //   // Đợi một frame rồi chuyển animation
  //   Future.delayed(const Duration(milliseconds: 50), () {
  //     _startNextAnimation();
  //   });
  // }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    if (spine != null && spine!.isMounted) {
      // Center skeleton on screen (using center anchor)
      final skeletonW = spine!.skeletonData?.skeletonWidth ?? 0;
      final skeletonH = spine!.skeletonData?.skeletonHeight ?? 0;

      // Center on screen
      final targetPos = newSize / 2;
      spine!.position = targetPos;
      debugPrint(
        '[AtlasGame] onGameResize: Set position to: $targetPos (newSize: $newSize, skeleton: ${skeletonW}x${skeletonH})',
      );
    }
  }
}
