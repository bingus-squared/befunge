import 'dart:convert';
import 'dart:js_interop';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'package:client/chars.dart';
import 'package:vector_math/vector_math.dart';
import 'package:web/helpers.dart';
import 'package:web_socket_channel/html.dart';

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

final directions = ['Up', 'Down', 'Left', 'Right'];

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

  var highlightWidth = camera.zoom >= 20 ? 2 : 1;
  var highlightRadius = camera.zoom >= 20
      ? 4
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

const chunkWidth = 32;
const chunkLimit = 4; // 335544320;
var rand = Random();
var camera = Camera();
var atlasCache = AtlasCache();
var chunkCache = ChunkCache();
bool didRender = false;
bool willRender = false;
var dirtyChunks = <(int, int)>{};
HtmlWebSocketChannel? channel;
var lastSubscribedChunks = <(int, int)>{};
var panning = false;
var selecting = false;
(int, int)? hoverCell;
(int, int)? selectStartCell;
(int, int)? selectEndCell;

void handleMessage(dynamic messageData) {
  print(JsonEncoder.withIndent('  ').convert(messageData));
  if (messageData
      case {
        'ChunkData': {
          'x': num x,
          'y': num y,
          'data': String data,
          'cursors': dynamic cursors
        }
      }) {
    final chunk = chunkCache.chunks[(x as int, y as int)];
    if (chunk != null) {
      chunk.cells = base64.decode(data);
      chunk.cursors.clear();
      for (final entry in cursors.entries) {
        final cursor = entry.value;
        final direction = directions.indexOf(cursor['direction']);
        chunk.cursors[int.parse(entry.key)] = Cursor(cursor['x'], cursor['y'], direction);
      }
      dirtyChunks.add((x, y));
      queueRender();
    }
  } else if (messageData
      case {'Update': {'action': dynamic action, 'x': int x, 'y': int y}}) {
    final chunkX = x ~/ chunkWidth;
    final chunkY = y ~/ chunkWidth;
    final localX = x % chunkWidth;
    final localY = y % chunkWidth;
    if (action case {'UpdateCell': {'c': int c}}) {
      final chunk = chunkCache.getChunk(chunkX, chunkY);
      chunk.getCells()[localX + localY * chunkWidth] = c;
      dirtyChunks.add((chunkX, chunkY));
      queueRender();
    } else if (action
        case {
          'SpawnCursor': {'id': int id, 'direction': String directionStr}
        }) {
      final chunk = chunkCache.getChunk(chunkX, chunkY);
      final direction = directions.indexOf(directionStr);
      final cursor = chunk.cursors
          .putIfAbsent(id, () => Cursor(localX, localY, direction));
      cursor.x = localX;
      cursor.y = localY;
      cursor.direction = direction;
      chunkCache.cursors[id] = (chunkX, chunkY);
      queueRender();
    } else if (action
        case {'MoveCursor': {'id': int id, 'to_x': int toX, 'to_y': int toY}}) {
      final toChunkX = toX ~/ chunkWidth;
      final toChunkY = toY ~/ chunkWidth;
      final chunk = chunkCache.getChunk(chunkX, chunkY);
      chunkCache.cursors[id] = (toChunkX, toChunkY);
      if (chunkX == toChunkX || chunkY == toChunkY) {
        final cursor = chunk.cursors.putIfAbsent(
            id, () => Cursor(toX % chunkWidth, toY % chunkWidth, 0));
        cursor.x = toX % chunkWidth;
        cursor.y = toY % chunkWidth;
      } else {
        chunk.cursors.remove(id);
        final newChunk = chunkCache.getChunk(toChunkX, toChunkY);
        final cursor = chunk.cursors.remove(id) ??
            Cursor(toX % chunkWidth, toY % chunkWidth, 0);
        newChunk.cursors[id] = cursor;
      }
      queueRender();
    } else if (action case {'DestroyCursor': {'id': int id}}) {
      final pos = chunkCache.cursors.remove(id);
      if (pos != null) {
        final chunk = chunkCache.getChunk(pos.$1, pos.$2);
        chunk.cursors.remove(id);
        queueRender();
      }
    } else {
      print('Unknown action');
    }
  } else {
    print('Unknown message');
  }
}

void connect() {
  channel = HtmlWebSocketChannel.connect('ws://localhost:3000/ws');
  channel!.stream.listen((message) {
    if (message is! String) {
      return;
    }
    final messageData = jsonDecode(message);
    if (messageData is List) {
      for (final message in messageData) {
        handleMessage(message);
      }
    } else {
      handleMessage(messageData);
    }
  }, onDone: () {
    final delay = rand.nextInt(9) + 1;
    print('Channel closed, reconnecting in $delay seconds');
    channel = null;
    Future.delayed(Duration(seconds: delay), connect);
  }, onError: (e) {
    print('Channel error: $e');
  });
  channel!.ready.then((_) {
    print('Connected');
    lastSubscribedChunks.clear();
    render();
  });
}

void main() {
  connect();
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
      if (cellX >= 0 &&
          cellY >= 0 &&
          cellX < chunkWidth * chunkLimit &&
          cellY < chunkWidth * chunkLimit) {
        hoverCell = (cellX, cellY);
        if (selecting) {
          selectEndCell = hoverCell;
        }
        render();
      }
    }
  });
  html.window.onWheel.listen((event) {
    event.preventDefault();
    final delta = event.deltaY;
    camera.zoomD = (camera.zoomD - delta / 400).clamp(2, 10);
    render();
  });
}
