import 'package:flutter/material.dart';

class FirmLogo extends StatelessWidget {
  final double size;
  final bool circle;
  const FirmLogo({super.key, this.size = 96, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.business, size: size * 0.7, color: Colors.grey),
    );
    if (!circle) return img;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: img,
    );
  }
}
