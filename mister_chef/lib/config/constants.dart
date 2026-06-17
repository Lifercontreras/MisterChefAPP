/// Constantes globales de la aplicación Mister Chef.
///
/// Centraliza URLs, endpoints de la API, claves de almacenamiento local,
/// roles de usuario, estados de documentos y parámetros de configuración.
/// De esta forma, cualquier cambio en la API o en la lógica de negocio
/// se realiza en un único lugar.
class AppConstants {
  // ══════════════════════════════════════════════════════
  // URL BASE DE LA API DE LARAVEL
  // Apunta al servidor backend en la red local.
  // Cambiar aquí para ambientes de producción o staging.
  // ══════════════════════════════════════════════════════
  static const String baseUrl = 'http://192.168.1.32:8000/api/v1';

  // ── ENDPOINTS DE AUTENTICACIÓN
  /// POST   — Iniciar sesión con email y contraseña.
  static const String endpointLogin  = '/login';
  /// POST   — Cerrar sesión e invalidar el token Bearer.
  static const String endpointLogout = '/logout';
  /// GET    — Obtener datos del empleado autenticado actualmente.
  static const String endpointMe     = '/me';

  // ── ENDPOINTS DE PRODUCTOS
  /// GET / POST — Listar o crear productos.
  static const String endpointProducts         = '/products';
  /// GET        — Productos con stock por debajo del mínimo.
  static const String endpointProductsLowStock = '/products/low-stock';

  // ── ENDPOINTS DE CLIENTES
  /// GET / POST — Listar o crear clientes.
  static const String endpointClients = '/clients';

  // ── ENDPOINTS DE EMPLEADOS
  /// GET / POST — Listar o crear empleados.
  static const String endpointEmployees = '/employees';

  // ── ENDPOINTS DE FACTURAS (pedidos)
  /// GET / POST — Listar facturas o crear una nueva.
  static const String endpointInvoices = '/invoices';

  // ── ENDPOINTS DE GEOLOCALIZACIÓN
  /// POST   — Registrar la ubicación GPS del vendedor.
  static const String endpointLocation           = '/location';
  /// POST   — Desactivar el rastreo de ubicación del vendedor.
  static const String endpointLocationDeactivate = '/location/deactivate';
  /// Clave de la API de Google Maps para mostrar mapas y calcular rutas.
  static const String googleMapsApiKey = 'AIzaSyDAMMrYq-8UW7-qDWZwEMh6neGlpMWDaus';

  // ── ENDPOINTS DE RUTAS DE ENTREGA
  /// GET / POST — Obtener paradas asignadas o crear una ruta.
  static const String endpointRoutes           = '/routes';
  /// POST       — Distribuir automáticamente las rutas entre vendedores.
  static const String endpointRouteDistribute  = '/routes/distribute';
  /// GET        — Obtener sugerencias de cambio de ruta pendientes.
  static const String endpointRouteSuggestions = '/route-suggestions';

  // ── ENDPOINT DE CHATBOT IA
  /// POST — Enviar un mensaje al asistente virtual del servidor.
  static const String endpointChatbot = '/chatbot';

  // ── CLAVES DE SharedPreferences (almacenamiento local)
  /// Token Bearer de autenticación del empleado.
  static const String keyAuthToken   = 'auth_token';
  /// Número de documento del empleado autenticado.
  static const String keyEmployeeDoc = 'employee_doc';
  /// Nombre completo del empleado autenticado.
  static const String keyUserName    = 'user_name';
  /// Rol del empleado: 'V' (Vendedor) o 'A' (Administrador).
  static const String keyUserRole    = 'user_role';
  /// Preferencia de modo oscuro (true = oscuro).
  static const String keyDarkMode    = 'dark_mode';
  /// Factor de escala de fuente elegido por el usuario.
  static const String keyFontScale   = 'font_scale';

  // ── ROLES DE USUARIO
  /// Rol de vendedor — accede a pedidos, clientes y ruta propia.
  static const String roleVendedor      = 'V';
  /// Rol de administrador — acceso completo a la plataforma.
  static const String roleAdministrador = 'A';

  // ── ESTADOS DE FACTURAS
  /// Factura pendiente — creada pero no confirmada.
  static const String invoicePending   = 'P';
  /// Factura confirmada — stock descontado y entrega lista.
  static const String invoiceConfirmed = 'C';
  /// Factura anulada — cancelada por un usuario autorizado.
  static const String invoiceCancelled = 'A';

  // ── ESTADOS DE SUGERENCIAS DE RUTA
  /// Sugerencia enviada por el vendedor, sin revisar.
  static const String suggestionPending  = 'P';
  /// Sugerencia aprobada por el administrador.
  static const String suggestionApproved = 'A';
  /// Sugerencia rechazada por el administrador.
  static const String suggestionRejected = 'R';

  // ── CONFIGURACIÓN DE RASTREO GPS
  /// Intervalo en segundos entre envíos automáticos de ubicación al servidor.
  static const int locationIntervalSeconds = 30;

  // ── TIEMPOS DE ESPERA HTTP
  /// Tiempo máximo para establecer conexión con la API antes de lanzar error.
  static const Duration connectTimeout = Duration(seconds: 15);
}
