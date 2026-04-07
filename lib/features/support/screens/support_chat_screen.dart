import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

/// AI-first support chat. Bot handles app questions; escalates to live agent.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});
  @override
  ConsumerState<SupportChatScreen> createState() =>
      _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _connectedToAgent = false;
  String? _agentName;
  String? _ticketId;

  static const _systemPrompt = '''
You are GACOM's AI support assistant. GACOM is a social gaming platform for competitive gamers in Nigeria and Africa.

Features you can help with:
- Registration / Login issues
- Wallet funding (Paystack), withdrawals
- Competition entry and prize claims
- Community creation (verified users only)
- Profile editing, avatar, gamer tag
- Settings: password change, notification, privacy
- Store / Marketplace navigation
- Ads / Campaign creation
- Verification (₦2,000 fee)

Be friendly, brief, and gaming-culture aware. Use emojis occasionally.

If the user's issue requires actual account access, refund, or complex financial help, respond EXACTLY with:
ESCALATE_TO_AGENT

Do not make up solutions. If unsure, suggest escalation.
''';

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      sender: 'bot',
      text:
          "Yo! 👾 I'm GACOM's support AI. What's the issue? I can help with account, wallet, competitions, communities and more. Or type **agent** to speak with a human.",
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(
          sender: 'user', text: text, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollDown();

    // User requested agent manually
    if (text.toLowerCase().contains('agent') ||
        text.toLowerCase().contains('human') ||
        text.toLowerCase().contains('customer care')) {
      await _escalateToAgent(reason: text);
      return;
    }

    if (_connectedToAgent) {
      // Forward message to agent ticket
      await _sendToAgentTicket(text);
      return;
    }

    // Call AI
    try {
      final history = _messages
          .where((m) => m.sender != 'system')
          .map((m) => {
                'role': m.sender == 'user' ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      final resp = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 400,
          'system': _systemPrompt,
          'messages': history,
        }),
      );

      if (!mounted) return;
      setState(() => _isTyping = false);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final reply =
            data['content']?[0]?['text'] as String? ?? 'Sorry, try again.';

        if (reply.trim() == 'ESCALATE_TO_AGENT') {
          await _escalateToAgent(reason: text);
        } else {
          setState(() {
            _messages.add(_ChatMessage(
                sender: 'bot', text: reply, timestamp: DateTime.now()));
          });
          _scrollDown();
        }
      } else {
        setState(() {
          _messages.add(_ChatMessage(
              sender: 'bot',
              text:
                  "Sorry, I'm having trouble right now. Type **agent** to speak with a human.",
              timestamp: DateTime.now()));
        });
        _scrollDown();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
              sender: 'bot',
              text: 'Network error. Type **agent** for human support.',
              timestamp: DateTime.now()));
        });
        _scrollDown();
      }
    }
  }

  Future<void> _escalateToAgent({required String reason}) async {
    final userId = SupabaseService.currentUserId;
    setState(() => _isTyping = false);

    try {
      // Find available agent
      final agents = await SupabaseService.client
          .from('exco_assignments')
          .select('exco_id, profiles!exco_id(display_name, is_online)')
          .eq('exco_role', 'customer_agent')
          .limit(5);

      Map<String, dynamic>? agent;
      for (final a in agents) {
        if (a['profiles']?['is_online'] == true) {
          agent = a;
          break;
        }
      }

      // Create support ticket
      final ticket = await SupabaseService.client
          .from('support_tickets')
          .insert({
        'user_id': userId,
        'issue': reason,
        'status': 'open',
        'assigned_agent_id': agent?['exco_id'],
        'ai_transcript': _messages
            .map((m) => '${m.sender}: ${m.text}')
            .join('\n'),
      }).select().single();

      _ticketId = ticket['id'] as String?;
      _connectedToAgent = true;
      _agentName =
          agent?['profiles']?['display_name'] as String? ?? null;

      setState(() {
        _messages.add(_ChatMessage(
          sender: 'system',
          text: agent != null
              ? '✅ Connected to agent **${_agentName}**. They can see your chat history and will respond shortly.'
              : '📋 Ticket created (ID: ${_ticketId?.substring(0, 8).toUpperCase()}). An agent will respond soon via notifications.',
          timestamp: DateTime.now(),
        ));
      });
      _scrollDown();
    } catch (_) {
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          sender: 'system',
          text:
              '⚠️ Could not connect to agent right now. Email support@gacom.gg',
          timestamp: DateTime.now(),
        ));
      });
      _scrollDown();
    }
  }

  Future<void> _sendToAgentTicket(String text) async {
    if (_ticketId == null) return;
    setState(() => _isTyping = false);
    try {
      await SupabaseService.client.from('support_messages').insert({
        'ticket_id': _ticketId,
        'sender_id': SupabaseService.currentUserId,
        'message': text,
        'is_agent': false,
      });
    } catch (_) {}
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _connectedToAgent
                  ? _agentName != null
                      ? _agentName!
                      : 'Support Agent'
                  : 'GACOM Support',
              style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700)),
          Text(
              _connectedToAgent ? 'Live Agent' : 'AI Assistant',
              style: TextStyle(
                  fontSize: 12,
                  color: _connectedToAgent
                      ? GacomColors.success
                      : GacomColors.textMuted)),
        ]),
        actions: [
          if (!_connectedToAgent)
            TextButton.icon(
              onPressed: () =>
                  _escalateToAgent(reason: 'User requested agent'),
              icon: const Icon(Icons.support_agent_rounded,
                  size: 16, color: GacomColors.deepOrange),
              label: const Text('Agent',
                  style: TextStyle(
                      color: GacomColors.deepOrange,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length && _isTyping) {
                return _TypingIndicator();
              }
              return _MessageBubble(msg: _messages[i])
                  .animate()
                  .fadeIn(duration: 200.ms);
            },
          ),
        ),
        _InputBar(
          controller: _msgCtrl,
          onSend: _sendMessage,
        ),
      ]),
    );
  }
}

class _ChatMessage {
  final String sender; // 'user', 'bot', 'system'
  final String text;
  final DateTime timestamp;
  _ChatMessage(
      {required this.sender,
      required this.text,
      required this.timestamp});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == 'user';
    final isSystem = msg.sender == 'system';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: GacomColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GacomColors.info.withOpacity(0.2))),
        child: Text(msg.text,
            style: const TextStyle(
                color: GacomColors.info, fontSize: 13),
            textAlign: TextAlign.center),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  gradient: GacomColors.orangeGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? GacomColors.deepOrange
                    : GacomColors.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: GacomColors.border, width: 0.5),
              ),
              child: Text(msg.text,
                  style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : GacomColors.textPrimary,
                      fontSize: 14,
                      height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
              gradient: GacomColors.orangeGradient,
              shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy_rounded,
              color: Colors.white, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: GacomColors.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: GacomColors.border, width: 0.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0),
            const SizedBox(width: 4),
            _Dot(delay: 200),
            const SizedBox(width: 4),
            _Dot(delay: 400),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
            color: GacomColors.textMuted, shape: BoxShape.circle),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
          .then()
          .fadeOut(duration: 400.ms);
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: GacomColors.darkVoid,
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: GacomColors.surfaceDark,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: GacomColors.border)),
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  color: GacomColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: GacomColors.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSend,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                gradient: GacomColors.orangeGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
