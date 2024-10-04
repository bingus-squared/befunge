import 'dart:convert';
import 'dart:html' as html;

import 'package:client/chunks.dart';
import 'package:client/rendering.dart';
import 'package:client/state.dart';
import 'package:web/helpers.dart';
import 'package:web_socket_channel/html.dart';

enum InputMode {
  normal,
  insert,
  command,
}

void setInputMode(InputMode mode) {
  inputMode = mode;
  final commandInput = document.querySelector('#command-input') as html.InputElement;
  final commandBar = document.querySelector('#command-bar-outer') as html.DivElement;
  switch (mode) {
    case InputMode.normal:
      commandInput.blur();
      commandBar.style.display = 'none';
    case InputMode.insert:
      commandInput.blur();
      hideHover = true;
      render();
      commandBar.style.display = 'none';
    case InputMode.command:
      commandBar.style.display = 'block';
      commandInput.focus();
      hideHover = true;
      render();
  }
}

void clearOutput() {
  final outputDiv = document.querySelector('#command-output') as html.DivElement;
  outputDiv.innerHtml = '';
  outputDiv.style.display = 'none';
}

void setOutput(String output) {
  if (output.isEmpty) {
    clearOutput();
    return;
  }
  final outputDiv = document.querySelector('#command-output') as html.DivElement;
  outputDiv.innerHtml = '';
  final pre = document.createElement('pre') as html.PreElement;
  pre.text = output;
  outputDiv.append(pre);
  outputDiv.style.display = 'block';
}

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
        chunk.cursors[int.parse(entry.key)] =
            Cursor(cursor['x'], cursor['y'], direction);
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

void printSel() {
  if (selectStartCell == null || selectEndCell == null) {
    return;
  }
  final start = selectStartCell!;
  final end = selectEndCell!;
  if (start == end) {
    setOutput('> sel ${start.$1},${start.$2}');
  } else {
    final topLeft = (start.$1 < end.$1 ? start.$1 : end.$1, start.$2 < end.$2 ? start.$2 : end.$2);
    final bottomRight = (start.$1 > end.$1 ? start.$1 : end.$1, start.$2 > end.$2 ? start.$2 : end.$2);
    setOutput('> sel ${topLeft.$1},${topLeft.$2} ${bottomRight.$1 - topLeft.$1 + 1},${bottomRight.$2 - topLeft.$2 + 1}');
  }
}

void start() {
  connect();
  render();
  setInputMode(InputMode.normal);

  html.window.onResize.listen((event) {
    render();
  });

  final canvas = document.querySelector('#output') as CanvasElement;
  final commandInput = document.querySelector('#command-input') as html.InputElement;
  void updateCursor() {
    canvas.style.cursor = panning ? 'grabbing' : 'pointer';
  }

  updateCursor();
  html.window.onContextMenu.listen((event) {
    final target = event.target;
    if (target is! CanvasElement || target != canvas) {
      return;
    }
    event.preventDefault();
  });
  html.window.onMouseDown.listen((event) {
    final target = event.target;
    if (target is! CanvasElement || target != canvas) {
      return;
    }
    event.preventDefault();
    if (event.button == 0) {
      selectStartCell = hoverCell;
      selectEndCell = hoverCell;
      selecting = true;
      printSel();
      render();
    } else if (event.button == 1) {
      panning = true;
      updateCursor();
    }
  });
  html.window.onMouseUp.listen((event) {
    if (event.button == 0) {
      selecting = false;
      hideHover = true;
      render();
      event.preventDefault();
    } else if (event.button == 1) {
      panning = false;
      updateCursor();
      event.preventDefault();
    }
  });
  html.window.onMouseMove.listen((event) {
    final target = event.target;
    if (target is! CanvasElement || target != canvas) {
      if (hoverCell != null) {
        hoverCell = null;
        render();
      }
      return;
    }
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
    if (hoverCell != (cellX, cellY) || hideHover) {
      hideHover = false;
      if (cellX >= 0 &&
          cellY >= 0 &&
          cellX < chunkWidth * chunkLimit &&
          cellY < chunkWidth * chunkLimit) {
        hoverCell = (cellX, cellY);
        if (selecting) {
          selectEndCell = hoverCell;
          printSel();
        }
      }
      render();
    }
  });
  html.window.onWheel.listen((event) {
    final target = event.target;
    if (target is! CanvasElement || target != canvas) {
      return;
    }
    event.preventDefault();
    final delta = event.deltaY;
    camera.zoomD = (camera.zoomD - delta / 400).clamp(2, 10);
    hideHover = true;
    render();
  });
  html.window.onKeyPress.listen((event) {
    print('Key press: ${event.key}');
    final key = event.key;
    if (inputMode == InputMode.command) {
      if (key == 'Enter') {
        final command = commandInput.value ?? '';
        commandInput.value = '';
        setInputMode(InputMode.normal);
        setOutput('Got command: $command');
        event.preventDefault();
      }
      return;
    }
    if (key == 'i') {
      setInputMode(InputMode.insert);
    } else if (key == ':') {
      setInputMode(InputMode.command);
    }
    event.preventDefault();
  });
  html.window.onKeyDown.listen((event) {
    print('Key down: ${event.key}');
    final key = event.key;
    if (key == 'Escape') {
      if (inputMode != InputMode.normal) {
        setInputMode(InputMode.normal);
        setOutput('normal mode');
      } else {
        clearOutput();
      }
      html.window.getSelection()?.removeAllRanges();
      hideHover = true;
      selecting = false;
      selectStartCell = null;
      selectEndCell = null;
      render();
    }
  });
  commandInput.onFocus.listen((event) {
    setInputMode(InputMode.command);
  });
}
