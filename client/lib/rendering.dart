import 'dart:convert';
import 'dart:js_interop';
import 'dart:html' as html;
import 'dart:math';

import 'package:client/chars.dart';
import 'package:client/io.dart';
import 'package:vector_math/vector_math.dart';
import 'package:web/helpers.dart';

import 'state.dart';

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

      const flagColors = [
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
          if (c >= 0x80 && c < 0x80 + flagColors.length) {
            newScale = (newScale * 0.8).round();
          }
          context.font = '${newScale}px monospace';
          context.clearRect(x * scale, y * scale, scale, scale);
          context.fillText(
              characters[c], x * scale + scale / 2, y * scale + scale / 2);
        }
      }
      context.globalCompositeOperation = "source-atop";

      for (var i = 0; i < flagColors.length; i++) {
        final x = (i + 0x80) % 16;
        final y = (i + 0x80) ~/ 16;
        context.fillStyle = flagColors[i] as JSString;
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

void queueRender() {
  if (!willRender) {
    willRender = true;
    html.window.requestAnimationFrame((time) {
      willRender = false;
      render();
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

  context.reset();
  context.fillStyle = 'rgb(222, 233, 255)' as JSString;
  context.fillRect(0, 0, width, height);

  final topLeftChunkX = camera.topLeftChunkX.floor();
  final topLeftChunkY = camera.topLeftChunkY.floor();
  final bottomRightChunkX = camera.bottomRightChunkX.ceil();
  final bottomRightChunkY = camera.bottomRightChunkY.ceil();
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

  var highlightWidth = camera.zoom >= 40
      ? camera.zoom / 20
      : camera.zoom >= 20
          ? 2
          : 1;
  var highlightRadius = camera.zoom >= 20
      ? camera.zoom / 10
      : camera.zoom >= 10
          ? 2
          : 0;
  var highlightPadding = camera.zoom >= 20
      ? -2
      : camera.zoom >= 10
          ? -1
          : 0;

  for (var y = topLeftChunkY; y <= bottomRightChunkY; y++) {
    for (var x = topLeftChunkX; x <= bottomRightChunkX; x++) {
      if (x < 0 || y < 0 || x >= chunkLimit || y >= chunkLimit) {
        continue;
      }
      final chunk = chunkCache.getChunk(x, y);
      for (final cursor in chunk.cursors.values) {
        print('cursor: ${cursor.x} ${cursor.y}');
        final cursorX =
            (cursor.x - camera.topLeftX + x * chunkWidth) * camera.zoom;
        final cursorY =
            (cursor.y - camera.topLeftY + y * chunkWidth) * camera.zoom;
        context.fillStyle = 'lch(85.06% 99.08 82.66 / 80.83%)' as JSString;
        final path = Path2D();
        path.roundRect(cursorX + 1, cursorY + 1, camera.zoom - 2,
            camera.zoom - 2, [max(0, highlightRadius - 1)] as JSObject);
        context.fill(path as JSObject);
      }
    }
  }

  for (var y = topLeftChunkY; y <= bottomRightChunkY; y++) {
    for (var x = topLeftChunkX; x <= bottomRightChunkX; x++) {
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

  if (selectStartCell != null) {
    var x0 = selectStartCell!.$1;
    var y0 = selectStartCell!.$2;
    var x1 = selectEndCell!.$1;
    var y1 = selectEndCell!.$2;
    (x0, x1) = (min(x0, x1), max(x0, x1));
    (y0, y1) = (min(y0, y1), max(y0, y1));
    final cellX = (x0 - camera.topLeftX) * camera.zoom;
    final cellY = (y0 - camera.topLeftY) * camera.zoom;
    if (inputMode == InputMode.insert) {
      context.strokeStyle = 'lch(52.37% 80.68 301.78)' as JSString;
    } else {
      context.strokeStyle = 'rgb(28, 48, 77)' as JSString;
    }
    context.lineWidth = highlightWidth;
    final padding = highlightPadding + highlightWidth;
    if (inputMode != InputMode.insert || !didInsert) {
      final path = Path2D();
      path.roundRect(
          cellX - padding,
          cellY - padding,
          (x1 - x0 + 1) * camera.zoom + padding * 2 + 1,
          (y1 - y0 + 1) * camera.zoom + padding * 2 + 1,
          [max(0, highlightRadius + highlightWidth)] as JSObject);
      context.stroke(path);
    }
    // Paint an arrow for insert mode
    if (inputMode == InputMode.insert && insertDirection != null) {
      final triangleSize = max(
          4, min(camera.zoom * 0.5, camera.zoom * 0.2 + highlightWidth * 2));
      context.save();
      context.translate(cellX + camera.zoom / 2, cellY + camera.zoom / 2);
      context.rotate(insertDirection! * pi / 2);
      context.translate(camera.zoom / 2 + padding, 0);
      context.fillStyle = 'lch(52.37% 80.68 301.78)' as JSString;
      context.beginPath();
      context.moveTo(0.5, -triangleSize / 2);
      context.lineTo(0.5 + triangleSize / 2, 0);
      context.lineTo(0.5, triangleSize / 2);
      context.fill();
      if (didInsert) {
        context.beginPath();
        context.lineCap = 'round';
        context.moveTo(1, -camera.zoom / 2 + highlightWidth / 2);
        context.lineTo(1, camera.zoom / 2 - highlightWidth / 2);
        context.stroke();
      }
      context.restore();
    }
  }

  if (hoverCell != null && !selecting && !hideHover) {
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

  for (final key in chunkCache.chunks.keys.toList()) {
    if (key.$1 < topLeftChunkX - 4 ||
        key.$1 > bottomRightChunkX + 4 ||
        key.$2 < topLeftChunkY - 4 ||
        key.$2 > bottomRightChunkY + 4) {
      chunkCache.removeChunk(key.$1, key.$2);
      if (lastSubscribedChunks.contains(key)) {
        lastSubscribedChunks.remove(key);
        channel!.sink.add(jsonEncode({
          'UnsubscribeChunk': {'x': key.$1, 'y': key.$2}
        }));
      }
    } else if (!lastSubscribedChunks.contains(key)) {
      lastSubscribedChunks.add(key);
      channel!.sink.add(jsonEncode({
        'SubscribeChunk': {'x': key.$1, 'y': key.$2}
      }));
    }
  }
}
