import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/route_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'route_distribution_preview_screen.dart';

/// Pantalla de gestión de rutas para el administrador.
///
/// Muestra las rutas activas y permite abrir la vista previa de la
/// redistribución total de clientes entre vendedores.
class RouteAdminScreen extends StatefulWidget {
  const RouteAdminScreen({super.key});

  @override
  State<RouteAdminScreen> createState() => _RouteAdminScreenState();
}

class _RouteAdminScreenState extends State<RouteAdminScreen> {
  final _routeService = RouteService();

  List<Map<String, dynamic>> _rutas = [];
  bool _loadingRutas = true;

  @override
  void initState() {
    super.initState();
    _loadRutas();
  }

  Future<void> _loadRutas() async {
    if (!mounted) return;
    setState(() => _loadingRutas = true);
    try {
      final rutas = await _routeService.getRoutes();
      if (mounted) {
        setState(() {
          _rutas = rutas;
          _loadingRutas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRutas = false);
    }
  }

  Future<void> _abrirDistribucion() async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RouteDistributionPreviewScreen(),
      ),
    );
    if (applied == true) await _loadRutas();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(
        currentRoute: AppRoutes.routeAdmin,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirDistribucion,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Distribuir clientes'),
      ),
      body: Column(
        children: [
          // ── AppBar
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Gestión de rutas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido
          Expanded(child: _buildRutasTab(cs)),
        ],
      ),
    );
  }

  Widget _buildRutasTab(AppColorScheme cs) {
    if (_loadingRutas) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_rutas.isEmpty) {
      return _emptyState(
        icon: Icons.map_outlined,
        title: 'No hay rutas asignadas',
        subtitle:
            'Usa "Distribuir clientes" para repartir los clientes entre los '
            'vendedores activos',
        cs: cs,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadRutas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
        itemCount: _rutas.length,
        itemBuilder: (_, i) => _buildRutaCard(_rutas[i], cs),
      ),
    );
  }

  Widget _buildRutaCard(Map<String, dynamic> ruta, AppColorScheme cs) {
    final nombre = ruta['employee_name'] ?? 'Vendedor';
    final total = ruta['total_clients'] ?? 0;
    final clients = List<Map<String, dynamic>>.from(ruta['clients'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        children: [
          // Cabecera vendedor
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'V',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.textPrimary,
                        ),
                      ),
                      Text(
                        '$total cliente${total != 1 ? 's' : ''} '
                        'asignado${total != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, color: cs.textHint),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusSuccess.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total paradas',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.statusSuccess,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de clientes
          if (clients.isNotEmpty) ...[
            Divider(height: 1, color: cs.border),
            ...clients.map((c) {
              final empresa = c['business_name'] ?? '';
              final nombre2 = '${c['name'] ?? ''}'.trim();
              final display = empresa.isNotEmpty ? empresa : nombre2;
              final address = c['address'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.textPrimary,
                            ),
                          ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.textHint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppColorScheme cs,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
