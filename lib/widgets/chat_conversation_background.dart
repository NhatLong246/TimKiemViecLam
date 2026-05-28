import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/chat_wallpaper_preferences.dart';

/// Nền khung hội thoại (preset hoặc ảnh tùy chọn).
class ChatConversationBackground extends StatelessWidget {
  final ChatWallpaperConfig config;
  final bool isCandidateTheme;

  const ChatConversationBackground({
    super.key,
    required this.config,
    this.isCandidateTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (config.hasCustomImage) {
      return _imageBackground(config.imageBase64!);
    }

    final preset =
        config.usesPreset ? config.presetId! : ChatWallpaperPresets.defaultId;
    return _presetBackground(preset);
  }

  Widget _imageBackground(String b64) {
    final bytes = _decode(b64);
    if (bytes == null) {
      return _presetBackground(ChatWallpaperPresets.defaultId);
    }
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                _presetBackground(ChatWallpaperPresets.defaultId),
          ),
          Container(color: Colors.white.withOpacity(0.08)),
        ],
      ),
    );
  }

  Uint8List? _decode(String raw) {
    try {
      var s = raw.trim();
      if (s.contains(',')) s = s.split(',').last;
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  Widget _presetBackground(String presetId) {
    switch (presetId) {
      case 'light':
        return _solid(const Color(0xFFF4F6F9));
      case 'cream':
        return _gradient(const [Color(0xFFFFFBF0), Color(0xFFFFF3E0)]);
      case 'mint':
        return _gradient(const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]);
      case 'lime':
        return _gradient(const [Color(0xFFF9FBE7), Color(0xFFDCEDC8)]);
      case 'forest':
        return _gradient(const [Color(0xFFE0F2F1), Color(0xFFA5D6A7)]);
      case 'teal':
        return _gradient(const [Color(0xFFE0F7FA), Color(0xFF80DEEA)]);
      case 'aqua':
        return _gradient(const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)]);
      case 'sky':
        return _gradient(
          const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'ocean':
        return _gradient(const [Color(0xFFB3E5FC), Color(0xFF81D4FA)]);
      case 'indigo':
        return _gradient(const [Color(0xFFE8EAF6), Color(0xFF9FA8DA)]);
      case 'lavender':
        return _gradient(const [Color(0xFFF3E5F5), Color(0xFFE1BEE7)]);
      case 'violet':
        return _gradient(const [Color(0xFFEDE7F6), Color(0xFFCE93D8)]);
      case 'grape':
        return _gradient(const [Color(0xFFF3E5F5), Color(0xFFBA68C8)]);
      case 'rose':
        return _gradient(const [Color(0xFFFCE4EC), Color(0xFFF8BBD9)]);
      case 'blush':
        return _gradient(const [Color(0xFFFFF0F5), Color(0xFFF8BBD0)]);
      case 'peach':
        return _gradient(const [Color(0xFFFFF3E0), Color(0xFFFFCCBC)]);
      case 'coral':
        return _gradient(const [Color(0xFFFFEBEE), Color(0xFFFFAB91)]);
      case 'sunset':
        return _gradient(
          const [Color(0xFFFFF3E0), Color(0xFFFFCC80), Color(0xFFFFAB91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'sand':
        return _gradient(const [Color(0xFFFFF8E1), Color(0xFFFFECB3)]);
      case 'lemon':
        return _gradient(const [Color(0xFFFFFDE7), Color(0xFFFFF59D)]);
      case 'slate':
        return _gradient(const [Color(0xFFECEFF1), Color(0xFFB0BEC5)]);
      case 'mocha':
        return _gradient(const [Color(0xFFEFEBE9), Color(0xFFD7CCC8)]);
      case 'dots':
        return CustomPaint(
          painter: _DotsPainter(
            isCandidateTheme
                ? const Color(0xFF2E7D32)
                : const Color(0xFF7B1FA2),
          ),
          child: const ColoredBox(color: Color(0xFFF5F7FA)),
        );
      case 'stripes':
        return CustomPaint(
          painter: _StripesPainter(
            isCandidateTheme
                ? const Color(0xFF2E7D32)
                : const Color(0xFF7B1FA2),
          ),
          child: const ColoredBox(color: Color(0xFFFAFAFA)),
        );
      case 'grid':
        return CustomPaint(
          painter: _GridPainter(
            isCandidateTheme
                ? const Color(0xFF2E7D32)
                : const Color(0xFF7B1FA2),
          ),
          child: const ColoredBox(color: Color(0xFFF8F9FB)),
        );
      case 'charcoal':
        return _gradient(const [Color(0xFF2C2C2C), Color(0xFF1A1A1A)]);
      case 'midnight':
        return _gradient(const [Color(0xFF1B263B), Color(0xFF0D1B2A)]);
      case 'navy_dark':
        return _gradient(const [Color(0xFF1A237E), Color(0xFF0D1642)]);
      case 'forest_dark':
        return _gradient(const [Color(0xFF1B4332), Color(0xFF081C15)]);
      case 'teal_dark':
        return _gradient(const [Color(0xFF00695C), Color(0xFF004D40)]);
      case 'purple_dark':
        return _gradient(const [Color(0xFF4A148C), Color(0xFF311B92)]);
      case 'wine':
        return _gradient(const [Color(0xFF4E342E), Color(0xFF3E2723)]);
      case 'slate_dark':
        return _gradient(const [Color(0xFF455A64), Color(0xFF263238)]);
      case 'obsidian':
        return _gradient(const [Color(0xFF1E1E1E), Color(0xFF121212)]);
      case 'amoled':
        return _solid(const Color(0xFF000000));
      case 'dots_dark':
        return CustomPaint(
          painter: _DotsPainter(Colors.white.withValues(alpha: 0.12)),
          child: const ColoredBox(color: Color(0xFF141414)),
        );
      case 'stripes_dark':
        return CustomPaint(
          painter: _StripesPainter(Colors.white.withValues(alpha: 0.08)),
          child: const ColoredBox(color: Color(0xFF1A1A1A)),
        );
      case 'grid_dark':
        return CustomPaint(
          painter: _GridPainter(Colors.white.withValues(alpha: 0.1)),
          child: const ColoredBox(color: Color(0xFF161616)),
        );
      case 'default':
      default:
        return _DefaultPatternBackground(isCandidateTheme: isCandidateTheme);
    }
  }

  static Widget _solid(Color color) => ColoredBox(color: color);

  static Widget _gradient(
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: begin, end: end, colors: colors),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DefaultPatternBackground extends StatelessWidget {
  final bool isCandidateTheme;
  const _DefaultPatternBackground({required this.isCandidateTheme});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _DefaultPatternPainter(
            Size(constraints.maxWidth, constraints.maxHeight),
            isCandidateTheme: isCandidateTheme,
          ),
        );
      },
    );
  }
}

class _DefaultPatternPainter extends CustomPainter {
  final Size screenSize;
  final bool isCandidateTheme;

  _DefaultPatternPainter(
    this.screenSize, {
    required this.isCandidateTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8EBF5),
    );

    final paint = Paint()..style = PaintingStyle.fill;
    if (isCandidateTheme) {
      paint.color = const Color(0x0C2E7D32);
      canvas.drawCircle(
        Offset(screenSize.width * 0.85, screenSize.height * 0.12),
        90,
        paint,
      );
      paint.color = const Color(0x0843A047);
      canvas.drawCircle(
        Offset(screenSize.width * 0.1, screenSize.height * 0.35),
        70,
        paint,
      );
      paint.color = const Color(0x062E7D32);
      canvas.drawCircle(
        Offset(screenSize.width * 0.75, screenSize.height * 0.65),
        110,
        paint,
      );
    } else {
      paint.color = const Color(0x0C7B1FA2);
      canvas.drawCircle(
        Offset(screenSize.width * 0.85, screenSize.height * 0.12),
        90,
        paint,
      );
      paint.color = const Color(0x081565C0);
      canvas.drawCircle(
        Offset(screenSize.width * 0.1, screenSize.height * 0.35),
        70,
        paint,
      );
      paint.color = const Color(0x067B1FA2);
      canvas.drawCircle(
        Offset(screenSize.width * 0.75, screenSize.height * 0.65),
        110,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DefaultPatternPainter oldDelegate) =>
      oldDelegate.isCandidateTheme != isCandidateTheme;
}

class _DotsPainter extends CustomPainter {
  final Color dotColor;
  _DotsPainter(this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor.withOpacity(0.08);
    const step = 22.0;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}

class _StripesPainter extends CustomPainter {
  final Color lineColor;
  _StripesPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor.withOpacity(0.07);
    const gap = 14.0;
    for (var y = 0.0; y < size.height + gap; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _GridPainter extends CustomPainter {
  final Color lineColor;
  _GridPainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withOpacity(0.09)
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
