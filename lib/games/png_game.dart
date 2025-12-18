import 'package:flame/camera.dart' show FixedResolutionViewport;
import 'package:flame/components.dart';
import 'package:flame/game.dart';

class PngGame extends FlameGame {
  late SpriteComponent player;
  Vector2 velocity = Vector2(120, 90);

  @override
  Future<void> onLoad() async {
    await images.load('player.png');
    player = SpriteComponent()
      ..sprite = Sprite(images.fromCache('player.png'))
      ..size = Vector2(96, 96)
      ..position = size / 2;
    add(player);
    camera.viewport = FixedResolutionViewport(resolution: Vector2(800, 600));

  }

  @override
  void update(double dt) {
    super.update(dt);
    player.position += velocity * dt;
    // bật tường
    if (player.x <= 0 || player.x + player.width >= size.x) velocity.x *= -1;
    if (player.y <= 0 || player.y + player.height >= size.y) velocity.y *= -1;
  }
}
