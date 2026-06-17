import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'api_service.dart';

/// Servicio de autenticación de Mister Chef.
///
/// Gestiona el ciclo completo de sesión del empleado:
/// inicio de sesión, cierre de sesión, verificación de estado
/// y persistencia local del token y datos de usuario.
///
/// Se comunica con los endpoints `/login`, `/logout` y `/me`
/// de la API de Laravel a través de [ApiService].
class AuthService {
  final _api = ApiService();

  // ══════════════════════════════════════════
  // LOGIN — POST /api/v1/login
  //
  // Envía las credenciales al servidor y, si son válidas, guarda
  // el token y los datos del empleado en SharedPreferences.
  //
  // Respuesta del servidor:
  // {
  //   "message": "Inicio de sesión exitoso.",
  //   "token": "...",
  //   "employee": {
  //     "document_employee", "name_1", "name_2",
  //     "last_name_1", "last_name_2", "email",
  //     "type",   ← 'V' = Vendedor | 'A' = Administrador
  //     "status", "can_modify_invoice", "phone_number",
  //     "first_login"
  //   }
  // }
  // ══════════════════════════════════════════

  /// Autentica al empleado con [email] y [password].
  ///
  /// Si las credenciales son válidas, persiste la sesión localmente.
  /// Lanza [ApiException] con código 401 si las credenciales son incorrectas.
  ///
  /// Retorna el mapa completo de la respuesta del servidor, incluyendo
  /// los datos del empleado para que la UI pueda redirigir según el rol.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _api.post(
      AppConstants.endpointLogin,
      {'email': email, 'password': password},
      auth: false, // No requiere token previo para autenticarse.
    );
    await _saveSession(res);
    return Map<String, dynamic>.from(res);
  }

  // ══════════════════════════════════════════
  // LOGOUT — POST /api/v1/logout
  //
  // Invalida el token en el servidor y limpia los datos locales.
  // Si la petición al servidor falla (sin internet), la sesión local
  // se limpia de todos modos para no dejar al usuario atrapado.
  // ══════════════════════════════════════════

  /// Cierra la sesión del empleado autenticado.
  ///
  /// Intenta invalidar el token en el servidor. Si falla (ej. sin conexión),
  /// igualmente elimina los datos locales de sesión.
  Future<void> logout() async {
    try {
      await _api.post(AppConstants.endpointLogout, {});
    } catch (_) {
      // Se ignora el error del servidor: la limpieza local es obligatoria.
    } finally {
      await _clearSession();
    }
  }

  // ══════════════════════════════════════════
  // ME — GET /api/v1/me
  //
  // Devuelve los datos actualizados del empleado autenticado.
  // Útil para refrescar información sin hacer login nuevamente.
  // ══════════════════════════════════════════

  /// Obtiene los datos completos del empleado actualmente autenticado.
  ///
  /// Requiere que haya una sesión activa (token válido en SharedPreferences).
  Future<Map<String, dynamic>> getMe() async {
    final res = await _api.get(AppConstants.endpointMe);
    return Map<String, dynamic>.from(res);
  }

  /// Persiste el token y los datos del empleado en [SharedPreferences]
  /// tras un inicio de sesión exitoso.
  ///
  /// Construye el nombre completo concatenando name_1, name_2 y last_name_1.
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

      // Construye nombre legible: "Carlos Andrés Gómez".
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

  /// Elimina todos los datos de sesión del almacenamiento local.
  ///
  /// Llamado automáticamente por [logout] y en caso de token expirado.
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAuthToken);
    await prefs.remove(AppConstants.keyEmployeeDoc);
    await prefs.remove(AppConstants.keyUserName);
    await prefs.remove(AppConstants.keyUserRole);
  }

  /// Verifica si existe un token de sesión válido almacenado localmente.
  ///
  /// No valida el token contra el servidor; solo comprueba su existencia.
  /// Retorna `true` si hay una sesión activa, `false` en caso contrario.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyAuthToken);
    return token != null && token.isNotEmpty;
  }

  /// Retorna un mapa con los datos del empleado guardados localmente.
  ///
  /// Claves del mapa: `'doc'` (documento), `'nombre'` (nombre completo),
  /// `'tipo'` (rol: 'V' o 'A').
  Future<Map<String, String>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'doc':    prefs.getString(AppConstants.keyEmployeeDoc) ?? '',
      'nombre': prefs.getString(AppConstants.keyUserName)     ?? '',
      'tipo':   prefs.getString(AppConstants.keyUserRole)     ?? '',
    };
  }

  /// Retorna `true` si el empleado autenticado tiene rol de Administrador.
  Future<bool> isAdmin() async {
    final data = await getUserData();
    return data['tipo'] == AppConstants.roleAdministrador;
  }

  /// Retorna `true` si el empleado autenticado tiene rol de Vendedor.
  Future<bool> isVendedor() async {
    final data = await getUserData();
    return data['tipo'] == AppConstants.roleVendedor;
  }

  /// Retorna `true` si es el primer inicio de sesión del empleado.
  ///
  /// En ese caso, la app lo redirige a [ChangePasswordScreen] para que
  /// establezca una contraseña personalizada antes de continuar.
  Future<bool> isFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_login') ?? false;
  }

  /// Cambia la contraseña del empleado autenticado.
  ///
  /// Envía [newPassword] al servidor y, si tiene éxito, marca
  /// `first_login` como `false` para no volver a forzar el cambio.
  Future<void> changePassword(String newPassword) async {
    await _api.post(
      '/change-password',
      {'password': newPassword, 'password_confirmation': newPassword},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_login', false);
  }
}
