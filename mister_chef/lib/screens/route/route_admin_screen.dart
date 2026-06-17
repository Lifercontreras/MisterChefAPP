import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/route_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/role_bottom_nav.dart';

/// Pantalla de gestión de rutas para el administrador.
///
/// Permite:
/// - Distribuir automáticamente los clientes sin ruta entre vendedores activos.
/// - Ver y gestionar las sugerencias de cambio de ruta pendientes.
/// - Aprobar o rechazar cada sugerencia.
class RouteAdminScreen extends StatefulWidget {
  const RouteAdminScreen({super.key});

  @override
  State<RouteAdminScreen> createState() => _RouteAdminScreenState();
}

class _RouteAdminScreenState extends State<RouteAdminScreen>
    with SingleTickerProviderStateMixin {
  final _routeService    = RouteService();
  final _employeeService = EmployeeService();

  late TabController _tabController;

  List<Map<String, dynamic>> _sugerencias    = [];
  List<Map<String, dynamic>> _rutas          = [];
  List<Map<String, dynamic>> _vendedores     = [];

  bool _loadingSugerencias = true;
  bool _loadingRutas       = true;
  bool _distribuyendo      = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSugerencias(), _loadRutas()]);
  }

  Future<void> _loadSugerencias() async {
    setState(() => _loadingSugerencias = true);
    try {
      final data = await _routeService.getRouteSuggestions();
      if (mounted) setState(() { _sugerencias = data; _loadingSugerencias = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSugerencias = false);
    }
  }

  Future<void> _loadRutas() async {
    setState(() => _loadingRutas = true);
    try {
      final rutas     = await _routeService.getRoutes();
      final vendedores = await _employeeService.getEmployees();
      if (mounted) {
        setState(() {
          _rutas      = rutas;
          _vendedores = vendedores.where((e) => e['type'] == 'V').toList();
          _loadingRutas = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRutas = false);
    }
  }

  Future<void> _distribuir() async {
    setState(() => _distribuyendo = true);
    try {
      final res = await _routeService.distributeRoutes();
      final total = res['total'] ?? 0;
      _showMsg('$total sugerencias generadas. Revísalas en la pestaña de sugerencias.');
      _tabController.animateTo(1);
      await _loadSugerencias();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _distribuyendo = false);
    }
  }

  Future<void> _aprobar(String id) async {
    try {
      await _routeService.approveSuggestion(id);
      _showMsg('Sugerencia aprobada. Cliente asignado a la ruta.');
      await _loadSugerencias();
      await _loadRutas();
    } catch (e) {
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _rechazar(String id, String documentEmployee) async {
    // Muestra un diálogo para elegir otro vendedor
    final vendedoresFiltrados = _vendedores
        .where((v) => v['document_employee'] != documentEmployee)
        .toList();

    if (vendedoresFiltrados.isEmpty) {
      _showMsg('No hay otros vendedores disponibles.', isError: true);
      return;
    }

    String? selectedDoc = vendedoresFiltrados.first['document_employee'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Rechazar y reasignar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selecciona el vendedor al que deseas asignar el cliente:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDoc,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                items: vendedoresFiltrados.map((v) {
                  final nombre = '${v['name_1']} ${v['last_name_1']}';
                  return DropdownMenuItem(
                    value: v['document_employee'] as String,
                    child: Text(nombre, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) => setStateDialog(() => selectedDoc = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedDoc != null) {
      try {
        await _routeService.rejectSuggestion(id, selectedDoc!);
        _showMsg('Sugerencia rechazada. Cliente reasignado correctamente.');
        await _loadSugerencias();
        await _loadRutas();
      } catch (e) {
        _showMsg(e.toString(), isError: true);
      }
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _employeeName(Map<String, dynamic> v) =>
      '${v['name_1'] ?? ''} ${v['last_name_1'] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.routeAdmin),
      body: Column(
        children: [
          // ── AppBar
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Gestión de rutas',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                        ),
                        // Botón distribuir
                        _distribuyendo
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : GestureDetector(
                                onTap: _distribuir,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Distribuir',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: [
                      const Tab(text: 'Rutas activas'),
                      Tab(text: 'Sugerencias'
                          '${_sugerencias.where((s) => s['status'] == 'P').isNotEmpty ? ' (${_sugerencias.where((s) => s['status'] == 'P').length})' : ''}'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRutasTab(cs),
                _buildSugerenciasTab(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: Rutas activas ────────────────────────────────────────────────

  Widget _buildRutasTab(AppColorScheme cs) {
    if (_loadingRutas) {
      return const Center(child: CircularProgressIndicator(
          color: AppColors.primary));
    }

    if (_rutas.isEmpty) {
      return _emptyState(
        icon: Icons.map_outlined,
        title: 'No hay rutas asignadas',
        subtitle: 'Usa "Distribuir" para asignar clientes a los vendedores',
        cs: cs,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadRutas,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _rutas.length,
        itemBuilder: (_, i) => _buildRutaCard(_rutas[i], cs),
      ),
    );
  }

  Widget _buildRutaCard(Map<String, dynamic> ruta, AppColorScheme cs) {
    final nombre   = ruta['employee_name'] ?? 'Vendedor';
    final total    = ruta['total_clients'] ?? 0;
    final clients  = List<Map<String, dynamic>>.from(ruta['clients'] ?? []);

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
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'V',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.textPrimary)),
                      Text('$total cliente${total != 1 ? 's' : ''} asignado${total != 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 11, color: cs.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusSuccess.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$total paradas',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.statusSuccess,
                          fontWeight: FontWeight.w500)),
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
                    horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(display,
                              style: TextStyle(fontSize: 12,
                                  color: cs.textPrimary)),
                          if (address.isNotEmpty)
                            Text(address,
                                style: TextStyle(
                                    fontSize: 10, color: cs.textHint)),
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

  // ── TAB 2: Sugerencias ──────────────────────────────────────────────────

  Widget _buildSugerenciasTab(AppColorScheme cs) {
    if (_loadingSugerencias) {
      return const Center(child: CircularProgressIndicator(
          color: AppColors.primary));
    }

    final pendientes = _sugerencias
        .where((s) => s['status'] == 'P')
        .toList();

    if (pendientes.isEmpty) {
      return _emptyState(
        icon: Icons.check_circle_outline,
        title: 'Sin sugerencias pendientes',
        subtitle: 'Todas las sugerencias han sido procesadas',
        cs: cs,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadSugerencias,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: pendientes.length,
        itemBuilder: (_, i) => _buildSugerenciaCard(pendientes[i], cs),
      ),
    );
  }

  Widget _buildSugerenciaCard(Map<String, dynamic> s, AppColorScheme cs) {
    final id           = s['id_suggestion']?.toString() ?? '';
    final client       = s['client']   as Map<String, dynamic>? ?? {};
    final employee     = s['employee'] as Map<String, dynamic>? ?? {};
    final distancia    = s['distance_km'];

    final empresa  = client['business_name'] ?? '';
    final nombre   = '${client['client_name1'] ?? ''} ${client['client_last_name1'] ?? ''}'.trim();
    final clientDisplay = empresa.isNotEmpty ? empresa : nombre;
    final address  = client['address'] ?? '';

    final empNombre = '${employee['name_1'] ?? ''} ${employee['last_name_1'] ?? ''}'.trim();
    final empDoc    = employee['document_employee']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente
          Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientDisplay,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.textPrimary)),
                    if (address.isNotEmpty)
                      Text(address,
                          style: TextStyle(fontSize: 11, color: cs.textHint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Vendedor sugerido
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Sugerido: $empNombre',
                    style: TextStyle(fontSize: 12, color: cs.textPrimary)),
              ),
              if (distancia != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.border),
                  ),
                  child: Text('${double.tryParse(distancia.toString())?.toStringAsFixed(1) ?? distancia} km',
                      style: TextStyle(fontSize: 10, color: cs.textHint)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rechazar(id, empDoc),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusError,
                    side: const BorderSide(color: AppColors.statusError),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _aprobar(id),
                  icon: const Icon(Icons.check, size: 14, color: Colors.white),
                  label: const Text('Aprobar',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusSuccess,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.textHint.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w500, color: cs.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.textHint)),
        ],
      ),
    );
  }
}