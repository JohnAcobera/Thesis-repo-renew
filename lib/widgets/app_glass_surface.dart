import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.width,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.78),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B2419).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.width,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: borderRadius,
    padding: padding,
    width: width,
    child: child,
  );
}
