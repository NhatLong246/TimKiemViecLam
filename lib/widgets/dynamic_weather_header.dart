import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class DynamicWeatherHeader extends StatefulWidget {
  final int conditionCode;
  final Widget child;

  const DynamicWeatherHeader({
    super.key,
    required this.conditionCode,
    required this.child,
  });

  @override
  State<DynamicWeatherHeader> createState() => _DynamicWeatherHeaderState();
}

class _DynamicWeatherHeaderState extends State<DynamicWeatherHeader>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() {
        _time = elapsed.inMicroseconds / 1000000.0; // Tính bằng giây
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int _getTimePeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 0; // Morning
    if (hour >= 12 && hour < 18) return 1; // Afternoon
    if (hour >= 18 && hour < 21) return 2; // Evening
    return 3; // Night
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF81C784), Color(0xFF2E7D32)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: VipWeatherEffectsPainter(
                  conditionCode: widget.conditionCode,
                  timePeriod: _getTimePeriod(),
                  animationValue: _time, // Truyền time liên tục vào
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class VipWeatherEffectsPainter extends CustomPainter {
  final int conditionCode;
  final int timePeriod;
  final double animationValue;
  final Random _random = Random(999);

  VipWeatherEffectsPainter({
    required this.conditionCode,
    required this.timePeriod,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sao đêm (Nền trời)
    if (timePeriod == 3 && (conditionCode == 800 || conditionCode == 801)) {
      _drawStars(canvas, size);
    }

    // 2. Mặt trời (Nếu quang đãng ban ngày)
    if (conditionCode == 800 && timePeriod < 3) {
      _drawRealisticSun(canvas, size);
    }

    // 3. Mây trôi (Parallax nhiều lớp)
    if (conditionCode >= 801 && conditionCode <= 804) {
      _drawRealisticClouds(canvas, size);
    }

    // 4. Mưa (Nhiều lớp tạo chiều sâu)
    if (conditionCode >= 200 && conditionCode < 600) {
      _drawRainParallax(canvas, size);
    } 
    // 5. Tuyết
    else if (conditionCode >= 600 && conditionCode < 700) {
      _drawSnowParallax(canvas, size);
    }
  }

  void _drawRealisticSun(Canvas canvas, Size size) {
    final centerX = size.width * 0.8;
    final centerY = size.height * 0.3;

    // 1. Hào quang tỏa rộng (Outer Glow)
    final outerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.orange.withOpacity(0.3),
          Colors.yellow.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: 200));
    canvas.drawCircle(Offset(centerX, centerY), 200, outerGlow);

    // 2. Mặt trời (Core)
    final sunCore = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, const Color(0xFFFFF59D), Colors.transparent],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: 70))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    
    final pulsatingRadius = 60 + sin(animationValue * 3 * pi) * 8;
    canvas.drawCircle(Offset(centerX, centerY), pulsatingRadius, sunCore);

    // 3. Tia nắng chéo (Light beams)
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(animationValue * pi * 0.5); // Xoay chậm
    
    final beamPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white24, Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(-10, 0, 10, 250))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
    for (int i = 0; i < 5; i++) {
      canvas.rotate(pi * 2 / 5);
      final path = Path()
        ..moveTo(-15, 50)
        ..lineTo(15, 50)
        ..lineTo(5, 300)
        ..lineTo(-5, 300)
        ..close();
      canvas.drawPath(path, beamPaint);
    }
    canvas.restore();

    // 4. Lens Flare (Hiệu ứng chói ống kính)
    final flarePaint1 = Paint()..color = Colors.greenAccent.withOpacity(0.05)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final flarePaint2 = Paint()..color = Colors.pinkAccent.withOpacity(0.05)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawCircle(Offset(centerX - 80, centerY + 80), 30, flarePaint1);
    canvas.drawCircle(Offset(centerX - 130, centerY + 130), 15, flarePaint2);
    canvas.drawCircle(Offset(centerX - 180, centerY + 180), 50, flarePaint1);
  }

  void _drawRealisticClouds(Canvas canvas, Size size) {
    // 3 lớp mây chuyên nghiệp: tỷ lệ cân đối, tốc độ tự nhiên, độ trong suốt vừa phải, phân tán đều
    _drawCloudLayer(canvas, size, layerSpeed: 0.015, scale: 0.6, count: 3, yOffset: 0.3, baseOpacity: 0.25);
    _drawCloudLayer(canvas, size, layerSpeed: 0.03, scale: 0.9, count: 4, yOffset: 0.6, baseOpacity: 0.45);
    _drawCloudLayer(canvas, size, layerSpeed: 0.05, scale: 1.2, count: 3, yOffset: 0.85, baseOpacity: 0.7);
  }

  void _drawCloudLayer(Canvas canvas, Size size, {
    required double layerSpeed,
    required double scale,
    required int count,
    required double yOffset,
    required double baseOpacity,
  }) {
    // Đổ bóng viền cực nhẹ (Anti-aliasing) giúp mây mềm mại nhưng vẫn giữ được hình khối chuẩn mực
    final paint = Paint()
      ..color = Colors.white.withOpacity(baseOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); 

    for (int i = 0; i < count; i++) {
      final seedX = _random.nextDouble() * size.width * 2;
      // Phân tán Y rộng hơn ra khắp vùng height
      final startY = size.height * yOffset + (_random.nextDouble() * 100 - 50);
      
      final animatedX = (seedX - (animationValue * size.width * layerSpeed)) % (size.width + 300) - 150;

      canvas.save();
      canvas.translate(animatedX, startY);
      canvas.scale(scale);
      
      // Path mây chuẩn mực: Dưới phẳng, trên bồng bềnh, tỷ lệ các cụm hình tròn hài hòa
      final path = Path()
        ..addOval(Rect.fromCircle(center: const Offset(0, 0), radius: 20))
        ..addOval(Rect.fromCircle(center: const Offset(30, -12), radius: 28))
        ..addOval(Rect.fromCircle(center: const Offset(65, -5), radius: 22))
        ..addOval(Rect.fromCircle(center: const Offset(90, 8), radius: 15))
        ..addOval(Rect.fromCircle(center: const Offset(15, 8), radius: 12))
        ..addRect(const Rect.fromLTRB(0, 0, 90, 20)); // Đáy phẳng hoàn hảo
        
      canvas.drawPath(path, paint);
      
      canvas.restore();
    }
  }

  void _drawRainParallax(Canvas canvas, Size size) {
    // Sương mù của mưa
    final mistPaint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), mistPaint);

    _drawRainLayer(canvas, size, count: 150, speedMult: 0.6, strokeW: 1.0, opacity: 0.2);
    _drawRainLayer(canvas, size, count: 80, speedMult: 1.8, strokeW: 2.0, opacity: 0.4);
    _drawRainLayer(canvas, size, count: 30, speedMult: 3.0, strokeW: 3.5, opacity: 0.6); // Mưa rào rất gần
  }

  void _drawRainLayer(Canvas canvas, Size size, {
    required int count,
    required double speedMult,
    required double strokeW,
    required double opacity,
  }) {
    // Gió giật đổi hướng nhẹ theo thời gian
    final windTilt = -8.0 + sin(animationValue * pi) * 4.0; 

    for (int i = 0; i < count; i++) {
      final startX = _random.nextDouble() * (size.width + 400) - 200;
      final startY = _random.nextDouble() * size.height;
      
      final dropSpeed = speedMult * 4;
      final animatedY = (startY + (animationValue * size.height * dropSpeed)) % size.height;
      final animatedX = (startX + (animatedY * (windTilt / size.height))) % size.width;
      final length = 20.0 * speedMult;

      // Hạt mưa có dạng vệt mờ dần (Motion blur)
      final rainPaint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(opacity)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromPoints(Offset(animatedX, animatedY), Offset(animatedX + windTilt, animatedY + length)))
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(animatedX, animatedY),
        Offset(animatedX + (windTilt * length / 50), animatedY + length),
        rainPaint,
      );
    }
  }

  void _drawSnowParallax(Canvas canvas, Size size) {
    _drawSnowLayer(canvas, size, count: 100, speedMult: 0.2, baseRadius: 1.5, opacity: 0.5);
    _drawSnowLayer(canvas, size, count: 50, speedMult: 0.5, baseRadius: 3.0, opacity: 0.8);
    _drawSnowLayer(canvas, size, count: 15, speedMult: 0.8, baseRadius: 6.0, opacity: 0.9); // Tuyết to sát màn hình
  }

  void _drawSnowLayer(Canvas canvas, Size size, {
    required int count,
    required double speedMult,
    required double baseRadius,
    required double opacity,
  }) {
    for (int i = 0; i < count; i++) {
      final startX = _random.nextDouble() * size.width;
      final startY = _random.nextDouble() * size.height;
      
      // Chuyển động hỗn loạn của tuyết
      final sway = sin((animationValue * 2 * pi) + i) * 40 * speedMult + cos((animationValue * pi) + i) * 20;
      final animatedY = (startY + (animationValue * size.height * speedMult)) % size.height;
      final animatedX = (startX + sway) % size.width;

      // Bông tuyết toả sáng viền (Glow)
      final snowPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withOpacity(opacity), Colors.white.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: Offset(animatedX, animatedY), radius: baseRadius));

      canvas.drawCircle(Offset(animatedX, animatedY), baseRadius, snowPaint);
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    for (int i = 0; i < 80; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * (size.height * 0.8);
      final radius = _random.nextDouble() * 2.5;
      
      final twinkle = sin((animationValue * 8 * pi) + i) * cos((animationValue * 4 * pi) + i*3);
      final opacity = (twinkle + 1) / 2 * 0.9;
      
      // Đa dạng màu sao: Trắng, hơi xanh, hơi vàng
      final colorType = _random.nextInt(3);
      Color starColor = Colors.white;
      if (colorType == 1) starColor = const Color(0xFFE3F2FD); // Xanh nhạt
      if (colorType == 2) starColor = const Color(0xFFFFFDE7); // Vàng nhạt

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [starColor.withOpacity(opacity), starColor.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius * 1.5));
      
      canvas.drawCircle(Offset(x, y), radius * 1.5, paint);
      
      // Chấm lõi sáng cho ngôi sao lớn
      if (radius > 1.8) {
        canvas.drawCircle(Offset(x, y), radius * 0.3, Paint()..color = Colors.white.withOpacity(opacity));
      }
    }
  }

  @override
  bool shouldRepaint(covariant VipWeatherEffectsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.conditionCode != conditionCode ||
           oldDelegate.timePeriod != timePeriod;
  }
}
