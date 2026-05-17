import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SaharaTheme {
  // Definición de la paleta de colores detectada
  static const Color doradoSahara = Color(0xFFC5A059);   // Identidad y acentos
  static const Color bronceOscuro = Color(0xFF9D7C44);   // Botones de acción (+ Nueva Reserva)
  static const Color blancoAlmendra = Color(0xFFFBF9F4); // Fondos suaves de spa
  static const Color grisCarbon = Color(0xFF4A4A4A);    // Tipografía principal
  static const Color grisPiedra = Color(0xFFE0E0E0);    // Líneas y bordes de la agenda
  static const Color rojoCoral = Color(0xFFFF5252);     // Indicador de hora actual

  // Mantengo los colores antiguos como estáticos por si se usan en otros sitios, 
  // pero actualizados a la nueva paleta donde aplique.
  static const Color gold = doradoSahara;
  static const Color beige = blancoAlmendra;
  static const Color black = Color(0xFF0B0B0B); // Mantenemos el negro real para el landing de lujo
  static const Color burgundy = Color(0xFF4A0E0E); // Necesario para el landing de lujo
  static const Color primary = black;
  static const Color surface = Colors.white;
  static const Color background = blancoAlmendra;

  static const LinearGradient darkGradient = LinearGradient(
    colors: [black, burgundy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [doradoSahara, bronceOscuro],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: doradoSahara,
      scaffoldBackgroundColor: blancoAlmendra,
      
      colorScheme: const ColorScheme.light(
        primary: doradoSahara,
        secondary: bronceOscuro,
        surface: Colors.white,
        error: rojoCoral,
        onPrimary: Colors.white,
        onSurface: grisCarbon,
      ),

      // Estilo de la Barra Superior (App Bar)
      appBarTheme: AppBarTheme(
        backgroundColor: blancoAlmendra,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: grisCarbon,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: doradoSahara),
      ),

      // Estilo de los Textos
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(color: grisCarbon, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.inter(color: grisCarbon, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: grisCarbon, fontSize: 14),
      ),

      // Estilo de los Botones (como el de "+ Nueva Reserva")
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bronceOscuro,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Configuración de los Selectores (Dropdowns) y Campos
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: grisPiedra),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: grisPiedra),
        ),
      ),
      
      // Líneas divisorias de la agenda
      dividerTheme: const DividerThemeData(
        color: grisPiedra,
        thickness: 1,
      ),
    );
  }

  // Getter para mantener compatibilidad con código existente que use SaharaTheme.theme
  static ThemeData get theme => lightTheme;
}
