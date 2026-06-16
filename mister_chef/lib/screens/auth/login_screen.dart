import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _AuthHeader(),
            _WaveClipper(),
            const _LoginForm(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// ENCABEZADO
// ════════════════════════════════════════════
class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.only(top: 56, bottom: 24, left: 24, right: 24),
      child: Stack(
        children: [
          Positioned(
            top: -50, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: const BoxDecoration(
                  color: AppColors.primaryDark, shape: BoxShape.circle),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 2.5),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/logo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 22,
                              fontWeight: FontWeight.w500, color: Colors.white),
                          children: [
                            TextSpan(text: 'Mister '),
                            TextSpan(text: 'Chef',
                                style: TextStyle(color: AppColors.accent)),
                          ],
                        ),
                      ),
                      Text('VENTAS Y DISTRIBUCIÓN',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.8,
                              color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveClipper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveShape(),
      child: Container(height: 28, color: AppColors.primary),
    );
  }
}

class _WaveShape extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.75, 0, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveShape oldClipper) => false;
}

// ════════════════════════════════════════════
// FORMULARIO LOGIN
// ════════════════════════════════════════════
class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure   = true;
  bool _isLoading = false;
  final _authService = AuthService();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final res = await _authService.login(
          _emailCtrl.text.trim(), _passCtrl.text.trim());
      if (!mounted) return;
      final firstLogin = res['employee']?['first_login'] as bool? ?? false;
      if (firstLogin) {
        Navigator.pushReplacementNamed(context, AppRoutes.changePassword);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _showError('Contraseña incorrecta. Verifica tus datos.');
      } else {
        _showError(e.message);
      }
    } catch (_) {
      _showError('Error al iniciar sesión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: AppColors.statusError,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bienvenido de nuevo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight)),
            const SizedBox(height: 4),
            const Text('Ingresa tus credenciales para continuar',
                style: TextStyle(fontSize: 13, color: AppColors.textHintLight)),
            const SizedBox(height: 22),

            _InputField(
              label: 'Correo electrónico', controller: _emailCtrl,
              hint: 'ejemplo@misterchef.com', icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu correo';
                if (!v.contains('@')) return 'Correo no válido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _InputField(
              label: 'Contraseña', controller: _passCtrl,
              hint: '••••••••', icon: Icons.lock_outline,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textHintLight, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Iniciar sesión',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// WIDGETS REUTILIZABLES
// ════════════════════════════════════════════
class _InputField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label, required this.controller,
    required this.hint,  required this.icon,
    this.obscureText = false, this.suffixIcon,
    this.keyboardType, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller, obscureText: obscureText,
          keyboardType: keyboardType, validator: validator,
          style: const TextStyle(fontSize: 14,
              color: AppColors.textPrimaryLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textHintLight, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            suffixIcon: suffixIcon,
            filled: true, fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderLight)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.statusError)),
          ),
        ),
      ],
    );
  }
}