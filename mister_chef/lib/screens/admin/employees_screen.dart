import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../services/employee_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'create_employee_screen.dart';
import 'employee_detail_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _employeeService = EmployeeService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allEmployees = [];
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
        final nombre =
            '${e['name_1'] ?? ''} ${e['last_name_1'] ?? ''}'.toLowerCase();
        final email = (e['email'] ?? '').toLowerCase();
        return nombre.contains(q) || email.contains(q);
      }).toList();
    });
  }

  String _fullName(Map<String, dynamic> e) {
    final parts = [
      e['name_1'] ?? '',
      e['name_2'] ?? '',
      e['last_name_1'] ?? '',
      e['last_name_2'] ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(' ');
  }

  String _initials(Map<String, dynamic> e) {
    final n = (e['name_1'] ?? '').toString();
    final l = (e['last_name_1'] ?? '').toString();
    return '${n.isNotEmpty ? n[0] : ''}${l.isNotEmpty ? l[0] : ''}'
        .toUpperCase();
  }

  bool _isActive(Map<String, dynamic> e) =>
      e['status']?.toString().toUpperCase() == 'A';

  bool _isAdmin(Map<String, dynamic> e) =>
      e['type']?.toString() == AppConstants.roleAdministrador;

  Future<void> _toggleStatus(Map<String, dynamic> e) async {
    final isActive = _isActive(e);
    final newStatus = isActive ? 'I' : 'A';
    final nombre = _fullName(e);
    final cs = AppColorScheme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card,
        title: Text(
          isActive ? 'Desactivar empleado' : 'Activar empleado',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.textPrimary),
        ),
        content: Text(
          isActive
              ? '¿Desactivar a $nombre? Ya no podrá iniciar sesión.'
              : '¿Activar a $nombre?',
          style: TextStyle(fontSize: 13, color: cs.textSec),
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: cs.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? AppColors.statusError
                  : AppColors.statusSuccess,
              foregroundColor: Colors.white,
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar:
          const RoleBottomNav(currentRoute: AppRoutes.employees),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateEmployeeScreen()),
          );
          _loadEmployees();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          /// APPBAR
          Container(
            color: AppColors.primary,
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Empleados',
                        style: TextStyle(color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Buscar...',
                        filled: true,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          /// LISTA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filteredEmployees.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e      = _filteredEmployees[i];
                      final nombre = _fullName(e);
                      final email  = e['email'] ?? '';
                      final active = _isActive(e);
                      final admin  = _isAdmin(e);

                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmployeeDetailScreen(
                                employeeDoc:  e['document_employee'].toString(),
                                employeeName: nombre,
                              ),
                            ),
                          );
                          if (result == true) _loadEmployees();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.border),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: active
                                      ? (admin ? AppColors.primary : AppColors.roleVendedor)
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
                                        style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: cs.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(email,
                                        style: TextStyle(fontSize: 10, color: cs.textHint),
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

                              // Badge rol + chevron
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: admin
                                          ? AppColors.primary.withOpacity(cs.isDark ? 0.2 : 0.1)
                                          : AppColors.roleVendedor.withOpacity(cs.isDark ? 0.2 : 0.1),
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
                                              ? AppColors.primary
                                              : AppColors.roleVendedor),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Icon(Icons.chevron_right, color: cs.border, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}