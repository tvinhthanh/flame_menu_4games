// spritesheet_utils.dart
import 'dart:ui' as ui;
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

class SheetInfo {
  final int cols;
  final int rows;
  final double tile;
  const SheetInfo(this.cols, this.rows, this.tile);
}

SheetInfo sheetInfo(ui.Image image, {double tile = 32}) {
  final cols = (image.width  / tile).floor();
  final rows = (image.height / tile).floor();
  return SheetInfo(cols, rows, tile);
}

/// Lấy sprite 32x32 từ asset theo toạ độ 1-based (x,y)
Future<Sprite> spriteAtAsset(
  Images images,
  String assetPath, {
  required int gridX,
  required int gridY,
  double tile = 32,
}) async {
  final image = await images.load(assetPath);
  return spriteAtImage(image, gridX: gridX, gridY: gridY, tile: tile);
}

/// Lấy sprite từ image đã load sẵn (32x32 mặc định)
Sprite spriteAtImage(
  ui.Image image, {
  required int gridX,
  required int gridY,
  double tile = 32,
}) {
  final info = sheetInfo(image, tile: tile); // -> 32 cols, 64 rows với 1024x2048
  final col0 = gridX - 1; // 0-based
  final row0 = gridY - 1;

  if (gridX < 1 || gridY < 1 || gridX > info.cols || gridY > info.rows) {
    throw RangeError(
      'Ô ($gridX,$gridY) vượt ngoài sheet: ${info.cols} cột × ${info.rows} hàng (tile=$tile).',
    );
  }

  final sheet = SpriteSheet(image: image, srcSize: Vector2.all(tile));
  return sheet.getSprite(row0, col0);
}
