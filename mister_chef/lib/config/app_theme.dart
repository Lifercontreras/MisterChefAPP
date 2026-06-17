import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Configuración de temas visuales de la aplicación Mister Chef.
///
/// Provee dos temas con Material Design 3:
/// - [lightTheme]: para uso en condiciones de buena iluminación.
/// - [darkTheme]: para uso nocturno o en ambientes oscuros.
///
/// Ambos temas aceptan el parámetro [dyslexiaFont] que activa la tipografía
/// **Lexend**, específicamente diseñada para facilitar la lectura a personas
/// con dislexia. Por defecto se usa **Inter**, tipografía de alta legibilidad.
///
/// Los temas definen de forma centralizada:
/// - Colores del esquema (primary, secondary, surface, error).
/// - Estilo del AppBar.
/// - Estilo de botones elevados.
/// - Decoración de campos de texto (inputs).
/// - Barra de navegación inferior.
class AppTheme {
  /// Tema claro de Mister Chef.
  ///
  /// Usa fondo blanco, superficies en gris suave y el rojo de la marca
  /// como color primario. Soporta la fuente Lexend si [dyslexiaFont] es `true`.
  static ThemeData lightTheme({bool dyslexiaFont = false}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    primaryColor: AppColors.primary,

    // Tipografía: Lexend (accesibilidad) o Inter (legibilidad estándar).
    textTheme: dyslexiaFont
        ? GoogleFonts.lexendTextTheme()
        : GoogleFonts.interTextTheme(),

    colorScheme: const ColorScheme.light(
      primary:   AppColors.primary,      // Rojo Mister Chef.
      secondary: AppColors.accent,       // Amarillo logo.
      surface:   AppColors.surfaceLight, // Gris suave para cards.
      error:     AppColors.statusError,  // Rojo de error.
    ),

    // AppBar rojo con texto blanco y sin elevación.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),

    // Botones con fondo rojo, texto blanco y bordes redondeados.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // Campos de texto con fondo gris claro y borde rojo al enfocarse.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.statusError),
      ),
    ),

    // Barra de navegación inferior con ícono rojo activo e inactivo gris.
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:   AppColors.navBarLight,
      selectedItemColor:   AppColors.navIconActive,
      unselectedItemColor: AppColors.navIconInactive,
      type:      BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  /// Tema oscuro de Mister Chef.
  ///
  /// Usa fondo muy oscuro (#121212), superficies en gris oscuro y mantiene
  /// el rojo de la marca como color primario. Soporta Lexend si [dyslexiaFont] es `true`.
  static ThemeData darkTheme({bool dyslexiaFont = false}) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    primaryColor: AppColors.primary,

    // Aplica la tipografía sobre el tema oscuro base de Flutter.
    textTheme: dyslexiaFont
        ? GoogleFonts.lexendTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme)
        : GoogleFonts.interTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme),

    colorScheme: const ColorScheme.dark(
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.surfaceDark,
      error:     AppColors.statusError,
    ),

    // AppBar mantiene el rojo de la marca incluso en modo oscuro.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // En modo oscuro, los inputs usan la superficie oscura como fondo.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.statusError),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     AppColors.navBarDark,
      selectedItemColor:   AppColors.navIconActive,
      unselectedItemColor: AppColors.navIconInactive,
      type:      BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
