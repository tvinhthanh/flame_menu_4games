import 'dart:io';
import 'dart:convert';

/// Script để điều chỉnh skeleton bounds trong JSON
/// 
/// Skeleton bounds (x, y, width, height) quyết định:
/// - Component size
/// - Origin position (translate offset)
/// - Vị trí hiển thị trên màn hình
/// 
/// Atlas chỉ ảnh hưởng texture mapping, KHÔNG ảnh hưởng vị trí skeleton.
/// 
/// Usage: dart adjust_skeleton_bounds.dart
void main() async {
  final file = File('assets/spine/alien-pro.json');
  if (!await file.exists()) {
    print('Error: File not found: ${file.path}');
    return;
  }

  print('=== ADJUST SKELETON BOUNDS ===\n');

  final content = await file.readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;

  final skeleton = json['skeleton'] as Map<String, dynamic>;
  
  print('Current skeleton bounds:');
  print('  x: ${skeleton['x']}');
  print('  y: ${skeleton['y']}');
  print('  width: ${skeleton['width']}');
  print('  height: ${skeleton['height']}\n');

  // Có thể điều chỉnh ở đây:
  // - x, y: offset của skeleton (ảnh hưởng đến translate)
  // - width, height: kích thước skeleton (ảnh hưởng đến component size)
  
  // Ví dụ: Để căn giữa tốt hơn, có thể điều chỉnh x, y
  // Hoặc để scale khác, có thể điều chỉnh width, height
  
  print('Để điều chỉnh, sửa các giá trị trong script này:');
  print('  skeleton[\'x\'] = ... (offset X)');
  print('  skeleton[\'y\'] = ... (offset Y)');
  print('  skeleton[\'width\'] = ... (component width)');
  print('  skeleton[\'height\'] = ... (component height)\n');
  
  print('Lưu ý:');
  print('  - x, y thường là MIN bounds của tất cả attachments');
  print('  - width, height = MAX bounds - MIN bounds');
  print('  - Runtime sẽ translate(-x, -y) để đưa origin về (0,0)');
  print('  - Component size = width x height\n');
  
  // Uncomment để apply changes:
  // skeleton['x'] = -191.3;  // Điều chỉnh offset X
  // skeleton['y'] = -4.51;   // Điều chỉnh offset Y
  // skeleton['width'] = 368.26;  // Điều chỉnh width
  // skeleton['height'] = 384.69; // Điều chỉnh height
  
  // Write back (only if changes were made)
  // final encoder = JsonEncoder.withIndent('    ');
  // final fixedJson = encoder.convert(json);
  // await file.writeAsString(fixedJson);
  // print('File saved to: ${file.path}');
  
  print('Script ready. Uncomment lines above to apply changes.');
}

