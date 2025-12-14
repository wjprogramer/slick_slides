import 'package:flutter/material.dart';

/// A toolbar widget for drawing controls on slides.
class DrawingToolbar extends StatelessWidget {
  /// Creates a [DrawingToolbar].
  const DrawingToolbar({
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onStrokeWidthChanged,
    required this.strokeWidth,
    this.canUndo = false,
    this.canRedo = false,
    this.strokeColor = Colors.red,
    this.onStrokeColorChanged,
    this.isEraserMode = false,
    this.onToggleEraser,
    this.eraserStrokeWidth = 30.0,
    this.onEraserStrokeWidthChanged,
    super.key,
  });

  /// Called when undo is requested.
  final VoidCallback onUndo;

  /// Called when redo is requested.
  final VoidCallback onRedo;

  /// Called when clear is requested.
  final VoidCallback onClear;

  /// Called when stroke width is changed.
  final void Function(double width) onStrokeWidthChanged;

  /// Current stroke width.
  final double strokeWidth;

  /// Whether undo is available.
  final bool canUndo;

  /// Whether redo is available.
  final bool canRedo;

  /// Current stroke color.
  final Color strokeColor;

  /// Called when stroke color is changed.
  final void Function(Color color)? onStrokeColorChanged;

  /// Whether eraser mode is enabled.
  final bool isEraserMode;

  /// Called when eraser mode is toggled.
  final VoidCallback? onToggleEraser;

  /// Current eraser stroke width.
  final double eraserStrokeWidth;

  /// Called when eraser stroke width is changed.
  final void Function(double width)? onEraserStrokeWidthChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(8),
      constraints: BoxConstraints(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Undo button
          Opacity(
            opacity: canUndo ? 1.0 : 0.5,
            child: _ToolbarButton(
              icon: Icons.undo,
              onPressed: canUndo ? onUndo : null,
              tooltip: 'Undo',
            ),
          ),
          const SizedBox(width: 8),
          // Redo button
          Opacity(
            opacity: canRedo ? 1.0 : 0.5,
            child: _ToolbarButton(
              icon: Icons.redo,
              onPressed: canRedo ? onRedo : null,
              tooltip: 'Redo',
            ),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(
            color: Colors.white24,
            width: 1,
            thickness: 1,
            indent: 4,
            endIndent: 4,
          ),
          const SizedBox(width: 8),
          // Eraser button
          if (onToggleEraser != null)
            Opacity(
              opacity: isEraserMode ? 1.0 : 0.5,
              child: _ToolbarButton(
                icon: Icons.auto_fix_high,
                onPressed: onToggleEraser,
                tooltip: 'Eraser',
                color: isEraserMode ? Colors.orange : Colors.white,
              ),
            ),
          if (onToggleEraser != null) const SizedBox(width: 8),
          if (onToggleEraser != null)
            const VerticalDivider(
              color: Colors.white24,
              width: 1,
              thickness: 1,
              indent: 4,
              endIndent: 4,
            ),
          if (onToggleEraser != null) const SizedBox(width: 8),
          // Stroke width slider (different for pen and eraser)
          if (isEraserMode && onEraserStrokeWidthChanged != null)
            Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_fix_high,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${eraserStrokeWidth.toInt()}px',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  const Icon(
                    Icons.brush,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${strokeWidth.toInt()}px',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 120,
              child: Slider(
                value: isEraserMode ? eraserStrokeWidth : strokeWidth,
                min: isEraserMode ? 1.0 : 1.0,
                max: isEraserMode ? 100.0 : 20.0,
                divisions: isEraserMode ? 99 : 19,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                onChanged: isEraserMode && onEraserStrokeWidthChanged != null
                    ? onEraserStrokeWidthChanged!
                    : onStrokeWidthChanged,
              ),
            ),
          ),
          if (onStrokeColorChanged != null) ...[
            const SizedBox(width: 8),
            const VerticalDivider(
              color: Colors.white24,
              width: 1,
              thickness: 1,
              indent: 4,
              endIndent: 4,
            ),
            const SizedBox(width: 8),
            // Color picker
            _ColorPickerButton(
              color: strokeColor,
              onColorChanged: onStrokeColorChanged!,
            ),
          ],
          const SizedBox(width: 8),
          const VerticalDivider(
            color: Colors.white24,
            width: 1,
            thickness: 1,
            indent: 4,
            endIndent: 4,
          ),
          const SizedBox(width: 8),
          // Clear button
          _ToolbarButton(
            icon: Icons.clear,
            onPressed: onClear,
            tooltip: 'Clear',
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color ?? Colors.white),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 20,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null
            ? Colors.white.withOpacity(0.1)
            : Colors.transparent,
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  const _ColorPickerButton({
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final void Function(Color color) onColorChanged;

  static const _colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.white,
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: 'Color',
      icon: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
      itemBuilder: (context) => _colors.map((color) {
        return PopupMenuItem<Color>(
          value: color,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey,
                width: 1,
              ),
            ),
          ),
        );
      }).toList(),
      onSelected: onColorChanged,
    );
  }
}
