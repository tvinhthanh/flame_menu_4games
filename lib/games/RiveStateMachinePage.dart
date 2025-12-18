import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveStateMachinePage extends StatefulWidget {
  const RiveStateMachinePage({super.key});

  @override
  State<RiveStateMachinePage> createState() => _RiveStateMachinePageState();
}

class _RiveStateMachinePageState extends State<RiveStateMachinePage> {
  Artboard? _riveArtboard;
  StateMachineController? _controller;

  // Các biến điều khiển trong rive
  SMIInput<bool>? _isIdle;
  SMITrigger? _characterIn;
  SMITrigger? _flowerIn;
  SMITrigger? _soulIn;
  SMITrigger? _titleIn;
  SMITrigger? _namIn;
  SMITrigger? _nuIn;
  SMITrigger? _namOut;
  SMITrigger? _nuOut;

  // State logic app quản lý
  int currentState = 0;

  @override
  void initState() {
    super.initState();
    rootBundle.load('assets/rive/tutien-gop.riv').then(
      (data) async {
        final file = RiveFile.import(data);
        final artboard = file.mainArtboard;
        var controller = StateMachineController.fromArtboard(
          artboard,
          "State Machine 1", // đúng tên machine trong rive
        );
        if (controller != null) {
          artboard.addController(controller);
          _controller = controller;

          // mapping biến trong rive
          _isIdle = controller.findInput("isIdle");
          _characterIn = controller.findInput("Nhanvat_in") as SMITrigger?;
          _flowerIn = controller.findInput("Hoasen_in") as SMITrigger?;
          _soulIn = controller.findInput("Linhhon_in") as SMITrigger?;
          _titleIn = controller.findInput("title_in") as SMITrigger?;
          _namIn = controller.findInput("Nam_in") as SMITrigger?;
          _nuIn = controller.findInput("Nu_in") as SMITrigger?;
          _namOut = controller.findInput("Nam_out") as SMITrigger?;
          _nuOut = controller.findInput("Nu_out") as SMITrigger?;

          setState(() => _riveArtboard = artboard);

          // khi vào app → chạy intro
          _playIntro();
        }
      },
    );
  }

  void _playIntro() {
    currentState = 0;
    _characterIn?.fire();
    _flowerIn?.fire();
    _soulIn?.fire();
    _logState();
  }

  void _onTapScreen() {
    if (currentState == 0) {
      // từ intro chuyển sang mid
      currentState = 1;
      _titleIn?.fire();
      // soul vẫn mid chạy bình thường
      _logState();
    }
  }

  void _onTapLeft() {
    if (currentState >= 1) {
      currentState = 2; // trạng thái nữ
      _nuIn?.fire();
      _namOut?.fire();
      _logState();
    }
  }

  void _onTapRight() {
    if (currentState >= 1) {
      currentState = 3; // trạng thái nam
      _namIn?.fire();
      _nuOut?.fire();
      _logState();
    }
  }

  void _logState() {
    debugPrint("🔹 Current State: $currentState");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _onTapScreen,
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < screenWidth / 2) {
            _onTapLeft();
          } else {
            _onTapRight();
          }
        },
        child: _riveArtboard == null
            ? const Center(child: CircularProgressIndicator())
            : Rive(artboard: _riveArtboard!),
      ),
    );
  }
}
