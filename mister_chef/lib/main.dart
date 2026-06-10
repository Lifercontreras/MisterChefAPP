import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'providers/accessibility_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/accessibility_screen.dart';
import 'screens/orders/orders_screen.dart';
import 'screens/orders/new_order_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/route/route_screen.dart';
import 'screens/customers/customers_screen.dart';
import 'screens/customers/customer_detail_screen.dart';
import 'screens/admin/employees_screen.dart';
import 'screens/admin/create_employee_screen.dart';
import 'screens/customers/create_customer_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/admin/products_screen.dart';
import 'screens/admin/create_product_screen.dart';
import 'screens/admin/delivery_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final accessibility = AccessibilityProvider();
  await accessibility.loadPreferences();

  runApp(
    ChangeNotifierProvider.value(
      value: accessibility,
      child: const MisterChefApp(),
    ),
  );
}

class MisterChefApp extends StatelessWidget {
  const MisterChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityProvider>();

    return MaterialApp(
      title: 'Mister Chef',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme(dyslexiaFont: accessibility.dyslexiaFont), 
      darkTheme: AppTheme.darkTheme(dyslexiaFont: accessibility.dyslexiaFont),  
      themeMode: accessibility.themeMode,
      initialRoute: AppRoutes.splash,

      // ── builder aplica fontScale y saturación a TODA la app
      builder: (context, child) {
        final accessibility = context.watch<AccessibilityProvider>();
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(accessibility.saturationMatrix),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(accessibility.fontScale),
            ),
            child: child!,
          ),
        );
      },

      routes: {
        AppRoutes.splash        : (_) => const SplashScreen(),
        AppRoutes.login         : (_) => const LoginScreen(),
        AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
        AppRoutes.home          : (_) => const HomeScreen(),
        AppRoutes.orders        : (_) => const OrdersScreen(),
        AppRoutes.newOrder      : (_) => const NewOrderScreen(),
        AppRoutes.route         : (_) => const RouteScreen(),
        AppRoutes.customers     : (_) => const CustomersScreen(),
        AppRoutes.createCustomer: (_) => const CreateCustomerScreen(),
        AppRoutes.accessibility : (_) => const AccessibilityScreen(),
        AppRoutes.employees     : (_) => const EmployeesScreen(),
        AppRoutes.chatbot       : (_) => const ChatbotScreen(),
        AppRoutes.products      : (_) => const ProductsScreen(),
        AppRoutes.deliveryMap   : (_) => const DeliveryMapScreen(),
      },
    );
  }
}