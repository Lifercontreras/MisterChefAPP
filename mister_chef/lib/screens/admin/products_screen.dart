import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/product_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'create_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productService = ProductService();
  final _searchCtrl     = TextEditingController();

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading   = true;
  bool _soloActivos = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _productService.getProducts();
      if (mounted) {
        setState(() {
          _all = data;
          _filter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        final nombre = (p['product_name'] ?? '').toLowerCase();
        final tipo   = (p['product_type']?['type'] ?? '').toLowerCase();
        final activo = p['status'] == true || p['status'] == 1;
        final matchSearch = nombre.contains(q) || tipo.contains(q);
        final matchStatus = _soloActivos ? activo : true;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _toggleStatus(Map<String, dynamic> product) async {
    final id     = product['id_product'].toString();
    final activo = product['status'] == true || product['status'] == 1;
    try {
      await _productService.changeStatus(id, !activo);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al cambiar el estado.', isError: true);
    }
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
    final cs = AppColorScheme.of(context); // ← agregado

    return Scaffold(
      backgroundColor: cs.background, // ← cambiado
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.products),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 52,
                                color: cs.textHint.withOpacity(0.4)), // ← cambiado
                            const SizedBox(height: 12),
                            Text('No se encontraron productos',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: cs.textHint)), // ← cambiado
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ProductCard(
                            product: _filtered[i],
                            onToggleStatus: () => _toggleStatus(_filtered[i]),
                            onEditStock: () => _showStockDialog(_filtered[i]),
                            onEdit: () async {
                              final result = await Navigator.push(context,
                                MaterialPageRoute(builder: (_) =>
                                  CreateProductScreen(product: _filtered[i])));
                              if (result == true) _load();
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                  const Text('Productos',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w500, color: Colors.white)),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _soloActivos = !_soloActivos);
                          _filter();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _soloActivos ? 'Activos' : 'Todos',
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => const CreateProductScreen()));
                          if (result == true) _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                    hintText: 'Buscar por nombre o tipo...',
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
    );
  }

  Future<void> _showStockDialog(Map<String, dynamic> product) async {
    final cs   = AppColorScheme.of(context); // ← agregado
    final ctrl = TextEditingController(text: product['stock']?.toString() ?? '0');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.card, // ← cambiado
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Actualizar stock\n${product['product_name']}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.textPrimary)), // ← cambiado
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: cs.textPrimary), // ← cambiado
          decoration: InputDecoration(
            labelText: 'Nuevo stock',
            labelStyle: TextStyle(color: cs.textSec), // ← cambiado
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: cs.textHint)), // ← cambiado
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoStock = int.tryParse(ctrl.text.trim());
              if (nuevoStock == null || nuevoStock < 0) return;
              Navigator.pop(context);
              try {
                await _productService.updateStock(
                    product['id_product'].toString(), nuevoStock);
                _showMsg('Stock actualizado correctamente');
                _load();
              } on ApiException catch (e) {
                _showMsg(e.message, isError: true);
              } catch (_) {
                _showMsg('Error al actualizar el stock.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── _ProductCard ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onToggleStatus;
  final VoidCallback onEditStock;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.onToggleStatus,
    required this.onEditStock,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = AppColorScheme.of(context);
    final isDark    = cs.isDark;
    final activo    = product['status'] == true || product['status'] == 1;
    final stock     = product['stock']         ?? 0;
    final minStock  = product['minimun_stock'] ?? 0;
    final precio    = (product['selling_price'] ?? 0).toDouble();
    final tipo      = product['product_type']?['type'] ?? '';
    final stockBajo = stock <= minStock;

    // ── Colores adaptativos para los chips de stock
    final stockActualBg   = stockBajo
        ? AppColors.chipWarningBg
        : (isDark
            ? AppColors.statusSuccess.withOpacity(0.15)
            : AppColors.chipSuccessBg);

    final stockMinimoBg   = isDark
        ? Colors.white.withOpacity(0.07)   // ← gris sutil sobre tarjeta oscura
        : AppColors.surfaceLight;

    final stockMinimoText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textPrimaryLight;

    final stockMinimoHint = isDark
        ? AppColors.textHintDark
        : AppColors.textHintLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stockBajo && activo
              ? AppColors.statusWarning.withOpacity(0.5)
              : cs.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nombre + precio
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['product_name'] ?? '',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.textPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.statusInfo.withOpacity(0.15) // ← más visible en oscuro
                                : AppColors.chipInfoBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tipo,
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.statusInfo)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: activo
                                ? AppColors.statusSuccess
                                : AppColors.statusError,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                                fontSize: 9,
                                color: activo
                                    ? AppColors.statusSuccess
                                    : AppColors.statusError)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('\$${precio.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ],
          ),

          const SizedBox(height: 10),

          // ── Chips de stock
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: stockActualBg, // ← adaptativo
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('$stock',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: stockBajo
                                  ? AppColors.statusWarning
                                  : AppColors.statusSuccess)),
                      Text('Stock actual',
                          style: TextStyle(
                              fontSize: 9,
                              color: stockBajo
                                  ? AppColors.statusWarning
                                  : AppColors.statusSuccess)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: stockMinimoBg, // ← adaptativo
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.border),
                  ),
                  child: Column(
                    children: [
                      Text('$minStock',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: stockMinimoText)), // ← adaptativo
                      Text('Stock mínimo',
                          style: TextStyle(
                              fontSize: 9,
                              color: stockMinimoHint)), // ← adaptativo
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Botones de acción
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  color: AppColors.statusInfo,
                  bgColor: isDark
                      ? AppColors.statusInfo.withOpacity(0.15) // ← adaptativo
                      : AppColors.chipInfoBg,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.inventory_outlined,
                  label: 'Stock',
                  color: AppColors.statusWarning,
                  bgColor: isDark
                      ? AppColors.statusWarning.withOpacity(0.15) // ← adaptativo
                      : AppColors.chipWarningBg,
                  onTap: onEditStock,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  icon: activo
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  label: activo ? 'Deshabilitar' : 'Habilitar',
                  color: activo
                      ? AppColors.statusError
                      : AppColors.statusSuccess,
                  bgColor: activo
                      ? (isDark
                          ? AppColors.statusError.withOpacity(0.15) // ← adaptativo
                          : AppColors.chipErrorBg)
                      : (isDark
                          ? AppColors.statusSuccess.withOpacity(0.15) // ← adaptativo
                          : AppColors.chipSuccessBg),
                  onTap: onToggleStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _ActionBtn ────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.label,
    required this.color, required this.bgColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}