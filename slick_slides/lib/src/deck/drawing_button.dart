import 'package:flutter/material.dart';
import 'package:slick_slides/slick_slides.dart';

/// A button widget that can be added to [DeckControls.actions] to toggle
/// drawing mode on slides.
class DrawingToggleButton extends StatelessWidget {
  /// Creates a [DrawingToggleButton].
  const DrawingToggleButton({
    required this.isDrawingEnabled,
    required this.onToggle,
    this.onClear,
    super.key,
  });

  /// Whether drawing is currently enabled.
  final bool isDrawingEnabled;

  /// Called when the drawing mode should be toggled.
  final VoidCallback onToggle;

  /// Called when the drawing should be cleared. If null, a long press
  /// on the button will toggle drawing mode instead.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(4),
        backgroundColor:
            isDrawingEnabled ? Colors.red.withOpacity(0.3) : Colors.transparent,
      ),
      onPressed: onToggle,
      onLongPress: onClear,
      child: Icon(
        Icons.edit,
        color: isDrawingEnabled ? Colors.red : Colors.white,
      ),
    );
  }
}
