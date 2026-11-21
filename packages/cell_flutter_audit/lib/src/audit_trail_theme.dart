// Styling knobs for the audit widgets.
library;

import 'package:flutter/material.dart';

/// Controls the colors, typography, and spacing of [AuditTrailView] and
/// [AuditEntryTile].
class AuditTrailTheme {
  /// Creates a theme with Material-3-friendly defaults.
  const AuditTrailTheme({
    this.vettedColor = const Color(0xFF2E7D32),
    this.unvettedColor = const Color(0xFFF9A825),
    this.rejectedColor = const Color(0xFFC62828),
    this.monospaceFont = 'monospace',
    this.cardPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderWidth = 3,
    this.showId = true,
    this.showTimestamp = true,
    this.showVettedIcon = true,
    this.autoScroll = true,
    this.emptyMessage =
        'No receipts yet. Mutations must go through `cell.apply` to appear here.',
  });

  /// Left border color for vetted receipts.
  final Color vettedColor;

  /// Left border color for unvetted (trusted internal) receipts.
  final Color unvettedColor;

  /// Left border color for rejected commands.
  final Color rejectedColor;

  /// Font family for ids and payloads.
  final String monospaceFont;

  /// Padding inside a card.
  final EdgeInsets cardPadding;

  /// Margin around a card.
  final EdgeInsets cardMargin;

  /// Width of the colored left border.
  final double borderWidth;

  /// Whether cards show the (truncated) receipt id.
  final bool showId;

  /// Whether cards show the `HH:mm:ss.SSS` timestamp.
  final bool showTimestamp;

  /// Whether cards show the vetted ✓ / ✗ icon.
  final bool showVettedIcon;

  /// Whether [AuditTrailView] scrolls to the newest entry on change.
  final bool autoScroll;

  /// The message shown when the ledger is empty.
  final String emptyMessage;
}
