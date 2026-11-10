import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

Map<String, Object> _createPreview(Map<String, Object> request) {
  final image = _decodeOrientedImage(
    request['sourceBytes'] as Uint8List,
    request['rotationDegrees'] as int,
  );
  final preview = image.width <= 1200 && image.height <= 1200
      ? image
      : image.width >= image.height
      ? img.copyResize(
          image,
          width: 1200,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          image,
          height: 1200,
          interpolation: img.Interpolation.average,
        );
  return {
    'width': image.width,
    'height': image.height,
    'previewBytes': Uint8List.fromList(img.encodeJpg(preview, quality: 85)),
  };
}

Uint8List _cropImage(Map<String, Object> request) {
  final image = _decodeOrientedImage(
    request['sourceBytes'] as Uint8List,
    request['rotationDegrees'] as int,
  );
  var cropped = img.copyCrop(
    image,
    x: request['x'] as int,
    y: request['y'] as int,
    width: request['side'] as int,
    height: request['side'] as int,
  );
  if (cropped.width > 1200) {
    cropped = img.copyResize(
      cropped,
      width: 1200,
      height: 1200,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}

img.Image _decodeOrientedImage(Uint8List bytes, int rotationDegrees) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Format gambar tidak dikenali.');
  }
  final oriented = img.bakeOrientation(decoded);
  if (rotationDegrees == 0) return oriented;
  return img.copyRotate(oriented, angle: rotationDegrees);
}

class ProfilePhotoCropperPage extends StatefulWidget {
  final Uint8List sourceBytes;

  const ProfilePhotoCropperPage({super.key, required this.sourceBytes});

  @override
  State<ProfilePhotoCropperPage> createState() =>
      _ProfilePhotoCropperPageState();
}

class _ProfilePhotoCropperPageState extends State<ProfilePhotoCropperPage> {
  static const Color _background = Color(0xFF111B21);
  static const Color _accent = Color(0xFF64B5F6);

  int? _sourceWidth;
  int? _sourceHeight;
  int? _baseImageWidth;
  int? _baseImageHeight;
  int _rotationTurns = 0;
  int _rotationDegrees = 0;
  Uint8List? _previewBytes;
  Rect? _displayRect;
  Rect? _selectionRect;
  Rect? _gestureStartRect;
  Rect? _gestureDisplayRect;
  Offset? _gestureStartPosition;
  _CropHandle? _activeHandle;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final result = await compute(_createPreview, {
        'sourceBytes': widget.sourceBytes,
        'rotationDegrees': 0,
      });
      if (!mounted) return;
      setState(() {
        _baseImageWidth = result['width'] as int;
        _baseImageHeight = result['height'] as int;
        _sourceWidth = result['width'] as int;
        _sourceHeight = result['height'] as int;
        _previewBytes = result['previewBytes'] as Uint8List;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Foto tidak dapat dibuka: '
            '${error.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  Rect _initialSelection(Rect imageRect) {
    final side = imageRect.shortestSide * 0.72;
    return Rect.fromCenter(center: imageRect.center, width: side, height: side);
  }

  void _beginDrag(Offset position, Rect displayRect, Rect selectionRect) {
    const handleRadius = 34.0;
    final handles = <(Offset, _CropHandle)>[
      (selectionRect.topLeft, _CropHandle.topLeft),
      (selectionRect.topRight, _CropHandle.topRight),
      (selectionRect.bottomLeft, _CropHandle.bottomLeft),
      (selectionRect.bottomRight, _CropHandle.bottomRight),
    ];

    _activeHandle = null;
    for (final (point, handle) in handles) {
      if ((position - point).distance <= handleRadius) {
        _activeHandle = handle;
        break;
      }
    }
    if (_activeHandle == null && selectionRect.contains(position)) {
      _activeHandle = _CropHandle.move;
    }

    _gestureStartPosition = position;
    _gestureStartRect = selectionRect;
    _gestureDisplayRect = displayRect;
  }

  void _updateDrag(Offset position) {
    final handle = _activeHandle;
    final start = _gestureStartRect;
    final display = _gestureDisplayRect;
    final startPosition = _gestureStartPosition;
    if (handle == null ||
        start == null ||
        display == null ||
        startPosition == null) {
      return;
    }

    final delta = position - startPosition;
    if (handle == _CropHandle.move) {
      final left = (start.left + delta.dx)
          .clamp(display.left, display.right - start.width)
          .toDouble();
      final top = (start.top + delta.dy)
          .clamp(display.top, display.bottom - start.height)
          .toDouble();
      setState(() {
        _selectionRect = Rect.fromLTWH(left, top, start.width, start.height);
      });
      return;
    }

    late final Offset anchor;
    late final double horizontalDirection;
    late final double verticalDirection;
    switch (handle) {
      case _CropHandle.topLeft:
        anchor = start.bottomRight;
        horizontalDirection = -1;
        verticalDirection = -1;
      case _CropHandle.topRight:
        anchor = start.bottomLeft;
        horizontalDirection = 1;
        verticalDirection = -1;
      case _CropHandle.bottomLeft:
        anchor = start.topRight;
        horizontalDirection = -1;
        verticalDirection = 1;
      case _CropHandle.bottomRight:
        anchor = start.topLeft;
        horizontalDirection = 1;
        verticalDirection = 1;
      case _CropHandle.move:
        return;
    }

    final draggedCorner = position;
    final widthFromX = (draggedCorner.dx - anchor.dx) * horizontalDirection;
    final widthFromY = (draggedCorner.dy - anchor.dy) * verticalDirection;
    final maxWidth = horizontalDirection < 0
        ? anchor.dx - display.left
        : display.right - anchor.dx;
    final maxHeight = verticalDirection < 0
        ? anchor.dy - display.top
        : display.bottom - anchor.dy;
    final maxSide = maxWidth < maxHeight ? maxWidth : maxHeight;
    final minSide = maxSide < 72 ? maxSide : 72.0;
    final side = ((widthFromX + widthFromY) / 2)
        .clamp(minSide, maxSide)
        .toDouble();

    setState(() {
      _selectionRect = Rect.fromLTRB(
        horizontalDirection < 0 ? anchor.dx - side : anchor.dx,
        verticalDirection < 0 ? anchor.dy - side : anchor.dy,
        horizontalDirection > 0 ? anchor.dx + side : anchor.dx,
        verticalDirection > 0 ? anchor.dy + side : anchor.dy,
      );
    });
  }

  void _rotateImage() {
    final baseWidth = _baseImageWidth;
    final baseHeight = _baseImageHeight;
    if (baseWidth == null || baseHeight == null || _isProcessing) return;

    final rotationTurns = _rotationTurns + 1;
    final rotationDegrees = rotationTurns % 4 * 90;
    final isQuarterTurn = rotationDegrees == 90 || rotationDegrees == 270;
    setState(() {
      _rotationTurns = rotationTurns;
      _rotationDegrees = rotationDegrees;
      _sourceWidth = isQuarterTurn ? baseHeight : baseWidth;
      _sourceHeight = isQuarterTurn ? baseWidth : baseHeight;
      _selectionRect = null;
      _errorMessage = null;
    });
  }

  Future<void> _finishCrop(Rect displayRect, Rect selectionRect) async {
    final sourceWidth = _sourceWidth;
    final sourceHeight = _sourceHeight;
    if (sourceWidth == null || sourceHeight == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final scale = sourceWidth / displayRect.width;
      final x = ((selectionRect.left - displayRect.left) * scale)
          .floor()
          .clamp(0, sourceWidth - 1)
          .toInt();
      final y = ((selectionRect.top - displayRect.top) * scale)
          .floor()
          .clamp(0, sourceHeight - 1)
          .toInt();
      final maxSide = (sourceWidth - x).clamp(1, sourceHeight - y).toInt();
      final side = (selectionRect.width * scale)
          .round()
          .clamp(1, maxSide)
          .toInt();
      final croppedBytes = await compute(_cropImage, {
        'sourceBytes': widget.sourceBytes,
        'rotationDegrees': _rotationDegrees,
        'x': x,
        'y': y,
        'side': side,
      });
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(croppedBytes);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Foto gagal diproses: '
            '${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _background,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit foto profil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _isLoading ||
                              _isProcessing ||
                              _sourceWidth == null ||
                              _sourceHeight == null
                          ? null
                          : () {
                              final displayRect = _displayRect;
                              if (displayRect == null) return;
                              final selectionRect =
                                  _selectionRect ??
                                  _initialSelection(displayRect);
                              _finishCrop(displayRect, selectionRect);
                            },
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildCropArea()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF8A80),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    IconButton(
                      tooltip: 'Putar 90°',
                      onPressed:
                          _isLoading || _isProcessing || _sourceWidth == null
                          ? null
                          : _rotateImage,
                      icon: const Icon(
                        Icons.rotate_right_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Text(
                      'Putar',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Geser kotak untuk memilih area · Tarik sudut untuk mengubah ukuran',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (_sourceWidth == null ||
        _sourceHeight == null ||
        _previewBytes == null) {
      return const Center(
        child: Text(
          'Foto tidak dapat dibuka.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final displayRect = _displayRectFor(
          _sourceWidth!,
          _sourceHeight!,
          size,
        );
        final selectionRect = _selectionRect ?? _initialSelection(displayRect);
        _displayRect = displayRect;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              _beginDrag(details.localPosition, displayRect, selectionRect),
          onPanUpdate: (details) => _updateDrag(details.localPosition),
          onPanEnd: (_) {
            _activeHandle = null;
            _gestureStartRect = null;
            _gestureDisplayRect = null;
            _gestureStartPosition = null;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: displayRect,
                child: ClipRect(
                  child: Center(
                    child: AnimatedRotation(
                      turns: _rotationTurns / 4,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      child: Image.memory(
                        _previewBytes!,
                        width: _rotationDegrees == 90 || _rotationDegrees == 270
                            ? displayRect.height
                            : displayRect.width,
                        height:
                            _rotationDegrees == 90 || _rotationDegrees == 270
                            ? displayRect.width
                            : displayRect.height,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                painter: _CropOverlayPainter(selectionRect),
                size: size,
              ),
              if (_isProcessing)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Rect _displayRectFor(int width, int height, Size bounds) {
    final scale = (bounds.width / width)
        .clamp(0.0, bounds.height / height)
        .toDouble();
    final displaySize = Size(width * scale, height * scale);
    return Rect.fromCenter(
      center: Offset(bounds.width / 2, bounds.height / 2),
      width: displaySize.width,
      height: displaySize.height,
    );
  }
}

enum _CropHandle { topLeft, topRight, bottomLeft, bottomRight, move }

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = const Color(0x99000000);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), dimPaint);
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom),
      dimPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 0.7;
    for (var index = 1; index < 3; index++) {
      final fraction = index / 3;
      final x = cropRect.left + cropRect.width * fraction;
      final y = cropRect.top + cropRect.height * fraction;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }

    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, framePaint);

    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const handleLength = 18.0;
    for (final (corner, horizontal, vertical) in <(Offset, double, double)>[
      (cropRect.topLeft, 1, 1),
      (cropRect.topRight, -1, 1),
      (cropRect.bottomLeft, 1, -1),
      (cropRect.bottomRight, -1, -1),
    ]) {
      canvas.drawLine(
        corner,
        corner + Offset(horizontal * handleLength, 0),
        handlePaint,
      );
      canvas.drawLine(
        corner,
        corner + Offset(0, vertical * handleLength),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
