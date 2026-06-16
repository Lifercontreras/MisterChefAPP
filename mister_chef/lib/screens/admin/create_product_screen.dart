import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/product_service.dart';
import '../../services/api_service.dart';

class CreateProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const CreateProductScreen({super.key, this.product});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _productService = ProductService();

  final _nameCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _stockCtrl    = TextEditingController();
  final _minStockCtrl = TextEditingController();

  List<Map<String, dynamic>> _types = [];
  String? _selectedType;
  bool _isSaving  = false;
  bool _isLoading = true;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _productService.getProductTypes();
      if (mounted) {
        setState(() {
          _types     = types;
          _isLoading = false;
        });
        if (_isEditing) _fillForm();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillForm() {
    final p = widget.product!;
    _nameCtrl.text     = p['product_name']  ?? '';
    _priceCtrl.text    = p['selling_price']?.toString() ?? '';
    _stockCtrl.text    = p['stock']?.toString()         ?? '';
    _minStockCtrl.text = p['minimun_stock']?.toString() ?? '';
    _selectedType      = p['id_produc_type']?.toString();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'product_name':   _nameCtrl.text.trim(),
        'selling_price':  double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        'minimun_stock':  int.tryParse(_minStockCtrl.text.trim()) ?? 0,
        'id_produc_type': _selectedType,
      };

      if (_isEditing) {
        await _productService.updateProduct(
            widget.product!['id_product'].toString(), data);
      } else {
        data['stock']  = int.tryParse(_stockCtrl.text.trim()) ?? 0;
        data['status'] = true;
        await _productService.createProduct(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Producto actualizado correctamente'
              : 'Producto creado correctamente'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      debugPrint('ERROR CREAR PRODUCTO: $e');
      _showError('Error al guardar el producto.');
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
    _nameCtrl.dispose();  _priceCtrl.dispose();
    _stockCtrl.dispose(); _minStockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Scaffold(
      backgroundColor: cs.surface, // ← cambiado
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary))
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SectionCard(
                            title: 'Información del producto',
                            icon: Icons.inventory_2_outlined,
                            children: [
                              _field(context, _nameCtrl,
                                  'Nombre del producto *', 'Pimienta negra',
                                  required: true),
                              const SizedBox(height: 12),
                              _field(context, _priceCtrl,
                                  'Precio de venta *', '5000',
                                  keyboard: TextInputType.number,
                                  required: true),
                              const SizedBox(height: 12),
                              if (!_isEditing) ...[
                                _field(context, _stockCtrl,
                                    'Stock inicial *', '100',
                                    keyboard: TextInputType.number,
                                    required: true),
                                const SizedBox(height: 12),
                              ],
                              _field(context, _minStockCtrl,
                                  'Stock mínimo *', '10',
                                  keyboard: TextInputType.number,
                                  required: true),
                              const SizedBox(height: 12),
                              _FieldLabel(label: 'Tipo de producto *'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedType,
                                dropdownColor: cs.card, // ← cambiado
                                decoration: _dropdownDeco(cs),
                                hint: Text('Selecciona un tipo',
                                    style: TextStyle(fontSize: 13,
                                        color: cs.textHint)), // ← cambiado
                                items: _types.map((t) => DropdownMenuItem(
                                  value: t['id_produc_type'].toString(),
                                  child: Text(t['type'] ?? '',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: cs.textPrimary)), // ← cambiado
                                )).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedType = v),
                                validator: (v) =>
                                    v == null ? 'Selecciona un tipo' : null,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cs.textPrimary), // ← cambiado
                                icon: Icon(Icons.keyboard_arrow_down,
                                    color: cs.textHint), // ← cambiado
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Botón guardar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.card, // ← cambiado
                      border: Border(top: BorderSide(color: cs.border)), // ← cambiado
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _guardar,
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
                                _isEditing ? 'Guardar cambios' : 'Crear producto',
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

  Widget _field(BuildContext context, TextEditingController ctrl,
      String label, String hint,
      {TextInputType? keyboard, bool required = false}) {
    final cs = AppColorScheme.of(context); // ← agregado
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          style: TextStyle(fontSize: 13, color: cs.textPrimary), // ← cambiado
          validator: required
              ? (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cs.textHint, fontSize: 13), // ← cambiado
            filled: true,
            fillColor: cs.surface, // ← cambiado
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: cs.border)), // ← cambiado
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: cs.border)), // ← cambiado
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.statusError)),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDeco(AppColorScheme cs) => InputDecoration(
    filled: true,
    fillColor: cs.surface, // ← cambiado
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: cs.border)), // ← cambiado
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: cs.border)), // ← cambiado
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.card, // ← cambiado
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.border), // ← cambiado
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
    final cs = AppColorScheme.of(context); // ← agregado
    return Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: cs.textSec, letterSpacing: 1.0)); // ← cambiado
  }
}