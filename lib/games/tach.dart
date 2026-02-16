import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;
import 'package:flame_rive/flame_rive.dart';

class TachGame extends FlameGame {
  // CHANGE THIS to your riv file
  static const _file = 'assets/rive/tutien-tach.riv';
  // If you expect a specific artboard name, set it; otherwise leave 'Artboard'
  static const _artboard = 'Artboard';
  // Name of state machine to look for (if any)
  static const _smName = 'State Machine 1';

  // The displayed component
  RiveComponent? _comp;

  // State Machine controller + inputs
  rive.StateMachineController? _smCtrl;
  final Map<String, rive.SMIInput> _smInputs = {};
  // keep lists by type for simple handling
  final List<rive.SMITrigger> _triggers = [];
  final List<rive.SMIBool> _bools = [];
  final List<rive.SMINumber> _numbers = [];

  // Fallback: raw animations list + controller
  final List<String> _anims = [];
  rive.RiveAnimationController? _animCtrl;
  int _animIdx = 0;

  // Fullscreen flag (we always show fullscreen but keep variable if you want toggling)
  bool _isFullscreen = true;

  @override
  Color backgroundColor() => const Color(0xFF0B1020);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    // Initialize decoder (safe to call multiple times)
    try {
      await rive.RiveFile.initialize();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Rive initialize failed: $e\n$st');
      }
    }

    // Load bytes & RiveFile
    final bytes = await rootBundle.load(_file);
    final file = rive.RiveFile.import(bytes);

    // Choose artboard: named or main
    final artboard = _artboard.isNotEmpty
        ? (file.artboardByName(_artboard) ?? file.mainArtboard)
        : file.mainArtboard;

    // Important: advance once (prepares animations)
    artboard.advance(0);

    // Try to get state machine
    _smCtrl = rive.StateMachineController.fromArtboard(artboard, _smName);
    if (_smCtrl != null) {
      artboard.addController(_smCtrl!);

      // collect inputs and categorize them
      for (final input in _smCtrl!.inputs) {
        _smInputs[input.name] = input;
        if (input is rive.SMITrigger) {
          _triggers.add(input);
        } else if (input is rive.SMIBool) {
          _bools.add(input);
        } else if (input is rive.SMINumber) {
          _numbers.add(input);
        }
        if (kDebugMode) {
          debugPrint('[SM input] ${input.name} -> ${input.runtimeType}');
        }
      }

      if (kDebugMode) {
        debugPrint(
          'StateMachine found: $_smName with inputs: ${_smInputs.keys}',
        );
      }

      // Optional: fire a default trigger or set default bool/number
      // _triggers.isNotEmpty ? _triggers.first.fire() : null;
    } else {
      // No state machine — fallback: enumerate all raw animations
      _anims
        ..clear()
        ..addAll(artboard.animations.map((a) => a.name));

      if (_anims.isNotEmpty) {
        _playAnim(0, artboard);
        if (kDebugMode) debugPrint('Raw animations found: $_anims');
      } else {
        if (kDebugMode)
          debugPrint('No state machine and no animations found in artboard.');
      }
    }

    // Create and add component (size will be adjusted in onGameResize to fullscreen)
    _comp = RiveComponent(
      artboard: artboard,
      anchor: Anchor.center,
      size: Vector2.all(300), // temporary; resized in onGameResize
      position: Vector2(size.x / 2, size.y / 2),
      priority: 10,
    );
    add(_comp!);
  }

  // Play a raw animation by index (fallback)
  void _playAnim(int idx, rive.Artboard ab) {
    if (_anims.isEmpty) return;
    if (_animCtrl != null) ab.removeController(_animCtrl!);

    _animIdx = idx % _anims.length;
    final name = _anims[_animIdx];
    final simple = rive.SimpleAnimation(name, mix: 0.2);
    ab.addController(simple);
    _animCtrl = simple;

    if (kDebugMode) debugPrint('Playing raw animation: $name');
  }

  // ---------- Gestures ----------
  @override
  void onTapDown(TapDownEvent _) {
    // If we have state machine, try to handle inputs:
    if (_smCtrl != null) {
      // Prefer named triggers if present (InFire / OutFire)
      final triggerIn = _triggers.firstWhere(
        (t) =>
            t is rive.SMITrigger &&
            (t.name == 'InFire' ||
                t.name == 'In_Fire' ||
                t.name.toLowerCase().contains('in')),
        orElse: () => null as rive.SMITrigger,
      );
      final triggerOut = _triggers.firstWhere(
        (t) =>
            t is rive.SMITrigger &&
            (t.name == 'OutFire' ||
                t.name == 'Out_Fire' ||
                t.name.toLowerCase().contains('out')),
        orElse: () => null as rive.SMITrigger,
      );

      if (triggerIn != null || triggerOut != null) {
        // If both present, alternate (fire Out on tap), else fire whichever exists
        if (triggerOut != null) {
          triggerOut.fire();
          if (kDebugMode) debugPrint('Fired trigger: ${triggerOut.name}');
        } else {
          triggerIn!.fire();
          if (kDebugMode) debugPrint('Fired trigger: ${triggerIn.name}');
        }
        return;
      }

      // No specific In/Out triggers: if any trigger exists, fire the first
      if (_triggers.isNotEmpty) {
        _triggers.first.fire();
        if (kDebugMode) debugPrint('Fired trigger: ${_triggers.first.name}');
        return;
      }

      // If no triggers, toggle first bool if exists
      if (_bools.isNotEmpty) {
        final b = _bools.first;
        b.value = !b.value;
        if (kDebugMode) debugPrint('Toggled bool ${b.name} -> ${b.value}');
        return;
      }

      // If no bools, increment first number (wrap around modestly)
      if (_numbers.isNotEmpty) {
        final n = _numbers.first;
        // increment by 1, clamp/wrap within a sane range (0..10)
        final newVal = ((n.value ?? 0) + 1) % 11;
        n.value = newVal;
        if (kDebugMode) debugPrint('Number ${n.name} -> ${n.value}');
        return;
      }

      // Nothing to control in SM — fallthrough to animation fallback if present
      if (_anims.isNotEmpty && _comp != null) {
        _playAnim((_animIdx + 1) % _anims.length, _comp!.artboard);
      }

      return;
    }

    // No StateMachine: cycle raw animations
    if (_comp != null && _anims.isNotEmpty) {
      _playAnim((_animIdx + 1) % _anims.length, _comp!.artboard);
    }
  }

  @override
  void onDoubleTapDown(TapDownEvent _) {
    // Pause/resume either SM controller or current raw animation controller
    var toggled = false;
    if (_smCtrl != null) {
      _smCtrl!.isActive = !_smCtrl!.isActive;
      toggled = true;
      if (kDebugMode) debugPrint('SM controller isActive=${_smCtrl!.isActive}');
    }
    if (!toggled && _animCtrl != null) {
      _animCtrl!.isActive = !_animCtrl!.isActive;
      if (kDebugMode)
        debugPrint('Anim controller isActive=${_animCtrl!.isActive}');
    }
  }

  // ---------- Layout (fullscreen) ----------
  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);

    // Make visibleGameSize match the viewport
    camera.viewfinder.visibleGameSize = s;

    if (_comp != null) {
      // Fill ~98% of screen to leave tiny padding
      final target = Vector2(s.x * 0.98, s.y * 0.98);
      _comp!
        ..position = Vector2(s.x / 2, s.y / 2)
        ..size = target;
    }
  }
}
