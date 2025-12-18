import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_spine/flame_spine.dart';

class AtlasGame extends FlameGame {
  SpineComponent? spineboy;                 // nullable, không dùng late
  static const double downPx = 60;

  @override
  Future<void> onLoad() async {
    final comp = await SpineComponent.fromAssets(
      atlasFile: 'assets/spine/spineboy-pma.atlas',
      skeletonFile: 'assets/spine/spineboy-pma.json',
    );

    comp
      ..anchor = Anchor.center
      ..scale = Vector2.all(0.45);
    comp.animationState.setAnimationByName(0, 'walk', true);

    spineboy = comp;                        // gán trước
    add(comp);

    _placeIfReady();                        // thử đặt lần nữa sau khi có comp
  }

  void _placeIfReady() {
    final c = spineboy;
    if (c == null || size.isZero()) return; // size chưa sẵn sàng hoặc comp chưa tạo
    c.position = size / 2 + Vector2(0, downPx);
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    _placeIfReady();                        // mỗi lần resize thì đặt lại
  }
}
