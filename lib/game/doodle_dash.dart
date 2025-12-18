import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;
import 'package:flame_menu_4games/game/world.dart';

import 'managers/managers.dart';
import 'sprites/sprites.dart';
import 'sprites/player.dart';

enum Character { dash, sparky, robodude }

class DoodleDash extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection, TapCallbacks {
  DoodleDash({super.children})
      : super(
          camera: CameraComponent.withFixedResolution(width: 400, height: 800),
        );

  late Player player; // Can be either SpritePlayer or RivePlayer
  final GameWorld _world = GameWorld();
  ObjectManager objectManager = ObjectManager();
  LevelManager levelManager = LevelManager();
  GameManager gameManager = GameManager();
  rive.Artboard? _robodudeArtboard;

  int screenBufferSpace = 300;
  late Vector2 worldSize;

  @override
  Future<void> onLoad() async {
    worldSize = Vector2(size.x, size.y * 3);

    camera.world = _world;

    // Load Rive artboard for robodude
    await _loadRiveArtboard();

    await add(_world);
    await add(gameManager);
    overlays.add('gameOverlay');
    await add(levelManager);
  }

  Future<void> _loadRiveArtboard() async {
  try {
    // Initialize Rive TRƯỚC - QUAN TRỌNG!
    await rive.RiveFile.initialize();
    
    final data = await rootBundle.load('assets/images/game/robodude.riv');
    final file = rive.RiveFile.import(data);
    _robodudeArtboard = file.mainArtboard.instance();
    print('Rive artboard loaded successfully');
  } catch (e) {
    print('Error loading Rive artboard: $e');
  }
}

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    if (gameManager.isPlaying) {
      if (event.localPosition.x < size.x / 2) {
        player.moveLeft();
      } else {
        player.moveRight();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameManager.isGameOver) {
      return;
    }

    if (gameManager.isIntro) {
      overlays.add('mainMenuOverlay');
      return;
    }

    if (gameManager.isPlaying) {
      checkLevelUp();

      // Camera only follows Y, X fixed at center
      if (!player.isMovingDown) {
        camera.moveTo(
          Vector2(
            size.x / 2, // X fixed at screen center
            player.position.y, // Y follows player
          ),
        );
      }

      // Check game over
      if (player.position.y >
          camera.viewfinder.position.y + size.y + screenBufferSpace) {
        onLose();
      }
    }
  }

  @override
  Color backgroundColor() {
    return const Color.fromARGB(255, 241, 247, 249);
  }

  Future<void> initializeGameStart() async {
    gameManager.reset();

    if (_world.children.query<ObjectManager>().isNotEmpty) {
      objectManager.removeFromParent();
    }

    levelManager.reset();

    if (!player.isLoaded) {
      await player.loaded;
    }

    player.reset();

    player.position = Vector2((size.x - player.size.x) / 2, size.y * 0.7);
    camera.moveTo(Vector2(size.x / 2, player.position.y));

    objectManager = ObjectManager(
      minVerticalDistanceToNextPlatform: levelManager.minDistance,
      maxVerticalDistanceToNextPlatform: levelManager.maxDistance,
    );

    await _world.add(objectManager);
    objectManager.configure(levelManager.level, levelManager.difficulty);
  }

  void setCharacter(Character selectedCharacter) {
    if (selectedCharacter == Character.robodude && _robodudeArtboard != null) {
      // Use RivePlayer for robodude
      player = RivePlayer(
        artboard: _robodudeArtboard!.instance(), // Create new instance
        jumpSpeed: levelManager.jumpSpeed,
      );
      print('Created RivePlayer for robodude');
    } else {
      // Use SpritePlayer for other characters
      player = SpritePlayer(
        character: selectedCharacter,
        jumpSpeed: levelManager.jumpSpeed,
      );
      print('Created SpritePlayer for ${selectedCharacter.name}');
    }
    _world.add(player);
  }

  Future<void> startGame() async {
    // Get selected character
    final selectedCharacter = gameManager.character;

    // Set selected level
    levelManager.setLevel(levelManager.selectedLevel);

    // Set character
    setCharacter(selectedCharacter);

    await player.loaded;
    await initializeGameStart();

    gameManager.state = GameState.playing;
    overlays.remove('mainMenuOverlay');
  }

  void resetGame() {
    startGame();
    overlays.remove('gameOverOverlay');
  }

  void onLose() {
    gameManager.state = GameState.gameOver;
    player.removeFromParent();
    overlays.add('gameOverOverlay');
  }

  void togglePauseState() {
    if (paused) {
      resumeEngine();
    } else {
      pauseEngine();
    }
  }

  void checkLevelUp() {
    if (levelManager.shouldLevelUp(gameManager.score.value)) {
      levelManager.increaseLevel();
      objectManager.configure(levelManager.level, levelManager.difficulty);
      player.setJumpSpeed(levelManager.jumpSpeed);
    }
  }
}