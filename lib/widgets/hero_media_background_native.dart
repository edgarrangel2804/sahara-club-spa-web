import 'package:flutter/material.dart';

class HeroMediaBackground extends StatelessWidget {
  const HeroMediaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/portada.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.black),
    );
  }
}
