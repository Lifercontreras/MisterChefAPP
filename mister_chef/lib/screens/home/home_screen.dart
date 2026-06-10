import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService  = AuthService();
  final _orderService = OrderService();

  String _userName     = '';
  String _userRole     = '';
  String _userInitials = '';

  int    _pedidosHoy        = 0;
  double _ventasHoy         = 0;
  int    _clientesVisitados = 0;

  List<Map<String, dynamic>> _ultimosPedidos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _authService.getUserData();
      final nombre   = userData['nombre'] ?? '';
      final tipo     = userData['tipo']   ?? '';

      Map<String, dynamic> stats = {};
      List<Map<String, dynamic>> pedidos = [];
      try {
        stats   = await _orderService.getTodayStats();
        pedidos = await _orderService.getInvoices();
        pedidos = pedidos.take(5).toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userName          = nombre;
          _userRole          = tipo;
          _userInitials      = _getInitials(nombre);
          _pedidosHoy        = stats['total_pedidos']      ?? 0;
          _ventasHoy         = (stats['total_ventas']      ?? 0).toDouble();
          _clientesVisitados = stats['clientes_visitados'] ?? 0;
          _ultimosPedidos    = pedidos;
          _isLoading         = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isAdmin    => _userRole == AppConstants.roleAdministrador;
  bool get _isVendedor => _userRole == AppConstants.roleVendedor;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'MC';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatRoleLabel() {
    switch (_userRole) {
      case AppConstants.roleAdministrador: return 'Administrador';
      case AppConstants.roleVendedor:      return 'Vendedor';
      default: return '';
    }
  }

  String _formatMoneda(double valor) {
    if (valor >= 1000000) return '\$${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000)    return '\$${(valor / 1000).toStringAsFixed(0)}K';
    return '\$${valor.toStringAsFixed(0)}';
  }

  String _formatTiempo(String? fecha) {
    if (fecha == null) return '';
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays}d';
  }

  String _clientName(Map<String, dynamic> invoice) {
    final c = invoice['client'];
    if (c == null) return 'Cliente desconocido';
    final empresa  = c['business_name']     ?? '';
    final nombre   = c['client_name1']      ?? '';
    final apellido = c['client_last_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : '$nombre $apellido'.trim();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case AppConstants.invoiceConfirmed: return AppColors.statusSuccess;
      case AppConstants.invoiceCancelled: return AppColors.statusError;
      default:                            return AppColors.statusWarning;
    }
  }

  Future<void> _cerrarSesion() async {
    await _authService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildStatsGrid(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.background,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(
                        color: AppColors.primary))
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel(cs),
                              const SizedBox(height: 10),
                              _buildMenuGrid(cs),
                              const SizedBox(height: 20),
                              _sectionLabelText('Últimos pedidos', cs),
                              const SizedBox(height: 10),
                              _buildRecentOrders(cs),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            _buildBottomNav(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Stack(
      children: [
        Positioned(top: -40, right: -30,
          child: Container(width: 120, height: 120,
            decoration: const BoxDecoration(
                color: AppColors.primaryDark, shape: BoxShape.circle)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${_userName.split(' ').firstWhere((e) => e.isNotEmpty, orElse: () => 'usuario')}! 👋',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                  Row(
                    children: [
                      Text(_formatRoleLabel(),
                          style: TextStyle(fontSize: 11,
                              color: Colors.white.withOpacity(0.65))),
                      if (_userRole.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isAdmin
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.accent.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _isAdmin ? 'ADMIN' : 'VENDEDOR',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: _isAdmin ? Colors.white : AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (v) { if (v == 'logout') _cerrarSesion(); },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Cerrar sesión'),
                    ]),
                  ),
                ],
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      _userInitials.isEmpty ? 'MC' : _userInitials,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = _isAdmin
        ? [
            {'num': '$_pedidosHoy',           'lbl': 'Pedidos totales'},
            {'num': _formatMoneda(_ventasHoy), 'lbl': 'Ventas totales'},
            {'num': '$_clientesVisitados',     'lbl': 'Confirmados'},
            {'num': '—',                       'lbl': 'Empleados'},
          ]
        : [
            {'num': '$_pedidosHoy',           'lbl': 'Pedidos hoy'},
            {'num': _formatMoneda(_ventasHoy), 'lbl': 'Ventas del día'},
            {'num': '$_clientesVisitados',     'lbl': 'Confirmados'},
            {'num': '—',                       'lbl': 'Paradas'},
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4,
        ),
        itemBuilder: (_, i) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(stats[i]['num']!,
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w500, color: Colors.white)),
              Text(stats[i]['lbl']!,
                  style: TextStyle(fontSize: 10,
                      color: Colors.white.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(AppColorScheme cs) =>
      _sectionLabelText('Acciones rápidas', cs);

  Widget _sectionLabelText(String label, AppColorScheme cs) =>
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: cs.textSec, letterSpacing: 1.2));

  Widget _buildMenuGrid(AppColorScheme cs) {
    final adminItems = [
      {'icon': Icons.receipt_long_outlined, 'title': 'Pedidos',      'desc': 'Ver facturas',          'route': AppRoutes.orders},
      {'icon': Icons.people_outline,        'title': 'Clientes',     'desc': 'Directorio',            'route': AppRoutes.customers},
      {'icon': Icons.badge_outlined,        'title': 'Empleados',    'desc': 'Gestión de personal',   'route': AppRoutes.employees},
      {'icon': Icons.inventory_2_outlined,  'title': 'Productos',    'desc': 'Inventario',            'route': AppRoutes.products},
      {'icon': Icons.map_outlined,          'title': 'Mapa en vivo', 'desc': 'Domiciliarios activos', 'route': AppRoutes.deliveryMap},
      {'icon': Icons.smart_toy_outlined,    'title': 'Asistente',    'desc': 'Chatbot IA',            'route': AppRoutes.chatbot},
    ];

    final vendedorItems = [
      {'icon': Icons.receipt_long_outlined, 'title': 'Nuevo pedido', 'desc': 'Registrar venta', 'route': AppRoutes.newOrder},
      {'icon': Icons.map_outlined,          'title': 'Mi ruta',      'desc': 'Ver en mapa',     'route': AppRoutes.route},
      {'icon': Icons.people_outline,        'title': 'Clientes',     'desc': 'Directorio',      'route': AppRoutes.customers},
      {'icon': Icons.smart_toy_outlined,    'title': 'Asistente',    'desc': 'Chatbot IA',      'route': AppRoutes.chatbot},
    ];

    final items = _isAdmin ? adminItems : vendedorItems;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
      ),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => Navigator.pushNamed(context, items[i]['route'] as String),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(items[i]['icon'] as IconData,
                  color: AppColors.primary, size: 26),
              const SizedBox(height: 8),
              Text(items[i]['title'] as String,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.textPrimary)),
              Text(items[i]['desc'] as String,
                  style: TextStyle(fontSize: 10, color: cs.textHint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders(AppColorScheme cs) {
    if (_ultimosPedidos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text('No hay pedidos registrados hoy',
            style: TextStyle(fontSize: 13, color: cs.textHint)),
      );
    }
    return Column(
      children: _ultimosPedidos.map((inv) {
        final total  = (inv['total'] ?? 0).toDouble();
        final status = inv['status'] ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.border),
          ),
          child: Row(
            children: [
              Container(width: 9, height: 9,
                  decoration: BoxDecoration(
                      color: _statusColor(status), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clientName(inv),
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.textPrimary)),
                    Text(_formatTiempo(inv['date']?.toString()),
                        style: TextStyle(fontSize: 10, color: cs.textHint)),
                  ],
                ),
              ),
              Text(_formatMoneda(total),
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNav(AppColorScheme cs) {
    final adminNav = [
      {'icon': Icons.home_outlined,              'active': Icons.home,              'label': 'Inicio',    'route': AppRoutes.home},
      {'icon': Icons.receipt_long_outlined,      'active': Icons.receipt_long,      'label': 'Pedidos',   'route': AppRoutes.orders},
      {'icon': Icons.people_outline,             'active': Icons.people,            'label': 'Clientes',  'route': AppRoutes.customers},
      {'icon': Icons.badge_outlined,             'active': Icons.badge,             'label': 'Empleados', 'route': AppRoutes.employees},
      {'icon': Icons.accessibility_new_outlined, 'active': Icons.accessibility_new, 'label': 'Acceso',   'route': AppRoutes.accessibility},
    ];

    final vendedorNav = [
      {'icon': Icons.home_outlined,              'active': Icons.home,              'label': 'Inicio',  'route': AppRoutes.home},
      {'icon': Icons.receipt_long_outlined,      'active': Icons.receipt_long,      'label': 'Pedidos', 'route': AppRoutes.orders},
      {'icon': Icons.map_outlined,               'active': Icons.map,               'label': 'Ruta',    'route': AppRoutes.route},
      {'icon': Icons.people_outline,             'active': Icons.people,            'label': 'Clientes','route': AppRoutes.customers},
      {'icon': Icons.accessibility_new_outlined, 'active': Icons.accessibility_new, 'label': 'Acceso', 'route': AppRoutes.accessibility},
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
        children: List.generate(navItems.length, (i) {
          final isActive = i == 0;
          return GestureDetector(
            onTap: () {
              if (i != 0) {
                Navigator.pushNamed(context, navItems[i]['route'] as String);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? navItems[i]['active'] as IconData
                      : navItems[i]['icon']   as IconData,
                  color: isActive
                      ? AppColors.navIconActive
                      : AppColors.navIconInactive,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(navItems[i]['label'] as String,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? AppColors.navIconActive
                            : AppColors.navIconInactive)),
              ],
            ),
          );
        }),
      ),
    );
  }
}