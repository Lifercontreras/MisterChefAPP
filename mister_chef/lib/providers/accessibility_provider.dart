import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Niveles de saturación de color disponibles para usuarios con necesidades visuales.
enum SaturationLevel {
  /// Colores normales, sin modificación.
  normal,
  /// Saturación aumentada para mayor viveza de colores.
  high,
  /// Saturación reducida para menor intensidad visual.
  low,
  /// Sin saturación: modo escala de grises para daltonismo severo.
  none,
}

/// Proveedor de estado para las preferencias de accesibilidad del usuario.
///
/// Controla cuatro aspectos visuales de la app que mejoran la experiencia
/// para usuarios con necesidades especiales:
///
/// - **Modo oscuro**: reduce el brillo de la pantalla.
/// - **Escala de fuente**: aumenta o reduce el tamaño del texto globalmente.
/// - **Fuente para dislexia**: activa la tipografía Lexend, diseñada para
///   facilitar la lectura a personas con dislexia.
/// - **Saturación de color**: ajusta el nivel de saturación o activa
///   escala de grises para personas con daltonismo.
///
/// Todas las preferencias se persisten en [SharedPreferences] para que
/// el usuario no tenga que configurarlas cada vez que abre la app.
///
/// Uso:
/// ```dart
/// final accessibility = context.watch<AccessibilityProvider>();
/// bool isDark = accessibility.isDarkMode;
/// ```
class AccessibilityProvider extends ChangeNotifier {
  // ── Estado interno
  bool           _isDarkMode   = false;
  double         _fontScale    = 1.0;
  bool           _dyslexiaFont = false;
  SaturationLevel _saturation  = SaturationLevel.normal;

  // ── Getters públicos
  /// `true` si el modo oscuro está activo.
  bool            get isDarkMode   => _isDarkMode;
  /// Factor de escala del texto (rango: 0.7 – 1.4).
  double          get fontScale    => _fontScale;
  /// `true` si la fuente para dislexia (Lexend) está activada.
  bool            get dyslexiaFont => _dyslexiaFont;
  /// Nivel de saturación de color activo.
  SaturationLevel get saturation   => _saturation;

  /// Etiqueta legible del tamaño de fuente actual para mostrar en UI.
  String get fontScaleLabel {
    if (_fontScale <= 0.85) return 'Pequeño';
    if (_fontScale <= 1.0)  return 'Normal';
    if (_fontScale <= 1.2)  return 'Grande';
    return 'Muy grande';
  }

  /// Modo de tema de Flutter según la preferencia del usuario.
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Matriz 4×5 para [ColorFilter] que aplica el nivel de saturación elegido.
  ///
  /// Usada en el `builder` de [MaterialApp] para filtrar todos los colores
  /// de la aplicación en tiempo real sin recompilar el tema.
  List<double> get saturationMatrix {
    switch (_saturation) {
      case SaturationLevel.high:
        // Aumenta la saturación en un 50% (canales primarios +0.5, cruzados -0.2).
        return [
          1.5, -0.2, -0.2, 0, 0,
          -0.2, 1.5, -0.2, 0, 0,
          -0.2, -0.2, 1.5, 0, 0,
          0,    0,    0,   1, 0,
        ];
      case SaturationLevel.low:
        // Reduce la saturación mezclando canales (colores más apagados).
        return [
          0.6, 0.2, 0.2, 0, 0,
          0.2, 0.6, 0.2, 0, 0,
          0.2, 0.2, 0.6, 0, 0,
          0,   0,   0,   1, 0,
        ];
      case SaturationLevel.none:
        // Escala de grises: promedio de los tres canales RGB.
        return [
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0,    0,    0,    1, 0,
        ];
      case SaturationLevel.normal:
      default:
        // Matriz identidad: sin modificación de color.
        return [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }

  /// Carga todas las preferencias de accesibilidad desde [SharedPreferences].
  ///
  /// Debe llamarse en `main()` antes de ejecutar la app para que las
  /// preferencias se apliquen desde el primer frame.
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode   = prefs.getBool('dark_mode')    ?? false;
    _fontScale    = prefs.getDouble('font_scale')  ?? 1.0;
    _dyslexiaFont = prefs.getBool('dyslexia_font') ?? false;
    final satIndex = prefs.getInt('saturation')    ?? 0;
    _saturation   = SaturationLevel.values[satIndex];
    notifyListeners();
  }

  /// Activa o desactiva el modo oscuro y persiste la preferencia.
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  /// Activa o desactiva la fuente para dislexia (Lexend) y persiste la preferencia.
  Future<void> setDyslexiaFont(bool value) async {
    _dyslexiaFont = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dyslexia_font', value);
    notifyListeners();
  }

  /// Cambia el nivel de saturación de color y persiste la preferencia.
  Future<void> setSaturation(SaturationLevel level) async {
    _saturation = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saturation', level.index);
    notifyListeners();
  }

  /// Incrementa la escala de fuente en 0.15 puntos (máximo: 1.4).
  ///
  /// No hace nada si ya se alcanzó el tamaño máximo.
  Future<void> increaseFontScale() async {
    if (_fontScale >= 1.4) return;
    _fontScale = (_fontScale + 0.15).clamp(0.7, 1.4);
    await _saveFontScale();
    notifyListeners();
  }

  /// Reduce la escala de fuente en 0.15 puntos (mínimo: 0.7).
  ///
  /// No hace nada si ya se alcanzó el tamaño mínimo.
  Future<void> decreaseFontScale() async {
    if (_fontScale <= 0.7) return;
    _fontScale = (_fontScale - 0.15).clamp(0.7, 1.4);
    await _saveFontScale();
    notifyListeners();
  }

  /// Persiste el factor de escala de fuente actual en [SharedPreferences].
  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', _fontScale);
  }
}
