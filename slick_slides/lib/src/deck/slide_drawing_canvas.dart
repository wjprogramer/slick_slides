import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A canvas widget that allows drawing on slides.
class SlideDrawingCanvas extends StatefulWidget {
  /// Creates a [SlideDrawingCanvas].
  const SlideDrawingCanvas({
    required this.isDrawingEnabled,
    required this.onDrawingChanged,
    this.initialPaths = const [],
    this.strokeWidth = 3.0,
    this.strokeColor = Colors.red,
    this.onStateChanged,
    this.isEraserMode = false,
    this.eraserStrokeWidth = 30.0,
    super.key,
  });

  /// Whether drawing is enabled.
  final bool isDrawingEnabled;

  /// Called when the drawing changes.
  final void Function(List<DrawingPath> paths) onDrawingChanged;

  /// Called when undo/redo state changes (optional).
  final void Function(bool canUndo, bool canRedo)? onStateChanged;

  /// Initial paths to display.
  final List<DrawingPath> initialPaths;

  /// The width of the stroke.
  final double strokeWidth;

  /// The color of the stroke.
  final Color strokeColor;

  /// Whether eraser mode is enabled.
  final bool isEraserMode;

  /// The width of the eraser stroke.
  final double eraserStrokeWidth;

  @override
  State<SlideDrawingCanvas> createState() => _SlideDrawingCanvasState();
}

/// The state of [SlideDrawingCanvas]. Exposed for internal use.
class _SlideDrawingCanvasState extends State<SlideDrawingCanvas> {
  late List<DrawingPath> _paths;
  DrawingPath? _currentPath;
  final List<List<DrawingPath>> _undoStack = [];
  final List<List<DrawingPath>> _redoStack = [];
  ui.Image? _rasterizedImage;
  Size? _canvasSize;
  int _rasterizedPathCount = 0; // Number of paths that have been rasterized
  double _devicePixelRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.initialPaths);
    _saveState();
    // Notify initial state after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyStateChanged();
      }
    });
  }

  @override
  void dispose() {
    _rasterizedImage?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SlideDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update paths when initialPaths change (e.g., when switching slides)
    // But only if we're not currently drawing (no _currentPath)
    if (_currentPath == null && oldWidget.initialPaths != widget.initialPaths) {
      // Check if the new initialPaths match our current _paths
      // If they match, it's likely just a reference update from onDrawingChanged
      // and we shouldn't reset the undo stack
      final pathsMatch = _pathsMatch(_paths, widget.initialPaths);

      if (!pathsMatch) {
        // Paths actually changed (e.g., switching slides or external update)
        // Reset undo stack only when paths actually change
        _paths = List.from(widget.initialPaths);
        _rasterizedPathCount = 0;
        _rasterizedImage?.dispose();
        _rasterizedImage = null;
        _undoStack.clear();
        _redoStack.clear();
        _saveState();
        // Notify state change after build completes to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _notifyStateChanged();
            // If there are paths, rerasterize them all
            if (_paths.isNotEmpty) {
              _rerasterizeAllPaths();
            }
          }
        });
      }
      // If paths match, it's just a reference update from onDrawingChanged
      // Don't reset undo stack in this case
    }
  }

  /// Checks if two path lists match in content (not just reference).
  bool _pathsMatch(List<DrawingPath> paths1, List<DrawingPath> paths2) {
    if (paths1.length != paths2.length) return false;

    for (var i = 0; i < paths1.length; i++) {
      final p1 = paths1[i];
      final p2 = paths2[i];
      if (p1.points.length != p2.points.length ||
          p1.color != p2.color ||
          p1.strokeWidth != p2.strokeWidth ||
          p1.isEraser != p2.isEraser) {
        return false;
      }
      // Check if points match (within tolerance)
      for (var j = 0; j < p1.points.length; j++) {
        if ((p1.points[j] - p2.points[j]).distance > 0.001) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDrawingEnabled) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _canvasSize = size;

          // Get device pixel ratio for high DPI rendering
          final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
          _devicePixelRatio = devicePixelRatio;

          return Stack(
            children: [
              // Rasterized image layer
              if (_rasterizedImage != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RasterizedImagePainter(
                        _rasterizedImage!, devicePixelRatio),
                  ),
                ),
              // Current drawing paths (not yet rasterized)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _DrawingPainter(
                    // Only show paths that haven't been rasterized yet
                    _paths.sublist(_rasterizedPathCount),
                    isEraserMode: widget.isEraserMode,
                  ),
                  size: size,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isDrawingEnabled) return;

    setState(() {
      _currentPath = DrawingPath(
        points: [details.localPosition],
        color: widget.isEraserMode ? Colors.transparent : widget.strokeColor,
        strokeWidth: widget.isEraserMode ? widget.eraserStrokeWidth : widget.strokeWidth,
        isEraser: widget.isEraserMode,
      );
      _paths.add(_currentPath!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    setState(() {
      _currentPath!.points.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    setState(() {
      _currentPath = null;
    });

    // Save state before rasterizing (so undo stack has the path)
    _saveState();

    // Rasterize the completed path after saving state
    _rasterizeCurrentPath();

    // Notify after setState completes to update undo/redo buttons
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyStateChanged();
      }
    });
  }

  Future<void> _rasterizeCurrentPath() async {
    if (_canvasSize == null || _paths.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _canvasSize!;
    final pixelRatio = _devicePixelRatio;

    // Scale canvas for high DPI
    canvas.scale(pixelRatio, pixelRatio);

    // Draw existing rasterized image
    // The image is already at physical pixel size, so we need to scale it to logical size
    if (_rasterizedImage != null) {
      final srcRect = Rect.fromLTWH(0, 0, _rasterizedImage!.width.toDouble(),
          _rasterizedImage!.height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(_rasterizedImage!, srcRect, dstRect, Paint());
    }

    // Draw the last completed path
    final lastPath = _paths.last;
    if (lastPath.points.isEmpty) return;

    if (lastPath.isEraser) {
      // Eraser mode: use dstOut blend mode to erase pixels
      final eraserPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..strokeWidth = lastPath.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white; // Color doesn't matter for dstOut

      if (lastPath.points.length == 1) {
        eraserPaint.style = PaintingStyle.fill;
        canvas.drawCircle(
            lastPath.points[0], lastPath.strokeWidth / 2, eraserPaint);
      } else {
        final uiPath = _createSmoothPath(lastPath.points);
        canvas.drawPath(uiPath, eraserPaint);
      }
    } else {
      // Normal drawing
      final paint = Paint()
        ..color = lastPath.color
        ..strokeWidth = lastPath.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (lastPath.points.length == 1) {
        final pointPaint = Paint()
          ..color = lastPath.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
            lastPath.points[0], lastPath.strokeWidth / 2, pointPaint);
      } else {
        final uiPath = _createSmoothPath(lastPath.points);
        canvas.drawPath(uiPath, paint);
      }
    }

    final picture = recorder.endRecording();
    // Use physical pixel size for high DPI rendering
    final image = await picture.toImage(
      (size.width * pixelRatio).toInt(),
      (size.height * pixelRatio).toInt(),
    );

    // Mark the path as rasterized (don't remove it, just increment counter)
    setState(() {
      _rasterizedPathCount++;
      _rasterizedImage?.dispose();
      _rasterizedImage = image;
    });
  }

  Future<void> _rerasterizeAllPaths() async {
    if (_canvasSize == null) return;
    
    // If paths are empty, clear the rasterized image
    if (_paths.isEmpty) {
      setState(() {
        _rasterizedImage?.dispose();
        _rasterizedImage = null;
        _rasterizedPathCount = 0;
      });
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _canvasSize!;
    final pixelRatio = _devicePixelRatio;

    // Scale canvas for high DPI
    canvas.scale(pixelRatio, pixelRatio);

    // Note: We don't need to draw existing rasterized image here because
    // _rerasterizeAllPaths is called to rebuild everything from scratch
    // Draw all paths from scratch (up to _rasterizedPathCount, or all if count is 0)
    final pathCount = _rasterizedPathCount > 0 ? _rasterizedPathCount : _paths.length;
    for (var i = 0; i < pathCount && i < _paths.length; i++) {
      final path = _paths[i];
      if (path.points.isEmpty) continue;

      if (path.isEraser) {
        // Eraser mode: use dstOut blend mode to erase pixels
        final eraserPaint = Paint()
          ..blendMode = BlendMode.dstOut
          ..strokeWidth = path.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white;

        if (path.points.length == 1) {
          eraserPaint.style = PaintingStyle.fill;
          canvas.drawCircle(path.points[0], path.strokeWidth / 2, eraserPaint);
        } else {
          final uiPath = _createSmoothPath(path.points);
          canvas.drawPath(uiPath, eraserPaint);
        }
      } else {
        // Normal drawing
        final paint = Paint()
          ..color = path.color
          ..strokeWidth = path.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        if (path.points.length == 1) {
          final pointPaint = Paint()
            ..color = path.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(path.points[0], path.strokeWidth / 2, pointPaint);
        } else {
          final uiPath = _createSmoothPath(path.points);
          canvas.drawPath(uiPath, paint);
        }
      }
    }

    final picture = recorder.endRecording();
    // Use physical pixel size for high DPI rendering
    final image = await picture.toImage(
      (size.width * pixelRatio).toInt(),
      (size.height * pixelRatio).toInt(),
    );

    setState(() {
      _rasterizedImage?.dispose();
      _rasterizedImage = image;
      // Update rasterized path count to match what we just rasterized
      if (_rasterizedPathCount == 0) {
        _rasterizedPathCount = pathCount;
      }
    });
  }

  /// Creates a smooth path from points using Catmull-Rom spline interpolation.
  /// This creates very smooth curves even with rapid drawing.
  Path _createSmoothPath(List<Offset> points) {
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }
    if (points.length == 2) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    // Use Catmull-Rom spline to cubic Bezier conversion
    // This creates very smooth curves that pass through all points
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Convert Catmull-Rom to cubic Bezier
      // Catmull-Rom with tension = 0.5 (centripetal parameterization)
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  void _saveState() {
    _undoStack.add(_paths
        .map((p) => DrawingPath(
              points: List.from(p.points),
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList());
    _redoStack.clear();
    // Limit undo stack size
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  /// Clears all drawings.
  void clear() {
    setState(() {
      _paths.clear();
      _currentPath = null;
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
      _rasterizedPathCount = 0;
    });
    _saveState();
    // Notify after setState completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyStateChanged();
      }
    });
  }

  /// Undo the last drawing action.
  void undo() {
    if (_undoStack.length <= 1) return; // Keep at least one state

    _redoStack.add(_paths
        .map((p) => DrawingPath(
              points: List.from(p.points),
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList());

    _undoStack.removeLast();
    final restoredPaths = _undoStack.last
        .map((p) => DrawingPath(
              points: List.from(p.points),
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList();

    setState(() {
      _paths = restoredPaths;
      _currentPath = null;
      // Reset rasterized count to match the restored paths
      _rasterizedPathCount = restoredPaths.length;
      // Clear rasterized image so it gets rebuilt
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
    });

    // Re-rasterize all paths after undo
    _rerasterizeAllPaths();

    // Notify after setState completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyStateChanged();
      }
    });
  }

  /// Redo the last undone action.
  void redo() {
    if (_redoStack.isEmpty) return;

    _undoStack.add(_paths
        .map((p) => DrawingPath(
              points: List.from(p.points),
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList());

    final restoredPaths = _redoStack
        .removeLast()
        .map((p) => DrawingPath(
              points: List.from(p.points),
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList();

    setState(() {
      _paths = restoredPaths;
      _currentPath = null;
      // Reset rasterized count to match the restored paths
      _rasterizedPathCount = restoredPaths.length;
      // Clear rasterized image so it gets rebuilt
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
    });

    // Re-rasterize all paths after redo
    _rerasterizeAllPaths();

    // Notify after setState completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyStateChanged();
      }
    });
  }

  /// Sets the drawing paths (used when switching slides).
  void setPaths(List<DrawingPath> paths) {
    setState(() {
      _paths.clear();
      _paths.addAll(paths);
      _currentPath = null;
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
      _rasterizedPathCount = 0;
    });
    _undoStack.clear();
    _redoStack.clear();
    _saveState();
  }

  /// Gets the current drawing paths.
  List<DrawingPath> get paths => List.from(_paths);

  /// Whether undo is available.
  bool get canUndo => _undoStack.length > 1;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Notifies that the undo/redo state may have changed.
  void _notifyStateChanged() {
    widget.onDrawingChanged(List.from(_paths));
    widget.onStateChanged?.call(canUndo, canRedo);
  }
}

/// Represents a drawing path.
class DrawingPath {
  /// Creates a [DrawingPath].
  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  /// The points that make up this path.
  final List<Offset> points;

  /// The color of the path.
  final Color color;

  /// The width of the stroke.
  final double strokeWidth;

  /// Whether this path is an eraser stroke.
  final bool isEraser;

  DrawingPath copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    bool? isEraser,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.paths, {this.isEraserMode = false});

  final List<DrawingPath> paths;
  final bool isEraserMode;

  /// Creates a smooth path from points using Catmull-Rom spline interpolation.
  /// This creates very smooth curves even with rapid drawing.
  Path _createSmoothPath(List<Offset> points) {
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }
    if (points.length == 2) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    // Use Catmull-Rom spline to cubic Bezier conversion
    // This creates very smooth curves that pass through all points
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Convert Catmull-Rom to cubic Bezier
      // Catmull-Rom with tension = 0.5 (centripetal parameterization)
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..strokeWidth = path.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Only use isEraserMode for paths that are currently being drawn
      // Existing paths should be displayed based on their own isEraser property
      // isEraserMode is only used to show preview for the current drawing path
      if (path.isEraser) {
        // Eraser path: show as semi-transparent red for visual feedback
        // Actual erasing happens during rasterization
        paint.color = Colors.red.withOpacity(0.3);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = path.strokeWidth;
      } else {
        paint.color = path.color;
      }

      if (path.points.length == 1) {
        // 避免發生：down 下去會是一個很大的圓圈，但移動之後就會變小
        // Draw a single point as a filled circle
        if (path.isEraser) {
          // Show eraser as semi-transparent circle
          final eraserPaint = Paint()
            ..color = Colors.red.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(path.points[0], path.strokeWidth / 2, eraserPaint);
        } else {
          final pointPaint = Paint()
            ..color = path.color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(path.points[0], path.strokeWidth / 2, pointPaint);
        }
      } else {
        // Draw a path connecting all points with smooth curves
        final uiPath = _createSmoothPath(path.points);
        canvas.drawPath(uiPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) {
    // Always repaint - we create a new painter instance on each build
    // to ensure repainting happens
    return true;
  }
}

/// Painter for rasterized image.
class _RasterizedImagePainter extends CustomPainter {
  _RasterizedImagePainter(this.image, this.devicePixelRatio);

  final ui.Image image;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw image scaled to logical size
    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(_RasterizedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
