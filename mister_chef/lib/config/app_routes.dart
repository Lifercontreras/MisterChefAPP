class AppRoutes {
  static const String splash        = '/';
  static const String login         = '/login';
  static const String changePassword = '/change-password';
  static const String home          = '/home';

  // ── Pedidos / Facturas
  static const String orders        = '/orders';
  static const String newOrder      = '/orders/new';
  static const String orderDetail   = '/orders/detail';

  // ── Clientes
  static const String customers     = '/customers';
  static const String customerDetail = '/customers/detail';
  static const String createCustomer  = '/customers/new';

  // ── Ruta (vendedor)
  static const String route         = '/route';

  // ── Chatbot (vendedor)
  static const String chatbot       = '/chatbot';

  // ── Admin
  static const String employees     = '/employees';
  static const String products      = '/products';
  static const String reports       = '/reports';
  static const String deliveryMap   = '/delivery-map';

  // ── Configuración
  static const String accessibility = '/accessibility';
  static const String settings      = '/settings';
}