import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/employee_service.dart';
import '../../services/api_service.dart';
import 'create_employee_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeDoc;
  final String employeeName;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeDoc,
    required this.employeeName,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _employeeService = EmployeeService();

  Map<String, dynamic>? _employee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _employeeService.getEmployeeById(widget.employeeDoc);
      if (mounted) setState(() { _employee = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _initials {
    final parts = widget.employeeName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get _isActive =>
      _employee?['status']?.toString().toUpperCase() == 'A';

  bool get _isAdmin =>
      _employee?['type']?.toString() == AppConstants.roleAdministrador;

  Future<void> _toggleStatus() async {
    final newStatus = _isActive ? 'I' : 'A';
    final cs = AppColorScheme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _isActive ? 'Desactivar empleado' : 'Activar empleado',
          style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.w500, color: cs.textPrimary),
        ),
        content: Text(
          _isActive
              ? '¿Desactivar a ${widget.employeeName}? Ya no podrá iniciar sesión.'
              : '¿Activar a ${widget.employeeName}?',
          style: TextStyle(fontSize: 13, color: cs.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: cs.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isActive
                  ? AppColors.statusError
                  : AppColors.statusSuccess,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(_isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _employeeService.changeStatus(widget.employeeDoc, newStatus);
      _showMsg(_isActive
          ? 'Empleado desactivado correctamente'
          : 'Empleado activado correctamente');
      await _loadData();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
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
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildHeader(cs),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStats(cs),
                          const SizedBox(height: 14),
                          _buildSectionLabel('Información de contacto', cs),
                          const SizedBox(height: 8),
                          _buildInfoCard(cs),
                          const SizedBox(height: 14),
                          _buildSectionLabel('Rol y permisos', cs),
                          const SizedBox(height: 8),
                          _buildRoleCard(cs),
                          const SizedBox(height: 14),
                          _buildActions(cs),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(AppColorScheme cs) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -40,
              child: Container(
                width: 140, height: 140,
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fila superior: volver + título + editar
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Detalle del empleado',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                      // ── Botón editar
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateEmployeeScreen(
                                  employee: _employee),
                            ),
                          );
                          if (result == true) _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text('Editar',
                                  style: TextStyle(fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Avatar + info
                  Row(
                    children: [
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          color: _isAdmin
                              ? AppColors.primary
                              : AppColors.roleVendedor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 3),
                        ),
                        child: Center(
                          child: Text(_initials,
                              style: const TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.employeeName,
                                style: const TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(
                              _isAdmin ? 'Administrador' : 'Vendedor',
                              style: TextStyle(fontSize: 11,
                                  color: Colors.white.withOpacity(0.7)),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: _isActive
                                        ? const Color(0xFFA5D6A7)
                                        : const Color(0xFFEF9A9A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isActive
                                      ? 'Empleado activo'
                                      : 'Empleado inactivo',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AppColorScheme cs) {
    final commission =
        _employee?['commission_percentage']?.toString() ?? '0';
    final hireDate = _employee?['hire_date']?.toString();
    String hireDateLabel = 'N/A';
    if (hireDate != null) {
      final dt = DateTime.tryParse(hireDate);
      if (dt != null) {
        hireDateLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      }
    }

    final stats = [
      {'num': '$commission%', 'lbl': 'Comisión'},
      {'num': hireDateLabel,  'lbl': 'Fecha ingreso'},
      {'num': _isAdmin ? 'Admin' : 'Vendedor', 'lbl': 'Rol'},
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: cs.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.border),
            ),
            child: Column(
              children: [
                Text(s['num']!,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary)),
                const SizedBox(height: 3),
                Text(s['lbl']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: cs.textHint)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard(AppColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.badge_outlined,
              label: 'Documento',
              value: _employee?['document_employee']?.toString() ?? '—',
              cs: cs),
          Divider(height: 1, color: cs.divider),
          _InfoRow(icon: Icons.email_outlined,
              label: 'Correo',
              value: _employee?['email'] ?? 'No registrado',
              cs: cs),
          Divider(height: 1, color: cs.divider),
          _InfoRow(icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: _employee?['phone_number']?.toString() ?? 'No registrado',
              cs: cs),
        ],
      ),
    );
  }

  Widget _buildRoleCard(AppColorScheme cs) {
    final canModify =
        _employee?['can_modify_invoice']?.toString() == 'S';

    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        children: [
          _InfoRow(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Tipo',
              value: _isAdmin ? 'Administrador' : 'Vendedor',
              cs: cs),
          Divider(height: 1, color: cs.divider),
          _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Puede anular facturas',
              value: canModify ? 'Sí' : 'No',
              cs: cs,
              valueColor: canModify
                  ? AppColors.statusSuccess
                  : AppColors.statusError),
        ],
      ),
    );
  }

  Widget _buildActions(AppColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: _isActive
                ? Icons.toggle_off_outlined
                : Icons.toggle_on_outlined,
            label: _isActive ? 'Desactivar' : 'Activar',
            color: _isActive ? AppColors.statusError : AppColors.statusSuccess,
            bgColor: _isActive
                ? AppColors.statusError.withOpacity(cs.isDark ? 0.15 : 0.08)
                : AppColors.statusSuccess.withOpacity(cs.isDark ? 0.15 : 0.08),
            onTap: _toggleStatus,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, AppColorScheme cs) =>
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: cs.textSec, letterSpacing: 1.2));
}

// ════════════════════════════════════════════
// WIDGETS INTERNOS
// ════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final AppColorScheme cs;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(cs.isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: cs.textHint)),
                Text(value,
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? cs.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}