import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'api_service.dart';

class AuthService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // LOGIN — POST /api/v1/login
  // Body:      { "email": "", "password": "" }
  // Respuesta: {
  //   "message": "Inicio de sesión exitoso.",
  //   "token": "...",
  //   "employee": {
  //     "document_employee", "name_1", "name_2",
  //     "last_name_1", "last_name_2", "email",
  //     "type",   ← 'V' = Vendedor | 'A' = Administrador
  //     "status", "can_modify_invoice", "phone_number"
  //   }
  // }
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post(
      AppConstants.endpointLogin,
      {'email': email, 'password': password},
      auth: false,
    );
    await _saveSession(res);
    return Map<String, dynamic>.from(res);
  }
  // ══════════════════════════════════════════
  // LOGOUT — POST /api/v1/logout
  // Respuesta: { "message": "Sesión cerrada correctamente." }
  // ══════════════════════════════════════════
  Future<void> logout() async {
    try {
      await _api.post(AppConstants.endpointLogout, {});
    } catch (_) {
      // Si falla el servidor igual limpiamos sesión local
    } finally {
      await _clearSession();
    }
  }

  // ══════════════════════════════════════════
  // ME — GET /api/v1/me
  // Devuelve los datos completos del empleado autenticado
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> getMe() async {
    final res = await _api.get(AppConstants.endpointMe);
    return Map<String, dynamic>.from(res);
  }

  // ── Guardar sesión localmente
  Future<void> _saveSession(dynamic res) async {
    final prefs    = await SharedPreferences.getInstance();
    final token    = res['token']    as String?;
    final employee = res['employee'] as Map<String, dynamic>?;

    if (token != null) {
      await prefs.setString(AppConstants.keyAuthToken, token);
    }

    if (employee != null) {
      final firstLogin = employee['first_login'] as bool? ?? false;
      await prefs.setBool('first_login', firstLogin);
      // Nombre completo: name_1 + name_2 + last_name_1
      final nombre = [
        employee['name_1']     ?? '',
        employee['name_2']     ?? '',
        employee['last_name_1'] ?? '',
      ].where((s) => s.toString().isNotEmpty).join(' ');

      await prefs.setString(AppConstants.keyEmployeeDoc,
          employee['document_employee']?.toString() ?? '');
      await prefs.setString(AppConstants.keyUserName, nombre);
      await prefs.setString(AppConstants.keyUserRole,
          employee['type']?.toString() ?? '');
    }
  }

  // ── Limpiar sesión local
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAuthToken);
    await prefs.remove(AppConstants.keyEmployeeDoc);
    await prefs.remove(AppConstants.keyUserName);
    await prefs.remove(AppConstants.keyUserRole);
  }

  // ── ¿Hay sesión activa?
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyAuthToken);
    return token != null && token.isNotEmpty;
  }

  // ── Datos guardados localmente
  Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'doc':    prefs.getString(AppConstants.keyEmployeeDoc) ?? '',
      'nombre': prefs.getString(AppConstants.keyUserName)     ?? '',
      'tipo':   prefs.getString(AppConstants.keyUserRole)     ?? '',
    };
  }

  // ── ¿Es administrador?
  Future<bool> isAdmin() async {
    final data = await getUserData();
    return data['tipo'] == AppConstants.roleAdministrador;
  }

  // ── ¿Es vendedor?
  Future<bool> isVendedor() async {
    final data = await getUserData();
    return data['tipo'] == AppConstants.roleVendedor;
  }
    // ── ¿Es primer login?
  Future<bool> isFirstLogin() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('first_login') ?? false;
  }

  // ── Cambiar contraseña
  Future<void> changePassword(String newPassword) async {
      await _api.post(
        '/change-password',
        {'password': newPassword, 'password_confirmation': newPassword},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_login', false);
  }
}