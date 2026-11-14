import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/distribution_preview_logic.dart';
import '../../services/api_service.dart';
import '../../services/route_service.dart';

/// Vista previa de la redistribución total de clientes entre vendedores.
///
/// La pantalla calcula la propuesta por sí sola al abrirse (para poder
/// recalcularla si el reparto cambió) y no escribe nada hasta que el
/// administrador confirma el botón inferior.
class RouteDistributionPreviewScreen extends StatefulWidget {
  const RouteDistributionPreviewScreen({super.key});

  @override
  State<RouteDistributionPreviewScreen> createState() =>
      _RouteDistributionPreviewScreenState();
}

class _RouteDistributionPreviewScreenState
    extends State<RouteDistributionPreviewScreen> {
  final _routeService = RouteService();

  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preview = await _routeService.previewDistribution();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo calcular la vista previa.';
        _loading = false;
      });
    }
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || _applying) return;

    final fingerprint = preview['fingerprint']?.toString() ?? '';
    if (fingerprint.isEmpty) {
      _showMsg(
        'No se pudo aplicar: la vista previa no trae un identificador válido.',
        isError: true,
      );
      return;
    }

    final changed = countClientsWithChangedAssignment(preview);
    final newAssignments = countNewAssignmentClients(preview);
    final cs = AppColorScheme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Aplicar distribución',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: cs.textPrimary,
          ),
        ),
        content: Text(
          changed == 0
              ? 'No se detectaron clientes que cambien de vendedor.\n\n'
                  'Esta acción reemplaza todas las asignaciones actuales, '
                  'incluidas las manuales.'
              : 'Cambiarán de vendedor $changed clientes'
                  '${newAssignments > 0 ? ' ($newAssignments se asignan por primera vez)' : ''}.\n\n'
                  'Esta acción reemplaza todas las asignaciones actuales, '
                  'incluidas las manuales.',
          style: TextStyle(fontSize: 13, color: cs.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: TextStyle(color: cs.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);

    try {
      final res = await _routeService.applyDistribution(fingerprint);
      if (!mounted) return;

      final applied = res['applied'];
      final clients = applied is Map ? applied['clients'] ?? 0 : 0;
      _showMsg('Distribución aplicada: $clients clientes asignados');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // El reparto cambió: no se escribió nada y se muestra la versión nueva.
        _showMsg('El reparto cambió, se recalculó la vista previa.');
        await _loadPreview();
      } else {
        _showMsg(e.message, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showMsg('Error al aplicar la distribución.', isError: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.statusError : AppColors.statusSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody(cs)),
          if (_preview != null && !_loading && _error == null)
            _buildBottomBar(cs),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vista previa de distribución',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme cs) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: cs.textHint.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPreview,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final preview = _preview;
    if (preview == null) {
      return const SizedBox.shrink();
    }

    final summary = preview['summary'];
    final summaryMap =
        summary is Map ? Map<String, dynamic>.from(summary) : const <String, dynamic>{};
    final sellers = previewSellers(preview);
    final skipped = previewSkipped(preview);

    final clients = summaryMap['clients'] ??
        sellers.fold<int>(
          0,
          (total, seller) => total + sellerClients(seller).length,
        );
    final sellersCount = summaryMap['sellers'] ?? sellers.length;
    final skippedCount =
        summaryMap['skipped_without_coordinates'] ?? skipped.length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildWarning(cs),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                value: '$clients',
                label: 'Clientes a repartir',
                color: AppColors.primary,
                cs: cs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                value: '$sellersCount',
                label: 'Vendedores',
                color: AppColors.statusInfo,
                cs: cs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                value: '$skippedCount',
                label: 'Omitidos',
                color: AppColors.statusWarning,
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'VENDEDORES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.textSec,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        ...sellers.map((seller) => _buildSellerCard(seller, cs)),
        if (skipped.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'OMITIDOS (SIN COORDENADAS)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.textSec,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildSkippedCard(skipped, cs),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWarning(AppColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.statusWarning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esto reasigna TODOS los clientes desde cero, incluidas las '
              'asignaciones manuales. Nada se guarda hasta que presiones '
              'Aplicar.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: cs.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller, AppColorScheme cs) {
    final name = sellerFullName(seller);
    final current = seller['current_clients'] ?? 0;
    final next = seller['new_clients'] ?? 0;
    final clients = sellerClients(seller);
    final document = normalizeEmployeeDocument(seller['document_employee']) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Tiene $current → recibirá $next',
              style: TextStyle(fontSize: 11, color: cs.textHint),
            ),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'V',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          children: [
            Divider(height: 1, color: cs.border),
            if (clients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sin clientes asignados en esta propuesta',
                  style: TextStyle(fontSize: 11, color: cs.textHint),
                ),
              )
            else
              ...clients.map(
                (client) => _buildClientRow(client, document, cs),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientRow(
    Map<String, dynamic> client,
    String sellerDocument,
    AppColorScheme cs,
  ) {
    final change = classifyClientChange(client, sellerDocument);
    final address = client['address']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.location_on_outlined,
              size: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientPreviewName(client),
                  style: TextStyle(fontSize: 12, color: cs.textPrimary),
                ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    style: TextStyle(fontSize: 10, color: cs.textHint),
                  ),
              ],
            ),
          ),
          if (change != ClientAssignmentChange.unchanged) ...[
            const SizedBox(width: 8),
            _ChangeBadge(change: change),
          ],
        ],
      ),
    );
  }

  Widget _buildSkippedCard(
    List<Map<String, dynamic>> skipped,
    AppColorScheme cs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: skipped
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 15,
                      color: AppColors.statusWarning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clientPreviewName(item),
                        style:
                            TextStyle(fontSize: 12, color: cs.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomBar(AppColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _applying ? null : _apply,
            icon: _applying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              _applying ? 'Aplicando...' : 'Aplicar distribución',
              style: const TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta compacta del resumen superior.
class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final AppColorScheme cs;

  const _SummaryTile({
    required this.value,
    required this.label,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: cs.textHint),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta discreta para clientes nuevos o reasignados.
class _ChangeBadge extends StatelessWidget {
  final ClientAssignmentChange change;

  const _ChangeBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final isNew = change == ClientAssignmentChange.newAssignment;
    final color = isNew ? AppColors.statusWarning : AppColors.statusInfo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isNew ? 'Nuevo' : 'Cambia',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
