/// Tabla de rutas nombradas de la aplicación Mister Chef.
///
/// Centraliza todos los identificadores de ruta utilizados en [MaterialApp.routes].
/// Usar estas constantes en lugar de cadenas literales evita errores de tipeo
/// y facilita el refactoring cuando cambia la estructura de navegación.
class AppRoutes {
  /// Pantalla de splash — primera pantalla mostrada al abrir la app.
  static const String splash        = '/';

  /// Pantalla de inicio de sesión.
  static const String login         = '/login';

  /// Pantalla de cambio de contraseña (obligatoria en primer inicio de sesión).
  static const String changePassword = '/change-password';

  /// Pantalla principal (dashboard) tras autenticarse.
  static const String home          = '/home';

  // ── PEDIDOS / FACTURAS
  /// Lista de todos los pedidos del usuario autenticado.
  static const String orders        = '/orders';
  /// Formulario para crear un nuevo pedido.
  static const String newOrder      = '/orders/new';
  /// Detalle completo de un pedido existente.
  static const String orderDetail   = '/orders/detail';

  // ── CLIENTES
  /// Lista de clientes asignados al vendedor (o todos, si es admin).
  static const String customers     = '/customers';
  /// Detalle e historial de pedidos de un cliente.
  static const String customerDetail = '/customers/detail';
  /// Formulario para registrar un nuevo cliente.
  static const String createCustomer  = '/customers/new';

  // ── RUTA DEL VENDEDOR
  /// Mapa con las paradas de entrega asignadas al vendedor para el día.
  static const String route         = '/route';

  // ── ASISTENTE VIRTUAL
  /// Pantalla de chat con el chatbot de inteligencia artificial.
  static const String chatbot       = '/chatbot';

  // ── MÓDULO DE ADMINISTRADOR
  /// Gestión del personal (empleados activos e inactivos).
  static const String employees     = '/employees';
  /// Gestión del inventario de productos.
  static const String products      = '/products';
  /// Reportes y métricas de ventas (pendiente de implementar).
  static const String reports       = '/reports';
  /// Mapa en tiempo real con la ubicación de los vendedores activos.
  static const String deliveryMap   = '/delivery-map';
  /// Gestión y distribución de rutas entre vendedores (solo admin).
  static const String routeAdmin    = '/route-admin';

  // ── CONFIGURACIÓN Y ACCESIBILIDAD
  /// Pantalla de opciones de accesibilidad (fuente, contraste, tamaño).
  static const String accessibility = '/accessibility';
  /// Pantalla de configuración general de la aplicación.
  static const String settings      = '/settings';
}