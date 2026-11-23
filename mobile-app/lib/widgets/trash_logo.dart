import 'package:flutter/material.dart';
import '../models/app_colors.dart';

class TrashLogo extends StatelessWidget {
  final double size;
  const TrashLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/trash.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.delete,
                size: size * 0.6,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }
}