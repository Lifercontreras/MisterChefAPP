import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/app_colors.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class CreateCustomerScreen extends StatefulWidget {
  final Map<String, dynamic>? customer; // ← null = crear, not null = editar

  const CreateCustomerScreen({super.key, this.customer});

  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _customerService = CustomerService();
  final _employeeService = EmployeeService();
  final _locationService = LocationService();

  final _name1Ctrl     = TextEditingController();
  final _name2Ctrl     = TextEditingController();
  final _lastName1Ctrl = TextEditingController();
  final _lastName2Ctrl = TextEditingController();
  final _businessCtrl  = TextEditingController();
  final _addressCtrl   = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _latCtrl       = TextEditingController();
  final _lngCtrl       = TextEditingController();

  List<Map<String, dynamic>> _employees   = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _cities      = [];

  String? _selectedEmployee;
  String? _selectedDepartment;
  String? _selectedCity;
  bool _isSaving     = false;
  bool _isLoading    = true;
  bool _isGettingGps = false;
  String _userRole   = '';
  String _userDoc    = '';

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final userData    = await AuthService().getUserData();
      _userRole         = userData['tipo'] ?? '';
      _userDoc          = userData['doc']  ?? '';
      final departments = await _locationService.getDepartments();

      List<Map<String, dynamic>> employees = [];
      if (_userRole == 'A') {
        employees = await _employeeService.getEmployees();
      } else {
        _selectedEmployee = _userDoc;
      }

      if (mounted) {
        setState(() {
          _employees   = employees;
          _departments = departments;
          _isLoading   = false;
        });

        if (_isEditing) await _fillForm();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error cargando datos: $e');
      }
    }
  }

  Future<void> _fillForm() async {
    final c = widget.customer!;
    _name1Ctrl.text     = c['client_name1']      ?? '';
    _name2Ctrl.text     = c['client_name2']      ?? '';
    _lastName1Ctrl.text = c['client_last_name1'] ?? '';
    _lastName2Ctrl.text = c['client_last_name2'] ?? '';
    _businessCtrl.text  = c['business_name']     ?? '';
    _addressCtrl.text   = c['address']           ?? '';
    _phoneCtrl.text     = c['phone_number']?.toString() ?? '';
    _latCtrl.text       = c['latitude']?.toString()     ?? '';
    _lngCtrl.text       = c['longitude']?.toString()    ?? '';
    _selectedEmployee   = c['document_employee']?.toString();

    // Cargar departamento y ciudad
    final deptId = c['city']?['id_departament']?.toString()
        ?? c['id_departament']?.toString();
    if (deptId != null) {
      _selectedDepartment = deptId;
      try {
        final cities = await _locationService.getCities(deptId);
        if (mounted) {
          setState(() {
            _cities       = cities;
            _selectedCity = c['city']?['id_city']?.toString()
                ?? c['id_city']?.toString();
          });
        }
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _obtenerUbicacionGps() async {
    setState(() => _isGettingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { _showError('El GPS está desactivado.'); return; }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permiso de ubicación denegado.'); return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('Permiso de ubicación denegado permanentemente.'); return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latCtrl.text = position.latitude.toStringAsFixed(7);
        _lngCtrl.text = position.longitude.toStringAsFixed(7);
      });

      // Geocodificación inversa: convierte lat/lng en una dirección legible.
      try {
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final calle = p.thoroughfare?.isNotEmpty == true
              ? p.thoroughfare!
              : (p.street ?? '');
          final numero = p.subThoroughfare ?? '';
          final partes = [
            if (calle.isNotEmpty) calle,
            if (numero.isNotEmpty) '#$numero',
          ];
          final direccion = partes.isNotEmpty
              ? partes.join(' ')
              : (p.street ?? p.locality ?? '');
          if (direccion.isNotEmpty && mounted) {
            setState(() => _addressCtrl.text = direccion);
          }
        }
      } catch (_) {
        // Si falla la geocodificación, el usuario puede escribir la dirección manualmente.
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ubicación obtenida correctamente'),
        backgroundColor: AppColors.statusSuccess,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      _showError('No se pudo obtener la ubicación GPS.');
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  Future<void> _onDepartmentChanged(String? id) async {
    setState(() {
      _selectedDepartment = id;
      _selectedCity       = null;
      _cities             = [];
    });
    if (id == null) return;
    try {
      final cities = await _locationService.getCities(id);
      if (mounted) setState(() => _cities = cities);
    } catch (_) {}
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'client_name1':      _name1Ctrl.text.trim(),
        'client_name2':      _name2Ctrl.text.trim().isEmpty ? null : _name2Ctrl.text.trim(),
        'client_last_name1': _lastName1Ctrl.text.trim(),
        'client_last_name2': _lastName2Ctrl.text.trim().isEmpty ? null : _lastName2Ctrl.text.trim(),
        'business_name':     _businessCtrl.text.trim(),
        'address':           _addressCtrl.text.trim(),
        'phone_number':      _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'latitude':          double.tryParse(_latCtrl.text.trim()) ?? 0.0,
        'longitude':         double.tryParse(_lngCtrl.text.trim()) ?? 0.0,
        'id_departament':    _selectedDepartment,
        'id_city':           _selectedCity,
        'document_employee': _selectedEmployee,
      };

      if (_isEditing) {
        await _customerService.updateClient(
            widget.customer!['id_client'].toString(), data);
      } else {
        data['status'] = true;
        await _customerService.createClient(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Cliente actualizado correctamente'
              : 'Cliente registrado correctamente'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Error al guardar el cliente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.statusError,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _name1Ctrl.dispose();     _name2Ctrl.dispose();
    _lastName1Ctrl.dispose(); _lastName2Ctrl.dispose();
    _businessCtrl.dispose();  _addressCtrl.dispose();
    _phoneCtrl.dispose();     _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar cliente' : 'Nuevo cliente',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SectionCard(
                      title: 'Información personal',
                      icon: Icons.person_outline,
                      cs: cs,
                      children: [
                        _field(_name1Ctrl, 'Nombre 1 *', 'Carlos',
                            cs: cs, required: true),
                        const SizedBox(height: 12),
                        _field(_name2Ctrl, 'Nombre 2', 'Opcional', cs: cs),
                        const SizedBox(height: 12),
                        _field(_lastName1Ctrl, 'Apellido 1 *', 'García',
                            cs: cs, required: true),
                        const SizedBox(height: 12),
                        _field(_lastName2Ctrl, 'Apellido 2', 'Opcional', cs: cs),
                        const SizedBox(height: 12),
                        _field(_businessCtrl, 'Nombre del negocio *',
                            'Tienda Doña María', cs: cs, required: true),
                        const SizedBox(height: 12),
                        _field(_phoneCtrl, 'Teléfono', '3112345678',
                            cs: cs, keyboard: TextInputType.phone),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      title: 'Ubicación',
                      icon: Icons.location_on_outlined,
                      cs: cs,
                      children: [
                        _field(_addressCtrl, 'Dirección *', 'Calle 5 #10-20',
                            cs: cs, required: true),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _field(_latCtrl, 'Latitud *', '8.2340',
                                  cs: cs,
                                  keyboard: TextInputType.number,
                                  required: true),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _field(_lngCtrl, 'Longitud *', '-73.3197',
                                  cs: cs,
                                  keyboard: TextInputType.number,
                                  required: true),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: GestureDetector(
                                onTap: _isGettingGps ? null : _obtenerUbicacionGps,
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: _isGettingGps
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Icon(Icons.my_location,
                                          color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca el ícono GPS para obtener tu ubicación actual',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.textHint.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel(label: 'Departamento *', cs: cs),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          dropdownColor: cs.card,
                          decoration: _dropdownDeco(cs),
                          hint: Text('Selecciona un departamento',
                              style: TextStyle(fontSize: 13, color: cs.textHint)),
                          style: TextStyle(fontSize: 13, color: cs.textPrimary),
                          icon: Icon(Icons.keyboard_arrow_down, color: cs.textHint),
                          items: _departments.map((d) => DropdownMenuItem(
                            value: d['id_departament'].toString(),
                            child: Text(
                              d['name_departament'] ?? d['department_name'] ?? '',
                              style: TextStyle(fontSize: 13, color: cs.textPrimary),
                            ),
                          )).toList(),
                          onChanged: (v) => _onDepartmentChanged(v),
                          validator: (v) =>
                              v == null ? 'Selecciona un departamento' : null,
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel(label: 'Ciudad *', cs: cs),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedCity,
                          dropdownColor: cs.card,
                          decoration: _dropdownDeco(cs),
                          hint: Text(
                            _selectedDepartment == null
                                ? 'Primero selecciona un departamento'
                                : 'Selecciona una ciudad',
                            style: TextStyle(fontSize: 13, color: cs.textHint),
                          ),
                          style: TextStyle(fontSize: 13, color: cs.textPrimary),
                          icon: Icon(Icons.keyboard_arrow_down, color: cs.textHint),
                          items: _cities.map((c) => DropdownMenuItem(
                            value: c['id_city'].toString(),
                            child: Text(
                              c['name_city'] ?? c['city_name'] ?? '',
                              style: TextStyle(fontSize: 13, color: cs.textPrimary),
                            ),
                          )).toList(),
                          onChanged: _selectedDepartment == null
                              ? null
                              : (v) => setState(() => _selectedCity = v),
                          validator: (v) =>
                              v == null ? 'Selecciona una ciudad' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_userRole == 'A') ...[
                      _SectionCard(
                        title: 'Empleado asignado',
                        icon: Icons.badge_outlined,
                        cs: cs,
                        children: [
                          _FieldLabel(label: 'Vendedor *', cs: cs),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedEmployee,
                            dropdownColor: cs.card,
                            decoration: _dropdownDeco(cs),
                            hint: Text('Selecciona un vendedor',
                                style: TextStyle(fontSize: 13, color: cs.textHint)),
                            style: TextStyle(fontSize: 13, color: cs.textPrimary),
                            icon: Icon(Icons.keyboard_arrow_down, color: cs.textHint),
                            items: _employees.map((e) {
                              final nombre =
                                  '${e['name_1'] ?? ''} ${e['last_name_1'] ?? ''}'.trim();
                              final doc = e['document_employee']?.toString() ?? '';
                              return DropdownMenuItem(
                                value: doc,
                                child: Text('$nombre ($doc)',
                                    style: TextStyle(
                                        fontSize: 13, color: cs.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedEmployee = v),
                            validator: (v) =>
                                v == null ? 'Selecciona un vendedor' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _isSaving ? null : _guardar,
        child: _isSaving
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check, size: 28),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {required AppColorScheme cs,
      TextInputType? keyboard,
      bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, cs: cs),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          style: TextStyle(fontSize: 13, color: cs.textPrimary),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cs.textHint, fontSize: 13),
            filled: true,
            fillColor: cs.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: cs.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: cs.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.statusError)),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDeco(AppColorScheme cs) => InputDecoration(
        filled: true,
        fillColor: cs.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: cs.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: cs.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: AppColors.statusError)),
      );
}

// ════════════════════════════════════════════
// WIDGETS INTERNOS
// ════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final AppColorScheme cs;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.children,
      required this.cs});

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                    fontSize: 11,
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
  final AppColorScheme cs;
  const _FieldLabel({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.textSec,
            letterSpacing: 1.0));
  }
}