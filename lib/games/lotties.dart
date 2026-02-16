import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;
import 'package:flame_rive/flame_rive.dart';

class LottiesGame extends FlameGame {
  // --- FILE 1 ---
  static const _file1 = 'assets/rive/Test1_Title.riv';
  static const _artboard1 = 'Artboard';
  static const _animIn = 'Ani_TitleIn';
  static const _animOut = 'Ani_TitleOut';

  // --- FILE 2 ---
  static const _file2 = 'assets/rive/Test2_LinhHon.riv';
  static const _artboard2 = 'Artboard';
  static const _smName2 = 'State Machine 1';

  // Components
  RiveComponent? _comp1;
  RiveComponent? _comp2;

  // File1 controllers
  rive.RiveAnimationController? _ctrl1;
  final List<String> _testAnims = [];
  int _animIdx = 0;

  // File2: SM controller + inputs
  rive.StateMachineController? _smCtrl2;
  final Map<String, rive.SMIInput> _smInputs2 = {};
  rive.SMITrigger? _inFire;
  rive.SMITrigger? _outFire;

  // fallback raw anims
  rive.RiveAnimationController? _ctrl2;
  final List<String> _file2Anims = [];
  int _anim2Idx = 0;

  @override
  Color backgroundColor() => const Color(0xFF0B1020);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    // === IMPORTANT: initialize Rive decoder once (safe to call repeatedly) ===
    try {
      await rive.RiveFile.initialize();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Rive initialize failed: $e\n$st');
      }
      // proceed anyway; import may still work on some platforms
    }

    // ---------- FILE 1 ----------
    final bytes1 = await rootBundle.load(_file1);
    final file1 = rive.RiveFile.import(bytes1);
    final ab1 = _artboard1.isNotEmpty
        ? (file1.artboardByName(_artboard1) ?? file1.mainArtboard)
        : file1.mainArtboard;
    ab1.advance(0);

    _testAnims
      ..clear()
      ..addAll(
        [
          _animIn,
          _animOut,
        ].where((name) => ab1.animations.any((a) => a.name == name)),
      );

    if (_testAnims.isNotEmpty) {
      _playAnim1(0, ab1);
    }

    _comp1 = RiveComponent(
      artboard: ab1,
      anchor: Anchor.center,
      size: Vector2.all(300),
      position: Vector2(size.x / 2, size.y * 0.35),
      priority: 10,
    );
    add(_comp1!);

    // ---------- FILE 2 ----------
    final bytes2 = await rootBundle.load(_file2);
    final file2 = rive.RiveFile.import(bytes2);
    final ab2 = _artboard2.isNotEmpty
        ? (file2.artboardByName(_artboard2) ?? file2.mainArtboard)
        : file2.mainArtboard;
    ab2.advance(0);

    // Try State Machine
    _smCtrl2 = rive.StateMachineController.fromArtboard(ab2, _smName2);
    if (_smCtrl2 != null) {
      ab2.addController(_smCtrl2!);

      for (final input in _smCtrl2!.inputs) {
        _smInputs2[input.name] = input;
        if (input.name == "InFire" && input is rive.SMITrigger) {
          _inFire = input;
        } else if (input.name == "OutFire" && input is rive.SMITrigger) {
          _outFire = input;
        }
      }

      if (kDebugMode) {
        debugPrint('[File2] Inputs: ${_smInputs2.keys}');
      }

      // Auto chạy vào khi load (nếu muốn)
      _inFire?.fire();
    } else {
      // fallback: raw animations
      _file2Anims
        ..clear()
        ..addAll(ab2.animations.map((a) => a.name));
      if (_file2Anims.isNotEmpty) {
        _playAnim2(0, ab2);
      } else {
        if (kDebugMode) debugPrint('[File2] No SM and no animations');
      }
    }

    _comp2 = RiveComponent(
      artboard: ab2,
      anchor: Anchor.center,
      size: Vector2.all(300),
      position: Vector2(size.x / 2, size.y * 0.75),
      priority: 10,
    );
    add(_comp2!);
  }

  // ---------- Helpers ----------
  void _playAnim1(int idx, rive.Artboard ab) {
    if (_testAnims.isEmpty) return;
    if (_ctrl1 != null) ab.removeController(_ctrl1!);

    _animIdx = idx % _testAnims.length;
    final name = _testAnims[_animIdx];
    final simple = rive.SimpleAnimation(name, mix: 0.2);
    ab.addController(simple);
    _ctrl1 = simple;
  }

  void _playAnim2(int idx, rive.Artboard ab) {
    if (_file2Anims.isEmpty) return;
    if (_ctrl2 != null) ab.removeController(_ctrl2!);

    _anim2Idx = idx % _file2Anims.length;
    final name = _file2Anims[_anim2Idx];
    final simple = rive.SimpleAnimation(name, mix: 0.2);
    ab.addController(simple);
    _ctrl2 = simple;
  }

  // ---------- Gestures ----------
  @override
  void onTapDown(TapDownEvent _) {
    if (_smCtrl2 != null) {
      // Toggle In/Out (simple heuristic)
      if (_inFire != null && _outFire != null) {
        // fire out if currently in? (behavior depends on your SM)
        _outFire!.fire();
      } else if (_inFire != null) {
        _inFire!.fire();
      }
      return;
    }

    if (_comp2 != null && _file2Anims.isNotEmpty) {
      _playAnim2((_anim2Idx + 1) % _file2Anims.length, _comp2!.artboard);
      return;
    }

    if (_comp1 != null && _testAnims.isNotEmpty) {
      _playAnim1((_animIdx + 1) % _testAnims.length, _comp1!.artboard);
    }
  }

  @override
  void onDoubleTapDown(TapDownEvent _) {
    if (_ctrl1 != null) _ctrl1!.isActive = !_ctrl1!.isActive;
    if (_smCtrl2 != null)
      _smCtrl2!.isActive = !_smCtrl2!.isActive;
    else if (_ctrl2 != null)
      _ctrl2!.isActive = !_ctrl2!.isActive;
  }

  // ---------- Layout ----------
  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    camera.viewfinder.visibleGameSize = s;

    _comp1?.position = Vector2(s.x / 2, s.y * 0.35);
    _comp2?.position = Vector2(s.x / 2, s.y * 0.75);

    final target = (s.x < s.y ? s.x : s.y) * 0.4;
    _comp1?.size = Vector2.all(target);
    _comp2?.size = Vector2.all(target);
  }
}
