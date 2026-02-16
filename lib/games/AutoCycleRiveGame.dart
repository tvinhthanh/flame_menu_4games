import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_rive/flame_rive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart' as rive;

class AutoCycleRiveGame extends FlameGame with TapDetector {
  static const _filePath = 'assets/rive/TestAdvanced.riv';
  static const _artboardName = 'Artboard';
  static const _smName = 'State Machine 1';

  RiveComponent? _comp;
  rive.Artboard? _artboard;
  rive.StateMachineController? _smController;

  // All State Machine inputs
  List<rive.SMIInput> _inputs = [];
  int _currentInputIndex = 0;
  double _cycleTimer = 0.0;
  static const double _cycleDuration = 3.0; // seconds

  @override
  Color backgroundColor() => const Color(0xFF0B1020);

  @override
  Future<void> onLoad() async {
    debugMode = true;
    camera.viewfinder.anchor = Anchor.center;

    // Load Rive file
    try {
      final bytes = await rootBundle.load(_filePath);
      final file = rive.RiveFile.import(bytes);
      final ab = file.artboardByName(_artboardName) ?? file.mainArtboard;
      ab.advance(0);
      _artboard = ab;

      debugPrint('✅ Loaded artboard: ${ab.name}');
    } catch (e) {
      debugPrint('❌ Failed to load Rive file: $e');
      return;
    }

    // Setup State Machine
    final sm = rive.StateMachineController.fromArtboard(_artboard!, _smName);
    if (sm != null) {
      _artboard!.addController(sm);
      _smController = sm;

      // Collect all inputs
      _inputs = sm.inputs.toList();
      debugPrint('🎮 Found ${_inputs.length} State Machine inputs:');
      for (int i = 0; i < _inputs.length; i++) {
        final input = _inputs[i];
        debugPrint('  [$i] ${input.name} (${input.runtimeType})');
      }

      if (_inputs.isNotEmpty) {
        _setInputState(0); // Start with first input
      }
    } else {
      debugPrint('⚠️ State Machine not found');
    }

    // Create component
    _comp = RiveComponent(
      artboard: _artboard!,
      anchor: Anchor.center,
      size: Vector2.all(400),
      position: size / 2,
      priority: 10,
    );
    add(_comp!);

    // Add status text
    final statusText = TextComponent(
      text: 'Auto-cycling through all animation states\nTap to manual control',
      position: Vector2(10, 30),

      priority: 100,
    );
    add(statusText);
  }

  void _setInputState(int index) {
    if (_inputs.isEmpty || index >= _inputs.length) return;

    _currentInputIndex = index;
    final input = _inputs[index];

    // Reset all inputs first
    for (final inp in _inputs) {
      if (inp is rive.SMIInput<bool>) {
        inp.value = false;
      } else if (inp is rive.SMIInput<double>) {
        inp.value = 0.0;
      }
    }

    // Activate current input
    if (input is rive.SMIInput<bool>) {
      input.value = true;
      debugPrint('🔛 Activated bool input: ${input.name} = true');
    } else if (input is rive.SMIInput<double>) {
      input.value = 1.0;
      debugPrint('🔛 Activated number input: ${input.name} = 1.0');
    } else if (input is rive.SMITrigger) {
      input.fire();
      debugPrint('🔛 Fired trigger: ${input.name}');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_inputs.isEmpty) return;

    _cycleTimer += dt;

    if (_cycleTimer >= _cycleDuration) {
      _cycleTimer = 0.0;
      final nextIndex = (_currentInputIndex + 1) % _inputs.length;
      _setInputState(nextIndex);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    // Manual cycle on tap
    if (_inputs.isNotEmpty) {
      _cycleTimer = 0.0; // Reset timer
      final nextIndex = (_currentInputIndex + 1) % _inputs.length;
      _setInputState(nextIndex);
    }
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    camera.viewfinder.visibleGameSize = s;

    if (_comp != null) {
      _comp!.position = s / 2;
      final target = (s.x < s.y ? s.x : s.y) * 0.8;
      _comp!.size = Vector2.all(target.clamp(300, 700).toDouble());
    }
  }
}
