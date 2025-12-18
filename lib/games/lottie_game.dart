import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_rive/flame_rive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;

class RiveShowcaseGame extends FlameGame with TapDetector, DoubleTapDetector {
  // === CHỈNH LẠI CHO KHỚP FILE CỦA BẠN ===
  static const _filePath     = 'assets/rive/TestAdvanced.riv';
  static const _artboardName = 'Artboard';          // '' nếu muốn dùng mainArtboard
  static const _smName       = 'State Machine 1';   // tên State Machine trong file .riv (nếu có)
  static const _smBool       = 'HoverOn';           // tên input Bool trong SM (nếu có)
  static const _fallbackAnim = 'Blink';             // animation fallback nếu không có SM
  // ======================================

  RiveComponent? _comp;
  rive.Artboard? _artboard;

  // Controller hiện tại (có thể là StateMachineController hoặc SimpleAnimation)
  rive.RiveAnimationController? _ctrl;

  // Nếu dùng State Machine
  rive.StateMachineController? _smCtrl;
  rive.SMIInput<bool>? _hoverInput; // trỏ thẳng tới SMI Bool nếu có

  // Nếu không có State Machine thì chơi raw animations
  final _anims = <String>[];
  int _animIdx = 0;

  @override
  Color backgroundColor() => const Color(0xFF0B1020);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    // 1) Load .riv & chọn artboard
    final bytes = await rootBundle.load(_filePath);
    final file  = rive.RiveFile.import(bytes);
    final ab    = _artboardName.isNotEmpty
        ? (file.artboardByName(_artboardName) ?? file.mainArtboard)
        : file.mainArtboard;
    ab.advance(0);
    _artboard = ab;

    // 2) Ưu tiên State Machine
    _smCtrl = rive.StateMachineController.fromArtboard(ab, _smName);
    if (_smCtrl != null) {
      ab.addController(_smCtrl!);

      // Thử lấy input Bool "HoverOn" bằng API chính thức
      _hoverInput = _smCtrl!.findSMI<bool>(_smBool) as SMIInput<bool>?;

      // Nếu không tìm thấy bằng tên, quét inputs để tìm Bool cùng tên (dự phòng)
      _hoverInput ??= _findSMIBool(_smCtrl!, _smBool);

      // Bật hover mặc định để thấy chuyển động
      _hoverInput?.value = true;

      // (tuỳ chọn) In ra danh sách input/animation để debug
      _debugLogInputsAndAnims(ab, _smCtrl!);

      _ctrl = _smCtrl;
    } else {
      // 3) Không có SM → chơi raw animations & cho phép cycle
      _anims
        ..clear()
        ..addAll(ab.animations.map((a) => a.name));
      if (_anims.isNotEmpty) {
        final start = _anims.contains(_fallbackAnim)
            ? _anims.indexOf(_fallbackAnim)
            : 0;
        _playAnim(start);
      } else {
        if (kDebugMode) {
          debugPrint('[RiveShowcase] No SM and no animations found on artboard "${ab.name}".');
        }
      }
    }

    // 4) Add vào Flame bằng RiveComponent (gọn & ổn định)
    _comp = RiveComponent(
      artboard: ab,
      anchor: Anchor.center,
      size: Vector2.all(360),
      position: size / 2,
      priority: 10,
    );
    add(_comp!);
  }

  // === Helpers ===

  // Dò một SMIBool theo tên (dự phòng nếu findSMI<bool> trả null)
  rive.SMIInput<bool>? _findSMIBool(rive.StateMachineController sm, String name) {
    for (final i in sm.inputs) {
      if (i is rive.SMIBool && i.name == name) {
        return i; // SMIBool extends SMIInput<bool>
      }
    }
    return null;
  }

  void _playAnim(int idx) {
    final ab = _artboard;
    if (ab == null || _anims.isEmpty) return;

    // gỡ controller cũ nếu có
    if (_ctrl != null) ab.removeController(_ctrl!);

    _animIdx = idx % _anims.length;
    final name = _anims[_animIdx];

    final simple = rive.SimpleAnimation(name, mix: 0.2);
    ab.addController(simple);
    _ctrl = simple;

    if (kDebugMode) debugPrint('[RiveShowcase] ▶️ Playing animation: $name');
  }

  void _debugLogInputsAndAnims(rive.Artboard ab, rive.StateMachineController sm) {
    if (!kDebugMode) return;
    final anims = ab.animations.map((a) => a.name).join(', ');
    debugPrint('[RiveShowcase] 🎞️ Animations: ${anims.isEmpty ? "<none>" : anims}');
    for (final i in sm.inputs) {
      debugPrint('[RiveShowcase] 🧠 Input -> ${i.runtimeType} "${i.name}"');
    }
  }

  // === Gestures ===

  @override
  void onTapDown(TapDownInfo _) {
    if (_smCtrl != null) {
      // Đang dùng State Machine: tap để toggle HoverOn (nếu có)
      if (_hoverInput != null) {
        final current = _hoverInput!.value;
        _hoverInput!.value = !current;
        if (kDebugMode) {
          debugPrint('[RiveShowcase] HoverOn -> ${_hoverInput!.value}');
        }
      }
      return;
    }

    // Không có SM: cycle animation
    if (_anims.isNotEmpty) _playAnim((_animIdx + 1) % _anims.length);
  }

  @override
  void onDoubleTap() {
    if (_ctrl == null) return;
    _ctrl!.isActive = !_ctrl!.isActive; // pause / resume
    if (kDebugMode) {
      debugPrint('[RiveShowcase] ${_ctrl!.isActive ? "Resume" : "Pause"}');
    }
  }

  // === Layout ===

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    camera.viewfinder.visibleGameSize = s;
    _comp?.position = s / 2;

    // Fit vừa màn
    final target = (s.x < s.y ? s.x : s.y) * 0.6;
    _comp?.size = Vector2.all(target.clamp(160, 560).toDouble());
  }
}
