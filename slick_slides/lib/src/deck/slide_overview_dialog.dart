import 'package:flutter/material.dart';
import 'package:slick_slides/slick_slides.dart';
import 'package:slick_slides/src/deck/slide_config.dart';

/// A button widget that can be added to [DeckControls.actions] to show
/// the slide overview dialog.
class SlideOverviewButton extends StatelessWidget {
  /// Creates a [SlideOverviewButton].
  const SlideOverviewButton({
    required this.controller,
    super.key,
  });

  /// The [SlideDeckController] to control navigation.
  final SlideDeckController controller;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(4),
      ),
      onPressed: () {
        final slides = controller.slides;
        final theme = controller.theme;
        final size = controller.size;
        if (slides == null || theme == null || size == null) return;
        
        showDialog(
          context: context,
          builder: (context) => SlideOverviewDialog(
            slides: slides,
            theme: theme,
            size: size,
            currentSlideIndex: controller.currentSlideIndex ?? 0,
            onSlideSelected: (index) {
              controller.goToSlide(index);
            },
          ),
        );
      },
      child: const Icon(
        Icons.grid_view,
        color: Colors.white,
      ),
    );
  }
}

/// A dialog that displays an overview of all slides in a [SlideDeck].
/// Clicking on a slide will navigate to that slide.
class SlideOverviewDialog extends StatelessWidget {
  /// Creates a [SlideOverviewDialog].
  const SlideOverviewDialog({
    required this.slides,
    required this.theme,
    required this.size,
    required this.currentSlideIndex,
    required this.onSlideSelected,
    super.key,
  });

  /// The list of slides in the deck.
  final List<Slide> slides;

  /// The theme of the deck.
  final SlideThemeData theme;

  /// The size of the slides.
  final Size size;

  /// The index of the currently displayed slide.
  final int currentSlideIndex;

  /// Called when a slide is selected.
  final void Function(int index) onSlideSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Slides Overview',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // Slides grid
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final isCurrent = index == currentSlideIndex;
                    return _SlideThumbnail(
                      slide: slides[index],
                      slideIndex: index,
                      totalSlides: slides.length,
                      theme: theme,
                      size: size,
                      isCurrent: isCurrent,
                      onTap: () {
                        onSlideSelected(index);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideThumbnail extends StatelessWidget {
  const _SlideThumbnail({
    required this.slide,
    required this.slideIndex,
    required this.totalSlides,
    required this.theme,
    required this.size,
    required this.isCurrent,
    required this.onTap,
  });

  final Slide slide;
  final int slideIndex;
  final int totalSlides;
  final SlideThemeData theme;
  final Size size;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Apply slide-specific theme if available, before building content
    final slideTheme = slide.theme ?? theme;
    final themedContext = SlideTheme(
      data: slideTheme,
      child: Builder(
        builder: (context) {
          // Build the actual slide content
          // For sub-slides, show the first sub-slide
          return slide.buildContent(context, 0);
        },
      ),
    );

    Widget slideContent = themedContext;

    // Wrap in SlideConfig to disable animations
    slideContent = SlideConfig(
      data: const SlideConfigData(
        animateIn: false,
      ),
      child: slideContent,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? Colors.blue : Colors.white.withOpacity(0.3),
            width: isCurrent ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Actual slide content, scaled to fit
            // Use IgnorePointer to prevent all interactions (including scrolling)
            // with slide content in the overview
            IgnorePointer(
              ignoring: true,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: slideContent,
                ),
              ),
            ),
            // Page number overlay (always shown)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${slideIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Overlay for current indicator
            if (isCurrent)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

