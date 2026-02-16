import 'dart:io';
import 'dart:convert';

/// Script to check atlas regions vs skeleton attachments
/// 
/// Nếu animation không lỗi nhưng vẫn drift/clip, có thể do:
/// 1. Atlas region không match với attachment name
/// 2. Region bounds/offsets sai
/// 3. Texture coordinates sai
/// 
/// Usage: dart check_atlas_regions.dart
void main() async {
  print('=== ATLAS REGION CHECKER ===\n');

  final atlasFile = File('assets/spine/alien-pro.atlas');
  final jsonFile = File('assets/spine/alien-pro.json');

  if (!await atlasFile.exists()) {
    print('Error: Atlas file not found: ${atlasFile.path}');
    return;
  }
  if (!await jsonFile.exists()) {
    print('Error: JSON file not found: ${jsonFile.path}');
    return;
  }

  // Parse atlas
  print('Parsing atlas: ${atlasFile.path}');
  final atlasContent = await atlasFile.readAsString();
  final atlasData = await _parseAtlasContent(atlasContent);
  
  print('Found ${atlasData.regions.length} regions in atlas\n');

  // Parse JSON
  print('Parsing skeleton: ${jsonFile.path}');
  final jsonContent = await jsonFile.readAsString();
  final json = jsonDecode(jsonContent) as Map<String, dynamic>;

  // Get all attachments from skins
  final skins = json['skins'] as List<dynamic>?;
  final Set<String> attachmentNames = {};
  
  if (skins != null) {
    for (final skinData in skins) {
      final skin = skinData as Map<String, dynamic>;
      final attachments = skin['attachments'] as Map<String, dynamic>?;
      if (attachments != null) {
        attachments.forEach((slotName, slotAttachments) {
          final slotAtts = slotAttachments as Map<String, dynamic>;
          slotAtts.forEach((attName, _) {
            attachmentNames.add(attName);
          });
        });
      }
    }
  }

  print('Found ${attachmentNames.length} unique attachments in skeleton\n');

  // Check matches
  print('=== CHECKING ATLAS REGIONS vs ATTACHMENTS ===\n');
  
  int missingCount = 0;
  int foundCount = 0;
  final List<String> missing = [];
  final List<String> found = [];

  for (final attName in attachmentNames) {
    if (atlasData.regions.containsKey(attName)) {
      foundCount++;
      found.add(attName);
    } else {
      missingCount++;
      missing.add(attName);
      
      // Try to find similar region
      String? similar;
      for (final regionName in atlasData.regions.keys) {
        if (regionName.contains(attName) || attName.contains(regionName)) {
          similar = regionName;
          break;
        }
      }
      
      if (similar != null) {
        print('  ❌ "$attName" → NOT FOUND (similar: "$similar")');
      } else {
        print('  ❌ "$attName" → NOT FOUND');
      }
    }
  }

  // Check regions not used
  print('\n=== CHECKING UNUSED REGIONS ===\n');
  final unusedRegions = <String>[];
  for (final regionName in atlasData.regions.keys) {
    if (!attachmentNames.contains(regionName)) {
      unusedRegions.add(regionName);
    }
  }

  print('=== SUMMARY ===');
  print('Total atlas regions: ${atlasData.regions.length}');
  print('Total attachments: ${attachmentNames.length}');
  print('Matched: $foundCount');
  print('Missing: $missingCount');
  print('Unused regions: ${unusedRegions.length}');

  if (missingCount > 0) {
    print('\n⚠️  WARNING: $missingCount attachments have no matching atlas region!');
    print('This can cause rendering issues (missing/drifted attachments).');
  } else {
    print('\n✓ All attachments have matching atlas regions.');
  }

  // Check region bounds
  print('\n=== CHECKING REGION BOUNDS ===\n');
  int invalidBounds = 0;
  for (final region in atlasData.regions.values) {
    if (region.width <= 0 || region.height <= 0) {
      invalidBounds++;
      print('  ⚠️  "$region.name": Invalid bounds (${region.width}x${region.height})');
    }
    if (region.x < 0 || region.y < 0) {
      invalidBounds++;
      print('  ⚠️  "$region.name": Negative position (${region.x}, ${region.y})');
    }
    if (region.x + region.width > atlasData.width || 
        region.y + region.height > atlasData.height) {
      invalidBounds++;
      print('  ⚠️  "$region.name": Out of bounds (${region.x + region.width}x${region.y + region.height} > ${atlasData.width}x${atlasData.height})');
    }
  }

  if (invalidBounds == 0) {
    print('✓ All region bounds are valid.');
  } else {
    print('\n⚠️  WARNING: $invalidBounds regions have invalid bounds!');
  }
}

// Simplified atlas parser (without Flutter dependencies)
Future<_AtlasData> _parseAtlasContent(String content) async {
  final lines = content.split(RegExp(r'\r?\n'));
  
  String? imagePath;
  int atlasWidth = 0;
  int atlasHeight = 0;
  final Map<String, _AtlasRegion> regions = {};
  
  String? currentRegion;
  Map<String, dynamic>? currentRegionData;
  
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (currentRegion != null && currentRegionData != null) {
        regions[currentRegion] = _AtlasRegion(
          name: currentRegion,
          x: currentRegionData['x'] ?? 0,
          y: currentRegionData['y'] ?? 0,
          width: currentRegionData['width'] ?? 0,
          height: currentRegionData['height'] ?? 0,
          originalWidth: currentRegionData['originalWidth'] ?? currentRegionData['width'] ?? 0,
          originalHeight: currentRegionData['originalHeight'] ?? currentRegionData['height'] ?? 0,
          offsetX: currentRegionData['offsetX'] ?? 0,
          offsetY: currentRegionData['offsetY'] ?? 0,
          rotated: currentRegionData['rotated'] ?? false,
        );
      }
      currentRegion = null;
      currentRegionData = null;
      continue;
    }
    
    if (trimmed.endsWith('.png') || trimmed.endsWith('.jpg') || trimmed.endsWith('.webp')) {
      imagePath = trimmed;
    } else if (trimmed.contains('size:')) {
      final match = RegExp(r'size:\s*(\d+),\s*(\d+)').firstMatch(trimmed);
      if (match != null) {
        atlasWidth = int.parse(match.group(1)!);
        atlasHeight = int.parse(match.group(2)!);
      }
    } else if (!trimmed.contains(':') && !trimmed.startsWith('format:') && 
               !trimmed.startsWith('filter:') && !trimmed.startsWith('repeat:')) {
      // Region name
      currentRegion = trimmed;
      currentRegionData = {};
    } else if (currentRegion != null && currentRegionData != null) {
      // Region property
      if (trimmed.startsWith('xy:')) {
        final match = RegExp(r'xy:\s*(\d+),\s*(\d+)').firstMatch(trimmed);
        if (match != null) {
          currentRegionData['x'] = int.parse(match.group(1)!);
          currentRegionData['y'] = int.parse(match.group(2)!);
        }
      } else if (trimmed.startsWith('size:')) {
        final match = RegExp(r'size:\s*(\d+),\s*(\d+)').firstMatch(trimmed);
        if (match != null) {
          currentRegionData['width'] = int.parse(match.group(1)!);
          currentRegionData['height'] = int.parse(match.group(2)!);
        }
      } else if (trimmed.startsWith('orig:')) {
        final match = RegExp(r'orig:\s*(\d+),\s*(\d+)').firstMatch(trimmed);
        if (match != null) {
          currentRegionData['originalWidth'] = int.parse(match.group(1)!);
          currentRegionData['originalHeight'] = int.parse(match.group(2)!);
        }
      } else if (trimmed.startsWith('offset:')) {
        final match = RegExp(r'offset:\s*(\d+),\s*(\d+)').firstMatch(trimmed);
        if (match != null) {
          currentRegionData['offsetX'] = int.parse(match.group(1)!);
          currentRegionData['offsetY'] = int.parse(match.group(2)!);
        }
      } else if (trimmed.startsWith('rotate:')) {
        currentRegionData['rotated'] = trimmed.contains('true') || trimmed.contains('xy');
      }
    }
  }
  
  // Handle last region
  if (currentRegion != null && currentRegionData != null) {
    regions[currentRegion] = _AtlasRegion(
      name: currentRegion,
      x: currentRegionData['x'] ?? 0,
      y: currentRegionData['y'] ?? 0,
      width: currentRegionData['width'] ?? 0,
      height: currentRegionData['height'] ?? 0,
      originalWidth: currentRegionData['originalWidth'] ?? currentRegionData['width'] ?? 0,
      originalHeight: currentRegionData['originalHeight'] ?? currentRegionData['height'] ?? 0,
      offsetX: currentRegionData['offsetX'] ?? 0,
      offsetY: currentRegionData['offsetY'] ?? 0,
      rotated: currentRegionData['rotated'] ?? false,
    );
  }
  
  return _AtlasData(
    imagePath: imagePath ?? '',
    width: atlasWidth,
    height: atlasHeight,
    regions: regions,
  );
}

class _AtlasRegion {
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;
  final int offsetX;
  final int offsetY;
  final bool rotated;

  _AtlasRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
    required this.offsetX,
    required this.offsetY,
    required this.rotated,
  });
}

class _AtlasData {
  final String imagePath;
  final int width;
  final int height;
  final Map<String, _AtlasRegion> regions;

  _AtlasData({
    required this.imagePath,
    required this.width,
    required this.height,
    required this.regions,
  });
}

