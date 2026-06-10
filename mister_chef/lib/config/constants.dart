class AppConstants {
  // ══════════════════════════════════════════════════════
  // URL BASE DE LA API DE LARAVEL
  // ══════════════════════════════════════════════════════
  static const String baseUrl = 'http://192.168.1.17:8000/api/v1';

  // ── AUTH
  static const String endpointLogin  = '/login';
  static const String endpointLogout = '/logout';
  static const String endpointMe     = '/me';

  // ── PRODUCTOS
  static const String endpointProducts         = '/products';
  static const String endpointProductsLowStock = '/products/low-stock';

  // ── CLIENTES
  static const String endpointClients = '/clients';

  // ── EMPLEADOS
  static const String endpointEmployees = '/employees';

  // ── FACTURAS (pedidos)
  static const String endpointInvoices = '/invoices';

  // ── GEOLOCALIZACIÓN
  static const String endpointLocation           = '/location';
  static const String endpointLocationDeactivate = '/location/deactivate';
  static const String googleMapsApiKey = 'AIzaSyDAMMrYq-8UW7-qDWZwEMh6neGlpMWDaus';

  // ── RUTAS
  static const String endpointRoutes           = '/routes';
  static const String endpointRouteDistribute  = '/routes/distribute';
  static const String endpointRouteSuggestions = '/route-suggestions';

  // ── CHATBOT
  static const String endpointChatbot = '/chatbot';

  // ── SharedPreferences keys
  static const String keyAuthToken   = 'auth_token';
  static const String keyEmployeeDoc = 'employee_doc';
  static const String keyUserName    = 'user_name';
  static const String keyUserRole    = 'user_role';
  static const String keyDarkMode    = 'dark_mode';
  static const String keyFontScale   = 'font_scale';

  // ── Roles
  static const String roleVendedor      = 'V';
  static const String roleAdministrador = 'A';

  // ── Estados de facturas
  static const String invoicePending   = 'P';
  static const String invoiceConfirmed = 'C';
  static const String invoiceCancelled = 'A';

  // ── Estados de sugerencias de ruta
  static const String suggestionPending  = 'P';
  static const String suggestionApproved = 'A';
  static const String suggestionRejected = 'R';

  // ── Intervalo GPS (segundos)
  static const int locationIntervalSeconds = 30;

  // ── Timeouts HTTP
  static const Duration connectTimeout = Duration(seconds: 15);

  
}