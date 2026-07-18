import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PatternLockWidget extends StatefulWidget {
  final Function(String) onCompleted;
  final bool isError;

  const PatternLockWidget({
    super.key, 
    required this.onCompleted, 
    this.isError = false
  });

  @override
  State<PatternLockWidget> createState() => _PatternLockWidgetState();
}

class _PatternLockWidgetState extends State<PatternLockWidget> {
  final List<int> _currentPattern = [];
  Offset? _currentTouchPoint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => _handlePanUpdate(details.localPosition),
      onPanUpdate: (details) => _handlePanUpdate(details.localPosition),
      onPanEnd: (details) {
        if (_currentPattern.isNotEmpty) {
          widget.onCompleted(_currentPattern.join(','));
        }
        setState(() {
          _currentPattern.clear();
          _currentTouchPoint = null;
        });
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _PatternPainter(
            pattern: _currentPattern,
            touchPoint: _currentTouchPoint,
            isError: widget.isError,
          ),
          child: Container(),
        ),
      ),
    );
  }

  void _handlePanUpdate(Offset localPosition) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final dotSize = size.width / 3;

    for (int i = 0; i < 9; i++) {
        final row = i ~/ 3;
        final col = i % 3;
        final center = Offset(
            col * dotSize + dotSize / 2, 
            row * dotSize + dotSize / 2
        );

        if ((localPosition - center).distance < dotSize * 0.4) {
          if (!_currentPattern.contains(i)) {
            setState(() {
              _currentPattern.add(i);
            });
          }
        }
    }

    setState(() {
      _currentTouchPoint = localPosition;
    });
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Offset? touchPoint;
  final bool isError;

  _PatternPainter({required this.pattern, this.touchPoint, required this.isError});

  @override
  void paint(Canvas canvas, Size size) {
    final dotSize = size.width / 3;
    final paint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Color primaryColor = isError ? Colors.red : AppTheme.primaryIvory;

    // 1. Draw connecting lines
    if (pattern.isNotEmpty) {
      paint.color = primaryColor.withValues(alpha: 0.5);
      final path = Path();
      
      for (int i = 0; i < pattern.length; i++) {
        final index = pattern[i];
        final row = index ~/ 3;
        final col = index % 3;
        final center = Offset(col * dotSize + dotSize / 2, row * dotSize + dotSize / 2);
        
        if (i == 0) {
          path.moveTo(center.dx, center.dy);
        } else {
          path.lineTo(center.dx, center.dy);
        }
      }

      if (touchPoint != null) {
        final lastIndex = pattern.last;
        final lastCenter = Offset(
          (lastIndex % 3) * dotSize + dotSize / 2, 
          (lastIndex ~/ 3) * dotSize + dotSize / 2
        );
        canvas.drawLine(lastCenter, touchPoint!, paint);
      }

      canvas.drawPath(path, paint);
    }

    // 2. Draw dots
    for (int i = 0; i < 9; i++) {
      final row = i ~/ 3;
      final col = i % 3;
      final center = Offset(col * dotSize + dotSize / 2, row * dotSize + dotSize / 2);
      
      final bool isSelected = pattern.contains(i);
      
      // Outer ring
      paint.style = PaintingStyle.stroke;
      paint.color = isSelected ? primaryColor : Colors.white24;
      paint.strokeWidth = 2;
      canvas.drawCircle(center, dotSize * 0.15, paint);
      
      // Inner dot
      if (isSelected) {
        paint.style = PaintingStyle.fill;
        paint.color = primaryColor;
        canvas.drawCircle(center, dotSize * 0.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
