import 'package:flutter/material.dart';

/// Paleta de colores estática de la aplicación Mister Chef.
///
/// Define todos los colores utilizados en la app organizados por
/// categoría semántica: primarios, fondos, texto, bordes, estados, etc.
///
/// Para obtener el color correcto según el tema activo (claro u oscuro),
/// usa [AppColorScheme.of(context)] en lugar de acceder directamente
/// a las constantes de esta clase.
class AppColors {
  // ── COLORES PRIMARIOS (identidad de marca Mister Chef)
  /// Rojo principal de la marca — usado en AppBar, botones y acentos.
  static const Color primary        = Color(0xFFD32F2F);
  /// Rojo oscuro — para estados hover, sombras y variantes activas.
  static const Color primaryDark    = Color(0xFFB71C1C);
  /// Rojo claro — para fondos de íconos activos y estados seleccionados.
  static const Color primaryLight   = Color(0xFFEF5350);
  /// Amarillo logo — color de acento secundario (avatares, badges).
  static const Color accent         = Color(0xFFF5C518);

  // ── FONDOS DE PANTALLA
  /// Fondo general en modo claro.
  static const Color backgroundLight = Color(0xFFFFFFFF);
  /// Fondo general en modo oscuro.
  static const Color backgroundDark  = Color(0xFF121212);
  /// Fondo de tarjetas y superficies elevadas en modo claro.
  static const Color surfaceLight    = Color(0xFFF7F6F2);
  /// Fondo de tarjetas y superficies elevadas en modo oscuro.
  static const Color surfaceDark     = Color(0xFF1E1E1E);
  /// Fondo de tarjetas (cards) en modo claro.
  static const Color cardLight       = Color(0xFFFFFFFF);
  /// Fondo de tarjetas (cards) en modo oscuro.
  static const Color cardDark        = Color(0xFF2A2A2A);

  // ── COLORES DE TEXTO
  /// Texto principal en modo claro (títulos, valores).
  static const Color textPrimaryLight   = Color(0xFF1C1C1C);
  /// Texto principal en modo oscuro.
  static const Color textPrimaryDark    = Color(0xFFF1F1F1);
  /// Texto secundario en modo claro (subtítulos, descripciones).
  static const Color textSecondaryLight = Color(0xFF555555);
  /// Texto secundario en modo oscuro.
  static const Color textSecondaryDark  = Color(0xFFAAAAAA);
  /// Texto de placeholder/hint en modo claro.
  static const Color textHintLight      = Color(0xFF999999);
  /// Texto de placeholder/hint en modo oscuro.
  static const Color textHintDark       = Color(0xFF666666);

  // ── BORDES Y DIVISORES
  /// Color de borde de inputs, tarjetas y divisores en modo claro.
  static const Color borderLight = Color(0xFFE8E7E2);
  /// Color de borde de inputs, tarjetas y divisores en modo oscuro.
  static const Color borderDark  = Color(0xFF333333);

  // ── ESTADOS DE PEDIDOS Y RUTAS
  /// Verde — factura confirmada / parada completada / cliente activo.
  static const Color statusSuccess  = Color(0xFF2E7D32);
  /// Naranja — factura pendiente / parada en camino.
  static const Color statusWarning  = Color(0xFFF57C00);
  /// Rojo — factura anulada / error / cliente inactivo.
  static const Color statusError    = Color(0xFFD32F2F);
  /// Azul — información general / indicador de datos.
  static const Color statusInfo     = Color(0xFF1565C0);

  // ── FONDOS DE CHIPS DE ESTADO (versiones suaves para badges)
  /// Fondo verde suave para chips de estado "exitoso/confirmado".
  static const Color chipSuccessBg  = Color(0xFFE8F4E8);
  /// Fondo naranja suave para chips de estado "pendiente/advertencia".
  static const Color chipWarningBg  = Color(0xFFFFF3E0);
  /// Fondo rojo suave para chips de estado "error/cancelado".
  static const Color chipErrorBg    = Color(0xFFFFEBEE);
  /// Fondo azul suave para chips de estado "informativo".
  static const Color chipInfoBg     = Color(0xFFE3F2FD);

  // ── COLORES POR ROL DE USUARIO
  /// Naranja para el badge del rol Vendedor.
  static const Color roleVendedor   = Color(0xFFE65100);
  /// Rojo para el badge del rol Administrador.
  static const Color roleAdmin      = Color(0xFFB71C1C);
  /// Fondo naranja suave para el badge Vendedor.
  static const Color roleVendedorBg = Color(0xFFFFF3E0);
  /// Fondo rojo suave para el badge Administrador.
  static const Color roleAdminBg    = Color(0xFFFFEBEE);

  // ── BARRA DE NAVEGACIÓN Y APP BAR
  /// Fondo de la barra de navegación inferior en modo claro.
  static const Color navBarLight    = Color(0xFFFFFFFF);
  /// Fondo de la barra de navegación inferior en modo oscuro.
  static const Color navBarDark     = Color(0xFF1A1A1A);
  /// Color del ícono activo en la barra de navegación.
  static const Color navIconActive  = Color(0xFFD32F2F);
  /// Color de los íconos inactivos en la barra de navegación.
  static const Color navIconInactive = Color(0xFF9E9E9E);

  // ── MAPA Y RUTAS DE ENTREGA
  /// Color de la línea de ruta trazada en el mapa.
  static const Color mapRoute       = Color(0xFFD32F2F);
  /// Marcador de parada completada en el mapa.
  static const Color stopDone       = Color(0xFF2E7D32);
  /// Marcador de la parada actual del vendedor.
  static const Color stopActive     = Color(0xFFD32F2F);
  /// Marcador de parada pendiente en el mapa.
  static const Color stopPending    = Color(0xFF9E9E9E);
  /// Fondo del área del mapa.
  static const Color mapBackground  = Color(0xFFE8F4E8);
}

/// Helper que devuelve el color semántico correcto según el tema activo.
///
/// Abstrae la lógica de elegir entre la variante clara u oscura de cada color,
/// de modo que los widgets no necesitan conocer el tema directamente.
///
/// Uso:
/// ```dart
/// final cs = AppColorScheme.of(context);
/// Container(color: cs.background)
/// ```
class AppColorScheme {
  /// `true` si el tema activo es oscuro.
  final bool isDark;
  const AppColorScheme._(this.isDark);

  /// Crea un [AppColorScheme] basado en el [Brightness] del contexto actual.
  static AppColorScheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppColorScheme._(brightness == Brightness.dark);
  }

  /// Color de fondo general de la pantalla.
  Color get background  => isDark ? AppColors.backgroundDark  : AppColors.backgroundLight;
  /// Color de superficie elevada (inputs, secciones internas).
  Color get surface     => isDark ? AppColors.surfaceDark      : AppColors.surfaceLight;
  /// Color de fondo de tarjetas (cards).
  Color get card        => isDark ? AppColors.cardDark         : AppColors.cardLight;
  /// Color del texto principal.
  Color get textPrimary => isDark ? AppColors.textPrimaryDark  : AppColors.textPrimaryLight;
  /// Color del texto secundario.
  Color get textSec     => isDark ? AppColors.textSecondaryDark: AppColors.textSecondaryLight;
  /// Color del texto de hint/placeholder.
  Color get textHint    => isDark ? AppColors.textHintDark     : AppColors.textHintLight;
  /// Color de bordes y separadores.
  Color get border      => isDark ? AppColors.borderDark       : AppColors.borderLight;
  /// Color de divisores horizontales entre elementos.
  Color get divider     => isDark ? AppColors.borderDark       : const Color(0xFFF0F0F0);
  /// Color de fondo de la barra de navegación.
  Color get navBar      => isDark ? AppColors.navBarDark       : AppColors.navBarLight;
}
