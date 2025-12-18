import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import '../doodle_dash.dart';
import 'sprites.dart';

enum PlayerState {
  left,
  right,
  center,
  rocket,
  nooglerCenter,
  nooglerLeft,
  nooglerRight,
}

// Base class for common interface
abstract class Player extends PositionComponent {
  bool get isMovingDown;
  bool get isInvincible;
  bool get isWearingHat;
  bool get hasPowerup;
  void moveLeft();
  void moveRight();
  void stopMoving();
  void reset();
  void jump({double? specialJumpSpeed});
  void setJumpSpeed(double newJumpSpeed);
}

// Rive-based player for robodude
class RivePlayer extends PositionComponent
    with HasGameRef<DoodleDash>, KeyboardHandler, CollisionCallbacks
    implements Player {
  RivePlayer({
    required this.artboard,
    super.position,
    this.jumpSpeed = 600,
  }) : super(
          size: Vector2(79, 109),
          anchor: Anchor.center,
          priority: 10,
        );

  final rive.Artboard artboard;
  Vector2 _velocity = Vector2.zero();
  int _hAxisInput = 0;
  final int movingLeftInput = -1;
  final int movingRightInput = 1;

  final double _gravity = 9;
  double jumpSpeed;

  rive.StateMachineController? _controller;
  rive.SMITrigger? _flyTrigger;

  bool _isInvincible = false;
  bool _isWearingHat = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(CircleHitbox());

    // Load state machine
    _controller = rive.StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );

    if (_controller != null) {
      artboard.addController(_controller!);
      _flyTrigger = _controller!.findInput<rive.SMITrigger>('flyTrigger') as rive.SMITrigger?;
      print('Fly trigger loaded: ${_flyTrigger != null}');
    }

    print('RivePlayer loaded successfully');
  }

  @override
  void update(double dt) {
    if (gameRef.gameManager.isIntro || gameRef.gameManager.isGameOver) return;

    final double playerHorizontalCenter = size.x / 2;

    _velocity.x = _hAxisInput * jumpSpeed;
    _velocity.y += _gravity;

    if (position.x < playerHorizontalCenter) {
      position.x = gameRef.size.x - playerHorizontalCenter;
    }
    if (position.x > gameRef.size.x - playerHorizontalCenter) {
      position.x = playerHorizontalCenter;
    }

    position += _velocity * dt;

    // Flip sprite based on direction
    if (_hAxisInput < 0) {
      scale.x = -1;
    } else if (_hAxisInput > 0) {
      scale.x = 1;
    }

    // Advance artboard animation
    artboard.advance(dt);

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    artboard.draw(canvas);
    canvas.restore();
  }

  @override
  void reset() {
    _velocity = Vector2.zero();
    _hAxisInput = 0;
    _isInvincible = false;
    _isWearingHat = false;
    scale.x = 1;
  }

  @override
  void moveLeft() {
    _hAxisInput = movingLeftInput;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hAxisInput == movingLeftInput) {
        stopMoving();
      }
    });
  }

  @override
  void moveRight() {
    _hAxisInput = movingRightInput;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hAxisInput == movingRightInput) {
        stopMoving();
      }
    });
  }

  @override
  void stopMoving() {
    _hAxisInput = 0;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _hAxisInput = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      _hAxisInput += movingLeftInput;
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      _hAxisInput += movingRightInput;
    }

    return true;
  }

  @override
  bool get isMovingDown => _velocity.y > 0;

  @override
  bool get hasPowerup => _isInvincible || _isWearingHat;
  
  @override
  bool get isInvincible => _isInvincible;
  
  @override
  bool get isWearingHat => _isWearingHat;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyPlatform && !isInvincible) {
      gameRef.onLose();
      return;
    }

    bool isCollidingVertically =
        (intersectionPoints.first.y - intersectionPoints.last.y).abs() < 5;

    bool enablePowerUp = false;

    if (!hasPowerup && (other is Rocket || other is NooglerHat)) {
      enablePowerUp = true;
    }

    if (isMovingDown && isCollidingVertically) {
      if (other is NormalPlatform) {
        jump();
        return;
      } else if (other is SpringBoard) {
        jump(specialJumpSpeed: jumpSpeed * 2);
        return;
      } else if (other is BrokenPlatform &&
          other.current == BrokenPlatformState.cracked) {
        jump();
        other.breakPlatform();
        return;
      }

      if (other is Rocket || other is NooglerHat) {
        enablePowerUp = true;
      }
    }

    if (!enablePowerUp) return;

    if (other is Rocket) {
      _isInvincible = true;
      _flyTrigger?.fire();
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    } else if (other is NooglerHat) {
      _isWearingHat = true;
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      _removePowerupAfterTime(other.activeLengthInMS);
      return;
    }
  }

  void _removePowerupAfterTime(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      _isInvincible = false;
      _isWearingHat = false;
    });
  }

  @override
  void jump({double? specialJumpSpeed}) {
    _velocity.y = specialJumpSpeed != null ? -specialJumpSpeed : -jumpSpeed;
  }

  @override
  void setJumpSpeed(double newJumpSpeed) {
    jumpSpeed = newJumpSpeed;
  }
}

// Sprite-based player for dash and sparky
class SpritePlayer extends SpriteGroupComponent<PlayerState>
    with HasGameRef<DoodleDash>, KeyboardHandler, CollisionCallbacks
    implements Player {
  SpritePlayer({
    super.position,
    required this.character,
    this.jumpSpeed = 600,
  }) : super(size: Vector2(79, 109), anchor: Anchor.center, priority: 10);

  Vector2 _velocity = Vector2.zero();
  int _hAxisInput = 0;
  final int movingLeftInput = -1;
  final int movingRightInput = 1;

  Character character;

  final double _gravity = 9;
  double jumpSpeed;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(CircleHitbox());
    await _loadCharacterSprites();

    if (sprites == null || sprites!.isEmpty) {
      throw Exception('Failed to load sprites');
    }

    current = PlayerState.center;

    print('SpritePlayer onLoad completed. Current state: $current, character=${character.name}');
  }

  @override
  void update(double dt) {
    if (gameRef.gameManager.isIntro || gameRef.gameManager.isGameOver) return;

    final double dashHorizontalCenter = size.x / 2;

    _velocity.x = _hAxisInput * jumpSpeed;
    _velocity.y += _gravity;

    if (position.x < dashHorizontalCenter) {
      position.x = gameRef.size.x - (dashHorizontalCenter);
    }
    if (position.x > gameRef.size.x - (dashHorizontalCenter)) {
      position.x = dashHorizontalCenter;
    }

    position += _velocity * dt;
    super.update(dt);
  }

  @override
  void reset() {
    _velocity = Vector2.zero();
    if (sprites != null && sprites!.isNotEmpty) {
      current = PlayerState.center;
    }
  }

  @override
  void moveLeft() {
    _hAxisInput = movingLeftInput;
    if (isWearingHat) {
      current = PlayerState.nooglerLeft;
    } else if (!hasPowerup) {
      current = PlayerState.left;
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hAxisInput == movingLeftInput) {
        stopMoving();
      }
    });
  }

  @override
  void moveRight() {
    _hAxisInput = movingRightInput;
    if (isWearingHat) {
      current = PlayerState.nooglerRight;
    } else if (!hasPowerup) {
      current = PlayerState.right;
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_hAxisInput == movingRightInput) {
        stopMoving();
      }
    });
  }

  @override
  void stopMoving() {
    _hAxisInput = 0;
    if (isWearingHat) {
      current = PlayerState.nooglerCenter;
    } else if (!hasPowerup) {
      current = PlayerState.center;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _hAxisInput = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      if (isWearingHat) {
        current = PlayerState.nooglerLeft;
      } else if (!hasPowerup) {
        current = PlayerState.left;
      }
      _hAxisInput += movingLeftInput;
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      if (isWearingHat) {
        current = PlayerState.nooglerRight;
      } else if (!hasPowerup) {
        current = PlayerState.right;
      }
      _hAxisInput += movingRightInput;
    }

    return true;
  }

  @override
  bool get isMovingDown => _velocity.y > 0;

  @override
  bool get hasPowerup =>
      current == PlayerState.rocket ||
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  @override
  bool get isInvincible => current == PlayerState.rocket;

  @override
  bool get isWearingHat =>
      current == PlayerState.nooglerLeft ||
      current == PlayerState.nooglerRight ||
      current == PlayerState.nooglerCenter;

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is EnemyPlatform && !isInvincible) {
      gameRef.onLose();
      return;
    }

    bool isCollidingVertically =
        (intersectionPoints.first.y - intersectionPoints.last.y).abs() < 5;

    bool enablePowerUp = false;

    if (!hasPowerup && (other is Rocket || other is NooglerHat)) {
      enablePowerUp = true;
    }

    if (isMovingDown && isCollidingVertically) {
      current = PlayerState.center;
      if (other is NormalPlatform) {
        jump();
        return;
      } else if (other is SpringBoard) {
        jump(specialJumpSpeed: jumpSpeed * 2);
        return;
      } else if (other is BrokenPlatform &&
          other.current == BrokenPlatformState.cracked) {
        jump();
        other.breakPlatform();
        return;
      }

      if (other is Rocket || other is NooglerHat) {
        enablePowerUp = true;
      }
    }

    if (!enablePowerUp) return;

    if (other is Rocket) {
      current = PlayerState.rocket;
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    } else if (other is NooglerHat) {
      if (current == PlayerState.center) current = PlayerState.nooglerCenter;
      if (current == PlayerState.left) current = PlayerState.nooglerLeft;
      if (current == PlayerState.right) current = PlayerState.nooglerRight;
      _removePowerupAfterTime(other.activeLengthInMS);
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    }
  }

  void _removePowerupAfterTime(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      current = PlayerState.center;
    });
  }

  @override
  void jump({double? specialJumpSpeed}) {
    _velocity.y = specialJumpSpeed != null ? -specialJumpSpeed : -jumpSpeed;
  }

  @override
  void setJumpSpeed(double newJumpSpeed) {
    jumpSpeed = newJumpSpeed;
  }

  Future<void> _loadCharacterSprites() async {
    try {
      print('Loading sprites for character: ${character.name}');

      final left = await gameRef.loadSprite('game/${character.name}_left.png');
      final right = await gameRef.loadSprite('game/${character.name}_right.png');
      final center = await gameRef.loadSprite('game/${character.name}_center.png');
      final rocket = await gameRef.loadSprite('game/rocket_4.png');
      final nooglerCenter = await gameRef.loadSprite('game/${character.name}_hat_center.png');
      final nooglerLeft = await gameRef.loadSprite('game/${character.name}_hat_left.png');
      final nooglerRight = await gameRef.loadSprite('game/${character.name}_hat_right.png');

      sprites = <PlayerState, Sprite>{
        PlayerState.left: left,
        PlayerState.right: right,
        PlayerState.center: center,
        PlayerState.rocket: rocket,
        PlayerState.nooglerCenter: nooglerCenter,
        PlayerState.nooglerLeft: nooglerLeft,
        PlayerState.nooglerRight: nooglerRight,
      };

      print('All sprites loaded successfully for: ${character.name}');
    } catch (e, st) {
      print('Error loading sprites for ${character.name}: $e\n$st');
      rethrow;
    }
  }
}