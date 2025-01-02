import 'dart:math';

import 'package:client/io.dart';
import 'package:web_socket_channel/html.dart';

import 'chunks.dart';
import 'rendering.dart';

const chunkWidth = 32;
var chunkLimit = 0;
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
var hideHover = false;
(int, int)? hoverCell;
(int, int)? selectStartCell;
(int, int)? selectEndCell;
int? insertDirection = 0;
var didInsert = false;
(int, int, int)? pivotFrom;
InputMode inputMode = InputMode.normal;
