import 'package:flame_menu_4games/game/doodle_dash.dart';
import 'package:flame_menu_4games/game/widgets/main_menu_overlay.dart';
import 'package:flame_menu_4games/games/RiveStateMachinePage.dart';
import 'package:flame_menu_4games/games/gop.dart';
import 'package:flame_menu_4games/games/gop_controll.dart';
import 'package:flame_menu_4games/games/lottie_game.dart';
import 'package:flame_menu_4games/games/lotties.dart';
import 'package:flame_menu_4games/games/tach.dart' show TachGame;
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lottie/lottie.dart';
import 'games/png_game.dart';
import 'games/json_tiled_game.dart';
import 'games/atlas_game.dart';

enum GameKind {
  png,
  tiledJson,
  rive,
  lottie,
  atlas,
  gop,
  tach,
  gopC,
  riveState,
  doodleDash,
}

class GameMenuScreen extends StatelessWidget {
  const GameMenuScreen({super.key});

  void _openGame(BuildContext context, GameKind kind) {
    switch (kind) {
      case GameKind.png:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: PngGame())),
        );
        break;

      case GameKind.tiledJson:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: RiveOnlyGame())),
        );
        break;

      case GameKind.rive:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameWidget(game: RiveShowcaseGame()),
          ),
        );
        break;

      case GameKind.lottie:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: LottiesGame())),
        );
        break;

      case GameKind.gop:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: GopGame())),
        );
        break;

      case GameKind.tach:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: TachGame())),
        );
        break;

      case GameKind.gopC:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: GopControlGame())),
        );
        break;

      case GameKind.atlas:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameWidget(game: AtlasGame())),
        );
        break;

      case GameKind.riveState:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RiveStateMachinePage()),
        );
        break;

      case GameKind.doodleDash:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameWidget(
              game: DoodleDash(),
              // <-- Bật main menu overlay ngay khi GameWidget được tạo
              initialActiveOverlays: const ['mainMenuOverlay'],
              overlayBuilderMap: {
                'gameOverlay': (context, game) {
                  final doodleGame = game as DoodleDash;
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ValueListenableBuilder<int>(
                              valueListenable: doodleGame.gameManager.score,
                              builder: (context, score, child) {
                                return Text(
                                  'Score: $score',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },

                // <-- Use your MainMenuOverlay (wrapped in try/catch)
                'mainMenuOverlay': (context, game) {
                  try {
                    return MainMenuOverlay(game as Game); // <-- pass game here
                  } catch (e, st) {
                    // debug info if overlay build fails (avoids silent crash)
                    debugPrint('Error building MainMenuOverlay: $e\n$st');
                    return Center(
                      child: Card(
                        color: Colors.red.shade200,
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Lỗi khi dựng MainMenuOverlay:\n$e',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    );
                  }
                },

                'gameOverOverlay': (context, game) {
                  final doodleGame = game as DoodleDash;
                  return Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(32),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Game Over!',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<int>(
                                valueListenable: doodleGame.gameManager.score,
                                builder: (context, score, child) {
                                  return Text(
                                    'Score: $score',
                                    style: const TextStyle(fontSize: 24),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => doodleGame.resetGame(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Restart',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Back to Menu',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              },
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🎯 PNG Sprite', GameKind.png),
      ('🗺️ Tiled JSON (map)', GameKind.tiledJson),
      ('🧠 Rive test', GameKind.rive),
      ('🎬 Lottie Overlay', GameKind.lottie),
      ('🧩 Atlas (SpriteSheet)', GameKind.atlas),
      ('Gộp', GameKind.gop),
      ('TácH', GameKind.tach),
      ('Gộp Control', GameKind.gopC),
      ('RiveState', GameKind.riveState),
      ('Doodle Dash', GameKind.doodleDash),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Flame – Menu 4 Games')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, i) {
          return ElevatedButton(
            onPressed: () => _openGame(context, items[i].$2),
            child: Text(items[i].$1, textAlign: TextAlign.center),
          );
        },
      ),
    );
  }
}

class _LottiePage extends StatelessWidget {
  const _LottiePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lottie Overlay')),
      body: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lottie demo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Lottie.asset(
                    'assets/images/lotties/VongTrang.json', // sửa đúng path của bạn
                    repeat: true,
                    animate: true,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
