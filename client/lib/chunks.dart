import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/helpers.dart';

import 'rendering.dart';
import 'state.dart';

final directions = ['Right', 'Down', 'Left', 'Up'];

(int, int) dirNormal(int? direction) {
  switch (direction) {
    case 0:
      return (1, 0);
    case 1:
      return (0, 1);
    case 2:
      return (-1, 0);
    case 3:
      return (0, -1);
    default:
      return (0, 0);
  }
}

class Cursor {
  int x;
  int y;
  int direction;
  Cursor(this.x, this.y, this.direction);
}

class Chunk {
  final int x;
  final int y;
  Uint8List? cells;
  final canvas = document.createElement('canvas') as CanvasElement;
  late int lastZoom;
  var cursors = <int, Cursor>{};

  Chunk(this.x, this.y);

  Uint8List getCells() {
    return cells ??= Uint8List(chunkWidth * chunkWidth)
      ..fillRange(0, chunkWidth * chunkWidth, 0x20);
  }

  void paint() {
    final zoom = camera.zoom;
    final scaledChunkWidth = chunkWidth * zoom;
    lastZoom = zoom;
    canvas.width = chunkWidth * zoom;
    canvas.height = chunkWidth * zoom;
    final atlas = atlasCache.getAtlas(zoom);
    final context = canvas.context2D;
    context.clearRect(0, 0, scaledChunkWidth, scaledChunkWidth);
    context.fillStyle = 'rgb(20, 25, 33)' as JSString;
    context.font = '${zoom}px monospace';
    context.textAlign = 'center';
    context.textBaseline = 'middle';

    if (zoom > 8) {
      context.fillStyle = 'rgb(187, 197, 216)' as JSString;
      for (var y = 0; y <= chunkWidth; y++) {
        for (var x = 0; x <= chunkWidth; x++) {
          final cellX = x * zoom;
          final cellY = y * zoom;
          if (zoom >= 20) {
            final len = 2;
            context.fillRect(cellX, cellY, len, 1);
            context.fillRect(cellX, cellY, 1, len);
            context.fillRect(cellX + zoom - (len - 1), cellY, len - 1, 1);
            context.fillRect(cellX, cellY - (len - 1), 1, len - 1);
          } else {
            context.fillRect(cellX, cellY, 1, 1);
          }
        }
      }
    }

    if (atlas == null) {
      queueRender();
    } else if (cells != null) {
      for (var y = 0; y < chunkWidth; y++) {
        for (var x = 0; x < chunkWidth; x++) {
          final cellX = x * zoom;
          final cellY = y * zoom;
          var c = cells![x + y * chunkWidth];
          if (c == 0x20) {
            continue;
          }
          final atlasCellWidth = atlas.width ~/ 16;
          final atlasX = (c % 16) * atlasCellWidth;
          final atlasY = (c ~/ 16) * atlasCellWidth;
          context.drawImage(
            atlas as JSObject,
            atlasX,
            atlasY,
            atlasCellWidth,
            atlasCellWidth,
            cellX,
            cellY,
            zoom,
            zoom,
          );
        }
      }
    }
  }
}

class ChunkCache {
  final chunks = <(int, int), Chunk>{};
  final cursors = <int, (int, int)>{};

  Chunk getChunk(int x, int y) {
    final key = (x, y);
    if (chunks.containsKey(key)) {
      if (dirtyChunks.contains(key)) {
        dirtyChunks.remove(key);
        chunks[key]!.paint();
      }
      return chunks[key]!;
    } else {
      final chunk = Chunk(x, y);
      chunk.lastZoom = camera.zoom;
      chunks[key] = chunk;
      dirtyChunks.remove(key);
      return chunk;
    }
  }

  void removeChunk(int x, int y) {
    final key = (x, y);
    chunks.remove(key);
    dirtyChunks.remove(key);
    for (final id in cursors.keys.toList()) {
      cursors.remove(id);
    }
  }
}
