import 'package:flutter/material.dart';
import 'package:slick_slides_client/slick_slides_client.dart';

class Remote extends StatelessWidget {
  const Remote({
    required this.onNext,
    required this.onPrevious,
    required this.deckState,
    super.key,
  });

  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final DeckState deckState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: deckState.isConnected ? onPrevious : null,
                    child: const Icon(
                      Icons.arrow_back,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: deckState.isConnected ? onNext : null,
                    child: const Icon(
                      Icons.arrow_forward,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(deckState.presenterNote ?? ''),
          ),
        ),
      ],
    );
  }
}
