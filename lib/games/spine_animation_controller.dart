import 'package:spine38_runtime/spine38.dart';
import 'package:flutter/foundation.dart';

/// Helper class để quản lý animation switching an toàn
/// 
/// Giải quyết vấn đề: Animation "bẩn" làm nhiễm state khi chuyển đổi
/// 
/// CÁCH HOẠT ĐỘNG:
/// - Mỗi lần chuyển animation → reset skeleton về setup pose
/// - Đảm bảo animation mới chạy trên state sạch
/// - Không cần fix animation data ngay
/// 
/// Usage:
/// ```dart
/// final controller = SpineAnimationController(spine);
/// controller.playAnimation('run', loop: true);
/// controller.playAnimation('jump', loop: false);
/// ```
class SpineAnimationController {
  final SpineComponent spine;
  String? _currentAnimation;
  bool _currentLoop = false;

  SpineAnimationController(this.spine);

  /// Play animation với reset skeleton (an toàn)
  /// 
  /// [name] - Tên animation
  /// [loop] - Có loop không
  /// [resetBeforePlay] - Reset skeleton trước khi play (mặc định: true)
  void playAnimation(
    String name, {
    bool loop = false,
    bool resetBeforePlay = true,
  }) {
    if (_currentAnimation == name && _currentLoop == loop) {
      // Đang chạy animation này rồi, không cần làm gì
      return;
    }

    if (resetBeforePlay) {
      // Reset skeleton về setup pose để tránh state pollution
      spine.setToSetupPose();
      debugPrint('[SpineAnimationController] Reset skeleton to setup pose before playing: $name');
    }

    // Play animation mới
    spine.setAnimation(track: 0, name: name, loop: loop);
    _currentAnimation = name;
    _currentLoop = loop;

    debugPrint('[SpineAnimationController] Playing animation: $name (loop: $loop)');
  }

  /// Stop animation và reset về setup pose
  void stopAnimation() {
    spine.setToSetupPose();
    _currentAnimation = null;
    _currentLoop = false;
    debugPrint('[SpineAnimationController] Stopped animation, reset to setup pose');
  }

  /// Get animation hiện tại
  String? get currentAnimation => _currentAnimation;

  /// Check xem có đang chạy animation không
  bool get isPlaying => _currentAnimation != null;
}

