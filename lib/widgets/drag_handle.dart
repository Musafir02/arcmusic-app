import 'package:flutter/material.dart';
import '../core/theme.dart';

class DragHandle extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const DragHandle({
    super.key,
    this.width = 36.0,
    this.height = 4.0,
    this.margin = const EdgeInsets.only(bottom: 20.0),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
