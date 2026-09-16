import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/runner_game.dart';

/// Shared recognizable silhouettes, independent of the platform icon font.
class PowerUpIcon extends StatelessWidget {
  final PowerUp power;
  final Color color;
  final double size;
  const PowerUpIcon(
    this.power, {
    super.key,
    required this.color,
    this.size = 28,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: switch (power) {
      PowerUp.magnet => 'Magnet',
      PowerUp.shield => 'Shield',
      PowerUp.score => 'Double score',
      PowerUp.coins => 'Double coins',
    },
    child: CustomPaint(
      size: Size.square(size),
      painter: _PowerPainter(power, color),
    ),
  );
}

class _PowerPainter extends CustomPainter {
  final PowerUp power;
  final Color color;
  _PowerPainter(this.power, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    switch (power) {
      case PowerUp.magnet:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7;
        canvas.drawPath(
          Path()
            ..moveTo(7, 6)
            ..lineTo(7, 17)
            ..cubicTo(7, 30, 25, 30, 25, 17)
            ..lineTo(25, 6),
          paint,
        );
        paint
          ..color = Colors.white
          ..strokeWidth = 7;
        canvas.drawLine(const Offset(7, 5), const Offset(7, 10), paint);
        canvas.drawLine(const Offset(25, 5), const Offset(25, 10), paint);
      case PowerUp.shield:
        canvas.drawPath(
          Path()
            ..moveTo(16, 2)
            ..lineTo(28, 7)
            ..lineTo(26, 19)
            ..quadraticBezierTo(24, 26, 16, 31)
            ..quadraticBezierTo(8, 26, 6, 19)
            ..lineTo(4, 7)
            ..close(),
          paint,
        );
        paint
          ..color = const Color(0xff102532)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawPath(
          Path()
            ..moveTo(10, 16)
            ..lineTo(14, 20)
            ..lineTo(23, 11),
          paint,
        );
      case PowerUp.score:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? 15.0 : 8.5;
          final x = 16 + math.cos(a) * r, y = 16 + math.sin(a) * r;
          if (i == 0) {
            star.moveTo(x, y);
          } else {
            star.lineTo(x, y);
          }
        }
        canvas.drawPath(star..close(), paint);
        _double(canvas, const Offset(7, 10));
      case PowerUp.coins:
        canvas.drawOval(const Rect.fromLTWH(2, 2, 20, 24), paint);
        paint.color = color.withValues(alpha: .55);
        canvas.drawOval(const Rect.fromLTWH(11, 7, 20, 24), paint);
        paint
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        canvas.drawOval(const Rect.fromLTWH(3, 3, 18, 22), paint);
        _double(canvas, const Offset(10, 13));
    }
    canvas.restore();
  }

  void _double(Canvas canvas, Offset at) {
    final text = TextPainter(
      text: const TextSpan(
        text: '2×',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xff102532),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at);
    text.dispose();
  }

  @override
  bool shouldRepaint(_PowerPainter oldDelegate) =>
      oldDelegate.power != power || oldDelegate.color != color;
}
