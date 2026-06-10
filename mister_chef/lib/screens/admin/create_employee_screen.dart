import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/employee_service.dart';
import '../../services/api_service.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeService = EmployeeService();

  // Controladores
  final _docCtrl        = TextEditingController();
  final _name1Ctrl      = TextEditingController();
  final _name2Ctrl      = TextEditingController();
  final _lastName1Ctrl  = TextEditingController();
  final _lastName2Ctrl  = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '0.00');

  // Estado del formulario
  String _selectedType      = AppConstants.roleVendedor; // 'V' o 'A'
  String _canModifyInvoice  = 'N'; // 'S' o 'N'
  bool   _isSaving          = false;

  // Contraseña temporal generada (se muestra después de crear)
  String? _tempPassword;

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
      final res = await _employeeService.createEmployee({
        'document_employee':    _docCtrl.text.trim(),
        'name_1':               _name1Ctrl.text.trim(),
        'name_2':               _name2Ctrl.text.trim().isEmpty
            ? null
            : _name2Ctrl.text.trim(),
        'last_name_1':          _lastName1Ctrl.text.trim(),
        'last_name_2':          _lastName2Ctrl.text.trim().isEmpty
            ? null
            : _lastName2Ctrl.text.trim(),
        'email':                _emailCtrl.text.trim(),
        'phone_number':         _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'type':                 _selectedType,
        'commission_percentage': double.tryParse(_commissionCtrl.text) ?? 0,
        'can_modify_invoice':   _canModifyInvoice,
      });

      // Obtener contraseña temporal de la respuesta
      final tempPass = res['temp_password']?.toString() ?? '';

      if (mounted) {
        setState(() => _tempPassword = tempPass);
        // Mostrar dialog con la contraseña temporal
        await _showPasswordDialog(tempPass);
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al registrar el empleado. Intenta de nuevo.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Mostrar la contraseña temporal UNA SOLA VEZ
  Future<void> _showPasswordDialog(String password) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_outlined,
                color: AppColors.statusSuccess, size: 22),
            SizedBox(width: 8),
            Text('Empleado registrado',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El empleado fue creado exitosamente. Comparte esta contraseña temporal:',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.chipSuccessBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.statusSuccess.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    password,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Botón copiar
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contraseña copiada'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
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
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
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
                color: AppColors.chipWarningBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      color: AppColors.statusWarning, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta contraseña no volverá a mostrarse. Compártela al empleado ahora.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.statusWarning),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nuevo empleado',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
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

                    // ── Información personal
                    _SectionCard(
                      title: 'Información personal',
                      icon: Icons.person_outline,
                      children: [
                        // Documento
                        _FormField(
                          label: 'Documento de identidad *',
                          controller: _docCtrl,
                          hint: 'Ej: 12345678',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Ingresa el documento';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Nombres
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Nombre 1 *',
                                controller: _name1Ctrl,
                                hint: 'Carlos',
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Requerido';
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

                        // Apellidos
                        Row(
                          children: [
                            Expanded(
                              child: _FormField(
                                label: 'Apellido 1 *',
                                controller: _lastName1Ctrl,
                                hint: 'García',
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Requerido';
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

                        // Email
                        _FormField(
                          label: 'Correo electrónico *',
                          controller: _emailCtrl,
                          hint: 'carlos@misterchef.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Ingresa el correo';
                            if (!v.contains('@')) return 'Correo no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Teléfono
                        _FormField(
                          label: 'Teléfono',
                          controller: _phoneCtrl,
                          hint: '3112345678 (opcional)',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Rol y permisos
                    _SectionCard(
                      title: 'Rol y permisos',
                      icon: Icons.admin_panel_settings_outlined,
                      children: [

                        // Selector de rol
                        const _FieldLabel(label: 'Tipo de empleado *'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleOption(
                                label: 'Vendedor',
                                isSelected: _selectedType ==
                                    AppConstants.roleVendedor,
                                color: AppColors.roleVendedor,
                                bgColor: AppColors.roleVendedorBg,
                                onTap: () => setState(() =>
                                    _selectedType =
                                        AppConstants.roleVendedor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _RoleOption(
                                label: 'Administrador',
                                isSelected: _selectedType ==
                                    AppConstants.roleAdministrador,
                                color: AppColors.roleAdmin,
                                bgColor: AppColors.roleAdminBg,
                                onTap: () => setState(() =>
                                    _selectedType =
                                        AppConstants.roleAdministrador),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Comisión
                        _FormField(
                          label: 'Porcentaje de comisión',
                          controller: _commissionCtrl,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          suffixText: '%',
                        ),
                        const SizedBox(height: 14),

                        // ¿Puede anular facturas?
                        const _FieldLabel(
                            label: '¿Puede anular facturas?'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ToggleOption(
                              label: 'Sí',
                              isSelected: _canModifyInvoice == 'S',
                              color: AppColors.statusSuccess,
                              bgColor: AppColors.chipSuccessBg,
                              onTap: () => setState(
                                  () => _canModifyInvoice = 'S'),
                            ),
                            const SizedBox(width: 10),
                            _ToggleOption(
                              label: 'No',
                              isSelected: _canModifyInvoice == 'N',
                              color: AppColors.statusError,
                              bgColor: AppColors.chipErrorBg,
                              onTap: () => setState(
                                  () => _canModifyInvoice = 'N'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Info contraseña
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.chipInfoBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.statusInfo.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.statusInfo, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Se generará una contraseña temporal automáticamente. '
                              'Aparecerá una sola vez al registrar al empleado.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.statusInfo),
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

            // ── Botón registrar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: AppColors.borderLight)),
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
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Registrar empleado',
                          style: TextStyle(
                              fontSize: 15,
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

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.8)),
            ],
          ),
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
    return Text(label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryLight,
            letterSpacing: 1.0));
  }
}

class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? suffixText;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textPrimaryLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textHintLight, fontSize: 13),
            suffixText: suffixText,
            filled: true,
            fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.borderLight)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.borderLight)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.statusError)),
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color, bgColor;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: isSelected ? color : AppColors.borderLight,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? color : AppColors.borderLight,
                    width: 1.5),
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
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? color : AppColors.textHintLight)),
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
  final Color color, bgColor;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: isSelected ? color : AppColors.borderLight,
              width: isSelected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? color : AppColors.textHintLight)),
      ),
    );
  }
}