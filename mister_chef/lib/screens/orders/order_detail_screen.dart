import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orderService = OrderService();
  final _authService  = AuthService();

  Map<String, dynamic>? _invoice;
  bool _isLoading   = true;
  bool _isActioning = false;
  bool _canModify   = false;
  bool _isAdmin     = false;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
    _checkPermissions();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final data = await _orderService.getInvoiceById(widget.orderId);
      if (mounted) setState(() { _invoice = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final me = await _authService.getMe();
      if (mounted) {
        setState(() {
          _isAdmin   = (me['type'] ?? '') == AppConstants.roleAdministrador;
          _canModify = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmar() async {
    final confirmed = await _showConfirmDialog(
      title: 'Confirmar pedido',
      message: '¿Confirmar este pedido? Se descontará el stock de los productos.',
      actionLabel: 'Confirmar',
      color: AppColors.statusSuccess,
    );
    if (!confirmed) return;

    setState(() => _isActioning = true);
    try {
      await _orderService.confirmInvoice(widget.orderId);
      _showMsg('Pedido confirmado. Stock actualizado.');
      _loadInvoice();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al confirmar el pedido.', isError: true);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _anular() async {
    final confirmed = await _showConfirmDialog(
      title: 'Anular pedido',
      message: '¿Estás seguro de que deseas anular este pedido? Esta acción no se puede deshacer.',
      actionLabel: 'Anular',
      color: AppColors.statusError,
    );
    if (!confirmed) return;

    setState(() => _isActioning = true);
    try {
      await _orderService.cancelInvoice(widget.orderId);
      _showMsg('Pedido anulado correctamente.');
      _loadInvoice();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al anular el pedido.', isError: true);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    required Color color,
  }) async {
    final cs = AppColorScheme.of(context); // ← agregado
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card, // ← cambiado
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w500,
                color: cs.textPrimary)), // ← cambiado
        content: Text(message,
            style: TextStyle(fontSize: 13, color: cs.textSec)), // ← cambiado
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: cs.textHint)), // ← cambiado
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatMoneda(dynamic valor) {
    final v = double.tryParse((valor ?? 0).toString()) ?? 0.0;
    return '\$${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ← corregido: fuerza UTC si no tiene zona horaria
  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '';
    String fechaStr = fecha.toString();

    DateTime? dt;
    // Si ya tiene zona horaria (contiene + o Z) parsear directo
    if (fechaStr.contains('Z') || fechaStr.contains('+')) {
      dt = DateTime.tryParse(fechaStr)?.toLocal();
    } else {
      // Sin zona horaria: el servidor envía UTC sin marcarlo, forzar UTC
      dt = DateTime.tryParse('${fechaStr}Z')?.toLocal();
    }

    if (dt == null) return fechaStr;

    final d  = dt.day.toString().padLeft(2, '0');
    final m  = dt.month.toString().padLeft(2, '0');
    final y  = dt.year;
    final h  = dt.hour.toString().padLeft(2, '0');
    final mn = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$mn';
  }

  String _clientName() {
    final c = _invoice?['client'];
    if (c == null) return 'Cliente desconocido';
    final empresa  = c['business_name']     ?? '';
    final nombre   = c['client_name1']      ?? '';
    final apellido = c['client_last_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : '$nombre $apellido'.trim();
  }

  String _statusLabel(String? status) {
    switch (status) {
      case AppConstants.invoicePending:   return 'Pendiente';
      case AppConstants.invoiceConfirmed: return 'Confirmada';
      case AppConstants.invoiceCancelled: return 'Anulada';
      default: return 'Desconocido';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case AppConstants.invoicePending:   return AppColors.statusWarning;
      case AppConstants.invoiceConfirmed: return AppColors.statusSuccess;
      case AppConstants.invoiceCancelled: return AppColors.statusError;
      default: return AppColors.textHintLight;
    }
  }

  Color _statusBgColor(String? status, bool isDark) { // ← recibe isDark
    switch (status) {
      case AppConstants.invoicePending:
        return AppColors.statusWarning.withOpacity(isDark ? 0.15 : 0.1);
      case AppConstants.invoiceConfirmed:
        return AppColors.statusSuccess.withOpacity(isDark ? 0.15 : 0.1);
      case AppConstants.invoiceCancelled:
        return AppColors.statusError.withOpacity(isDark ? 0.15 : 0.1);
      default:
        return AppColors.borderLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = AppColorScheme.of(context); // ← agregado
    final status = _invoice?['status'];

    return Scaffold(
      backgroundColor: cs.surface, // ← cambiado
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('#${widget.orderId}',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w500)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary))
          : _invoice == null
              ? Center(child: Text('Pedido no encontrado',
                  style: TextStyle(color: cs.textHint))) // ← cambiado
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadInvoice,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ── Estado del pedido
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.card, // ← cambiado
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border), // ← cambiado
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _statusBgColor(status, cs.isDark), // ← cambiado
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        status == AppConstants.invoiceConfirmed
                                            ? Icons.check_circle_outline
                                            : status == AppConstants.invoiceCancelled
                                                ? Icons.cancel_outlined
                                                : Icons.hourglass_empty,
                                        color: _statusColor(status),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_statusLabel(status),
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: _statusColor(status))),
                                        Text(
                                          'Factura #${_invoice!['id_invoice']} · ${_formatFecha(_invoice!['date'])}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.textHint), // ← cambiado
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Info del cliente
                              _buildSectionLabel('Cliente', cs),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.card, // ← cambiado
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border), // ← cambiado
                                ),
                                child: Column(
                                  children: [
                                    _InfoRow(
                                      icon: Icons.store_outlined,
                                      label: 'Cliente',
                                      value: _clientName(),
                                      cs: cs, // ← agregado
                                    ),
                                    Divider(height: 1, color: cs.divider), // ← cambiado
                                    _InfoRow(
                                      icon: Icons.location_on_outlined,
                                      label: 'Dirección',
                                      value: _invoice!['client']?['address']
                                          ?? 'No registrada',
                                      cs: cs,
                                    ),
                                    if (_invoice!['client']?['phone_number'] != null) ...[
                                      Divider(height: 1, color: cs.divider),
                                      _InfoRow(
                                        icon: Icons.phone_outlined,
                                        label: 'Teléfono',
                                        value: _invoice!['client']['phone_number'].toString(),
                                        cs: cs,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Productos
                              _buildSectionLabel('Productos', cs),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: cs.card, // ← cambiado
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border), // ← cambiado
                                ),
                                child: Column(
                                  children: (_invoice!['details'] as List? ?? [])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final i        = entry.key;
                                    final d        = entry.value as Map<String, dynamic>;
                                    final prod     = d['product'];
                                    final nombre   = prod?['product_name']?.toString() ?? '';
                                    final precio   = double.tryParse(prod?['selling_price']?.toString() ?? '0') ?? 0.0;
                                    final cantidad = int.tryParse(d['amount']?.toString() ?? '0') ?? 0;
                                    final subtotal = double.tryParse(d['subtotal']?.toString() ?? '0') ?? (precio * cantidad);
                                    final total    = _invoice!['details'] as List;

                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38, height: 38,
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent.withOpacity(
                                                      cs.isDark ? 0.2 : 0.15), // ← adaptativo
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                    Icons.inventory_2_outlined,
                                                    color: AppColors.primary,
                                                    size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(nombre,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: cs.textPrimary)), // ← cambiado
                                                    Text('${_formatMoneda(precio)} c/u',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: cs.textHint)), // ← cambiado
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text('x$cantidad',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: cs.textHint)), // ← cambiado
                                                  Text(_formatMoneda(subtotal),
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w500,
                                                          color: cs.textPrimary)), // ← cambiado
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (i < total.length - 1)
                                          Divider(height: 1,
                                              color: cs.divider, // ← cambiado
                                              indent: 14, endIndent: 14),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ── Creado por
                              if (_getCreador() != null) ...[
                                _buildSectionLabel('Creado por', cs),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cs.card, // ← cambiado
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cs.border), // ← cambiado
                                  ),
                                  child: _InfoRow(
                                    icon: Icons.person_outline,
                                    label: 'Empleado',
                                    value: _getCreador()!,
                                    cs: cs,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // ── Total
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cs.card, // ← cambiado
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border), // ← cambiado
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total del pedido',
                                        style: TextStyle(fontSize: 14,
                                            color: cs.textSec)), // ← cambiado
                                    Text(_formatMoneda(_invoice!['total']),
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primary)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (status != AppConstants.invoiceCancelled)
                      _buildActionButtons(status, cs),
                  ],
                ),
    );
  }

  String? _getCreador() {
    final audits = _invoice?['audits'] as List?;
    if (audits == null || audits.isEmpty) return null;
    final creacion = audits.firstWhere(
      (a) => a['action_type'] == 'C',
      orElse: () => audits.last,
    );
    final emp = creacion['employee'];
    if (emp == null) return null;
    final nombre = '${emp['name_1'] ?? ''} ${emp['last_name_1'] ?? ''}'.trim();
    return nombre.isEmpty ? null : nombre;
  }

  Widget _buildSectionLabel(String label, AppColorScheme cs) =>
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: cs.textSec, letterSpacing: 1.2));

  Widget _buildActionButtons(String? status, AppColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card, // ← cambiado
        border: Border(top: BorderSide(color: cs.border)), // ← cambiado
      ),
      child: Row(
        children: [
          if (status == AppConstants.invoicePending && _isAdmin)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActioning ? null : _confirmar,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                  elevation: 0,
                ),
              ),
            ),

          if (status == AppConstants.invoicePending && _isAdmin)
            const SizedBox(width: 10),

          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isActioning ? null : _anular,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Anular'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppColors.statusError),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),

          if (_isActioning)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}

// ── Fila de información
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final AppColorScheme cs; // ← agregado

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs, // ← agregado
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(cs.isDark ? 0.2 : 0.08), // ← adaptativo
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: cs.textHint)), // ← cambiado
                Text(value,
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.textPrimary)), // ← cambiado
              ],
            ),
          ),
        ],
      ),
    );
  }
}