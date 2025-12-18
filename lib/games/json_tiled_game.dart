import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'spritesheet_utils.dart';

class RiveOnlyGame extends FlameGame with TapCallbacks {
  final String spriteAsset = 'BeNgoi2.png';

  SpriteComponent? _centerSprite;
  late ui.Image _image;
  late int _cols;
  late int _rows;
  late double _tileWidth;
  late double _tileHeight;

  _RandomButton? _randomBtn;
  @override
  Color backgroundColor() => Colors.white;
  @override
  Future<void> onLoad() async {
    _image = await images.load(spriteAsset);

    // sheet 2x2
    _cols = 2;
    _rows = 2;

    // tự tính kích thước tile
    _tileWidth = _image.width / _cols;
    _tileHeight = _image.height / _rows;

    // sprite mặc định (ví dụ 0,0)
    final defaultSprite = spriteAtImageCustom(
      _image,
      gridX: 0,
      gridY: 0,
      tileW: _tileWidth,
      tileH: _tileHeight,
    );
    _centerSprite = SpriteComponent(
      sprite: defaultSprite,
      size: Vector2(200, 200 * (_tileHeight / _tileWidth)), // giữ tỉ lệ
      anchor: Anchor.center,
    );
    add(_centerSprite!);

    // nút Random
    _randomBtn = _RandomButton(
      label: 'Random',
      onPressed: () {
        final rnd = math.Random();
        final rx = rnd.nextInt(_cols);
        final ry = rnd.nextInt(_rows);
        showTile(rx, ry);
      },
    );
    add(_randomBtn!);
  }

  void showTile(int x, int y) {
    try {
      final sprite = spriteAtImageCustom(
        _image,
        gridX: x,
        gridY: y,
        tileW: _tileWidth,
        tileH: _tileHeight,
      );
      _centerSprite?.sprite = sprite;
    } catch (e) {
      debugPrint('Error showTile($x,$y): $e');
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _centerSprite?.position = Vector2(canvasSize.x / 2, canvasSize.y - 200);
    _randomBtn
      ?..size = Vector2(160, 60)
      ..anchor = Anchor.bottomCenter
      ..position = Vector2(canvasSize.x / 2, canvasSize.y - 20);
  }
}

/// Hàm mới hỗ trợ tile width/height tuỳ ý
Sprite spriteAtImageCustom(
  ui.Image image, {
  required int gridX,
  required int gridY,
  required double tileW,
  required double tileH,
}) {
  return Sprite(
    image,
    srcPosition: Vector2(gridX * tileW, gridY * tileH),
    srcSize: Vector2(tileW, tileH),
  );
}

class _RandomButton extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onPressed;

  _RandomButton({required this.label, required this.onPressed})
    : super(size: Vector2(160, 60), anchor: Anchor.bottomCenter);

  @override
  void render(Canvas canvas) {
    final rect = toRect();
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // nền trắng
    final bg = Paint()..color = Colors.white;
    canvas.drawRRect(rrect, bg);

    // viền đen
    final border = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, border);

    // chữ đen
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);

    tp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onPressed();
}
