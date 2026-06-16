import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/accessibility_provider.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityProvider>();
    final isDark = accessibility.isDarkMode;

    final bgColor     = isDark ? AppColors.backgroundDark  : AppColors.surfaceLight;
    final cardColor   = isDark ? AppColors.cardDark         : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark  : AppColors.textPrimaryLight;
    final textSec     = isDark ? AppColors.textSecondaryDark: AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderDark       : AppColors.borderLight;
    final divColor    = isDark ? AppColors.borderDark       : const Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Accesibilidad',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _HeroCard(cardColor: cardColor, borderColor: borderColor,
                textPrimary: textPrimary, textSec: textSec),
            const SizedBox(height: 20),

            // ── Apariencia
            _SectionLabel(label: 'Apariencia', textColor: textSec),
            const SizedBox(height: 8),
            _SettingCard(
              cardColor: cardColor, borderColor: borderColor,
              dividerColor: divColor,
              children: [
                _ToggleRow(
                  icon: Icons.dark_mode_outlined,
                  iconBg: const Color(0xFF1A237E).withOpacity(0.1),
                  iconColor: const Color(0xFF1A237E),
                  title: 'Modo oscuro',
                  subtitle: 'Cambia el fondo a colores oscuros',
                  value: accessibility.isDarkMode,
                  textPrimary: textPrimary, textSec: textSec,
                  onChanged: (v) =>
                      context.read<AccessibilityProvider>().setDarkMode(v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

            // ── Saturación
            _SectionLabel(label: 'Saturación de color', textColor: textSec),
            const SizedBox(height: 8),
            _SettingCard(
              cardColor: cardColor, borderColor: borderColor,
              dividerColor: divColor,
              children: [
                _SaturationOption(
                  icon: Icons.palette_outlined,
                  iconBg: Colors.purple.withOpacity(0.1),
                  iconColor: Colors.purple,
                  title: 'Normal',
                  subtitle: 'Colores estándar de la app',
                  level: SaturationLevel.normal,
                  current: accessibility.saturation,
                  textPrimary: textPrimary, textSec: textSec,
                  onTap: () => context.read<AccessibilityProvider>()
                      .setSaturation(SaturationLevel.normal),
                ),
                _SaturationOption(
                  icon: Icons.brightness_high_outlined,
                  iconBg: Colors.orange.withOpacity(0.1),
                  iconColor: Colors.orange,
                  title: 'Saturación alta',
                  subtitle: 'Colores más intensos y vivos',
                  level: SaturationLevel.high,
                  current: accessibility.saturation,
                  textPrimary: textPrimary, textSec: textSec,
                  onTap: () => context.read<AccessibilityProvider>()
                      .setSaturation(SaturationLevel.high),
                ),
                _SaturationOption(
                  icon: Icons.brightness_low_outlined,
                  iconBg: Colors.teal.withOpacity(0.1),
                  iconColor: Colors.teal,
                  title: 'Saturación baja',
                  subtitle: 'Colores más suaves y tenues',
                  level: SaturationLevel.low,
                  current: accessibility.saturation,
                  textPrimary: textPrimary, textSec: textSec,
                  onTap: () => context.read<AccessibilityProvider>()
                      .setSaturation(SaturationLevel.low),
                ),
                _SaturationOption(
                  icon: Icons.gradient_outlined,
                  iconBg: Colors.grey.withOpacity(0.1),
                  iconColor: Colors.grey,
                  title: 'Sin saturación',
                  subtitle: 'Escala de grises',
                  level: SaturationLevel.none,
                  current: accessibility.saturation,
                  textPrimary: textPrimary, textSec: textSec,
                  onTap: () => context.read<AccessibilityProvider>()
                      .setSaturation(SaturationLevel.none),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Lectura
            _SectionLabel(label: 'Lectura', textColor: textSec),
            const SizedBox(height: 8),
            _SettingCard(
              cardColor: cardColor, borderColor: borderColor,
              dividerColor: divColor,
              children: [
                _ToggleRow(
                  icon: Icons.font_download_outlined,
                  iconBg: Colors.green.withOpacity(0.1),
                  iconColor: Colors.green,
                  title: 'Fuente para dislexia',
                  subtitle: 'Usa OpenDyslexic para facilitar la lectura',
                  value: accessibility.dyslexiaFont,
                  textPrimary: textPrimary, textSec: textSec,
                  onChanged: (v) =>
                      context.read<AccessibilityProvider>().setDyslexiaFont(v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Tamaño de letra
            _SectionLabel(label: 'Tamaño de letra', textColor: textSec),
            const SizedBox(height: 8),
            _SettingCard(
              cardColor: cardColor, borderColor: borderColor,
              dividerColor: divColor,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.chipInfoBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.text_fields,
                            color: Color(0xFF1565C0), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tamaño del texto',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary)),
                          Text('Ajusta qué tan grande se ve el texto',
                              style: TextStyle(fontSize: 10, color: textSec)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => context
                              .read<AccessibilityProvider>()
                              .decreaseFontScale(),
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(10)),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10)),
                              border: Border(right: BorderSide(color: borderColor)),
                            ),
                            child: const Icon(Icons.remove,
                                color: AppColors.primary, size: 20),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(accessibility.fontScaleLabel,
                                  style: TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: textPrimary)),
                              Text('tamaño actual',
                                  style: TextStyle(fontSize: 9, color: textSec)),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => context
                              .read<AccessibilityProvider>()
                              .increaseFontScale(),
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(10)),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(10)),
                              border: Border(left: BorderSide(color: borderColor)),
                            ),
                            child: const Icon(Icons.add,
                                color: AppColors.primary, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Vista previa
            _SectionLabel(label: 'Vista previa del texto', textColor: textSec),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mister Chef',
                      style: TextStyle(
                          fontSize: 18 * accessibility.fontScale,
                          fontWeight: FontWeight.w500,
                          color: textPrimary)),
                  const SizedBox(height: 4),
                  Text('Pedidos y distribución',
                      style: TextStyle(
                          fontSize: 14 * accessibility.fontScale,
                          color: textSec)),
                  const SizedBox(height: 4),
                  Text('Última actualización: hace 5 min',
                      style: TextStyle(
                          fontSize: 11 * accessibility.fontScale,
                          color: textSec.withOpacity(0.6))),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// WIDGETS INTERNOS
// ════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final Color cardColor, borderColor, textPrimary, textSec;
  const _HeroCard({required this.cardColor, required this.borderColor,
      required this.textPrimary, required this.textSec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Center(
                child: Text('♿', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Opciones de accesibilidad',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w500, color: textPrimary)),
                const SizedBox(height: 2),
                Text('Personaliza la app según tus necesidades',
                    style: TextStyle(fontSize: 11, color: textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textColor;
  const _SectionLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: textColor, letterSpacing: 1.2));
  }
}

class _SettingCard extends StatelessWidget {
  final Color cardColor, borderColor, dividerColor;
  final List<Widget> children;
  const _SettingCard({required this.cardColor, required this.borderColor,
      required this.dividerColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: children
            .expand((w) => [
                  w,
                  if (w != children.last)
                    Divider(height: 1, thickness: 1, color: dividerColor),
                ])
            .toList(),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor, textPrimary, textSec;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.icon, required this.iconBg,
      required this.iconColor, required this.title, required this.subtitle,
      required this.value, required this.onChanged,
      required this.textPrimary, required this.textSec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500, color: textPrimary)),
                Text(subtitle,
                    style: TextStyle(fontSize: 10, color: textSec)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }
}

class _SaturationOption extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor, textPrimary, textSec;
  final String title, subtitle;
  final SaturationLevel level, current;
  final VoidCallback onTap;

  const _SaturationOption({required this.icon, required this.iconBg,
      required this.iconColor, required this.title, required this.subtitle,
      required this.level, required this.current, required this.onTap,
      required this.textPrimary, required this.textSec});

  @override
  Widget build(BuildContext context) {
    final isSelected = level == current;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500, color: textPrimary)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 10, color: textSec)),
                ],
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderLight,
                    width: 2),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}