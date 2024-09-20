import 'dart:js_interop';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'package:client/chars.dart';
import 'package:vector_math/vector_math.dart';
import 'package:web/helpers.dart';

class Camera {
  Vector2 center = Vector2.zero();
  double zoomD = 4.0;
  int get zoom => pow(zoomD, 2).round();
  late double lastWidth;
  late double lastHeight;
  int get scaledChunkWidth => chunkWidth * zoom;
  double get topLeftChunkX => center.x / chunkWidth - lastWidth / scaledChunkWidth / 2;
  double get topLeftChunkY => center.y / chunkWidth - lastHeight / scaledChunkWidth / 2;
  double get bottomRightChunkX => topLeftChunkX + lastWidth / scaledChunkWidth;
  double get bottomRightChunkY => topLeftChunkY + lastHeight / scaledChunkWidth;
}

class AtlasCache {
  static const int atlasMin = 16;
  static const int atlasMax = 128;
  final atlases = <int, CanvasElement>{};
  final inProgress = <int>{};

  void generateAtlas(int scale) async {
    try {
      final canvas = html.CanvasElement(width: scale * 16, height: scale * 16) as CanvasElement;
      final context = canvas.context2D;
      context.fillStyle = 'rgb(20, 25, 33)' as JSString;
      context.font = '${scale - 2}px monospace';
      context.textAlign = 'center';
      context.textBaseline = 'middle';
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          var c = x + y * 16;
          context.clearRect(x * scale, y * scale, scale, scale);
          context.fillText(characters[c], x * scale + scale / 2, y * scale + scale / 2);
        }
      }
      atlases[scale] = canvas;
    } finally {
      inProgress.remove(scale);
    }
  }

  CanvasElement? getAtlas(int scale) {
    final closest =
        pow(2, (log(scale) / log(2)).ceil()).clamp(atlasMin, atlasMax).toInt();
    if (atlases.containsKey(closest)) {
      return atlases[closest];
    } else if (!inProgress.contains(closest)) {
      inProgress.add(closest);
      generateAtlas(closest);
    }
    for (var i = atlasMin; i <= atlasMax; i *= 2) {
      if (i >= scale) {
        return atlases[i];
      }
    }
  }
}

const chunkWidth = 32;
const maxChunkOffset = 335544320;
var rand = Random();

class Chunk {
  final cells = Uint8List(chunkWidth * chunkWidth);
  final canvas = document.createElement('canvas') as CanvasElement;
  late int lastZoom;

  Chunk() {
    cells.fillRange(0, cells.length, 0x20);
    for (var i = 0; i < cells.length; i++) {
      if (rand.nextInt(100) < 5) {
        cells[i] = rand.nextInt(256);
      }
    }
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

    if (atlas == null) {
      queueRender();
    } else {
      for (var y = 0; y < chunkWidth; y++) {
        for (var x = 0; x < chunkWidth; x++) {
          final cellX = x * zoom;
          final cellY = y * zoom;
          var c = cells[x + y * chunkWidth];
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

    context.fillStyle = 'rgb(158, 190, 255)' as JSString;
    for (var y = 0; y <= chunkWidth; y++) {
      for (var x = 0; x <= chunkWidth; x++) {
        final cellX = x * zoom;
        final cellY = y * zoom;
        context.fillRect(cellX, cellY, 1, 1);
      }
    }
  }
}

class ChunkCache {
  final chunks = <(int, int), Chunk>{};

  Chunk getChunk(int x, int y) {
    final key = (x, y);
    if (chunks.containsKey(key)) {
      if (dirtyChunks.contains(key)) {
        dirtyChunks.remove(key);
        chunks[key]!.paint();
      }
      return chunks[key]!;
    } else {
      final chunk = Chunk();
      chunk.lastZoom = camera.zoom;
      chunks[key] = chunk;
      chunk.paint();
      dirtyChunks.remove(key);
      return chunk;
    }
  }

  removeChunk(int x, int y) {
    final key = (x, y);
    chunks.remove(key);
    dirtyChunks.remove(key);
  }
}

var camera = Camera();
var atlasCache = AtlasCache();
var chunkCache = ChunkCache();

bool didRender = false;
bool willRender = false;
var dirtyChunks = <(int, int)>{};

void queueRender() {
  if (!willRender) {
    willRender = true;
    html.window.requestAnimationFrame((time) {
      willRender = false;
      if (!didRender) {
        didRender = true;
        render();
      }
    });
  }
}

void render() {
  final body = document.querySelector('body') as HTMLBodyElement;
  final canvas = document.querySelector('#output') as CanvasElement;
  final height = body.clientHeight;
  final width = body.clientWidth;
  if (canvas.height != height || canvas.width != width) {
    canvas.height = height;
    canvas.width = width;
  }
  camera.lastWidth = width.toDouble();
  camera.lastHeight = height.toDouble();
  final context = canvas.context2D;

  context.fillStyle = 'rgb(222, 233, 255)' as JSString;
  context.fillRect(0, 0, width, height);

  final topLeftChunkX = camera.topLeftChunkX.floor();
  final topLeftChunkY = camera.topLeftChunkY.floor();
  final bottomRightCellX = camera.bottomRightChunkX.ceil();
  final bottomRightCellY = camera.bottomRightChunkY.ceil();
  final offsetX =
      ((camera.topLeftChunkX - topLeftChunkX) * camera.scaledChunkWidth).round() / camera.scaledChunkWidth;
  final offsetY =
      ((camera.topLeftChunkY - topLeftChunkY) * camera.scaledChunkWidth).round() / camera.scaledChunkWidth;

  // context.drawImage(atlas as JSObject, 0, 0); return;

  // context.drawImage(chunkCache.getChunk(0, 0).canvas as JSObject, 0, 0); return;

  for (var y = topLeftChunkY; y <= bottomRightCellY; y++) {
    for (var x = topLeftChunkX; x <= bottomRightCellX; x++) {
      final chunkX = ((x - topLeftChunkX) - offsetX) * camera.scaledChunkWidth;
      final chunkY = ((y - topLeftChunkY) - offsetY) * camera.scaledChunkWidth;
      if (x < 0 || y < 0) {
        context.fillStyle = 'rgb(187, 197, 216)' as JSString;
        context.fillRect(chunkX, chunkY, camera.scaledChunkWidth, camera.scaledChunkWidth);
        continue;
      }
      final chunk = chunkCache.getChunk(x, y);
      if (chunk.lastZoom != camera.zoom) {
        chunk.paint();
      }
      context.drawImage(chunk.canvas as JSObject, chunkX, chunkY);
    }
  }

  for (final key in chunkCache.chunks.keys) {
    if (key.$1 < topLeftChunkX - 4 ||
        key.$1 > bottomRightCellX + 4 ||
        key.$2 < topLeftChunkY - 4 ||
        key.$2 > bottomRightCellY + 4) {
      chunkCache.removeChunk(key.$1, key.$2);
    }
  }
}

void main() {
  render();
  html.window.onResize.listen((event) {
    render();
  });

  var panning = false;

  final canvas = document.querySelector('#output') as CanvasElement;
  void updateCursor() {
    canvas.style.cursor = panning ? 'grabbing' : 'default';
  }
  updateCursor();

  html.window.onContextMenu.listen((event) {
    print('Context menu: $event');
    event.preventDefault();
  });
  html.window.onMouseDown.listen((event) {
    print('Mouse down: $event');
    event.preventDefault();
    if (event.button == 1) {
      panning = true;
      updateCursor();
    }
  });
  html.window.onMouseUp.listen((event) {
    print('Mouse up: $event');
    event.preventDefault();
    if (event.button == 1) {
      panning = false;
      updateCursor();
    }
  });
  html.window.onMouseMove.listen((event) {
    print('Mouse move: $event');
    event.preventDefault();
    if (panning) {
      camera.center.x -= event.movement.x / camera.zoom;
      camera.center.y -= event.movement.y / camera.zoom;
      render();
    }
  });
  // Scroll to zoom
  html.window.onWheel.listen((event) {
    print('Wheel: $event');
    event.preventDefault();
    final delta = event.deltaY;
    camera.zoomD = (camera.zoomD - delta / 400).clamp(2, 16);
    render();
  });
}
