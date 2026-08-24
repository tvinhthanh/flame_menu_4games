# flame_menu_4games

Flutter game-menu shell built on the Flame engine, used to work out how Spine
skeletal animation behaves inside Flutter.

The two analysis documents are the substance here:

- **[SPINE_ANIMATION_ANALYSIS.md](SPINE_ANIMATION_ANALYSIS.md)** — how Spine
  skeletons load, bind and play in Flame
- **[SPINE_UNITY_VS_FLUTTER.md](SPINE_UNITY_VS_FLUTTER.md)** — where the Flutter
  runtime diverges from the Unity one, and what does not port across

`adjust_skeleton_bounds.dart` is a utility for correcting skeleton bounding boxes
that import wrong.

```bash
flutter pub get && flutter run
```
