import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';
import 'package:slick_slides/slick_slides.dart';
import 'package:slick_slides/src/deck/slide_config.dart';

const _dimmedCodeOpacity = 0.3;
const _dimCodeDuration = Duration(milliseconds: 500);

// TODO: 現在如果一行太長，會換行到行號下面
/// A widget that displays and optionally animates code with syntax
/// highlighting.
class ColoredCode extends StatefulWidget {
  /// Creates a widget that displays and optionally animates code with syntax
  /// highlighting. Set the [animateFromCode] property to animate between two
  /// code snippets.
  const ColoredCode({
    required this.code,
    this.animateFromCode,
    this.language = 'dart',
    this.tabSize = 2,
    this.textStyle,
    this.highlightedLines = const [],
    this.maxAnimationDuration = const Duration(milliseconds: 2000),
    this.keystrokeDuration = const Duration(milliseconds: 50),
    this.animateHighlightedLines = false,
    this.showLineNumbers = false,
    super.key,
  });

  /// The code to display, or the final code if [animateFromCode] is set.
  final String code;

  /// The code to animate from. The final displayed code will be [code].
  final String? animateFromCode;

  /// The language to use for syntax highlighting. Defaults to 'dart'.
  final String language;

  /// The number of spaces to use for tabs. Defaults to 2.
  final int tabSize;

  /// The text style to use for the code. Defaults to the default style of the
  /// build context.
  final TextStyle? textStyle;

  /// Maximum duration of the animation. Defaults to 2 seconds.
  final Duration maxAnimationDuration;

  /// Duration of each keystroke animation. Defaults to 50 milliseconds.
  final Duration keystrokeDuration;

  /// The lines to highlight at the end of the animation.
  final List<int> highlightedLines;

  /// Whether to animate the highlighted lines. Defaults to false.
  final bool animateHighlightedLines;

  /// Whether to show line numbers. Defaults to false.
  final bool showLineNumbers;

  @override
  State<ColoredCode> createState() => _ColoredCodeState();
}

class _ColoredCodeState extends State<ColoredCode>
    with TickerProviderStateMixin {
  late AnimationController _typingController;
  late AnimationController _highlightController;
  int _numOperations = 0;
  List<Diff>? _diff;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      value: 0.0,
    );
    _typingController.addListener(() {
      setState(() {});
      if (_typingController.isCompleted &&
          widget.animateHighlightedLines &&
          widget.highlightedLines.isNotEmpty) {
        // Start animating the highlighted lines after the typing animation
        // completes.
        _highlightController.animateTo(
          _dimmedCodeOpacity,
          duration: const Duration(milliseconds: 500),
        );
      }
    });

    _highlightController = AnimationController(
      vsync: this,
      value: 1.0,
    );
    _highlightController.addListener(() {
      setState(() {});
    });

    if (widget.animateFromCode != null ||
        (widget.highlightedLines.isNotEmpty &&
            widget.animateHighlightedLines)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAnimations();
      });
    } else {
      _highlightController.value = _dimmedCodeOpacity;
    }
  }

  void _startAnimations() {
    if (!_animateIn) {
      return;
    }

    if (widget.animateFromCode != null) {
      var numOperations = 0;
      _diff = DiffMatchPatch().diff(widget.animateFromCode!, widget.code);
      for (var d in _diff!) {
        if (d.operation == DIFF_DELETE) {
          numOperations += 1;
        } else if (d.operation == DIFF_INSERT) {
          numOperations += d.text.length;
        }
      }
      _numOperations = numOperations;
      var totalMs = numOperations * widget.keystrokeDuration.inMilliseconds;
      if (totalMs > widget.maxAnimationDuration.inMilliseconds) {
        totalMs = widget.maxAnimationDuration.inMilliseconds;
      }
      var duration = Duration(milliseconds: totalMs);
      _typingController.animateTo(
        1.0,
        duration: duration,
      );
    } else if (widget.highlightedLines.isNotEmpty &&
        widget.animateHighlightedLines) {
      // Start animating the highlighted lines immediately.
      _highlightController.value = 1.0;
      _highlightController.animateTo(
        _dimmedCodeOpacity,
        duration: _dimCodeDuration,
      );
    }
  }

  bool get _animateIn {
    var config = SlideConfig.of(context);
    return config?.animateIn ?? true;
  }

  @override
  void dispose() {
    _typingController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var theme = SlideTheme.of(context)!;

    String animatedCode;
    if (_typingController.isAnimating &&
        widget.animateFromCode != null &&
        _diff != null) {
      animatedCode = _getAnimatedCode(
        (_typingController.value * _numOperations).floor(),
      );
    } else if (_animateIn &&
        widget.animateFromCode != null &&
        _typingController.value == 0.0) {
      animatedCode = widget.animateFromCode!;
    } else {
      animatedCode = widget.code;
    }

    var highlightedText = SlickSlides.highlighters[widget.language]!.highlight(
      animatedCode,
    );

    var coloredCode = Text.rich(
      highlightedText,
    );

    // If line numbers are enabled, embed line numbers in the code text
    if (widget.showLineNumbers) {
      var codeLines = animatedCode.split('\n');
      var numLines = codeLines.length;
      final textStyle = widget.textStyle ?? theme.textTheme.code;
      
      // Calculate padding needed for line numbers (right-aligned)
      final maxLineNumberText = numLines.toString();
      final maxLineNumberLength = maxLineNumberText.length;
      
      // Calculate the width needed for line numbers
      final lineNumberTextPainter = TextPainter(
        text: TextSpan(
          text: maxLineNumberText,
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      lineNumberTextPainter.layout();
      final lineNumberWidth = lineNumberTextPainter.width + 24.0; // Add spacing
      
      // Highlight the FULL code first to preserve syntax context (especially for brackets)
      final fullHighlightedText = highlightedText;
      
      // Now split the highlighted text by lines while preserving the TextSpan structure
      final lineNumberStyle = textStyle.copyWith(
        color: textStyle.color?.withOpacity(0.5),
      );
      
      // Extract TextSpans for each line from the full highlighted text
      final children = <TextSpan>[];
      int currentPos = 0;
      
      for (var i = 0; i < codeLines.length; i++) {
        final lineNumber = (i + 1).toString();
        final padding = ' ' * (maxLineNumberLength - lineNumber.length);
        final lineLength = codeLines[i].length;
        
        // Add line number (not highlighted)
        children.add(TextSpan(
          text: '$padding$lineNumber ',
          style: lineNumberStyle,
        ));
        
        // Extract the highlighted TextSpan for this line from the full highlighted text
        final lineHighlighted = _extractLineFromHighlightedText(
          fullHighlightedText,
          currentPos,
          lineLength,
        );
        children.add(lineHighlighted);
        
        // Add newline (except for last line)
        if (i < codeLines.length - 1) {
          children.add(const TextSpan(text: '\n'));
        }
        
        currentPos += lineLength + 1; // +1 for the newline character
      }
      
      final codeWithLineNumbersSpan = TextSpan(children: children);
      
      var coloredCodeWithNumbers = Text.rich(
        codeWithLineNumbersSpan,
        textAlign: TextAlign.left,
      );

      if (widget.highlightedLines.isEmpty) {
        return DefaultTextStyle(
          style: textStyle,
          child: coloredCodeWithNumbers,
        );
      }

      // For highlighted lines, rebuild with proper structure
      return _buildHighlightedCodeWithEmbeddedLineNumbers(
        codeWithLineNumbersSpan,
        codeLines,
        animatedCode,
        numLines,
        textStyle,
        lineNumberStyle,
        maxLineNumberLength,
        lineNumberWidth,
      );
    }

    if (widget.highlightedLines.isEmpty) {
      return DefaultTextStyle(
        style: widget.textStyle ?? theme.textTheme.code,
        child: coloredCode,
      );
    }

    return _buildHighlightedCode(
      coloredCode,
      highlightedText,
      animatedCode.split('\n'),
      animatedCode.split('\n').length,
      widget.textStyle ?? theme.textTheme.code,
    );
  }

  TextSpan _extractLineFromHighlightedText(
    TextSpan highlightedText,
    int startPos,
    int length,
  ) {
    // Recursively extract the TextSpan for a specific line
    final result = <TextSpan>[];
    int currentPos = 0;
    final targetEnd = startPos + length;
    
    void extractFromSpan(TextSpan span) {
      if (span.text != null) {
        final spanStart = currentPos;
        final spanEnd = currentPos + span.text!.length;
        
        // Check if this span overlaps with the target line
        if (spanEnd > startPos && spanStart < targetEnd) {
          // Calculate the start position relative to this span
          final extractStart = (spanStart < startPos) ? startPos - spanStart : 0;
          // Calculate the end position relative to this span
          final extractEnd = (spanEnd > targetEnd)
              ? targetEnd - spanStart
              : span.text!.length;
          
          // Ensure extractEnd is within bounds
          final safeExtractEnd = extractEnd.clamp(0, span.text!.length);
          final safeExtractStart = extractStart.clamp(0, safeExtractEnd);
          
          if (safeExtractStart < safeExtractEnd) {
            result.add(TextSpan(
              text: span.text!.substring(safeExtractStart, safeExtractEnd),
              style: span.style,
              children: span.children,
            ));
          }
        }
        
        currentPos = spanEnd;
      } else if (span.children != null) {
        for (final child in span.children!) {
          extractFromSpan(child as TextSpan);
        }
      }
    }
    
    extractFromSpan(highlightedText);
    
    if (result.length == 1) {
      return result[0];
    } else if (result.isEmpty) {
      // Fallback: return plain text with highlighting
      final plainText = highlightedText.toPlainText();
      final safeStart = startPos.clamp(0, plainText.length);
      final safeEnd = (startPos + length).clamp(safeStart, plainText.length);
      return TextSpan(
        text: plainText.substring(safeStart, safeEnd),
      );
    } else {
      return TextSpan(children: result);
    }
  }

  Widget _buildHighlightedCodeWithEmbeddedLineNumbers(
    TextSpan codeWithLineNumbersSpan,
    List<String> codeLines,
    String animatedCode,
    int numLines,
    TextStyle textStyle,
    TextStyle lineNumberStyle,
    int maxLineNumberLength,
    double lineNumberWidth,
  ) {
    // Get the full highlighted text to extract lines properly
    final fullHighlightedText = SlickSlides.highlighters[widget.language]!.highlight(
      animatedCode,
    );
    
    // Build faded version (for highlighted lines animation)
    final fadedChildren = <TextSpan>[];
    int currentPos = 0;
    
    for (var i = 0; i < codeLines.length; i++) {
      final lineNumber = (i + 1).toString();
      final padding = ' ' * (maxLineNumberLength - lineNumber.length);
      final lineLength = codeLines[i].length;
      
      // Add line number (not highlighted, always visible)
      fadedChildren.add(TextSpan(
        text: '$padding$lineNumber ',
        style: lineNumberStyle,
      ));
      
      // Extract the highlighted TextSpan for this line
      final lineHighlighted = _extractLineFromHighlightedText(
        fullHighlightedText,
        currentPos,
        lineLength,
      );
      fadedChildren.add(lineHighlighted);
      
      if (i < codeLines.length - 1) {
        fadedChildren.add(const TextSpan(text: '\n'));
      }
      
      currentPos += lineLength + 1; // +1 for the newline character
    }
    final fadedCodeWithLineNumbersSpan = TextSpan(children: fadedChildren);

    if (!_animateIn || !widget.animateHighlightedLines) {
      _highlightController.value = _dimmedCodeOpacity;
    }

    return DefaultTextStyle(
      style: textStyle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate actual line height using TextPainter
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'A',
              style: textStyle,
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          );
          textPainter.layout(maxWidth: constraints.maxWidth);
          final baseLineHeight = textPainter.height;
          final lineHeightMultiplier = textStyle.height ?? 1.0;
          final actualLineHeight = baseLineHeight * lineHeightMultiplier;

          // Build TextSpan with line numbers, applying highlight logic
          final finalChildren = <TextSpan>[];
          for (var i = 0; i < codeLines.length; i++) {
            final lineNumber = (i + 1).toString();
            final padding = ' ' * (maxLineNumberLength - lineNumber.length);
            
            // Add line number (always visible, not affected by highlight)
            finalChildren.add(TextSpan(
              text: '$padding$lineNumber ',
              style: lineNumberStyle,
            ));
            
            // Add code - we'll handle highlighting in the Stack below
            final lineHighlighted = SlickSlides.highlighters[widget.language]!.highlight(
              codeLines[i],
            );
            finalChildren.add(lineHighlighted);
            
            if (i < codeLines.length - 1) {
              finalChildren.add(const TextSpan(text: '\n'));
            }
          }
          final finalCodeSpan = TextSpan(children: finalChildren);

          return Stack(
            children: [
              // Base code (dimmed if highlighted)
              ClipPath(
                clipper: _HighlightedLinesClipper(
                  numLines: numLines,
                  highlightedLines: widget.highlightedLines,
                  invert: false,
                  lineHeight: actualLineHeight,
                ),
                child: Text.rich(
                  codeWithLineNumbersSpan,
                  textAlign: TextAlign.left,
                ),
              ),
              // Highlighted code (only for highlighted lines)
              Opacity(
                opacity: _highlightController.value,
                child: ClipPath(
                  clipper: _HighlightedLinesClipper(
                    numLines: numLines,
                    highlightedLines: widget.highlightedLines,
                    invert: true,
                    lineHeight: actualLineHeight,
                  ),
                  child: Text.rich(
                    fadedCodeWithLineNumbersSpan,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighlightedCode(
    Widget coloredCode,
    TextSpan highlightedText,
    List<String> codeLines,
    int numLines,
    TextStyle textStyle,
  ) {
    var fadedColoredCode = Text.rich(
      highlightedText,
    );

    if (!_animateIn || !widget.animateHighlightedLines) {
      _highlightController.value = _dimmedCodeOpacity;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate actual line height using TextPainter
        // Measure a single line to get the line height
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'A',
            style: textStyle,
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        // Use the text height, accounting for line height multiplier
        final baseLineHeight = textPainter.height;
        final lineHeightMultiplier = textStyle.height ?? 1.0;
        final actualLineHeight = baseLineHeight * lineHeightMultiplier;

        return Stack(
          children: [
            ClipPath(
              clipper: _HighlightedLinesClipper(
                numLines: numLines,
                highlightedLines: widget.highlightedLines,
                invert: false,
                lineHeight: actualLineHeight,
              ),
              child: coloredCode,
            ),
            Opacity(
              opacity: _highlightController.value,
              child: ClipPath(
                clipper: _HighlightedLinesClipper(
                  numLines: numLines,
                  highlightedLines: widget.highlightedLines,
                  invert: true,
                  lineHeight: actualLineHeight,
                ),
                child: fadedColoredCode,
              ),
            ),
          ],
        );
      },
    );
  }

  String _getAnimatedCode(int frame) {
    frame.clamp(0, _numOperations - 1);

    // Animate insertions and deletions.
    int operationCount = 0;
    int diffIdx = 0;
    int characterIdx = 0;
    var animatedCode = '';
    bool containsNewline = false;
    while (operationCount < frame) {
      var diff = _diff![diffIdx];

      if (diff.operation == DIFF_EQUAL) {
        // Equal.
        animatedCode += diff.text;
        diffIdx += 1;
      } else if (diff.operation == DIFF_DELETE) {
        // Delete.
        diffIdx += 1;
        operationCount += 1;
      } else {
        // Insert.
        animatedCode += diff.text.substring(characterIdx, characterIdx + 1);
        if (diff.text.contains('\n')) {
          containsNewline = true;
        }

        characterIdx += 1;
        operationCount += 1;
        if (characterIdx == diff.text.length) {
          diffIdx += 1;
          characterIdx = 0;
          containsNewline = false;
        }
      }
    }

    if (containsNewline) {
      animatedCode += '\n';
    }

    // Add remaining old code.
    while (diffIdx < _diff!.length) {
      var diff = _diff![diffIdx];
      if (diff.operation == DIFF_EQUAL) {
        // Equal.
        animatedCode += diff.text;
      } else if (diff.operation == DIFF_DELETE) {
        // Delete.
        animatedCode += diff.text;
      }
      diffIdx += 1;
    }

    return animatedCode;
  }
}

class _HighlightedLinesClipper extends CustomClipper<Path> {
  _HighlightedLinesClipper({
    required this.numLines,
    required this.highlightedLines,
    required this.invert,
    this.lineHeight,
  });

  final int numLines;
  final List<int> highlightedLines;
  final bool invert;
  final double? lineHeight;

  @override
  Path getClip(Size size) {
    var path = Path();
    // Use provided lineHeight if available, otherwise calculate from size
    final actualLineHeight = lineHeight ?? (size.height / numLines);
    for (var i = 0; i < numLines; i++) {
      if (highlightedLines.contains(i) != invert) {
        var y = i * actualLineHeight;
        path.addRect(
          Rect.fromLTWH(0.0, y, size.width, actualLineHeight),
        );
      }
    }
    return path;
  }

  @override
  bool shouldReclip(_HighlightedLinesClipper oldClipper) {
    return oldClipper.highlightedLines != highlightedLines ||
        oldClipper.lineHeight != lineHeight;
  }
}
