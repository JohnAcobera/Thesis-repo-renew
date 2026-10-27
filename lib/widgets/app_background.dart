import 'package:flutter/material.dart';

const _appPrimary = Color(0xFFFF7434);
const _appBase = Color(0xFFFFF8EE);

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _AppBackgroundPainter(),
    child: child,
  );
}

class _AppBackgroundPainter extends CustomPainter {
  const _AppBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.35), _appBase),
            _appBase,
            Color.alphaBlend(_appPrimary.withValues(alpha: 0.26), _appBase),
          ],
          stops: const [0, 0.52, 1],
        ).createShader(bounds),
    );

    const rowStops = [0.0, 0.13, 0.28, 0.44, 0.61, 0.78, 0.92, 1.0];
    const columnStops = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

    Offset vertex(int row, int column) {
      final xJitter = column == 0 || column == columnStops.length - 1
          ? 0.0
          : (((row * 7 + column * 11) % 5) - 2) * 0.018;
      final yJitter = row == 0 || row == rowStops.length - 1
          ? 0.0
          : (((row * 13 + column * 3) % 5) - 2) * 0.012;
      return Offset(
        size.width * (columnStops[column] + xJitter),
        size.height * (rowStops[row] + yJitter),
      );
    }

    for (var row = 0; row < rowStops.length - 1; row++) {
      for (var column = 0; column < columnStops.length - 1; column++) {
        final topLeft = vertex(row, column);
        final topRight = vertex(row, column + 1);
        final bottomRight = vertex(row + 1, column + 1);
        final bottomLeft = vertex(row + 1, column);
        final triangles = (row + column).isEven
            ? [
                [topLeft, topRight, bottomRight],
                [topLeft, bottomRight, bottomLeft],
              ]
            : [
                [topLeft, topRight, bottomLeft],
                [topRight, bottomRight, bottomLeft],
              ];

        for (var face = 0; face < triangles.length; face++) {
          final emphasized = (row * 5 + column * 3 + face * 7) % 11 == 0;
          final opacity = emphasized
              ? 0.16 + row * 0.014
              : 0.035 + row * 0.02 + ((column + face) % 2) * 0.018;
          final points = triangles[face];
          final path = Path()
            ..moveTo(points[0].dx, points[0].dy)
            ..lineTo(points[1].dx, points[1].dy)
            ..lineTo(points[2].dx, points[2].dy)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..color = (emphasized && (row + column).isEven
                  ? Colors.white
                  : _appPrimary).withValues(alpha: opacity),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AppBackgroundPainter oldDelegate) => false;
}
