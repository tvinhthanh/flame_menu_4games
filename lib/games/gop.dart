import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;
import 'package:flame_rive/flame_rive.dart';

/// Game configuration
class GameConfig {
  static const String riveFile = 'assets/rive/tutien-gop.riv';
  static const String stateMachineName = 'State Machine 1';
  static const Color backgroundColor = Color(0xFF0B1020);
}

/// Game states
enum GameState { loading, ready, error }

class GopGame extends FlameGame {
  RiveComponent? _comp;
  final void Function(bool isMale)? onGenderSelected;

  late rive.RiveFile _riveFile;
  late List<rive.Artboard> _artboards = [];

  rive.StateMachineController? _stateMachineController;
  rive.SMITrigger? _nuTrigger;
  rive.SMITrigger? _namTrigger;
  rive.SMIBool? _nhanVatBool;
  rive.SMIBool? _startBool;

  GameState _currentState = GameState.loading;
  int _artboardIndex = 0;
  bool fullScreenMode = true;
  bool? _selectedGender;

  GopGame({this.onGenderSelected});

  @override
  Color backgroundColor() => GameConfig.backgroundColor;

  @override
  Future<void> onLoad() async {
    try {
      camera.viewfinder.anchor = Anchor.center;

      await _initializeRive();
      if (_artboards.isEmpty) {
        _setState(GameState.error);
        if (kDebugMode) debugPrint("❌ No artboards found in Rive file.");
        return;
      }

      _loadArtboard(0);
      _setupStateMachine();

      // ✅ Trigger Start để bắt đầu animation
      _startBool?.value = true;

      _setState(GameState.ready);
    } catch (e, st) {
      if (kDebugMode) debugPrint("❌ Error loading game: $e\n$st");
      _setState(GameState.error);
    }
  }

  Future<void> _initializeRive() async {
    try {
      await rive.RiveFile.initialize();
      final bytes = await rootBundle.load(GameConfig.riveFile);
      _riveFile = rive.RiveFile.import(bytes);
      _artboards = _riveFile.artboards.toList();

      if (kDebugMode) {
        debugPrint("✅ Loaded ${_artboards.length} artboards");
        for (int i = 0; i < _artboards.length; i++) {
          debugPrint("  Artboard $i: ${_artboards[i].name}");
          final names = _artboards[i].animations.map((a) => a.name).toList();
          debugPrint("    animations: ${names.join(', ')}");
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint("❌ Error initializing Rive: $e\n$st");
      rethrow;
    }
  }

  void _loadArtboard(int idx) {
    if (_artboards.isEmpty) {
      if (kDebugMode)
        debugPrint("❌ _loadArtboard called but no artboards available.");
      return;
    }

    final safeIdx = math.max(0, math.min(idx, _artboards.length - 1));

    if (_comp != null && safeIdx == _artboardIndex) {
      if (kDebugMode)
        debugPrint(
          "ℹ️ Artboard $safeIdx already loaded, skipping _loadArtboard.",
        );
      return;
    }

    _cleanupCurrentComponent();

    _artboardIndex = safeIdx;
    final artboard = _artboards[_artboardIndex].instance();
    artboard.advance(0);

    _comp = RiveComponent(
      artboard: artboard,
      anchor: Anchor.center,
      size: _getComponentSize(),
      position: _getComponentPosition(),
    );

    add(_comp!);
    if (kDebugMode)
      debugPrint("✅ Loaded artboard $_artboardIndex: ${artboard.name}");
  }

  /// ✅ Setup State Machine và lấy inputs
  void _setupStateMachine() {
    if (_comp == null) return;

    final artboard = _comp!.artboard;

    // Tìm State Machine
    _stateMachineController = rive.StateMachineController.fromArtboard(
      artboard,
      GameConfig.stateMachineName,
    );

    if (_stateMachineController == null) {
      if (kDebugMode)
        debugPrint(
          "❌ State Machine '${GameConfig.stateMachineName}' not found",
        );
      return;
    }

    artboard.addController(_stateMachineController!);

    // ✅ Debug: In ra tất cả inputs
    if (kDebugMode) {
      debugPrint("📋 Available inputs:");
      for (var input in _stateMachineController!.inputs) {
        debugPrint("   - ${input.name} (${input.runtimeType})");
      }
    }

    // ✅ Lấy triggers - thử cả case-sensitive và case-insensitive
    _nuTrigger =
        _stateMachineController!.findInput<bool>('Nu') as rive.SMITrigger?;
    _nuTrigger ??=
        _stateMachineController!.findInput<bool>('nu') as rive.SMITrigger?;

    _namTrigger =
        _stateMachineController!.findInput<bool>('Nam') as rive.SMITrigger?;
    _namTrigger ??=
        _stateMachineController!.findInput<bool>('nam') as rive.SMITrigger?;

    // ✅ Lấy booleans
    _nhanVatBool =
        _stateMachineController!.findInput<bool>('NhanVat') as rive.SMIBool?;
    _nhanVatBool ??=
        _stateMachineController!.findInput<bool>('nhanvat') as rive.SMIBool?;

    _startBool =
        _stateMachineController!.findInput<bool>('Start') as rive.SMIBool?;
    _startBool ??=
        _stateMachineController!.findInput<bool>('start') as rive.SMIBool?;

    if (kDebugMode) {
      debugPrint("✅ State Machine setup complete");
      debugPrint("   Nu trigger: ${_nuTrigger != null ? '✅' : '❌'}");
      debugPrint("   Nam trigger: ${_namTrigger != null ? '✅' : '❌'}");
      debugPrint("   NhanVat bool: ${_nhanVatBool != null ? '✅' : '❌'}");
      debugPrint("   Start bool: ${_startBool != null ? '✅' : '❌'}");
    }
  }

  Vector2 _getComponentSize() => fullScreenMode ? size : Vector2.all(300.0);
  Vector2 _getComponentPosition() =>
      fullScreenMode ? size / 2 : Vector2(size.x / 2, size.y * 0.6);

  void _cleanupCurrentComponent() {
    if (_comp != null) {
      if (_stateMachineController != null) {
        try {
          _comp!.artboard.removeController(_stateMachineController!);
        } catch (_) {}
        _stateMachineController = null;
      }

      try {
        remove(_comp!);
      } catch (_) {}
      _comp = null;
    }

    _nuTrigger = null;
    _namTrigger = null;
    _nhanVatBool = null;
    _startBool = null;
  }

  void _setState(GameState newState) {
    if (_currentState != newState) {
      if (kDebugMode) debugPrint("🎮 State: $_currentState → $newState");
      _currentState = newState;
    }
  }

  @override
  void onTapDown(TapDownEvent info) {
    if (_comp == null || _currentState != GameState.ready) return;

    final pos = info.localPosition;
    _handleCharacterSelection(pos);
  }

  /// ✅ Chọn giới tính bằng trigger
  void _handleCharacterSelection(Vector2 pos) {
    // Xác định giới tính: click phải = Nam, click trái = Nữ
    final isMale = pos.x >= size.x / 2;

    // Không cho chọn lại
    if (_selectedGender == isMale) {
      if (kDebugMode)
        debugPrint("⚠️ Gender already selected: ${isMale ? 'Male' : 'Female'}");
      return;
    }

    _selectedGender = isMale;

    // ✅ Fire trigger tương ứng với debug chi tiết
    if (isMale) {
      if (_namTrigger != null) {
        _namTrigger!.fire();
        if (kDebugMode) {
          debugPrint("👨 Male selected - Nam trigger fired");
          debugPrint("   Trigger exists: ✅");
          debugPrint("   Current state: ${_stateMachineController}");
        }
      } else {
        if (kDebugMode) debugPrint("❌ Nam trigger not found!");
      }
    } else {
      if (_nuTrigger != null) {
        _nuTrigger!.fire();
        if (kDebugMode) {
          debugPrint("👩 Female selected - Nu trigger fired");
          debugPrint("   Trigger exists: ✅");
          debugPrint("   Current state: ${_stateMachineController}");
        }
      } else {
        if (kDebugMode) debugPrint("❌ Nu trigger not found!");
      }
    }

    // ✅ Set boolean NhanVat (nếu cần)
    if (_nhanVatBool != null) {
      _nhanVatBool!.value = true;
      if (kDebugMode) debugPrint("   NhanVat set to true");
    }

    // ✅ Gọi callback
    if (onGenderSelected != null) {
      onGenderSelected!(isMale);
    }
  }

  /// ✅ Public methods để control từ ngoài
  void setNhanVatVisible(bool visible) {
    _nhanVatBool?.value = visible;
    if (kDebugMode) debugPrint("NhanVat visibility: $visible");
  }

  void triggerStart() {
    _startBool?.value = true;
    if (kDebugMode) debugPrint("Start triggered");
  }

  void triggerMale() {
    if (_namTrigger != null) {
      _namTrigger!.fire();
      _selectedGender = true;
      if (kDebugMode) debugPrint("👨 Male trigger fired manually");
    } else {
      if (kDebugMode) debugPrint("❌ Nam trigger not available");
    }
  }

  void triggerFemale() {
    if (_nuTrigger != null) {
      _nuTrigger!.fire();
      _selectedGender = false;
      if (kDebugMode) debugPrint("👩 Female trigger fired manually");
    } else {
      if (kDebugMode) debugPrint("❌ Nu trigger not available");
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (_comp != null) {
      _comp!.position = _getComponentPosition();
      _comp!.size = _getComponentSize();
      if (kDebugMode) debugPrint("📐 Game resized to: $newSize");
    }
  }

  @override
  void onRemove() {
    _cleanupCurrentComponent();
    super.onRemove();
  }

  void toggleFullscreenMode() {
    fullScreenMode = !fullScreenMode;
    if (_comp != null) {
      _comp!.size = _getComponentSize();
      _comp!.position = _getComponentPosition();
    }
    if (kDebugMode) debugPrint("🖥️ Fullscreen: $fullScreenMode");
  }

  void resetGame() {
    _selectedGender = null;
    _startBool?.value = false;
    _nhanVatBool?.value = false;

    Future.delayed(const Duration(milliseconds: 100), () {
      _startBool?.value = true;
    });

    if (kDebugMode) debugPrint("🔄 Game reset");
  }

  // Getters
  GameState get currentState => _currentState;
  int get artboardCount => _artboards.length;
  bool? get selectedGender => _selectedGender;
  bool get isMaleSelected => _selectedGender == true;
  bool get isFemaleSelected => _selectedGender == false;
  bool get hasSelectedGender => _selectedGender != null;

  // State Machine inputs getters
  rive.SMITrigger? get nuTrigger => _nuTrigger;
  rive.SMITrigger? get namTrigger => _namTrigger;
  rive.SMIBool? get nhanVatBool => _nhanVatBool;
  rive.SMIBool? get startBool => _startBool;
}
