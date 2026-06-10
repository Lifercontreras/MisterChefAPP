import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/chatbot_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_bottom_nav.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _chatbotService = ChatbotService();
  final _msgCtrl        = TextEditingController();
  final _scrollCtrl     = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  final List<String> _suggestions = [
    '¿Cuántos clientes me faltan visitar hoy?',
    '¿Cómo van mis ventas del día?',
    '¿Qué productos tienen stock bajo?',
    '¿Cuáles son mis clientes más cercanos?',
    '¿Cuándo fue la última compra de mis clientes?',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isSending) return;
    _msgCtrl.clear();

    final needsLocation = _mentionsLocation(msg);
    double? lat, lng;

    if (needsLocation) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
    }

    setState(() {
      _messages.add({'role': 'user', 'text': msg, 'loading': false});
      _messages.add({'role': 'bot',  'text': '',  'loading': true});
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await _chatbotService.sendMessage(
          msg, latitude: lat, longitude: lng);
      if (mounted) {
        setState(() {
          _messages.last = {'role': 'bot', 'text': response, 'loading': false};
        });
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _messages.last = {'role': 'bot', 'text': 'Error: ${e.message}', 'loading': false};
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.last = {'role': 'bot', 'text': 'Error al conectar con el asistente.', 'loading': false};
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _mentionsLocation(String msg) {
    final lower = msg.toLowerCase();
    return ['cerca', 'cercano', 'próximo', 'proximo', 'ubicación',
            'ubicacion', 'distancia', 'donde estoy'].any(lower.contains);
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.chatbot),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(cs)  // ← pasa cs
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return m['role'] == 'user'
                          ? _UserBubble(text: m['text'])
                          : _BotBubble(
                              text: m['text'],
                              isLoading: m['loading'] as bool,
                            );
                    },
                  ),
          ),
          _buildInput(cs), // ← pasa cs
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
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asistente Mister Chef',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500, color: Colors.white)),
                  Text('Siempre disponible para ayudarte',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorScheme cs) { // ← recibe cs
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 14),
          Text('¿En qué puedo ayudarte?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                  color: cs.textPrimary)), // ← cambiado
          const SizedBox(height: 6),
          Text('Puedo consultarte sobre clientes, ventas, stock y más.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.textHint)), // ← cambiado
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('SUGERENCIAS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: cs.textSec, letterSpacing: 1.2)), // ← cambiado
          ),
          const SizedBox(height: 10),
          ..._suggestions.map((s) => GestureDetector(
            onTap: () => _send(s),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.card, // ← cambiado
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.border), // ← cambiado
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s,
                      style: TextStyle(fontSize: 13,
                          color: cs.textPrimary))), // ← cambiado
                  Icon(Icons.arrow_forward_ios,
                      color: cs.border, size: 12), // ← cambiado
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInput(AppColorScheme cs) { // ← recibe cs
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: cs.card, // ← cambiado
        border: Border(top: BorderSide(color: cs.border)), // ← cambiado
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: cs.textPrimary), // ← cambiado
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  hintStyle: TextStyle(color: cs.textHint, fontSize: 13), // ← cambiado
                  filled: true,
                  fillColor: cs.surface, // ← cambiado
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: cs.border)), // ← cambiado
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: cs.border)), // ← cambiado
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
                onSubmitted: _isSending ? null : _send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : () => _send(_msgCtrl.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _isSending ? cs.border : AppColors.primary, // ← cambiado
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSending ? Icons.hourglass_empty : Icons.send_rounded,
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Burbuja del usuario
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: Colors.white,
                height: 1.4)),
      ),
    );
  }
}

// ── Burbuja del bot
class _BotBubble extends StatelessWidget {
  final String text;
  final bool isLoading;
  const _BotBubble({required this.text, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 8, bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: AppColors.primary, size: 14),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10, right: 50),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.card, // ← cambiado
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(color: cs.border), // ← cambiado
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 40, height: 16,
                      child: _TypingIndicator(),
                    )
                  : Text(text,
                      style: TextStyle(fontSize: 13,
                          color: cs.textPrimary, height: 1.4)), // ← cambiado
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicador de "escribiendo..."
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay   = i / 3;
            final t       = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 4),
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}