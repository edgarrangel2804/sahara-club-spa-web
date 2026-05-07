import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SaharaTheme {
  static const Color black = Color(0xFF0B0B0B);
  static const Color burgundy = Color(0xFF4A0E0E);
  static const Color gold = Color(0xFFC6A76A);
  static const Color beige = Color(0xFFE8DCC8);
  static const Color white = Colors.white;

  static const LinearGradient darkGradient = LinearGradient(
    colors: [black, burgundy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, Color(0xFF8B7355)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: black,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 48,
        color: beige,
        fontWeight: FontWeight.w300,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 32,
        color: beige,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 24,
        color: white,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.inter(
        color: Colors.white70,
        fontSize: 16,
      ),
      bodySmall: GoogleFonts.inter(
        color: Colors.white60,
        fontSize: 14,
      ),
    ),
  );
}
