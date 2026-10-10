// Shows a card's picture from its image reference, and falls back to a suit
// symbol whenever the reference is missing, malformed, or cannot be loaded.
// A card is always displayable, with or without an image.

import 'package:flutter/material.dart';

import '../models/playing_card.dart';

class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.imageRef,
    required this.suit,
    this.size = 48,
  });

  final String? imageRef;
  final String suit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef?.trim() ?? '';
    final placeholder = SuitPlaceholder(suit: suit, size: size);
    final uri = Uri.tryParse(ref);

    Widget child;
    if (ref.isEmpty) {
      // No image stored.
      child = placeholder;
    } else if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      // Remote image: may be slow or offline, so handle both.
      child = Image.network(
        ref,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, image, progress) {
          if (progress == null) return image;
          return Center(
            child: SizedBox(
              width: size / 3,
              height: size / 3,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else if (ref.startsWith('assets/')) {
      // Bundled asset: fails if it was never registered in pubspec.yaml.
      child = Image.asset(
        ref,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else {
      // Anything else is a malformed reference.
      child = placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class SuitPlaceholder extends StatelessWidget {
  const SuitPlaceholder({super.key, required this.suit, this.size = 48});

  final String suit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: scheme.secondaryContainer,
      child: Text(
        Suits.symbol(suit),
        style: TextStyle(
          fontSize: size * 0.55,
          height: 1,
          color: Suits.isRed(suit) ? scheme.error : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
