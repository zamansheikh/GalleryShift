import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

enum DeckKind { everything, shuffle, onThisDay, screenshots, videos, month }

/// A named set of assets to swipe through. [assets] holds every asset in the
/// set, reviewed or not; the controller filters out what is already decided.
class Deck {
  const Deck({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assets,
    this.month,
  });

  final String id;
  final DeckKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<AssetEntity> assets;

  /// First day of the month, for [DeckKind.month].
  final DateTime? month;
}

enum Decision { keep, delete }
