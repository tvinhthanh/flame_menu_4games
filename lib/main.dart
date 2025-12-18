import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:spine_flutter/spine_flutter.dart';
import 'game_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Spine runtime
  await initSpineFlutter(enableMemoryDebugging: false);

  // Debug: In ra các file Spine JSON đang bundle + 100 ký tự đầu để xem version
  if (kDebugMode) {
    await _debugSpineAssets();
  }

  runApp(const MyApp());
}

Future<void> _debugSpineAssets() async {
  try {
    final raw = await rootBundle.loadString('AssetManifest.json');
    final manifest = (json.decode(raw) as Map).cast<String, dynamic>();
    final spineJsons = manifest.keys
        .where((k) => k.startsWith('assets/spine/') && k.endsWith('.json'))
        .toList()
      ..sort();

    debugPrint('--- Spine JSON assets in bundle ---');
    if (spineJsons.isEmpty) {
      debugPrint('No JSON under assets/spine/ (nếu bạn dùng .skel thì bỏ qua check này).');
      return;
    }
    for (final p in spineJsons) {
      final head = (await rootBundle.loadString(p));
      final preview = head.substring(0, head.length < 100 ? head.length : 100);
      debugPrint('HEAD of $p: $preview'); // cần thấy "spine":"4.2"
    }
  } catch (e, st) {
    debugPrint('debugSpineAssets error: $e\n$st');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flame – 4 Games Menu',
      theme: ThemeData.dark(),
      home: const GameMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
