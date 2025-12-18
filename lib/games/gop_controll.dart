import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;
import 'package:flame_rive/flame_rive.dart';

enum GameState {
  loading,
  intro,
  waitingForTitle,
  interactive,
  error,
}

class GopControlGame extends FlameGame with TapDetector {
  static const _riveFilePath = 'assets/rive/tutien-gop.riv';
  static const _stateMachineName = 'State Machine 1';

  RiveComponent? _comp;
  rive.StateMachineController? _smCtrl;
  late rive.RiveFile _riveFile;
  late rive.Artboard _artboard;

  final Map<String, rive.SMIInput> _inputs = {};
  GameState _state = GameState.loading;
  bool _introPlayed = false;

  @override
  Color backgroundColor() => const Color(0xFF0B1020);

  void safeLog(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  @override
Future<void> onLoad() async {
  try {
    final bytes = await rootBundle.load(_riveFilePath);
    _riveFile = rive.RiveFile.import(bytes);
    _artboard = _riveFile.mainArtboard.instance();
    _artboard.advance(0);

    _smCtrl = rive.StateMachineController.fromArtboard(_artboard, _stateMachineName);
    if (_smCtrl != null) {
      _artboard.addController(_smCtrl!);
      for (final input in _smCtrl!.inputs) {
        _inputs[input.name] = input;
        safeLog("✅ Found input: ${input.name}");
      }
    }

    _comp = RiveComponent(
      artboard: _artboard,
      anchor: Anchor.center,
      size: Vector2(300, 300),
      position: Vector2.zero(),
    );
    add(_comp!);

    // Sau khi thêm component, check size
    if (size.x > 0 && !_introPlayed) {
      _introPlayed = true;
      _playIntroSequence();
    } else {
      // Delay 100ms để chắc chắn size sẵn sàng
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_introPlayed) {
          _introPlayed = true;
          _playIntroSequence();
        }
      });
    }

    _state = GameState.loading;
  } catch (e) {
    safeLog("❌ Lỗi load game: $e");
    _state = GameState.error;
  }
}

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);

    if (_comp != null) {
      _comp!.position = Vector2(s.x / 2, s.y / 2);
      _comp!.size = Vector2(s.x, s.y);
    }

    // Chạy intro lần đầu sau khi size đã có
    if (!_introPlayed && _state == GameState.loading) {
      _introPlayed = true;
      _playIntroSequence();
    }
  }

  /// Trigger input trong state machine
  void _trigger(String name) {
    final input = _inputs[name];
    if (input == null) {
      safeLog("⚠️ Input $name không tồn tại!");
      return;
    }
    if (input is rive.SMITrigger) {
      input.fire();
      safeLog("🔥 Trigger $name");
    } else if (input is rive.SMIBool) {
      input.value = !input.value;
      safeLog("🔀 Bool $name = ${input.value}");
    } else if (input is rive.SMINumber) {
      input.value = (input.value + 1) % 2;
      safeLog("🔢 Number $name = ${input.value}");
    }
  }

  /// Chạy OneShotAnimation tuần tự
  Future<void> _playIntroSequence() async {
  final animations = [
    "Nhanvat_In",
    "HoaSen_In",
    "LinhHon_In",
    "Background",
  ];
  for (final name in animations) {
    await _playOneShot(name);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Trigger các input state machine sau intro
  _trigger("NhanVat");
  _trigger("HoaSen");
  _trigger("LinhHon_MId");

  _state = GameState.intro;

  // Delay 4 giây → tự chuyển sang waitingForTitle
  Future.delayed(const Duration(seconds: 4), () {
    if (_state == GameState.intro) {
      _state = GameState.waitingForTitle;
      safeLog("⏱ Auto switch to waitingForTitle");
      _playOneShot("Title_In"); // play Title animation luôn
    }
  });
}


  Future<void> _playOneShot(String name) {
  final completer = Completer<void>();

  // Khai báo biến controller trước
  late final OneShotAnimation controller;

  controller = OneShotAnimation(
    name,
    autoplay: true,
    onStop: () {
      safeLog("✅ Animation $name finished");
      _artboard.removeController(controller); // OK vì controller đã khai báo trước
      completer.complete();
    },
  );

  _artboard.addController(controller);
  safeLog("🎬 Playing animation $name");
  return completer.future;
}


  @override
  void onTapDown(TapDownInfo info) {
    final pos = info.eventPosition.global;

    switch (_state) {
      case GameState.waitingForTitle:
        _playOneShot("Title_In");
        _state = GameState.interactive;
        safeLog("🎬 Title animation start");
        break;

      case GameState.interactive:
        if (pos.x < size.x / 2) {
          _trigger("Nu");   // đúng trigger Rive
          safeLog("👩 Female selected");
        } else {
          _trigger("Nam");  // đúng trigger Rive
          safeLog("👨 Male selected");
        }
        break;

      default:
        safeLog("🚫 Tap ignored, state: $_state");
    }
  }
}
