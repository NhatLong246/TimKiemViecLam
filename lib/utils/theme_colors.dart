import 'package:flutter/material.dart';

/// Màu chữ / nền theo theme — dùng thay cho màu hex cố định.
extension ThemeColors on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;

  Color get textPrimary => cs.onSurface;

  Color get textSecondary => cs.onSurfaceVariant;

  Color get pageBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get cardBackground => Theme.of(this).cardColor;

  Color get borderColor => Theme.of(this).dividerColor;

  Color get elevatedSurface {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2A2A36) : const Color(0xFFF5F5F5);
  }
}

/// Tương thích code cũ dùng `context.palette.elevatedSurface`.
extension ThemePaletteCompat on BuildContext {
  _PaletteCompat get palette => _PaletteCompat(this);
}

class _PaletteCompat {
  _PaletteCompat(this._context);
  final BuildContext _context;

  Color get elevatedSurface => _context.elevatedSurface;

  Color get borderColor => _context.borderColor;
}
