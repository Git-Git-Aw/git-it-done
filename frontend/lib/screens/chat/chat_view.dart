import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_services.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/format.dart';

/// Chat with the AI Dorm Manager. The same widget is used for the three modes:
/// `visitor` (no login), `tenant`, and `landlord`.
///
/// The AI never changes anything by itself. When it wants to (generate bills,
/// submit a report, send an inquiry...) it shows a confirmation card and
/// nothing happens until the person presses Confirm.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.mode});

  final String mode;

  @override
  State<ChatView> createState() => _ChatViewState();
}

enum _EntryKind { user, assistant, action }

class _Entry {
  _Entry.user(this.text)
      : kind = _EntryKind.user,
        action = null;

  _Entry.assistant(this.text)
      : kind = _EntryKind.assistant,
        action = null;

  _Entry.action(PendingAction pending)
      : kind = _EntryKind.action,
        text = '',
        action = pending;

  final _EntryKind kind;
  final String text;
  final PendingAction? action;

  /// For action cards: waiting, working, done, cancelled, or failed.
  String state = 'waiting';
  String message = '';
}

class _ChatViewState extends State<ChatView> {
  final List<_Entry> _entries = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _intro {
    switch (widget.mode) {
      case 'landlord':
        return 'Ask about payments, rooms, and repairs, or give a command such as '
            'generating bills. Every change needs your confirmation first.';
      case 'tenant':
        return 'Ask about your balance, due dates, or house rules, or tell me about a '
            'problem in your room. I will ask you to confirm before anything is sent.';
      default:
        return 'You are chatting as a visitor. I can share public information only: '
            'available rooms, rates, house rules, and requirements. '
            'You can also leave your name and contact number for the landlord.';
    }
  }

  List<String> get _suggestions {
    switch (widget.mode) {
      case 'landlord':
        return const [
          'Who is overdue this month?',
          'Which rooms are vacant?',
          'Show the open maintenance reports',
          'Generate bills for this month',
        ];
      case 'tenant':
        return const [
          'What is my balance?',
          'When is my next due date?',
          'What are the house rules?',
          'The faucet in my room is leaking',
        ];
      default:
        return const [
          'Which rooms are available?',
          'What are the rates?',
          'What are the house rules?',
          'I want to leave my contact number',
        ];
    }
  }

  List<Map<String, String>> _historyForApi() {
    final messages = <Map<String, String>>[];
    for (final entry in _entries) {
      if (entry.kind == _EntryKind.user) {
        messages.add({'role': 'user', 'content': entry.text});
      } else if (entry.kind == _EntryKind.assistant) {
        messages.add({'role': 'assistant', 'content': entry.text});
      }
    }
    return messages.length > 12 ? messages.sublist(messages.length - 12) : messages;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _entries.add(_Entry.user(text));
      _sending = true;
      _error = null;
      _input.clear();
    });
    _scrollDown();
    try {
      final data = await AppServices.api.post(
        '/api/chat',
        body: {'messages': _historyForApi()},
      );
      final reply = ChatReply.fromJson(asMap(data));
      if (!mounted) return;
      setState(() {
        _entries.add(_Entry.assistant(reply.reply));
        for (final action in reply.pendingActions) {
          _entries.add(_Entry.action(action));
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // Take the failed message back so the person can send it again.
        _entries.removeLast();
        _input.text = text;
        _error = e.message;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollDown();
      }
    }
  }

  Future<void> _resolve(_Entry entry, bool confirm) async {
    final pending = entry.action;
    if (pending == null) return;
    final verb = confirm ? 'confirm' : 'cancel';
    setState(() {
      entry.state = 'working';
      entry.message = '';
    });
    try {
      final data = await AppServices.api.post('/api/chat/actions/${pending.id}/$verb');
      final outcome = ActionOutcome.fromJson(asMap(data));
      if (!mounted) return;
      setState(() {
        entry.state = outcome.status == 'executed' ? 'done' : 'cancelled';
        entry.message = outcome.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // No status code means the server was not reached, so the card stays
        // open and the person can try again.
        entry.state = e.statusCode == null ? 'waiting' : 'failed';
        entry.message = e.message;
      });
    }
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _intro,
                      style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _entries.isEmpty ? _buildWelcome() : _buildMessages(),
            ),
            if (_error != null)
              Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Dorm Manager',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Try one of these, or type your own question.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final text in _suggestions)
                  ActionChip(
                    label: Text(text),
                    onPressed: _sending ? null : () => _send(text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _entries.length) return const _TypingBubble();
        final entry = _entries[index];
        switch (entry.kind) {
          case _EntryKind.user:
            return _Bubble(text: entry.text, mine: true);
          case _EntryKind.assistant:
            return _Bubble(text: plainText(entry.text), mine: false);
          case _EntryKind.action:
            return _ActionCard(
              entry: entry,
              onConfirm: () => _resolve(entry, true),
              onCancel: () => _resolve(entry, false),
            );
        }
      },
    );
  }

  Widget _buildInputBar() {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Type your message',
                  counterText: '',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: _sending ? null : () => _send(),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: mine ? brandGradient : null,
            color: mine ? null : Colors.white,
            border: mine ? null : Border.all(color: const Color(0xFFEDE4F7)),
            boxShadow: softShadow,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: SelectableText(
            text,
            style: TextStyle(color: mine ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDE4F7)),
          boxShadow: softShadow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Dorm Manager is typing...',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

String _actionTitle(String tool) {
  switch (tool) {
    case 'generate_bills':
      return 'Generate monthly bills';
    case 'record_payment':
      return 'Record a payment';
    case 'update_maintenance_report':
      return 'Update a maintenance report';
    case 'post_announcement':
      return 'Post an announcement';
    case 'submit_maintenance_report':
      return 'Send a repair report to the landlord';
    case 'submit_inquiry':
      return 'Send your inquiry to the landlord';
    default:
      return titleCase(tool);
  }
}

/// The confirmation card: summary of what the AI wants to do, with Confirm and Cancel.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.entry,
    required this.onConfirm,
    required this.onCancel,
  });

  final _Entry entry;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = entry.action;
    if (pending == null) return const SizedBox.shrink();
    final open = entry.state == 'waiting' || entry.state == 'working';
    final working = entry.state == 'working';
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _actionTitle(pending.tool),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(pending.summary),
                const SizedBox(height: 10),
                if (open) ...[
                  Text(
                    'Nothing changes until you confirm.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: working ? null : onConfirm,
                        icon: working
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Confirm'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: working ? null : onCancel,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
                if (entry.state == 'done')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.message)),
                    ],
                  ),
                if (entry.state == 'cancelled')
                  Text(
                    entry.message.isEmpty ? 'Cancelled. Nothing was changed.' : entry.message,
                    style: TextStyle(color: theme.hintColor),
                  ),
                if (entry.message.isNotEmpty && (entry.state == 'failed' || entry.state == 'waiting'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entry.message,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
