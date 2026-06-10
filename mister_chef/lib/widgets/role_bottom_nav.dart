import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';

class RoleBottomNav extends StatefulWidget {
  final String currentRoute;
  const RoleBottomNav({super.key, required this.currentRoute});

  @override
  State<RoleBottomNav> createState() => _RoleBottomNavState();
}

class _RoleBottomNavState extends State<RoleBottomNav> {
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final data = await AuthService().getUserData();
    if (mounted) setState(() => _role = data['tipo'] ?? '');
  }

  bool get _isAdmin => _role == AppConstants.roleAdministrador;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    final adminNav = [
      {'icon': Icons.home_outlined,              'active': Icons.home,              'label': 'Inicio',    'route': AppRoutes.home},
      {'icon': Icons.receipt_long_outlined,      'active': Icons.receipt_long,      'label': 'Pedidos',   'route': AppRoutes.orders},
      {'icon': Icons.people_outline,             'active': Icons.people,            'label': 'Clientes',  'route': AppRoutes.customers},
      {'icon': Icons.badge_outlined,             'active': Icons.badge,             'label': 'Empleados', 'route': AppRoutes.employees},
      {'icon': Icons.smart_toy_outlined,         'active': Icons.smart_toy,         'label': 'Asistente', 'route': AppRoutes.chatbot},
    ];

    final vendedorNav = [
      {'icon': Icons.home_outlined,              'active': Icons.home,              'label': 'Inicio',   'route': AppRoutes.home},
      {'icon': Icons.receipt_long_outlined,      'active': Icons.receipt_long,      'label': 'Pedidos',  'route': AppRoutes.orders},
      {'icon': Icons.map_outlined,               'active': Icons.map,               'label': 'Ruta',     'route': AppRoutes.route},
      {'icon': Icons.people_outline,             'active': Icons.people,            'label': 'Clientes', 'route': AppRoutes.customers},
      {'icon': Icons.accessibility_new_outlined, 'active': Icons.accessibility_new, 'label': 'Acceso',   'route': AppRoutes.accessibility},
    ];

    final navItems = _isAdmin ? adminNav : vendedorNav;

    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.map((item) {
          final route    = item['route'] as String;
          final isActive = widget.currentRoute == route;

          return GestureDetector(
            onTap: () {
              if (!isActive) {
                if (route == AppRoutes.home) {
                  Navigator.pushReplacementNamed(context, route);
                } else {
                  Navigator.pushNamed(context, route);
                }
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? item['active'] as IconData
                      : item['icon']   as IconData,
                  color: isActive
                      ? AppColors.navIconActive
                      : AppColors.navIconInactive,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppColors.navIconActive
                        : AppColors.navIconInactive,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}