import 'package:flutter/material.dart';
 
class AppColors {
  // ── Colores primarios (identidad Mister Chef)
  static const Color primary        = Color(0xFFD32F2F); // rojo principal
  static const Color primaryDark    = Color(0xFFB71C1C); // rojo oscuro (hover / sombras)
  static const Color primaryLight   = Color(0xFFEF5350); // rojo claro (estados activos)
  static const Color accent         = Color(0xFFF5C518); // amarillo logo
 
  // ── Fondos
  static const Color backgroundLight = Color(0xFFFFFFFF); // fondo modo claro
  static const Color backgroundDark  = Color(0xFF121212); // fondo modo oscuro
  static const Color surfaceLight    = Color(0xFFF7F6F2); // tarjetas modo claro
  static const Color surfaceDark     = Color(0xFF1E1E1E); // tarjetas modo oscuro
  static const Color cardLight       = Color(0xFFFFFFFF);
  static const Color cardDark        = Color(0xFF2A2A2A);
 
  // ── Texto
  static const Color textPrimaryLight   = Color(0xFF1C1C1C);
  static const Color textPrimaryDark    = Color(0xFFF1F1F1);
  static const Color textSecondaryLight = Color(0xFF555555);
  static const Color textSecondaryDark  = Color(0xFFAAAAAA);
  static const Color textHintLight      = Color(0xFF999999);
  static const Color textHintDark       = Color(0xFF666666);
 
  // ── Bordes
  static const Color borderLight = Color(0xFFE8E7E2);
  static const Color borderDark  = Color(0xFF333333);
 
  // ── Estados de pedidos / rutas
  static const Color statusSuccess  = Color(0xFF2E7D32); // completado / entregado
  static const Color statusWarning  = Color(0xFFF57C00); // en camino / pendiente
  static const Color statusError    = Color(0xFFD32F2F); // cancelado / error
  static const Color statusInfo     = Color(0xFF1565C0); // información
 
  // ── Chips de estado (fondo suave)
  static const Color chipSuccessBg  = Color(0xFFE8F4E8);
  static const Color chipWarningBg  = Color(0xFFFFF3E0);
  static const Color chipErrorBg    = Color(0xFFFFEBEE);
  static const Color chipInfoBg     = Color(0xFFE3F2FD);
 
  // ── Roles de usuario
  static const Color roleVendedor   = Color(0xFFE65100); // naranja vendedor
  static const Color roleAdmin      = Color(0xFFB71C1C); // rojo admin
  static const Color roleVendedorBg = Color(0xFFFFF3E0);
  static const Color roleAdminBg    = Color(0xFFFFEBEE);
 
  // ── Navbar / AppBar
  static const Color navBarLight    = Color(0xFFFFFFFF);
  static const Color navBarDark     = Color(0xFF1A1A1A);
  static const Color navIconActive  = Color(0xFFD32F2F);
  static const Color navIconInactive = Color(0xFF9E9E9E);
 
  // ── Mapa / rutas
  static const Color mapRoute       = Color(0xFFD32F2F);  // línea de ruta
  static const Color stopDone       = Color(0xFF2E7D32);  // parada completada
  static const Color stopActive     = Color(0xFFD32F2F);  // parada actual
  static const Color stopPending    = Color(0xFF9E9E9E);  // parada pendiente
  static const Color mapBackground  = Color(0xFFE8F4E8);  // fondo del mapa
}
/// Helper para obtener colores según el tema activo.
/// Uso: AppColorScheme.of(context).background
class AppColorScheme {
  final bool isDark;
  const AppColorScheme._(this.isDark);

  static AppColorScheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppColorScheme._(brightness == Brightness.dark);
  }

  Color get background  => isDark ? AppColors.backgroundDark  : AppColors.backgroundLight;
  Color get surface     => isDark ? AppColors.surfaceDark      : AppColors.surfaceLight;
  Color get card        => isDark ? AppColors.cardDark         : AppColors.cardLight;
  Color get textPrimary => isDark ? AppColors.textPrimaryDark  : AppColors.textPrimaryLight;
  Color get textSec     => isDark ? AppColors.textSecondaryDark: AppColors.textSecondaryLight;
  Color get textHint    => isDark ? AppColors.textHintDark     : AppColors.textHintLight;
  Color get border      => isDark ? AppColors.borderDark       : AppColors.borderLight;
  Color get divider     => isDark ? AppColors.borderDark       : const Color(0xFFF0F0F0);
  Color get navBar      => isDark ? AppColors.navBarDark       : AppColors.navBarLight;
}