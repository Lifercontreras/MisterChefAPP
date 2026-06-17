import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/order_service.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../services/api_service.dart';

class NewOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? preselectedCustomer;

  const NewOrderScreen({super.key, this.preselectedCustomer});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _orderService    = OrderService();
  final _customerService = CustomerService();
  final _productService  = ProductService();

  final _invoiceIdCtrl = TextEditingController();

  Map<String, dynamic>? _selectedCustomer;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products  = [];

  final List<Map<String, dynamic>> _cart = [];

  bool _isLoadingData = false;
  bool _isSaving      = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    final now  = DateTime.now();
    final seed = (now.millisecondsSinceEpoch % 9999).toString().padLeft(4, '0');
    _invoiceIdCtrl.text = 'F$seed';
    _loadData();
  }

  @override
  void dispose() {
    _invoiceIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final results = await Future.wait([
        _customerService.getClients(status: true),
        _productService.getProducts(status: true),
      ]);
      if (mounted) {
        setState(() {
          _customers     = results[0];
          _products      = results[1];
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  int _getAmount(String productId) {
    final item = _cart.firstWhere(
      (e) => e['product']['id_product'] == productId,
      orElse: () => {},
    );
    return item.isEmpty ? 0 : (item['amount'] as int);
  }

  void _setAmount(Map<String, dynamic> product, int amount) {
    final idx = _cart.indexWhere(
        (e) => e['product']['id_product'] == product['id_product']);
    setState(() {
      if (amount <= 0) {
        if (idx >= 0) _cart.removeAt(idx);
      } else {
        if (idx >= 0) {
          _cart[idx]['amount'] = amount;
        } else {
          _cart.add({'product': product, 'amount': amount});
        }
      }
    });
  }

  double get _total => _cart.fold(0, (sum, item) {
        final price  = double.tryParse(item['product']['selling_price'].toString()) ?? 0.0;
        final amount = item['amount'] as int;
        return sum + price * amount;
      });

  String _formatMoneda(double valor) =>
      '\$${valor.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  String _customerDisplayName(Map<String, dynamic> c) {
    final empresa  = c['business_name']     ?? '';
    final nombre   = c['client_name1']      ?? '';
    final apellido = c['client_last_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : '$nombre $apellido'.trim();
  }

  Future<void> _confirmarPedido() async {
    if (_invoiceIdCtrl.text.trim().isEmpty) {
      _showMsg('Ingresa el código de la factura', isError: true);
      return;
    }
    if (_selectedCustomer == null) {
      _showMsg('Selecciona un cliente', isError: true);
      return;
    }
    final clienteActivo = _selectedCustomer!['status'] == true ||
        _selectedCustomer!['status'] == 1;
    if (!clienteActivo) {
      _showMsg('Este cliente está inactivo, no puedes crear facturas',
          isError: true);
      return;
    }
    if (_cart.isEmpty) {
      _showMsg('Agrega al menos un producto', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _orderService.createInvoice(
        idInvoice: _invoiceIdCtrl.text.trim().toUpperCase(),
        idClient:  _selectedCustomer!['id_client'].toString(),
        details: _cart
            .map((item) => {
                  'id_product': item['product']['id_product'].toString(),
                  'amount':     item['amount'],
                })
            .toList(),
      );

      if (mounted) {
        _showMsg('¡Pedido creado exitosamente!');
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al guardar el pedido. Intenta de nuevo.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  void _showCustomerPicker() {
    final cs = AppColorScheme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.card, // ← cambiado
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CustomerPickerSheet(
        customers: _customers,
        onSelected: (c) {
          setState(() => _selectedCustomer = c);
          Navigator.pop(context);
        },
        displayName: _customerDisplayName,
      ),
    );
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
        title: const Text('Nuevo pedido',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        elevation: 0,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Selector de cliente
                        _SectionLabel(label: 'Cliente'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showCustomerPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: cs.card, // ← cambiado
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedCustomer != null
                                    ? AppColors.primary
                                    : cs.border, // ← cambiado
                                width: _selectedCustomer != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    color: _selectedCustomer != null
                                        ? AppColors.primary
                                        : cs.textHint, // ← cambiado
                                    size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedCustomer != null
                                        ? _customerDisplayName(_selectedCustomer!)
                                        : 'Seleccionar cliente...',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _selectedCustomer != null
                                            ? cs.textPrimary  // ← cambiado
                                            : cs.textHint),   // ← cambiado
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: cs.textHint, size: 18), // ← cambiado
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Productos
                        _SectionLabel(label: 'Productos'),
                        const SizedBox(height: 8),

                        if (_products.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            child: Text('No hay productos disponibles',
                                style: TextStyle(
                                    color: cs.textHint, // ← cambiado
                                    fontSize: 13)),
                          )
                        else
                          ..._products.map((prod) {
                            final id     = prod['id_product'].toString();
                            final amount = _getAmount(id);
                            final price  = double.tryParse(prod['selling_price'].toString()) ?? 0.0;
                            final stock  = (prod['stock'] ?? 0) as int;
                            final isLow  = stock <= (prod['minimun_stock'] ?? 0);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.card, // ← cambiado
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: amount > 0
                                      ? AppColors.primary
                                      : cs.border, // ← cambiado
                                  width: amount > 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined,
                                        color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(prod['product_name'] ?? '',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: cs.textPrimary), // ← cambiado
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Row(
                                          children: [
                                            Text(_formatMoneda(price),
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: cs.textHint)), // ← cambiado
                                            const SizedBox(width: 8),
                                            if (isLow)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.chipWarningBg,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text('Stock: $stock',
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        color: AppColors.statusWarning,
                                                        fontWeight: FontWeight.w500)),
                                              )
                                            else
                                              Text('Stock: $stock',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: cs.textHint)), // ← cambiado
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  Row(
                                    children: [
                                      _QtyBtn(
                                        icon: Icons.remove,
                                        onTap: () => _setAmount(prod, amount - 1),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text('$amount',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: cs.textPrimary)), // ← cambiado
                                      ),
                                      _QtyBtn(
                                        icon: Icons.add,
                                        onTap: () => _setAmount(prod, amount + 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.card, // ← cambiado
                    border: Border(top: BorderSide(color: cs.border)), // ← cambiado
                  ),
                  child: Column(
                    children: [
                      if (_cart.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_cart.length} producto${_cart.length != 1 ? 's' : ''} seleccionado${_cart.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                  fontSize: 12, color: cs.textHint)), // ← cambiado
                            Text(_formatMoneda(_total),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: cs.textPrimary)), // ← cambiado
                          ],
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Text('Selecciona los productos del pedido',
                            style: TextStyle(
                                fontSize: 12, color: cs.textHint)), // ← cambiado
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _confirmarPedido,
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
                              : const Text('Confirmar y generar factura',
                                  style: TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ════════════════════════════════════════════
// MODAL SELECTOR DE CLIENTE
// ════════════════════════════════════════════
class _CustomerPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final String Function(Map<String, dynamic>) displayName;

  const _CustomerPickerSheet({
    required this.customers,
    required this.onSelected,
    required this.displayName,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = widget.customers.where((c) {
          final name = widget.displayName(c).toLowerCase();
          final addr = (c['address'] ?? '').toString().toLowerCase();
          return name.contains(q) || addr.contains(q);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: cs.border, // ← cambiado
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Seleccionar cliente',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                    color: cs.textPrimary)), // ← cambiado
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: cs.textPrimary), // ← cambiado
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                hintStyle: TextStyle(color: cs.textHint), // ← cambiado
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.primary, size: 20),
                filled: true,
                fillColor: cs.surface, // ← cambiado
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.border)), // ← cambiado
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.border)), // ← cambiado
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.border), // ← cambiado
              itemBuilder: (_, i) {
                final c    = _filtered[i];
                final name = widget.displayName(c);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(name,
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.textPrimary)), // ← cambiado
                  subtitle: Text(c['address'] ?? '',
                      style: TextStyle(fontSize: 11,
                          color: cs.textHint)), // ← cambiado
                  onTap: () => widget.onSelected(c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de cantidad reutilizable
class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cs.border), // ← cambiado
          color: cs.card, // ← cambiado
        ),
        child: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }
}

// ── Label de sección
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Text(label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: cs.textSec, letterSpacing: 1.2)); // ← cambiado
  }
}