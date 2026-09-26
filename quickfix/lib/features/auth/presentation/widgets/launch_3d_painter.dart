import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents a single 3D particle in floating perspective space.
class Particle3D {
  double x; // -1.0 to 1.0
  double y; // -1.0 to 1.0
  double z; // 0.1 to 2.0 (depth)
  double radius;
  double speed;
  double angle;
  Color color;

  Particle3D({
    required this.x,
    required this.y,
    required this.z,
    required this.radius,
    required this.speed,
    required this.angle,
    required this.color,
  });

  factory Particle3D.random(math.Random random, List<Color> palette) {
    return Particle3D(
      x: (random.nextDouble() * 2.0) - 1.0,
      y: (random.nextDouble() * 2.0) - 1.0,
      z: 0.2 + random.nextDouble() * 1.5,
      radius: 1.5 + random.nextDouble() * 2.5,
      speed: 0.15 + random.nextDouble() * 0.35,
      angle: random.nextDouble() * math.pi * 2,
      color: palette[random.nextInt(palette.length)],
    );
  }

  void update(double dt) {
    // Slowly orbit and float upward in 3D
    angle += speed * dt * 0.5;
    y -= speed * dt * 0.12;
    // Wrap around screen boundaries
    if (y < -1.1) {
      y = 1.1;
    }
  }
}

/// CustomPainter rendering a floating 3D particle constellation with perspective projection.
class ParticleField3DPainter extends CustomPainter {
  final List<Particle3D> particles;
  final double animationValue;
  final double focalLength;

  ParticleField3DPainter({
    required this.particles,
    required this.animationValue,
    this.focalLength = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (final p in particles) {
      // Perspective projection
      final scale = focalLength / (focalLength + p.z);
      // Subtle floating wobble based on angle and animation
      final wobbleX = math.cos(p.angle + animationValue * math.pi * 2) * 0.04;
      final wobbleY = math.sin(p.angle + animationValue * math.pi * 2) * 0.04;

      final projectedX = centerX + (p.x + wobbleX) * (size.width * 0.55) * scale;
      final projectedY = centerY + (p.y + wobbleY) * (size.height * 0.55) * scale;
      final projectedRadius = p.radius * scale;
      final projectedOpacity = (scale * 0.85).clamp(0.05, 0.95);

      final paint = Paint()
        ..color = p.color.withValues(alpha: projectedOpacity)
        ..style = PaintingStyle.fill;

      // Glow halo for larger particles
      if (projectedRadius > 2.0) {
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: projectedOpacity * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(Offset(projectedX, projectedY), projectedRadius * 2.2, glowPaint);
      }

      canvas.drawCircle(Offset(projectedX, projectedY), projectedRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleField3DPainter oldDelegate) => true;
}

/// CustomPainter rendering 3D tilted dual orbital energy rings with glowing tracer nodes.
class OrbitalRings3DPainter extends CustomPainter {
  final double rotationAngle;
  final Color primaryColor;
  final Color accentColor;

  OrbitalRings3DPainter({
    required this.rotationAngle,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.46;

    // Ring 1: Tilted at +35 degrees
    _drawOrbitRing(
      canvas: canvas,
      center: center,
      radiusX: baseRadius,
      radiusY: baseRadius * 0.38,
      tiltRad: 35 * (math.pi / 180),
      currentAngle: rotationAngle,
      ringColor: primaryColor.withValues(alpha: 0.3),
      nodeColor: primaryColor,
    );

    // Ring 2: Tilted at -40 degrees (counter-rotating)
    _drawOrbitRing(
      canvas: canvas,
      center: center,
      radiusX: baseRadius * 1.18,
      radiusY: baseRadius * 0.42,
      tiltRad: -40 * (math.pi / 180),
      currentAngle: -rotationAngle * 1.25 + math.pi,
      ringColor: accentColor.withValues(alpha: 0.25),
      nodeColor: accentColor,
    );
  }

  void _drawOrbitRing({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double tiltRad,
    required double currentAngle,
    required Color ringColor,
    required Color nodeColor,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltRad);

    // Draw the ellipse path
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 2,
      height: radiusY * 2,
    );

    final trackPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(rect, trackPaint);

    // Draw orbiting satellite node
    final nodeX = radiusX * math.cos(currentAngle);
    final nodeY = radiusY * math.sin(currentAngle);
    final nodeOffset = Offset(nodeX, nodeY);

    // Glow for node
    final glowPaint = Paint()
      ..color = nodeColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(nodeOffset, 6.0, glowPaint);

    // Solid node center
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodeOffset, 3.0, corePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbitalRings3DPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle;
}
