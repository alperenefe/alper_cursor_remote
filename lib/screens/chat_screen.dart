import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:provider/provider.dart';



import '../models/chat_message.dart';
import '../models/prompt_attachment.dart';
import '../models/queued_prompt.dart';

import '../navigation/home_tab_controller.dart';
import '../services/attachment_picker_service.dart';
import '../state/app_state.dart';
import '../testing/e2e_flags.dart';
import '../testing/e2e_keys.dart';

import '../screens/sessions_sheet.dart';
import '../widgets/chat/bubble_message_body.dart';
import '../widgets/chat/session_activity_banner.dart';
import '../widgets/session_rename_dialog.dart';
import '../widgets/ui/app_option_sheet.dart';
import '../widgets/ui/chat_polish.dart';
import '../widgets/ui/composer_pickers.dart';
import '../widgets/ui/composer_speech_button.dart';

import '../theme/design_tokens.dart';



final _bubbleTimeFormat = DateFormat('HH:mm');



String _composerHint(AppState s) {

  if (!s.connected) {
    return 'Bağlanınca gönderilir — mesajı yazıp Gönder\'e bas';
  }

  if (s.composerQueueMode) {
    return 'Sıraya ekle — gönder veya Enter';
  }
  if (s.waitingResponse && s.busySendPolicy == BusySendPolicy.interrupt) {
    return 'Gönder — mevcut işi keser';
  }
  return 'Mesaj yazın…';

}



class ChatScreen extends StatefulWidget {

  const ChatScreen({super.key});



  @override

  State<ChatScreen> createState() => _ChatScreenState();

}



class _ChatScreenState extends State<ChatScreen> {

  final _ctrl = TextEditingController();

  final _searchCtrl = TextEditingController();

  final _scroll = ScrollController();



  bool _pinnedToBottom = true;

  bool _showScrollDown = false;

  bool _searchOpen = false;

  int _lastMessageCount = 0;
  String? _lastActiveSessionId;
  bool _listeningAppState = false;
  AppState? _appState;

  final List<PromptAttachment> _pendingAttachments = [];
  final _attachmentPicker = AttachmentPickerService();

  static const _pinThreshold = 100.0;



  @override

  void initState() {

    super.initState();

    _scroll.addListener(_onScroll);

    _searchCtrl.addListener(() => setState(() {}));

  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listeningAppState) return;
    _listeningAppState = true;
    _appState = context.read<AppState>();
    _lastActiveSessionId = _appState!.cursorSessionId;
    _appState!.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    _ctrl.dispose();
    _searchCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final s = _appState!;
    final sid = s.cursorSessionId;
    if (sid != null && sid != _lastActiveSessionId) {
      _lastActiveSessionId = sid;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final count = s.displayMessages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onMessagesChanged(count);
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchCtrl.clear();
    });
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirm = 'Evet',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: DesignTokens.amber500,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editQueuedMessage(
    AppState s,
    String messageId,
    String currentText,
  ) async {
    final ctrl = TextEditingController(text: currentText);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sıradaki mesajı düzenle'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 6,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Mesaj metni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    s.updateQueuedPrompt(messageId, text: ctrl.text);
    ctrl.dispose();
  }

  Future<void> _deleteQueuedMessage(AppState s, String messageId) async {
    if (!await _confirm(
      'Sıradaki mesajı sil?',
      'Bu mesaj kuyruktan ve sohbetten kaldırılır.',
      confirm: 'Sil',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    s.removeQueuedPrompt(messageId);
  }

  Future<void> _confirmClearQueue(AppState s) async {
    if (!mounted || !s.hasQueuedPrompts) return;
    if (!await _confirm(
      'Sırayı temizle?',
      '${s.queuedPromptCount} bekleyen mesaj silinecek.',
      confirm: 'Temizle',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    s.clearPromptQueue();
  }



  void _onScroll() {

    if (!_scroll.hasClients) return;

    final pos = _scroll.position;

    final pinned =

        pos.maxScrollExtent - pos.pixels <= _pinThreshold;

    final showDown = !pinned && pos.maxScrollExtent > 0;

    if (pinned != _pinnedToBottom || showDown != _showScrollDown) {

      setState(() {

        _pinnedToBottom = pinned;

        _showScrollDown = showDown;

      });

    }

  }



  void _scrollToBottom({bool force = false}) {

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!_scroll.hasClients) return;

      if (!force && !_pinnedToBottom) return;

      final target = _scroll.position.maxScrollExtent;

      if ((target - _scroll.offset).abs() < 4) return;

      _scroll.animateTo(

        target,

        duration: const Duration(milliseconds: 220),

        curve: Curves.easeOut,

      );

    });

  }



  void _onMessagesChanged(int count) {

    if (count > _lastMessageCount && _pinnedToBottom) {

      _scrollToBottom(force: true);

    }

    _lastMessageCount = count;

  }



  void _sendMessage(AppState s, {bool immediate = false}) {
    final text = _ctrl.text;
    final atts = List<PromptAttachment>.from(_pendingAttachments);
    if (text.trim().isEmpty && atts.isEmpty) return;

    setState(() {
      _pinnedToBottom = true;
      _pendingAttachments.clear();
    });
    _ctrl.clear();
    s.sendPrompt(text, immediate: immediate, attachments: atts);
    _scrollToBottom(force: true);
  }

  Future<void> _showAttachSourceSheet() async {
    final source = await showAppOptionSheet<String>(
      context: context,
      title: 'Ek ekle',
      options: const [
        AppSheetOption(
          value: 'gallery',
          title: 'Galeri',
          subtitle: 'Fotoğraf veya video',
          icon: Icons.photo_library_outlined,
        ),
        AppSheetOption(
          value: 'camera',
          title: 'Kamera',
          subtitle: 'Anında çek',
          icon: Icons.photo_camera_outlined,
        ),
        AppSheetOption(
          value: 'file',
          title: 'Dosya',
          subtitle: 'PDF, metin ve diğerleri',
          icon: Icons.attach_file,
        ),
      ],
    );
    if (!mounted || source == null) return;

    try {
      switch (source) {
        case 'gallery':
          await _addPicked(await _attachmentPicker.pickFromGallery());
        case 'camera':
          final one = await _attachmentPicker.pickFromCamera();
          if (one != null) await _addPicked([one]);
        case 'file':
          await _addPicked(await _attachmentPicker.pickFiles());
      }
    } on AttachmentPickException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ek seçilemedi. İzinleri kontrol edin.')),
      );
    }
  }

  Future<void> _addPicked(List<PromptAttachment> picked) async {
    if (picked.isEmpty) return;
    AttachmentPickerService.ensureCanAdd(_pendingAttachments, picked);
    if (!mounted) return;
    setState(() => _pendingAttachments.addAll(picked));
  }



  List<ChatMessage> _filterMessages(List<ChatMessage> all) {

    final q = _searchCtrl.text.trim().toLowerCase();

    if (q.isEmpty) return all;

    return all

        .where((m) => m.text.toLowerCase().contains(q))

        .toList();

  }



  @override

  Widget build(BuildContext context) {

    final s = context.watch<AppState>();

    final allMessages = s.displayMessages;

    final messages = _filterMessages(allMessages);

    final searchActive = _searchCtrl.text.trim().isNotEmpty;



    final listBottomPad = 96.0 +
        (_pendingAttachments.isNotEmpty ? 48.0 : 0.0) +
        (MediaQuery.paddingOf(context).bottom);

    final showStatusBanner = !s.connected &&
        s.statusNote != null &&
        s.statusNote!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
      bottom: false,
      child: Column(

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),

            child: Row(

              children: [

                Expanded(
                  child: ConnectionStatusPill(state: s),
                ),

                IconButton(

                  tooltip: _searchOpen ? 'Aramayı kapat' : 'Sohbette ara',

                  onPressed: () {
                    if (_searchOpen) {
                      _closeSearch();
                    } else {
                      setState(() => _searchOpen = true);
                    }
                  },

                  icon: Icon(

                    _searchOpen ? Icons.search_off : Icons.search,

                    size: 22,

                  ),

                  color: _searchOpen || searchActive

                      ? DesignTokens.blue600

                      : DesignTokens.slate400,

                ),

                if (s.canDisconnect)

                  IconButton(

                    tooltip: s.isHandshaking ? 'İptal et' : 'Bağlantıyı kes',

                    onPressed: () => s.disconnect(),

                    icon: const Icon(Icons.link_off, size: 22),

                    color: DesignTokens.amber500,

                  ),

                if (!s.canDisconnect && s.hasSavedConnection)

                  Padding(

                    padding: const EdgeInsets.only(right: 4),

                    child: FilledButton.tonal(

                      onPressed:

                          s.settingsReady ? () => s.connectWithSaved() : null,

                      style: FilledButton.styleFrom(

                        visualDensity: VisualDensity.compact,

                        padding: const EdgeInsets.symmetric(horizontal: 12),

                      ),

                      child: const Text('Bağlan'),

                    ),

                  ),

                if (s.loadingHistory)

                  const Padding(

                    padding: EdgeInsets.only(right: 8),

                    child: SizedBox(

                      width: 18,

                      height: 18,

                      child: CircularProgressIndicator(strokeWidth: 2),

                    ),

                  ),

                IconButton(
                  key: E2eKeys.openSessions,
                  tooltip: 'Oturumlar ve geçmiş',

                  onPressed: s.connected

                      ? () => showSessionsSheet(context)

                      : null,

                  icon: Badge(
                    isLabelVisible: s.flowingSessionCount > 0,
                    label: Text(
                      '${s.flowingSessionCount}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: DesignTokens.amber500,
                    child: const Icon(Icons.history, size: 22),
                  ),

                ),

                if (s.isPcBusy)

                  const SizedBox(

                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(strokeWidth: 2),

                  ),

              ],

            ),

          ),

          if (_searchOpen)

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),

              child: TextField(

                controller: _searchCtrl,

                autofocus: true,

                decoration: InputDecoration(

                  hintText: 'Mesajlarda ara…',

                  isDense: true,

                  filled: true,

                  fillColor: DesignTokens.slate800,

                  prefixIcon: const Icon(Icons.search, size: 20),

                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchCtrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          tooltip: 'Metni temizle',
                          onPressed: () => _searchCtrl.clear(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Aramayı kapat',
                        onPressed: _closeSearch,
                      ),
                    ],
                  ),

                  border: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(10),

                    borderSide:

                        const BorderSide(color: DesignTokens.borderSubtle),

                  ),

                ),

              ),

            ),

          if (searchActive)

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),

              child: Align(

                alignment: Alignment.centerLeft,

                child: Text(

                  '${messages.length} / ${allMessages.length} mesaj',

                  style: TextStyle(fontSize: 12, color: DesignTokens.slate500),

                ),

              ),

            ),

          AgentWorkingStrip(state: s),
          const SessionActivityBanner(),

          if (s.connected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SessionSelectorTile(
                state: s,
                onOpenSessions: () => showSessionsSheet(context),
                onRename: () => showSessionRenameDialog(
                  context,
                  s,
                  sessionId: s.renameableActiveSessionId,
                ),
              ),
            ),

          if (showStatusBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: DesignTokens.amber500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DesignTokens.amber500.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: DesignTokens.amber500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.statusNote!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: DesignTokens.slate200,
                          ),
                        ),
                      ),
                      if (!s.connected && s.hasSavedConnection)
                        FilledButton.tonal(
                          onPressed: s.settingsReady && !s.isLinkInProgress
                              ? () => s.connectWithSaved()
                              : null,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            s.isLinkInProgress ? 'Bağlanıyor…' : 'Tekrar dene',
                          ),
                        )
                      else if (!s.canDisconnect && s.hasSavedConnection)
                        TextButton(
                          onPressed: s.settingsReady
                              ? () => s.connectWithSaved()
                              : null,
                          child: const Text('Bağlan'),
                        )
                      else if (!s.hasSavedConnection)
                        TextButton(
                          onPressed: () =>
                              HomeTabController.goToConnection(context),
                          child: const Text('Ayarlar'),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          Expanded(

            child: Stack(

              alignment: Alignment.bottomCenter,

              children: [

                if (messages.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ChatEmptyStateView(
                        state: s,
                        searchActive: searchActive,
                        onReconnect: () => s.tryAutoConnect(),
                      ),
                    ),
                  )

                else

                  ListView.builder(

                    controller: _scroll,

                    padding: EdgeInsets.fromLTRB(12, 0, 12, listBottomPad),

                    itemCount: messages.length,

                    itemBuilder: (context, i) {

                      final msg = messages[i];

                      return _Bubble(
                        message: msg,
                        highlight: _searchCtrl.text.trim(),
                        isQueued: s.isQueuedUserMessage(msg.id),
                        isAwaitingReply: s.isAwaitingReplyUserMessage(msg.id),
                        onSendQueuedNow: () => s.sendQueuedMessageNow(msg.id),
                        onEditQueued: () {
                          for (final q in s.queuedPrompts) {
                            if (q.localMessageId == msg.id) {
                              _editQueuedMessage(s, msg.id, q.text);
                              break;
                            }
                          }
                        },
                        onDeleteQueued: () => _deleteQueuedMessage(s, msg.id),
                      );

                    },

                  ),

                if (_showScrollDown && messages.isNotEmpty)

                  Padding(

                    padding: const EdgeInsets.only(bottom: 12),

                    child: FloatingActionButton.small(

                      heroTag: 'chat_scroll_end',

                      tooltip: 'En alta in',

                      onPressed: () {

                        setState(() => _pinnedToBottom = true);

                        _scrollToBottom(force: true);

                      },

                      backgroundColor: DesignTokens.blue600,

                      child: const Icon(Icons.keyboard_arrow_down),

                    ),

                  ),

              ],

            ),

          ),

          DecoratedBox(
            decoration: const BoxDecoration(
              color: DesignTokens.slate900,
              boxShadow: DesignTokens.composerShadow,
            ),
            child: Padding(

              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),

              child: Column(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  if (_pendingAttachments.isNotEmpty)
                    _PendingAttachmentChips(
                      items: _pendingAttachments,
                      onRemove: (index) => setState(
                        () => _pendingAttachments.removeAt(index),
                      ),
                    ),
                  _CursorComposerBox(
                    s: s,
                    controller: _ctrl,
                    hasPendingAttachments: _pendingAttachments.isNotEmpty,
                    onAttach: _showAttachSourceSheet,
                    onClearQueue: () => _confirmClearQueue(s),
                    onSend: () => _sendMessage(
                      s,
                      immediate: s.waitingResponse &&
                          s.busySendPolicy == BusySendPolicy.interrupt,
                    ),
                  ),
                ],

              ),

            ),

          ),

        ],

      ),

    ),
    );

  }

}



class _Bubble extends StatelessWidget {

  const _Bubble({

    required this.message,

    this.highlight = '',

    this.isQueued = false,
    this.isAwaitingReply = false,
    this.onSendQueuedNow,
    this.onEditQueued,
    this.onDeleteQueued,
  });

  final ChatMessage message;
  final String highlight;
  final bool isQueued;
  final bool isAwaitingReply;
  final VoidCallback? onSendQueuedNow;
  final VoidCallback? onEditQueued;
  final VoidCallback? onDeleteQueued;



  void _showQueuedBubbleMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(ctx);
                onEditQueued?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Hemen gönder'),
              onTap: () {
                Navigator.pop(ctx);
                onSendQueuedNow?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: DesignTokens.amber500),
              title: const Text('Sıradan sil'),
              onTap: () {
                Navigator.pop(ctx);
                onDeleteQueued?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    final isLog = message.role == ChatRole.log;

    final isProgress = message.role == ChatRole.progress;

    final bg = isUser

        ? DesignTokens.blue600.withValues(alpha: 0.25)

        : isLog

            ? DesignTokens.slate800

            : isProgress

                ? Colors.transparent

                : DesignTokens.slate900;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    Key? e2eBubbleKey;
    if (E2eFlags.enabled && isUser) {
      final tag = RegExp(r'\[E2E [^\]]+\]').firstMatch(message.text)?.group(0);
      if (tag != null) {
        e2eBubbleKey = Key('e2e_bubble_$tag');
      }
    }

    if (isProgress) {

      return Padding(

        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),

        child: Align(

          alignment: Alignment.centerLeft,

          child: Text(

            message.text,

            style: TextStyle(

              fontSize: 12,

              height: 1.35,

              color: DesignTokens.slate500,

              fontStyle: FontStyle.italic,

            ),

          ),

        ),

      );

    }



    return GestureDetector(
      onLongPress: () {
        if (isQueued && onEditQueued != null && onDeleteQueued != null) {
          _showQueuedBubbleMenu(context);
          return;
        }
        if (message.text.trim().isEmpty) return;
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metin panoya kopyalandı'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [

          if (message.agentMode != null && isUser)

            Text(

              'Mod: ${agentModeLabel(message.agentMode!)}',

              style: TextStyle(fontSize: 11, color: DesignTokens.slate500),

            ),

          Container(
            key: e2eBubbleKey,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.84,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: isUser
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
              border: Border.all(

                color: isQueued
                    ? DesignTokens.amber500.withValues(alpha: 0.55)
                    : isAwaitingReply
                        ? DesignTokens.blue600.withValues(alpha: 0.45)
                        : DesignTokens.borderSubtle,

              ),

            ),

            child: BubbleMessageBody(
              text: message.text,
              isUser: isUser,
              highlight: highlight,
              isStreaming: message.isStreaming,
              baseStyle: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isLog ? DesignTokens.slate400 : DesignTokens.slate200,
                fontStyle:
                    message.isStreaming ? FontStyle.italic : FontStyle.normal,
              ),
            ),

          ),

          Padding(

            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Text(

                  _bubbleTimeFormat.format(message.at.toLocal()),

                  style: TextStyle(

                    fontSize: 10,

                    color: DesignTokens.slate500,

                  ),

                ),

                if (isQueued) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Sırada',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.amber500,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Düzenle',
                    onPressed: onEditQueued,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: DesignTokens.slate400,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Sıradan sil',
                    onPressed: onDeleteQueued,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: DesignTokens.slate400,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Hemen gönder (kes)',
                    onPressed: onSendQueuedNow,
                    icon: const Icon(Icons.bolt, size: 18),
                    color: DesignTokens.amber500,
                  ),
                ] else if (isAwaitingReply) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Yanıt bekleniyor',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.blue600,
                    ),
                  ),
                ],

              ],

            ),

          ),

        ],

      ),

    ),
    );

  }

}



/// Cursor Composer: metin üstte, mod/sıra/aksiyonlar altta tek satır.
class _PendingAttachmentChips extends StatelessWidget {
  const _PendingAttachmentChips({
    required this.items,
    required this.onRemove,
  });

  final List<PromptAttachment> items;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (var i = 0; i < items.length; i++)
            InputChip(
              label: Text(
                items[i].displayLabel,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              avatar: _AttachmentChipAvatar(item: items[i]),
              onDeleted: () => onRemove(i),
              deleteIconColor: DesignTokens.slate400,
              backgroundColor: DesignTokens.slate800,
              side: const BorderSide(color: DesignTokens.borderSubtle),
            ),
        ],
      ),
    );
  }
}

class _CursorComposerBox extends StatefulWidget {
  const _CursorComposerBox({
    required this.s,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onClearQueue,
    this.hasPendingAttachments = false,
  });

  final AppState s;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onClearQueue;
  final bool hasPendingAttachments;

  @override
  State<_CursorComposerBox> createState() => _CursorComposerBoxState();
}

class _CursorComposerBoxState extends State<_CursorComposerBox> {
  final GlobalKey<ComposerSpeechButtonState> _speechKey =
      GlobalKey<ComposerSpeechButtonState>();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _sendStoppingSpeech() {
    _speechKey.currentState?.stopIfListening();
    widget.onSend();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final queueMode = s.composerQueueMode;
    final canSend = widget.controller.text.trim().isNotEmpty ||
        widget.hasPendingAttachments;

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.slate800,
        borderRadius: DesignTokens.radiusMd,
        border: Border.all(
          color: queueMode
              ? DesignTokens.amber500.withValues(alpha: 0.35)
              : DesignTokens.borderSubtle,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 128),
            child: TextField(
            key: E2eKeys.chatComposer,
            controller: widget.controller,
            enabled: s.connected,
            autofocus: false,
            maxLines: 6,
            minLines: 1,
            style: const TextStyle(fontSize: 15, height: 1.35),
            textInputAction: TextInputAction.send,
            onSubmitted: canSend ? (_) => _sendStoppingSpeech() : null,
            decoration: InputDecoration(
              hintText: _composerHint(s),
              hintStyle: TextStyle(color: DesignTokens.slate500, fontSize: 14),
              contentPadding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 4),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (s.connected) ...[
                          ComposerAgentModeMenu(
                            selected: s.promptAgentMode,
                            enabled: !s.isActiveSessionAwaitingAgent,
                            onSelected: s.setPromptAgentMode,
                          ),
                          const SizedBox(width: 6),
                          ComposerBusyPolicyChip(
                            policy: s.busySendPolicy,
                            enabled: !s.isActiveSessionAwaitingAgent,
                            onSelected: s.setBusySendPolicy,
                          ),
                        ],
                        if (s.hasQueuedPrompts)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _QueuedBadge(
                              count: s.queuedPromptCount,
                              onClear:
                                  widget.onClearQueue ?? s.clearPromptQueue,
                            ),
                          ),
                        if (s.connected)
                          ComposerSpeechButton(
                            key: _speechKey,
                            enabled: !s.isActiveSessionAwaitingAgent,
                            controller: widget.controller,
                            onError: (msg) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            },
                          ),
                        if (widget.onAttach != null)
                          IconButton(
                            tooltip: 'Ek ekle (galeri, kamera, dosya)',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: widget.onAttach,
                            icon: const Icon(Icons.attach_file, size: 20),
                            color: widget.hasPendingAttachments
                                ? DesignTokens.blue600
                                : DesignTokens.slate400,
                          ),
                        if (s.canStopWaitingAgent)
                          IconButton(
                            tooltip: 'Yanıt beklemeyi iptal et',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: s.stopPrompt,
                            icon: const Icon(Icons.stop_circle_outlined,
                                size: 22),
                            color: DesignTokens.amber500,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _ComposerSendButton(
                  enabled: canSend,
                  queueMode: queueMode,
                  onPressed: _sendStoppingSpeech,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChipAvatar extends StatelessWidget {
  const _AttachmentChipAvatar({required this.item});

  final PromptAttachment item;

  @override
  Widget build(BuildContext context) {
    if (!item.isImage || item.base64.isEmpty) {
      return Icon(
        Icons.insert_drive_file,
        size: 18,
        color: DesignTokens.slate400,
      );
    }
    try {
      final bytes = base64Decode(item.base64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          cacheWidth: 56,
          cacheHeight: 56,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 18),
        ),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, size: 18);
    }
  }
}

class _QueuedBadge extends StatelessWidget {
  const _QueuedBadge({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sırayı temizle',
      child: Material(
      color: DesignTokens.amber500.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 13, color: DesignTokens.amber500),
              const SizedBox(width: 4),
              Text(
                '$count sırada',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.amber500,
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

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.enabled,
    required this.queueMode,
    required this.onPressed,
  });

  final bool enabled;
  final bool queueMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: queueMode ? 'Sıraya ekle' : 'Gönder',
      child: Material(
        color: enabled ? DesignTokens.blue600 : DesignTokens.slate700,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: E2eKeys.sendMessage,
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              queueMode ? Icons.queue : Icons.arrow_upward,
              size: 20,
              color: enabled ? Colors.white : DesignTokens.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

