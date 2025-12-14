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
  
  // For velocity calculation
  Offset? _lastPosition;
  DateTime? _lastTime;
  static const _velocitySmoothingFactor = 0.7; // Smooth velocity changes

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

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
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

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isDrawingEnabled) return;

    final localPosition = event.localPosition;
    final pressure = event.pressure.clamp(0.0, 1.0);
    // Note: Flutter's PointerEvent doesn't have tiltX/tiltY yet
    // These would need to be obtained via platform channels
    final tiltX = 0.0;
    final tiltY = 0.0;

    _lastPosition = localPosition;
    _lastTime = DateTime.now();

    setState(() {
      _currentPath = DrawingPath(
        points: [localPosition],
        drawingPoints: [
          DrawingPoint(
            position: localPosition,
            pressure: pressure,
            tiltX: tiltX,
            tiltY: tiltY,
            velocity: 0.0,
          ),
        ],
        color: widget.isEraserMode ? Colors.transparent : widget.strokeColor,
        strokeWidth: widget.isEraserMode ? widget.eraserStrokeWidth : widget.strokeWidth,
        isEraser: widget.isEraserMode,
      );
      _paths.add(_currentPath!);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    final localPosition = event.localPosition;
    final pressure = event.pressure.clamp(0.0, 1.0);
    // Note: Flutter's PointerEvent doesn't have tiltX/tiltY yet
    // These would need to be obtained via platform channels
    final tiltX = 0.0;
    final tiltY = 0.0;

    // Calculate velocity
    double velocity = 0.0;
    if (_lastPosition != null && _lastTime != null) {
      final now = DateTime.now();
      final deltaTime = now.difference(_lastTime!).inMicroseconds / 1000000.0;
      if (deltaTime > 0) {
        final distance = (localPosition - _lastPosition!).distance;
        final currentVelocity = distance / deltaTime;
        // Smooth velocity changes
        final lastVelocity = _currentPath!.drawingPoints?.last.velocity ?? 0.0;
        velocity = lastVelocity * _velocitySmoothingFactor + 
                   currentVelocity * (1.0 - _velocitySmoothingFactor);
      }
    }

    _lastPosition = localPosition;
    _lastTime = DateTime.now();

    setState(() {
      _currentPath!.points.add(localPosition);
      _currentPath!.drawingPoints?.add(
        DrawingPoint(
          position: localPosition,
          pressure: pressure,
          tiltX: tiltX,
          tiltY: tiltY,
          velocity: velocity,
        ),
      );
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    setState(() {
      _currentPath = null;
      _lastPosition = null;
      _lastTime = null;
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

  void _onPointerCancel(PointerCancelEvent event) {
    if (!widget.isDrawingEnabled || _currentPath == null) return;

    setState(() {
      // Remove the current path if cancelled
      if (_paths.isNotEmpty && _paths.last == _currentPath) {
        _paths.removeLast();
      }
      _currentPath = null;
      _lastPosition = null;
      _lastTime = null;
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

    _drawPathWithPressure(canvas, lastPath);

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

  /// Draws a path with pressure, tilt, and velocity support.
  void _drawPathWithPressure(Canvas canvas, DrawingPath path) {
    if (path.isEraser) {
      // Eraser mode: use dstOut blend mode to erase pixels
      if (path.points.length == 1) {
        final eraserPaint = Paint()
          ..blendMode = BlendMode.dstOut
          ..style = PaintingStyle.fill
          ..color = Colors.white;
        final radius = path.strokeWidth / 2;
        // Apply pressure if available
        final pressure = (path.drawingPoints?.isNotEmpty ?? false) 
            ? path.drawingPoints!.first.pressure 
            : 1.0;
        canvas.drawCircle(path.points[0], radius * pressure, eraserPaint);
      } else {
        _drawVariableWidthPath(
          canvas,
          path,
          blendMode: BlendMode.dstOut,
          color: Colors.white,
        );
      }
    } else {
      // Normal drawing
      if (path.points.length == 1) {
        final pointPaint = Paint()
          ..color = path.color
          ..style = PaintingStyle.fill;
        final radius = path.strokeWidth / 2;
        // Apply pressure if available
        final pressure = (path.drawingPoints?.isNotEmpty ?? false) 
            ? path.drawingPoints!.first.pressure 
            : 1.0;
        canvas.drawCircle(path.points[0], radius * pressure, pointPaint);
      } else {
        _drawVariableWidthPath(canvas, path, color: path.color);
      }
    }
  }

  /// Draws a path with variable width based on pressure, tilt, and velocity.
  void _drawVariableWidthPath(
    Canvas canvas,
    DrawingPath path, {
    BlendMode? blendMode,
    Color? color,
  }) {
    final drawingPoints = path.drawingPoints;
    final baseStrokeWidth = path.strokeWidth;
    final pathColor = color ?? path.color;

    if (drawingPoints == null || drawingPoints.length < 2) {
      // Fallback to simple path if no pressure data
      final paint = Paint()
        ..color = pathColor
        ..strokeWidth = baseStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (blendMode != null) paint.blendMode = blendMode;
      final uiPath = _createSmoothPath(path.points);
      canvas.drawPath(uiPath, paint);
      return;
    }

    // Calculate width and opacity for each point with smoothing
    // Apply moving average to smooth out pressure changes
    final widths = <double>[];
    final opacities = <double>[];
    
    // First pass: calculate raw values
    final rawWidths = <double>[];
    final rawOpacities = <double>[];
    
    for (var point in drawingPoints) {
      // Calculate width for this point
      final pressureFactor = 0.5 + (point.pressure * 0.5);
      final normalizedVelocity = (point.velocity / 1000.0).clamp(0.0, 1.0);
      final velocityFactor = 1.0 - (normalizedVelocity * 0.3); // 0.7 to 1.0
      final width = baseStrokeWidth * pressureFactor * velocityFactor;
      rawWidths.add(width);
      
      // Calculate opacity for this point
      final opacity = (0.7 + (point.pressure * 0.3)).clamp(0.7, 1.0);
      rawOpacities.add(opacity);
    }
    
    // Second pass: apply smoothing using weighted moving average
    const smoothingWindow = 3; // Use 3 points for smoothing
    for (var i = 0; i < rawWidths.length; i++) {
      double smoothedWidth = 0.0;
      double smoothedOpacity = 0.0;
      double totalWeight = 0.0;
      
      // Weighted average: center point has more weight
      for (var j = -smoothingWindow; j <= smoothingWindow; j++) {
        final idx = i + j;
        if (idx >= 0 && idx < rawWidths.length) {
          // Gaussian-like weight: closer points have more influence
          final distance = j.abs();
          final weight = distance == 0 ? 1.0 : (distance == 1 ? 0.5 : 0.25);
          
          smoothedWidth += rawWidths[idx] * weight;
          smoothedOpacity += rawOpacities[idx] * weight;
          totalWeight += weight;
        }
      }
      
      widths.add(smoothedWidth / totalWeight);
      opacities.add(smoothedOpacity / totalWeight);
    }

    // Draw with smooth transitions between segments
    // Use smooth curve interpolation for width and opacity
    for (var i = 0; i < drawingPoints.length - 1; i++) {
      final p0 = drawingPoints[i];
      final p1 = drawingPoints[i + 1];
      
      // Use more sub-segments and smooth interpolation
      const subSegments = 8; // More segments for smoother transition
      
      for (var j = 0; j < subSegments; j++) {
        final t = j / subSegments;
        final tNext = (j + 1) / subSegments;
        
        // Use cubic interpolation for smoother transitions
        // This creates a more natural, smoother curve
        double cubicInterpolate(double t) {
          // Smooth step function: 3t^2 - 2t^3
          return t * t * (3.0 - 2.0 * t);
        }
        
        final smoothT0 = cubicInterpolate(t);
        final smoothT1 = cubicInterpolate(tNext);
        
        // Interpolate position
        final pos0 = Offset.lerp(p0.position, p1.position, smoothT0)!;
        final pos1 = Offset.lerp(p0.position, p1.position, smoothT1)!;
        
        // Interpolate width with smooth curve
        final width0 = widths[i] + (widths[i + 1] - widths[i]) * smoothT0;
        final width1 = widths[i] + (widths[i + 1] - widths[i]) * smoothT1;
        // Use average for the segment
        final avgWidth = (width0 + width1) / 2.0;
        
        // Interpolate opacity with smooth curve
        final opacity0 = opacities[i] + (opacities[i + 1] - opacities[i]) * smoothT0;
        final opacity1 = opacities[i] + (opacities[i + 1] - opacities[i]) * smoothT1;
        final avgOpacity = (opacity0 + opacity1) / 2.0;
        
        final paintColor = pathColor.withOpacity(avgOpacity);
        
        final paint = Paint()
          ..color = paintColor
          ..strokeWidth = avgWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (blendMode != null) paint.blendMode = blendMode;
        
        // Draw line segment
        final segmentPath = Path()
          ..moveTo(pos0.dx, pos0.dy)
          ..lineTo(pos1.dx, pos1.dy);
        canvas.drawPath(segmentPath, paint);
      }
    }
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

      _drawPathWithPressure(canvas, path);
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
              drawingPoints: p.drawingPoints != null 
                  ? List.from(p.drawingPoints!)
                  : null,
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
              drawingPoints: p.drawingPoints != null 
                  ? List.from(p.drawingPoints!)
                  : null,
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList());

    _undoStack.removeLast();
    final restoredPaths = _undoStack.last
        .map((p) => DrawingPath(
              points: List.from(p.points),
              drawingPoints: p.drawingPoints != null 
                  ? List.from(p.drawingPoints!)
                  : null,
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
              drawingPoints: p.drawingPoints != null 
                  ? List.from(p.drawingPoints!)
                  : null,
              color: p.color,
              strokeWidth: p.strokeWidth,
              isEraser: p.isEraser,
            ))
        .toList());

    final restoredPaths = _redoStack
        .removeLast()
        .map((p) => DrawingPath(
              points: List.from(p.points),
              drawingPoints: p.drawingPoints != null 
                  ? List.from(p.drawingPoints!)
                  : null,
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

/// Represents a point with pressure, tilt, and velocity information.
class DrawingPoint {
  const DrawingPoint({
    required this.position,
    this.pressure = 1.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.velocity = 0.0,
  });

  final Offset position;
  final double pressure; // 0.0 to 1.0
  final double tiltX; // -1.0 to 1.0
  final double tiltY; // -1.0 to 1.0
  final double velocity; // pixels per second
}

/// Represents a drawing path.
class DrawingPath {
  /// Creates a [DrawingPath].
  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
    this.drawingPoints,
  });

  /// The points that make up this path.
  final List<Offset> points;

  /// The drawing points with pressure, tilt, and velocity information.
  final List<DrawingPoint>? drawingPoints;

  /// The color of the path.
  final Color color;

  /// The width of the stroke.
  final double strokeWidth;

  /// Whether this path is an eraser stroke.
  final bool isEraser;

  DrawingPath copyWith({
    List<Offset>? points,
    List<DrawingPoint>? drawingPoints,
    Color? color,
    double? strokeWidth,
    bool? isEraser,
  }) {
    return DrawingPath(
      points: points ?? this.points,
      drawingPoints: drawingPoints ?? this.drawingPoints,
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

      // Only use isEraserMode for paths that are currently being drawn
      // Existing paths should be displayed based on their own isEraser property
      // isEraserMode is only used to show preview for the current drawing path
      if (path.isEraser) {
        // Eraser path: show as semi-transparent red for visual feedback
        // Actual erasing happens during rasterization
        if (path.points.length == 1) {
          final eraserPaint = Paint()
            ..color = Colors.red.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          final radius = path.strokeWidth / 2;
          final pressure = (path.drawingPoints?.isNotEmpty ?? false) 
              ? path.drawingPoints!.first.pressure 
              : 1.0;
          canvas.drawCircle(path.points[0], radius * pressure, eraserPaint);
        } else {
          _drawVariableWidthPathPreview(canvas, path, 
              color: Colors.red.withOpacity(0.3));
        }
      } else {
        // Normal drawing with pressure support
        if (path.points.length == 1) {
          final pointPaint = Paint()
            ..color = path.color
            ..style = PaintingStyle.fill;
          final radius = path.strokeWidth / 2;
          final pressure = (path.drawingPoints?.isNotEmpty ?? false) 
              ? path.drawingPoints!.first.pressure 
              : 1.0;
          canvas.drawCircle(path.points[0], radius * pressure, pointPaint);
        } else {
          _drawVariableWidthPathPreview(canvas, path, color: path.color);
        }
      }
    }
  }

  /// Draws a path with variable width for preview (same logic as rasterization).
  void _drawVariableWidthPathPreview(
    Canvas canvas,
    DrawingPath path, {
    Color? color,
  }) {
    final drawingPoints = path.drawingPoints;
    final baseStrokeWidth = path.strokeWidth;
    final pathColor = color ?? path.color;

    if (drawingPoints == null || drawingPoints.length < 2) {
      // Fallback to simple path if no pressure data
      final paint = Paint()
        ..color = pathColor
        ..strokeWidth = baseStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final uiPath = _createSmoothPath(path.points);
      canvas.drawPath(uiPath, paint);
      return;
    }

    // Calculate width and opacity for each point with smoothing
    // Apply moving average to smooth out pressure changes
    final widths = <double>[];
    final opacities = <double>[];
    
    // First pass: calculate raw values
    final rawWidths = <double>[];
    final rawOpacities = <double>[];
    
    for (var point in drawingPoints) {
      // Calculate width for this point
      final pressureFactor = 0.5 + (point.pressure * 0.5);
      final normalizedVelocity = (point.velocity / 1000.0).clamp(0.0, 1.0);
      final velocityFactor = 1.0 - (normalizedVelocity * 0.3); // 0.7 to 1.0
      final width = baseStrokeWidth * pressureFactor * velocityFactor;
      rawWidths.add(width);
      
      // Calculate opacity for this point
      final opacity = (0.7 + (point.pressure * 0.3)).clamp(0.7, 1.0);
      rawOpacities.add(opacity);
    }
    
    // Second pass: apply smoothing using weighted moving average
    const smoothingWindow = 3; // Use 3 points for smoothing
    for (var i = 0; i < rawWidths.length; i++) {
      double smoothedWidth = 0.0;
      double smoothedOpacity = 0.0;
      double totalWeight = 0.0;
      
      // Weighted average: center point has more weight
      for (var j = -smoothingWindow; j <= smoothingWindow; j++) {
        final idx = i + j;
        if (idx >= 0 && idx < rawWidths.length) {
          // Gaussian-like weight: closer points have more influence
          final distance = j.abs();
          final weight = distance == 0 ? 1.0 : (distance == 1 ? 0.5 : 0.25);
          
          smoothedWidth += rawWidths[idx] * weight;
          smoothedOpacity += rawOpacities[idx] * weight;
          totalWeight += weight;
        }
      }
      
      widths.add(smoothedWidth / totalWeight);
      opacities.add(smoothedOpacity / totalWeight);
    }

    // Draw with smooth transitions between segments
    // Use smooth curve interpolation for width and opacity
    for (var i = 0; i < drawingPoints.length - 1; i++) {
      final p0 = drawingPoints[i];
      final p1 = drawingPoints[i + 1];
      
      // Use more sub-segments and smooth interpolation
      const subSegments = 8; // More segments for smoother transition
      
      for (var j = 0; j < subSegments; j++) {
        final t = j / subSegments;
        final tNext = (j + 1) / subSegments;
        
        // Use cubic interpolation for smoother transitions
        // This creates a more natural, smoother curve
        double cubicInterpolate(double t) {
          // Smooth step function: 3t^2 - 2t^3
          return t * t * (3.0 - 2.0 * t);
        }
        
        final smoothT0 = cubicInterpolate(t);
        final smoothT1 = cubicInterpolate(tNext);
        
        // Interpolate position
        final pos0 = Offset.lerp(p0.position, p1.position, smoothT0)!;
        final pos1 = Offset.lerp(p0.position, p1.position, smoothT1)!;
        
        // Interpolate width with smooth curve
        final width0 = widths[i] + (widths[i + 1] - widths[i]) * smoothT0;
        final width1 = widths[i] + (widths[i + 1] - widths[i]) * smoothT1;
        // Use average for the segment
        final avgWidth = (width0 + width1) / 2.0;
        
        // Interpolate opacity with smooth curve
        final opacity0 = opacities[i] + (opacities[i + 1] - opacities[i]) * smoothT0;
        final opacity1 = opacities[i] + (opacities[i + 1] - opacities[i]) * smoothT1;
        final avgOpacity = (opacity0 + opacity1) / 2.0;
        
        final paintColor = pathColor.withOpacity(avgOpacity);
        
        final paint = Paint()
          ..color = paintColor
          ..strokeWidth = avgWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        
        // Draw line segment
        final segmentPath = Path()
          ..moveTo(pos0.dx, pos0.dy)
          ..lineTo(pos1.dx, pos1.dy);
        canvas.drawPath(segmentPath, paint);
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
