import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../services/employee_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'create_employee_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _employeeService = EmployeeService();
  final _searchCtrl      = TextEditingController();

  List<Map<String, dynamic>> _allEmployees      = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await _employeeService.getEmployees();
      if (mounted) {
        setState(() {
          _allEmployees = data;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((e) {
        final nombre = '${e['name_1'] ?? ''} ${e['last_name_1'] ?? ''}'.toLowerCase();
        final email  = (e['email'] ?? '').toLowerCase();
        return nombre.contains(q) || email.contains(q);
      }).toList();
    });
  }

  String _fullName(Map<String, dynamic> e) {
    final parts = [
      e['name_1']      ?? '',
      e['name_2']      ?? '',
      e['last_name_1'] ?? '',
      e['last_name_2'] ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' ');
  }

  String _initials(Map<String, dynamic> e) {
    final n = (e['name_1']      ?? '').toString();
    final l = (e['last_name_1'] ?? '').toString();
    return '${n.isNotEmpty ? n[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  }

  bool _isActive(Map<String, dynamic> e) =>
      e['status']?.toString().toUpperCase() == 'A';

  bool _isAdmin(Map<String, dynamic> e) =>
      e['type']?.toString() == AppConstants.roleAdministrador;

  Future<void> _toggleStatus(Map<String, dynamic> e) async {
    final isActive  = _isActive(e);
    final newStatus = isActive ? 'I' : 'A';
    final nombre    = _fullName(e);
    final cs        = AppColorScheme.of(context); // ← agregado

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card, // ← cambiado
        title: Text(
          isActive ? 'Desactivar empleado' : 'Activar empleado',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.textPrimary), // ← cambiado
        ),
        content: Text(
          isActive
              ? '¿Desactivar a $nombre? Ya no podrá iniciar sesión.'
              : '¿Activar a $nombre?',
          style: TextStyle(fontSize: 13, color: cs.textSec), // ← cambiado
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: cs.textHint)), // ← cambiado
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isActive ? AppColors.statusError : AppColors.statusSuccess,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _employeeService.changeStatus(
          e['document_employee'].toString(), newStatus);
      _showMsg(isActive
          ? 'Empleado desactivado correctamente'
          : 'Empleado activado correctamente');
      _loadEmployees();
    } on ApiException catch (ex) {
      _showMsg(ex.message, isError: true);
    } catch (_) {
      _showMsg('Error al cambiar el estado', isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Scaffold(
      backgroundColor: cs.background, // ya estaba correcto
      bottomNavigationBar:
          const RoleBottomNav(currentRoute: AppRoutes.employees),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Empleados',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CreateEmployeeScreen()),
                            );
                            _loadEmployees();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('+ Nuevo',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Buscador
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Buscar empleado...',
                          hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.white.withOpacity(0.7), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lista
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined,
                                size: 52,
                                color: cs.textHint.withOpacity(0.4)), // ← cambiado
                            const SizedBox(height: 12),
                            Text('No se encontraron empleados',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: cs.textHint)), // ← cambiado
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadEmployees,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredEmployees.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final e      = _filteredEmployees[i];
                            final nombre = _fullName(e);
                            final email  = e['email'] ?? '';
                            final active = _isActive(e);
                            final admin  = _isAdmin(e);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.card, // ← cambiado
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.border), // ← cambiado
                              ),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? (admin
                                              ? AppColors.primary
                                              : AppColors.roleVendedor)
                                          : AppColors.textHintLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(_initials(e),
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: cs.textPrimary)), // ← cambiado
                                        const SizedBox(height: 2),
                                        Text(email,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: cs.textHint), // ← cambiado
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            width: 6, height: 6,
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? AppColors.statusSuccess
                                                  : AppColors.statusError,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            active ? 'Activo' : 'Inactivo',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: active
                                                    ? AppColors.statusSuccess
                                                    : AppColors.statusError),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),

                                  // Badge rol
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: admin
                                              ? AppColors.primary.withOpacity(
                                                  cs.isDark ? 0.2 : 0.1)        // ← adaptativo
                                              : AppColors.roleVendedor.withOpacity(
                                                  cs.isDark ? 0.2 : 0.1),        // ← adaptativo
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: admin
                                                ? AppColors.primary.withOpacity(0.4)
                                                : AppColors.roleVendedor.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Text(
                                          admin ? 'ADMIN' : 'VEND',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: admin
                                                  ? AppColors.primary          // ← usa primary directo
                                                  : AppColors.roleVendedor),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => _toggleStatus(e),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? AppColors.statusError.withOpacity(
                                                    cs.isDark ? 0.15 : 0.08)    // ← adaptativo
                                                : AppColors.statusSuccess.withOpacity(
                                                    cs.isDark ? 0.15 : 0.08),   // ← adaptativo
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: active
                                                  ? AppColors.statusError.withOpacity(0.35)
                                                  : AppColors.statusSuccess.withOpacity(0.35),
                                            ),
                                          ),
                                          child: Text(
                                            active ? 'Desactivar' : 'Activar',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: active
                                                    ? AppColors.statusError
                                                    : AppColors.statusSuccess),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}