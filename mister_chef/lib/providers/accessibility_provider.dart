import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SaturationLevel { normal, high, low, none }

class AccessibilityProvider extends ChangeNotifier {
  bool           _isDarkMode   = false;
  double         _fontScale    = 1.0;
  bool           _dyslexiaFont = false;
  SaturationLevel _saturation  = SaturationLevel.normal;

  bool            get isDarkMode   => _isDarkMode;
  double          get fontScale    => _fontScale;
  bool            get dyslexiaFont => _dyslexiaFont;
  SaturationLevel get saturation   => _saturation;

  String get fontScaleLabel {
    if (_fontScale <= 0.85) return 'Pequeño';
    if (_fontScale <= 1.0)  return 'Normal';
    if (_fontScale <= 1.2)  return 'Grande';
    return 'Muy grande';
  }

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Matriz de saturación para ColorFiltered
  List<double> get saturationMatrix {
    switch (_saturation) {
      case SaturationLevel.high:
        // Saturación alta
        return [
          1.5, -0.2, -0.2, 0, 0,
          -0.2, 1.5, -0.2, 0, 0,
          -0.2, -0.2, 1.5, 0, 0,
          0,    0,    0,   1, 0,
        ];
      case SaturationLevel.low:
        // Saturación baja
        return [
          0.6, 0.2, 0.2, 0, 0,
          0.2, 0.6, 0.2, 0, 0,
          0.2, 0.2, 0.6, 0, 0,
          0,   0,   0,   1, 0,
        ];
      case SaturationLevel.none:
        // Sin saturación (escala de grises)
        return [
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0,    0,    0,    1, 0,
        ];
      case SaturationLevel.normal:
      default:
        // Identidad — sin cambios
        return [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode   = prefs.getBool('dark_mode')    ?? false;
    _fontScale    = prefs.getDouble('font_scale')  ?? 1.0;
    _dyslexiaFont = prefs.getBool('dyslexia_font') ?? false;
    final satIndex = prefs.getInt('saturation')    ?? 0;
    _saturation   = SaturationLevel.values[satIndex];
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setDyslexiaFont(bool value) async {
    _dyslexiaFont = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dyslexia_font', value);
    notifyListeners();
  }

  Future<void> setSaturation(SaturationLevel level) async {
    _saturation = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saturation', level.index);
    notifyListeners();
  }

  Future<void> increaseFontScale() async {
    if (_fontScale >= 1.4) return;
    _fontScale = (_fontScale + 0.15).clamp(0.7, 1.4);
    await _saveFontScale();
    notifyListeners();
  }

  Future<void> decreaseFontScale() async {
    if (_fontScale <= 0.7) return;
    _fontScale = (_fontScale - 0.15).clamp(0.7, 1.4);
    await _saveFontScale();
    notifyListeners();
  }

  Future<void> _saveFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', _fontScale);
  }
}