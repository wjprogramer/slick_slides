import 'package:flutter/material.dart';

/// A collapsible toolbar widget that can be placed in the top-right corner.
/// Similar in style to [DeckControls].
class Toolbar extends StatefulWidget {
  /// Creates a [Toolbar].
  const Toolbar({
    required this.actions,
    this.visible = true,
    super.key,
  });

  /// The actions to display in the toolbar.
  final List<Widget> actions;

  /// Whether the toolbar is visible.
  final bool visible;

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(4),
                ),
                onPressed: _toggleExpanded,
                child: Icon(
                  _expanded ? Icons.chevron_right : Icons.chevron_left,
                  color: Colors.white,
                ),
              ),
              // Actions (with fade animation)
              if (widget.actions.isNotEmpty) ...[
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axis: Axis.horizontal,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: _expandAnimation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 8),
                        ...widget.actions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final action = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: index > 0 ? 8 : 0,
                            ),
                            child: action,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
