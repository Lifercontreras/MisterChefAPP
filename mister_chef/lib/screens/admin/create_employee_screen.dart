import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/employee_service.dart';
import '../../services/api_service.dart';

class CreateEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic>? employee; // ← null = crear, not null = editar

  const CreateEmployeeScreen({super.key, this.employee});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _employeeService = EmployeeService();

  final _docCtrl        = TextEditingController();
  final _name1Ctrl      = TextEditingController();
  final _name2Ctrl      = TextEditingController();
  final _lastName1Ctrl  = TextEditingController();
  final _lastName2Ctrl  = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '0.00');

  String _selectedType     = AppConstants.roleVendedor;
  String _canModifyInvoice = 'N';
  bool   _isSaving         = false;
  String? _tempPassword;

  bool get _isEditing => widget.employee != null; // ← agregado

  @override
  void initState() {
    super.initState();
    if (_isEditing) _fillForm(); // ← agregado
  }

  // ← agregado
  void _fillForm() {
    final e = widget.employee!;
    _docCtrl.text        = e['document_employee']?.toString() ?? '';
    _name1Ctrl.text      = e['name_1']      ?? '';
    _name2Ctrl.text      = e['name_2']      ?? '';
    _lastName1Ctrl.text  = e['last_name_1'] ?? '';
    _lastName2Ctrl.text  = e['last_name_2'] ?? '';
    _emailCtrl.text      = e['email']       ?? '';
    _phoneCtrl.text      = e['phone_number']?.toString() ?? '';
    _commissionCtrl.text = e['commission_percentage']?.toString() ?? '0.00';
    _selectedType        = e['type']?.toString() == AppConstants.roleAdministrador
        ? AppConstants.roleAdministrador
        : AppConstants.roleVendedor;
    _canModifyInvoice    = e['can_modify_invoice']?.toString() == 'S' ? 'S' : 'N';
  }

  @override
  void dispose() {
    _docCtrl.dispose();
    _name1Ctrl.dispose();
    _name2Ctrl.dispose();
    _lastName1Ctrl.dispose();
    _lastName2Ctrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // ── Modo editar
        await _employeeService.updateEmployee(
          widget.employee!['document_employee'].toString(),
          {
            'name_1':                _name1Ctrl.text.trim(),
            'name_2':                _name2Ctrl.text.trim().isEmpty ? null : _name2Ctrl.text.trim(),
            'last_name_1':           _lastName1Ctrl.text.trim(),
            'last_name_2':           _lastName2Ctrl.text.trim().isEmpty ? null : _lastName2Ctrl.text.trim(),
            'email':                 _emailCtrl.text.trim(),
            'phone_number':          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            'type':                  _selectedType,
            'commission_percentage': double.tryParse(_commissionCtrl.text) ?? 0,
            'can_modify_invoice':    _canModifyInvoice,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Empleado actualizado correctamente'),
            backgroundColor: AppColors.statusSuccess,
            behavior: SnackBarBehavior.floating,
          ));
          Navigator.pop(context, true);
        }
      } else {
        // ── Modo crear
        final res = await _employeeService.createEmployee({
          'document_employee':     _docCtrl.text.trim(),
          'name_1':                _name1Ctrl.text.trim(),
          'name_2':                _name2Ctrl.text.trim().isEmpty ? null : _name2Ctrl.text.trim(),
          'last_name_1':           _lastName1Ctrl.text.trim(),
          'last_name_2':           _lastName2Ctrl.text.trim().isEmpty ? null : _lastName2Ctrl.text.trim(),
          'email':                 _emailCtrl.text.trim(),
          'phone_number':          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'type':                  _selectedType,
          'commission_percentage': double.tryParse(_commissionCtrl.text) ?? 0,
          'can_modify_invoice':    _canModifyInvoice,
        });
        final tempPass = res['temp_password']?.toString() ?? '';
        if (mounted) {
          setState(() => _tempPassword = tempPass);
          await _showPasswordDialog(tempPass);
          Navigator.pop(context, true);
        }
      }
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al guardar el empleado. Intenta de nuevo.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showPasswordDialog(String password) async {
    final cs = AppColorScheme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_outlined,
                color: AppColors.statusSuccess, size: 22),
            const SizedBox(width: 8),
            Text('Empleado registrado',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El empleado fue creado exitosamente. Comparte esta contraseña temporal:',
              style: TextStyle(fontSize: 13, color: cs.textSec),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusSuccess.withOpacity(cs.isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.statusSuccess.withOpacity(0.35)),
              ),
              child: Column(
                children: [
                  Text(password,
                      style: TextStyle(fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.textPrimary,
                          letterSpacing: 2,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Contraseña copiada'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccess,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('Copiar',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusWarning.withOpacity(cs.isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusWarning.withOpacity(0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      color: AppColors.statusWarning, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta contraseña no volverá a mostrarse. Compártela al empleado ahora.',
                      style: TextStyle(fontSize: 11, color: AppColors.statusWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar empleado' : 'Nuevo empleado', // ← cambiado
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _SectionCard(
                      title: 'Información personal',
                      icon: Icons.person_outline,
                      children: [
                        // Documento — solo lectura en modo editar
                        _FormField(
                          label: 'Documento de identidad *',
                          controller: _docCtrl,
                          hint: 'Ej: 12345678',
                          keyboardType: TextInputType.number,
                          readOnly: _isEditing, // ← no se puede cambiar el doc
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa el documento';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Nombre 1 *',
                                controller: _name1Ctrl,
                                hint: 'Carlos',
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FormField(
                                label: 'Nombre 2',
                                controller: _name2Ctrl,
                                hint: 'Opcional',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Apellido 1 *',
                                controller: _lastName1Ctrl,
                                hint: 'García',
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _FormField(
                                label: 'Apellido 2',
                                controller: _lastName2Ctrl,
                                hint: 'Opcional',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          label: 'Correo electrónico *',
                          controller: _emailCtrl,
                          hint: 'carlos@misterchef.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa el correo';
                            if (!v.contains('@')) return 'Correo no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _FormField(
                          label: 'Teléfono',
                          controller: _phoneCtrl,
                          hint: '3112345678 (opcional)',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _SectionCard(
                      title: 'Rol y permisos',
                      icon: Icons.admin_panel_settings_outlined,
                      children: [
                        const _FieldLabel(label: 'Tipo de empleado *'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleOption(
                                label: 'Vendedor',
                                isSelected: _selectedType == AppConstants.roleVendedor,
                                color: AppColors.roleVendedor,
                                onTap: () => setState(() =>
                                    _selectedType = AppConstants.roleVendedor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _RoleOption(
                                label: 'Administrador',
                                isSelected: _selectedType == AppConstants.roleAdministrador,
                                color: AppColors.primary,
                                onTap: () => setState(() =>
                                    _selectedType = AppConstants.roleAdministrador),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _FormField(
                          label: 'Porcentaje de comisión',
                          controller: _commissionCtrl,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          suffixText: '%',
                        ),
                        const SizedBox(height: 14),
                        const _FieldLabel(label: '¿Puede anular facturas?'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ToggleOption(
                              label: 'Sí',
                              isSelected: _canModifyInvoice == 'S',
                              color: AppColors.statusSuccess,
                              onTap: () => setState(() => _canModifyInvoice = 'S'),
                            ),
                            const SizedBox(width: 10),
                            _ToggleOption(
                              label: 'No',
                              isSelected: _canModifyInvoice == 'N',
                              color: AppColors.statusError,
                              onTap: () => setState(() => _canModifyInvoice = 'N'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Info contraseña (solo al crear)
                    if (!_isEditing)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.statusInfo.withOpacity(cs.isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.statusInfo.withOpacity(0.35)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.statusInfo, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Se generará una contraseña temporal automáticamente. '
                                'Aparecerá una sola vez al registrar al empleado.',
                                style: TextStyle(fontSize: 12, color: AppColors.statusInfo),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Botón guardar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.card,
                border: Border(top: BorderSide(color: cs.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isEditing ? 'Guardar cambios' : 'Registrar empleado', // ← cambiado
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// WIDGETS INTERNOS
// ════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: cs.textSec, letterSpacing: 1.0));
  }
}

class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? suffixText;
  final bool readOnly; // ← agregado

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.suffixText,
    this.readOnly = false, // ← agregado
  });

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly, // ← agregado
          style: TextStyle(fontSize: 13,
              color: readOnly ? cs.textHint : cs.textPrimary), // ← gris si readOnly
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cs.textHint, fontSize: 13),
            suffixText: suffixText,
            filled: true,
            fillColor: readOnly
                ? cs.surface.withOpacity(0.5) // ← más tenue si readOnly
                : cs.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: cs.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(
                    color: readOnly
                        ? cs.border.withOpacity(0.4) // ← borde más suave
                        : cs.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(
                    color: readOnly ? cs.border : AppColors.primary,
                    width: readOnly ? 1 : 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.statusError)),
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(cs.isDark ? 0.2 : 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: isSelected ? color : cs.border,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? color : cs.border, width: 1.5),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)))
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? color : cs.textHint)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(cs.isDark ? 0.2 : 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: isSelected ? color : cs.border,
              width: isSelected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? color : cs.textHint)),
      ),
    );
  }
}