import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'config/constants.dart';
import 'providers/accessibility_provider.dart';
import 'services/api_service.dart';
import 'services/tracking_service.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/accessibility_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/orders/new_order_screen.dart';
import 'screens/route/route_screen.dart';
import 'screens/route/route_admin_screen.dart';
import 'screens/customers/customers_screen.dart';
import 'screens/customers/create_customer_screen.dart';
import 'screens/admin/employees_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/admin/products_screen.dart';
import 'screens/admin/delivery_map_screen.dart';

/// Clave global del navegador.
///
/// Permite navegar desde fuera del árbol de widgets, por ejemplo cuando
/// [ApiService] detecta que la sesión expiró.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Clave global del mensajero de SnackBars.
///
/// Se usa para mostrar el aviso de sesión expirada incluso después de
/// reemplazar por completo el historial de navegación.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Punto de entrada principal de la aplicación Mister Chef.
///
/// Inicializa las preferencias de accesibilidad antes de lanzar la UI,
/// garantizando que el tema (claro/oscuro), la fuente y la escala de texto
/// se apliquen desde el primer frame.
Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos antes de operaciones async.
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquea la app en vertical, incluso si el dispositivo está en horizontal.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Sin URL base configurada la app no puede hablar con el back:
  // se muestra una pantalla de ayuda en lugar de arrancar rota.
  if (AppConstants.apiBaseUrl.isEmpty) {
    runApp(const _MissingApiBaseUrlApp());
    return;
  }

  // Reacción global ante un 401 en cualquier petición autenticada.
  ApiService.onUnauthorized = _handleSessionExpired;

  // Carga preferencias de accesibilidad guardadas por el usuario.
  final accessibility = AccessibilityProvider();
  await accessibility.loadPreferences();

  runApp(
    // Provee el estado de accesibilidad a todo el árbol de widgets.
    ChangeNotifierProvider.value(
      value: accessibility,
      child: const MisterChefApp(),
    ),
  );
}

/// Limpia el historial y lleva al login cuando el token dejó de ser válido.
///
/// [ApiService] ya limpió la sesión antes de invocar este callback y garantiza
/// que se ejecute una sola vez. El SnackBar se muestra sobre el login.
void _handleSessionExpired() {
  // La sesión ya no es válida: se detiene el rastreo de ubicación.
  unawaited(TrackingService().stop());

  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión de nuevo.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  });
}

/// Widget raíz de la aplicación.
///
/// Configura el [MaterialApp] con:
/// - Temas claro/oscuro dinámicos según preferencias del usuario.
/// - Fuente especial para dislexia (Lexend) si está activada.
/// - Escala de texto accesible mediante [TextScaler].
/// - Filtro de saturación de colores para diferentes necesidades visuales.
/// - Tabla de rutas nombradas para navegación entre pantallas.
class MisterChefApp extends StatelessWidget {
  const MisterChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityProvider>();

    return MaterialApp(
      title: 'Mister Chef',
      debugShowCheckedModeBanner: false,

      // Permiten navegar y mostrar avisos desde ApiService (401 global).
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,

      // Tema claro con soporte opcional de fuente para dislexia.
      theme: AppTheme.lightTheme(dyslexiaFont: accessibility.dyslexiaFont),
      // Tema oscuro con soporte opcional de fuente para dislexia.
      darkTheme: AppTheme.darkTheme(dyslexiaFont: accessibility.dyslexiaFont),
      // Alterna entre tema claro y oscuro según la preferencia guardada.
      themeMode: accessibility.themeMode,

      // Pantalla inicial: splash de carga.
      initialRoute: AppRoutes.splash,

      // Aplica filtro de saturación y escala de fuente a TODA la aplicación.
      builder: (context, child) {
        final accessibility = context.watch<AccessibilityProvider>();
        return ColorFiltered(
          // Matriz de color para ajustar saturación (normal, alta, baja, gris).
          colorFilter: ColorFilter.matrix(accessibility.saturationMatrix),
          child: MediaQuery(
            // Escala el texto globalmente según la preferencia del usuario.
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(accessibility.fontScale)),
            child: child!,
          ),
        );
      },

      // Registro de todas las rutas nombradas de la aplicación.
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.orders: (_) => const OrdersScreen(),
        AppRoutes.newOrder: (_) => const NewOrderScreen(),
        AppRoutes.route: (_) => const RouteScreen(),
        AppRoutes.routeAdmin: (_) => const RouteAdminScreen(),
        AppRoutes.customers: (_) => const CustomersScreen(),
        AppRoutes.createCustomer: (_) => const CreateCustomerScreen(),
        AppRoutes.accessibility: (_) => const AccessibilityScreen(),
        AppRoutes.employees: (_) => const EmployeesScreen(),
        AppRoutes.chatbot: (_) => const ChatbotScreen(),
        AppRoutes.products: (_) => const ProductsScreen(),
        AppRoutes.deliveryMap: (_) => const DeliveryMapScreen(),
      },
    );
  }
}

/// Pantalla mínima que se muestra cuando falta `API_BASE_URL`.
///
/// Evita que la app arranque con una URL vacía y falle de forma confusa.
class _MissingApiBaseUrlApp extends StatelessWidget {
  const _MissingApiBaseUrlApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Falta API_BASE_URL. Compila con '
                '--dart-define-from-file=env/prod.json',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
