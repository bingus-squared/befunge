import 'dart:js_interop';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'package:client/chars.dart';
import 'package:vector_math/vector_math.dart';
import 'package:web/helpers.dart';

class Camera {
  Vector2 center = Vector2(
    (chunkWidth * chunkLimit) / 2,
    (chunkWidth * chunkLimit) / 2,
  );
  double zoomD = 4.0;
  int get zoom => pow(zoomD, 2).round();
  late double lastWidth;
  late double lastHeight;
  int get scaledChunkWidth => chunkWidth * zoom;
  double get topLeftX => center.x - lastWidth / zoom / 2;
  double get topLeftY => center.y - lastHeight / zoom / 2;
  double get topLeftChunkX =>
      center.x / chunkWidth - lastWidth / scaledChunkWidth / 2;
  double get topLeftChunkY =>
      center.y / chunkWidth - lastHeight / scaledChunkWidth / 2;
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
      final canvas = html.CanvasElement(width: scale * 16, height: scale * 16)
          as CanvasElement;
      final context = canvas.context2D;
      context.fillStyle = 'rgb(20, 25, 33)' as JSString;
      context.font = '${scale - 2}px monospace';
      context.textAlign = 'center';
      context.textBaseline = 'middle';

      const flag_colors = [
        'lch(50.77% 78.04 0)',
        'lch(44.91% 78.09 36.11)',
        'lch(56.64% 78.04 60.56)',
        'lch(76.7% 97.79 86.11)',
        'lch(76.7% 90.18 132.36)',
        'lch(76.7% 90.18 168.33)',
        'lch(76.7% 62.88 216.11)',
        'lch(50.15% 88.83 282.78)',
        'lch(50.15% 108.08 314.48)',
        'lch(5.71% 0 314.48)',
      ];

      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          var c = x + y * 16;
          var newScale = scale - 2;
          if (c >= 0x80 && c < 0x80 + flag_colors.length) {
            newScale = (newScale * 0.8).round();
          }
          context.font = '${newScale}px monospace';
          context.clearRect(x * scale, y * scale, scale, scale);
          context.fillText(
              characters[c], x * scale + scale / 2, y * scale + scale / 2);
        }
      }
      context.globalCompositeOperation = "source-atop";

      for (var i = 0; i < flag_colors.length; i++) {
        final x = (i + 0x80) % 16;
        final y = (i + 0x80) ~/ 16;
        context.fillStyle = flag_colors[i] as JSString;
        context.fillRect(x * scale, y * scale, scale, scale);
      }
      context.globalCompositeOperation = "source-over";
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
const chunkLimit = 10; // 335544320;
var rand = Random();

class Chunk {
  final int x;
  final int y;
  final cells = Uint8List(chunkWidth * chunkWidth);
  final canvas = document.createElement('canvas') as CanvasElement;
  late int lastZoom;

  Chunk(this.x, this.y) {
    if (this.x == 0 && this.y == 0) {
      for (var i = 0; i < cells.length; i++) {
        cells[i] = i;
      }
    } else {
      cells.fillRange(0, cells.length, 0x20);
      for (var i = 0; i < cells.length; i++) {
        if (rand.nextInt(100) < 5) {
          cells[i] = rand.nextInt(256);
        }
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
      final chunk = Chunk(x, y);
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
      ((camera.topLeftChunkX - topLeftChunkX) * camera.scaledChunkWidth)
              .round() /
          camera.scaledChunkWidth;
  final offsetY =
      ((camera.topLeftChunkY - topLeftChunkY) * camera.scaledChunkWidth)
              .round() /
          camera.scaledChunkWidth;

  // context.drawImage(atlas as JSObject, 0, 0); return;

  // context.drawImage(chunkCache.getChunk(0, 0).canvas as JSObject, 0, 0); return;

  var highlightWidth = camera.zoom >= 20 ? 2 : 1;
  var highlightRadius = camera.zoom >= 20 ? 4 : camera.zoom >= 10 ? 2 : 0;
  var highlightPadding = camera.zoom >= 20 ? -2 : camera.zoom >= 10 ? -1 : 0;

  for (var y = topLeftChunkY; y <= bottomRightCellY; y++) {
    for (var x = topLeftChunkX; x <= bottomRightCellX; x++) {
      final chunkX = ((x - topLeftChunkX) - offsetX) * camera.scaledChunkWidth;
      final chunkY = ((y - topLeftChunkY) - offsetY) * camera.scaledChunkWidth;
      if (x < 0 || y < 0 || x >= chunkLimit || y >= chunkLimit) {
        context.fillStyle = 'rgb(187, 197, 216)' as JSString;
        context.fillRect(
            chunkX, chunkY, camera.scaledChunkWidth, camera.scaledChunkWidth);
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

  if (selectStartCell != null) {
    var x0 = selectStartCell!.$1;
    var y0 = selectStartCell!.$2;
    var x1 = selectEndCell!.$1;
    var y1 = selectEndCell!.$2;
    (x0, x1) = (min(x0, x1), max(x0, x1));
    (y0, y1) = (min(y0, y1), max(y0, y1));
    final cellX = (x0 - camera.topLeftX) * camera.zoom;
    final cellY = (y0 - camera.topLeftY) * camera.zoom;
    context.strokeStyle = 'rgb(28, 48, 77)' as JSString;
    context.lineWidth = highlightWidth;
    final path = Path2D();
    final padding = highlightPadding + 1;
    path.roundRect(
        cellX - padding,
        cellY - padding,
        (x1 - x0 + 1) * camera.zoom + padding * 2 + 1,
        (y1 - y0 + 1) * camera.zoom + padding * 2 + 1,
        [max(0, highlightRadius - 1)] as JSObject);
    context.stroke(path);
  }

  if (hoverCell != null && !selecting) {
    final cellX = hoverCell!.$1;
    final cellY = hoverCell!.$2;
    final chunkX = (cellX - camera.topLeftX) * camera.zoom;
    final chunkY = (cellY - camera.topLeftY) * camera.zoom;
    context.strokeStyle = 'rgb(143, 156, 178)' as JSString;
    context.lineWidth = highlightWidth;
    final path = Path2D();
    path.roundRect(
        chunkX - highlightPadding,
        chunkY - highlightPadding,
        camera.zoom + highlightPadding * 2 + 1,
        camera.zoom + highlightPadding * 2 + 1,
        [highlightRadius] as JSObject);
    context.stroke(path);
  }
}


var panning = false;
var selecting = false;
(int, int)? hoverCell = (0, 0);
(int, int)? selectStartCell;
(int, int)? selectEndCell;

void main() {
  render();
  html.window.onResize.listen((event) {
    render();
  });

  final canvas = document.querySelector('#output') as CanvasElement;
  void updateCursor() {
    canvas.style.cursor = panning ? 'grabbing' : 'pointer';
  }

  updateCursor();
  html.window.onContextMenu.listen((event) {
    event.preventDefault();
  });
  html.window.onMouseDown.listen((event) {
    event.preventDefault();
    if (event.button == 0) {
      selectStartCell = hoverCell;
      selectEndCell = hoverCell;
      selecting = true;
      render();
    } else if (event.button == 1) {
      panning = true;
      updateCursor();
    }
  });
  html.window.onMouseUp.listen((event) {
    event.preventDefault();
    if (event.button == 0) {
      selecting = false;
      render();
    } else if (event.button == 1) {
      panning = false;
      updateCursor();
    }
  });
  html.window.onMouseMove.listen((event) {
    event.preventDefault();
    if (panning) {
      camera.center.x -= event.movement.x / camera.zoom;
      camera.center.y -= event.movement.y / camera.zoom;
      render();
    }
    final x = event.offset.x;
    final y = event.offset.y;
    final cellX = (x / camera.zoom + camera.topLeftX).floor();
    final cellY = (y / camera.zoom + camera.topLeftY).floor();
    if (hoverCell != (cellX, cellY)) {
      hoverCell = (cellX, cellY);

      if (selecting) {
        selectEndCell = hoverCell;
        render();
      }

      render();
    }
  });
  html.window.onWheel.listen((event) {
    event.preventDefault();
    final delta = event.deltaY;
    camera.zoomD = (camera.zoomD - delta / 400).clamp(2, 10);
    render();
  });
}
