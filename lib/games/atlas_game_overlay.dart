import 'package:flutter/material.dart';
import 'atlas_game.dart';

/// Overlay widget để chọn animation
class AnimationSelectorOverlay extends StatefulWidget {
  final AtlasGame game;

  const AnimationSelectorOverlay({
    super.key,
    required this.game,
  });

  @override
  State<AnimationSelectorOverlay> createState() =>
      _AnimationSelectorOverlayState();
}

class _AnimationSelectorOverlayState extends State<AnimationSelectorOverlay> {
  String? _currentAnimation;

  @override
  void initState() {
    super.initState();
    // Lấy animation hiện tại
    if (widget.game.spine != null) {
      _currentAnimation = widget.game.spine!.currentAnimation;
    }
  }

  void _onAnimationSelected(String animationName) {
    final controller = widget.game.animationController;
    if (controller != null) {
      if (widget.game.showAnimation) {
        // Chế độ Animation: chạy animation với loop (an toàn, có reset)
        controller.playAnimation(animationName, loop: true);
      } else {
        // Chế độ Pose: hiển thị frame đầu tiên của animation (không loop, không reset)
        widget.game.setAnimationPose(animationName);
      }
      setState(() {
        _currentAnimation = animationName;
      });
    }
  }
  
  void _onToggleAnimation() {
    widget.game.toggleAnimation();
    setState(() {
      if (widget.game.spine != null) {
        _currentAnimation = widget.game.spine!.currentAnimation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spine = widget.game.spine;
    if (spine == null) {
      return const SizedBox.shrink();
    }

    final animations = spine.animationNames;
    if (animations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button toggle animation/setup pose
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: _onToggleAnimation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.game.showAnimation
                        ? Colors.green[700]
                        : Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    widget.game.showAnimation ? 'Animate' : 'Pose',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Animation buttons
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: animations.map((animName) {
                      final isSelected = _currentAnimation == animName;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: () => _onAnimationSelected(animName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? Colors.blue
                                : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            animName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

