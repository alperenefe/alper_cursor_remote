import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/prompt_attachment.dart';
import '../models/queued_prompt.dart';
import '../models/session_live_badge.dart';
import '../models/session_live_state.dart';
import '../models/session_summary.dart';
import '../models/traffic_entry.dart';
import '../services/assistant_text_sanitize.dart';
import 'session_registry.dart';
import 'session_isolation.dart';
import 'sessions/session_context.dart';
import 'sessions/session_list_builder.dart';
import 'chat/chat_message_match.dart';
import 'chat/chat_turn_logic.dart';
import 'chat/history_sync_protection.dart';
import 'display/conversation_display_order.dart';
import 'display/visible_messages_filter.dart';
import 'inbound/inbound_bucket_resolver.dart';
import 'inbound/inbound_session_resolver.dart';
import 'inbound/meaningful_assistant_inbound.dart';
import 'queue/global_queue_picker.dart';
import 'queue/prompt_queue_logic.dart';
import 'waiting/waiting_status_formatter.dart';
import 'sync/foreground_sync_targets.dart';
import 'sync/live_stream_reply_materialize.dart';
import 'sync/pending_turn_reconcile.dart';
import '../services/chat_history_applier.dart';
import '../services/history_trace_log.dart';
import '../services/session_trace_log.dart';
import '../services/cursor_ws_client.dart';
import '../services/message_parser.dart';
import '../services/settings_store.dart';
import '../services/ws_logger.dart';
import '../services/agent_work_notification.dart';
import '../services/local_session_cache.dart';
import '../services/session_reply_notification.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _init();
  }

  /// PC `get_chat_history` — oturum başına son N tur (kullanıcı+cevap kaydı).
  static const defaultChatHistoryLimit = 5;

  final _ws = CursorWsClient();
  final _settings = SettingsStore();

  String host = '';
  int port = 8766;
  String authToken = '';
  int responseIdleTimeoutMinutes = 45;
  bool settingsReady = false;
  /// Gönderilecek mesajın modu (sohbetten seçilir).
  String promptAgentMode = 'agent';
  bool showLogs = false;
  bool showSystem = false;
  bool mergeStreamChunks = true;
  /// false: chunk'lar balonda dönmez; yalnızca final cevap görünür.
  bool showStreamPreview = false;
  bool showProgress = true;
  bool mobileOptimizedPrompts = true;
  /// false = composer-2.5 (Fast kapalı, Edit ile aynı); true = composer-2.5-fast
  bool composerUseFast = false;
  String? lastProgressLine;
  DateTime? lastPcActivityAt;

  bool _socketUp = false;
  bool _sessionReady = false;
  bool _connecting = false;
  int _connectEpoch = 0;
  Timer? _responseIdleTimer;
  Timer? _waitDisplayTimer;
  Timer? _postCompleteHistoryTimer;
  Timer? _handshakeTimer;
  Timer? _queueFlushDebounce;
  static const handshakeTimeoutSeconds = 25;
  static const _handshakeTimeoutSeconds = handshakeTimeoutSeconds;

  bool get connected => _socketUp && _sessionReady;

  /// Soket açık ama auth / connected mesajı gelmedi (El sıkışılıyor…).
  bool get isHandshaking => _socketUp && !_sessionReady;

  /// TCP açılıyor.
  bool get isConnecting => _connecting;

  /// Bağlan / el sıkışma devam ediyor (UI kilidi).
  bool get isLinkInProgress => _connecting || isHandshaking;

  /// Bağlan, el sıkış veya tam bağlı — kesilebilir.
  bool get canDisconnect => isLinkInProgress || connected;
  BusySendPolicy busySendPolicy = BusySendPolicy.queue;
  bool autoReconnectEnabled = true;

  /// Uygulama arka planda (bildirim / cevap yüzeyi için).
  bool _appInBackground = false;
  bool get appInBackground => _appInBackground;

  void setAppInBackground(bool inBackground) {
    if (_appInBackground == inBackground) return;
    _appInBackground = inBackground;
    _scheduleAgentWorkNotificationSync();
  }

  final SessionRegistry _registry = SessionRegistry();
  /// Gönderim anı: user balon id → registry bucket (pending / local-* / uuid).
  final Map<String, String> _dispatchBucketByLocalMessageId = {};
  /// PC agent şu an hangi oturum için çalışıyor (tek süreç).
  String? _pcBusySessionKey;
  /// Arka planda cevap gelen oturum — UI bildirimi için.
  String? sessionAlertId;
  String? _sessionAlertPreview;

  SessionStore get _store => _registry.store;

  SessionResolver get _sessions => SessionResolver(_store);

  /// Gönderim / kuyruk — kullanıcının seçtiği `cursorSessionId` (getter yan etkisiz).
  String get _activeLocalId {
    final c = cursorSessionId?.trim();
    if (c == null || c.isEmpty) {
      return _store.activeOrCreate().localId;
    }
    _store.setActive(c);
    return c;
  }

  String get _activeSessionKey => _activeLocalId;

  void _ensureActiveSession() {
    final c = cursorSessionId?.trim();
    if (c == null || c.isEmpty) {
      cursorSessionId = _store.createSession();
    } else {
      _store.setActive(c);
    }
  }

  List<ChatMessage> get _allMessages => _registry.messagesFor(_activeLocalId);

  SessionLiveState get _live => _registry.liveFor(_activeLocalId);

  List<QueuedPrompt> get _promptQueue => _live.queue;

  bool get isPcBusy =>
      _pcBusySessionKey != null &&
      _registry.liveFor(_pcBusySessionKey).waitingResponse;

  /// Yalnızca aktif oturum PC'de çalışıyorsa (başka oturum meşgulü bu oturumu sıraya zorlamaz).
  bool get isActiveSessionPcBusy =>
      isPcBusy && _pcBusySessionKey == _activeSessionKey;

  /// Aktif oturum veya bu oturum için PC meşgul bayrağı.
  bool get waitingResponse {
    if (_live.waitingResponse) return true;
    final busy = _pcBusySessionKey;
    if (busy != null &&
        busy == _activeSessionKey &&
        _registry.liveFor(busy).waitingResponse) {
      return true;
    }
    return _live.inFlight != null;
  }

  /// Yalnızca açık sohbet oturumu agent bekliyor (diğer oturum PC'de çalışsa bile).
  bool get isActiveSessionAwaitingAgent {
    final live = _live;
    return live.waitingResponse || live.inFlight != null;
  }

  String? statusNote;
  /// Telefonda kalıcı; PC her WS bağlantısında yeni ID üretmesin diye biz göndeririz.
  String deviceClientId = '';
  String? cursorSessionId;
  String? _restoredSessionId;
  /// Oturum bazlı geçmiş isteği bitince aktif sekmeyi değiştirmeden merge.
  String? _pendingHistorySessionFilter;
  bool loadingHistory = false;
  bool _historyLoadedForConnection = false;
  /// «Yenile» — yalnızca liste; aktif oturumu ve sohbeti değiştirme.
  bool _historyRefreshListOnly = false;
  Completer<bool>? _deleteSessionCompleter;
  Completer<int>? _clearAllCompleter;
  final Map<String, Completer<void>> _historyLoadWaiters = {};
  Timer? _foregroundSyncDebounce;
  Timer? _agentNotifDebounce;
  Timer? _localCacheDebounce;
  String? _pendingDeleteSessionId;
  String? _lastDeleteError;

  List<SessionSummary> sessionSummaries = [];
  Map<String, String> sessionNames = {};
  List<Map<String, dynamic>> _historyEntries = [];

  final List<TrafficEntry> _traffic = [];
  static const _maxTraffic = 200;

  List<ChatMessage> get visibleMessages => filterVisibleMessages(
        _allMessages,
        showLogs: showLogs,
        showSystem: showSystem,
        mergeStreamChunks: mergeStreamChunks,
        showProgress: showProgress,
      );

  List<ChatMessage> _sortedChatMessagesFor(String? sessionId) =>
      sortedUserAssistantMessages(_registry.messagesFor(sessionId));

  /// Geçmiş birleştirmede plan/agent turları bozulmasın (salt zaman sırası yetmez).
  void _reorderSessionChatByTurns(List<ChatMessage> list) {
    final chatIdx = <int>[];
    final chatMsgs = <ChatMessage>[];
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.role == ChatRole.user || m.role == ChatRole.assistant) {
        chatIdx.add(i);
        chatMsgs.add(m);
      }
    }
    if (chatMsgs.isEmpty) return;
    final ordered = orderSettledByTurns(chatMsgs);
    if (ordered.length != chatIdx.length) return;
    for (var i = 0; i < chatIdx.length; i++) {
      list[chatIdx[i]] = ordered[i];
    }
  }

  List<QueuedPrompt> _effectiveQueuedFor(String? sessionId) =>
      effectiveQueuedFor(
        _registry,
        sessionId,
        userMessagesLikelySame: userMessagesLikelySame,
      );

  List<ChatMessage> _visibleMessagesFor(String? sessionId) =>
      strictMessagesForBucket(
        filterVisibleMessages(
          _registry.messagesFor(sessionId),
          showLogs: showLogs,
          showSystem: showSystem,
          mergeStreamChunks: mergeStreamChunks,
          showProgress: showProgress,
        ),
        sessionId,
      );

  /// Sohbet ekranında gösterilen sıra (orderSettledByTurns + pin/kuyruk).
  List<ChatMessage> buildDisplayMessagesForSession(String? sessionId) {
    final live = _registry.liveFor(sessionId);
    final inFlightId = live.inFlight?.localMessageId;
    final pinInFlight = inFlightId != null &&
        live.waitingResponse &&
        !effectiveQueuedFor(
          _registry,
          sessionId,
          userMessagesLikelySame: userMessagesLikelySame,
        ).any((q) => q.localMessageId == inFlightId) &&
        !userTurnHasVisibleAssistantReply(
          _sortedChatMessagesFor(sessionId),
          inFlightId,
          sameUserText: userMessagesLikelySame,
        );
    return buildConversationDisplayMessages(
      visible: _visibleMessagesFor(sessionId),
      effectiveQueue: _effectiveQueuedFor(sessionId),
      inFlightUserMessageId: pinInFlight ? inFlightId : null,
    );
  }

  /// Sıradaki (henüz PC'ye gitmemiş) kullanıcı balonları en altta, kuyruk FIFO.
  List<ChatMessage> get displayMessages =>
      buildDisplayMessagesForSession(_activeLocalId);

  List<QueuedPrompt> get queuedPrompts =>
      List.unmodifiable(_effectiveQueuedFor(_activeLocalId));

  List<TrafficEntry> get traffic => List.unmodifiable(_traffic);

  int get queuedPromptCount => _effectiveQueuedFor(_activeLocalId).length;

  bool get hasQueuedPrompts => queuedPromptCount > 0;

  /// Tüm oturumlardaki gerçek kuyruk (bağlantı / durum metni).
  int get totalQueuedPromptCount {
    var n = 0;
    for (final e in _registry.liveEntries) {
      n += _effectiveQueuedFor(e.key).length;
    }
    return n;
  }

  bool get _hasAnyQueuedGlobally => totalQueuedPromptCount > 0;

  bool get _hasFlushableQueuedGlobally =>
      pickNextQueuedGlobally(
        _registry,
        userMessagesLikelySame: userMessagesLikelySame,
      ) !=
      null;

  void _logSessionSnapshot(String event) {
    final active = _activeLocalId;
    final parts = <String>[
      event,
      'aktif=${active.length > 12 ? '${active.substring(0, 12)}…' : active}',
      'pcMeşgul=${_pcBusySessionKey ?? '-'}',
      'socket=${_ws.isConnected}',
      'hazır=$connected',
    ];
    for (final e in _registry.liveEntries) {
      final sid = e.key;
      final short = sid.length > 8 ? '${sid.substring(0, 8)}…' : sid;
      final live = e.value;
      final q = _effectiveQueuedFor(sid).length;
      if (live.waitingResponse || q > 0 || live.unreadReplies > 0) {
        parts.add(
          '$short:w=${live.waitingResponse},q=$q,u=${live.unreadReplies},'
          'pc=${_pcBusySessionKey == sid}',
        );
      }
    }
    WsLogger.session(parts.join(' | '));
  }

  /// Meşgulken veya çevrimdışıyken sıraya ekle modu.
  bool get composerQueueMode =>
      busySendPolicy == BusySendPolicy.queue &&
      (hasQueuedPrompts || isPcBusy || !connected);

  int get backgroundSessionAttentionCount {
    var n = 0;
    for (final e in _registry.liveEntries) {
      if (e.key == _activeSessionKey) continue;
      if (e.value.needsAttention) n++;
    }
    return n;
  }

  bool get hasBackgroundSessionActivity => backgroundSessionAttentionCount > 0;

  String? get sessionActivityBannerText {
    if (sessionAlertId != null && sessionAlertId != _activeSessionKey) {
      final name = displayNameForSession(sessionAlertId!);
      final preview = _sessionAlertPreview?.trim();
      if (preview != null && preview.isNotEmpty) {
        return '«$name» · $preview';
      }
      return '«$name» oturumunda yeni cevap';
    }
    // Çalışıyor / sırada: oturum listesinde zaten rozet var; şerit tekrar eder.
    return null;
  }

  void clearSessionActivityAlert() {
    sessionAlertId = null;
    _sessionAlertPreview = null;
    notifyListeners();
  }

  int unreadCountForSession(String sessionId) =>
      _registry.liveFor(sessionId).unreadReplies;

  bool isSessionWaiting(String sessionId) =>
      _registry.liveFor(sessionId).waitingResponse;

  bool get _anySessionWaitingResponse {
    for (final e in _registry.liveEntries) {
      if (e.value.waitingResponse) return true;
    }
    return false;
  }

  SessionLiveBadge? liveBadgeForSession(String sessionId) {
    final live = _registry.liveFor(sessionId);
    final key = sessionId.trim();
    if (live.waitingResponse) {
      final onPc =
          live.inFlightWireDispatched || _pcBusySessionKey == key;
      final since = live.waitingSince ?? DateTime.now();
      final elapsed = formatWaitingElapsedShort(since);
      return SessionLiveBadge(
        label: onPc ? 'Çalışıyor · $elapsed' : 'Bekliyor · $elapsed',
        kind: SessionLiveBadgeKind.working,
        onPc: onPc,
      );
    }
    final queuedN = _effectiveQueuedFor(sessionId).length;
    if (queuedN > 0) {
      return SessionLiveBadge(
        label: queuedN == 1 ? '1 sırada' : '$queuedN sırada',
        kind: SessionLiveBadgeKind.queued,
      );
    }
    if (live.unreadReplies > 0) {
      final n = live.unreadReplies;
      return SessionLiveBadge(
        label: n == 1 ? '1 yeni cevap' : '$n yeni cevap',
        kind: SessionLiveBadgeKind.unread,
      );
    }
    return null;
  }

  bool isSessionFlowing(String sessionId) =>
      liveBadgeForSession(sessionId) != null;

  /// Agent / kuyruk / okunmamış olan oturum sayısı.
  int get flowingSessionCount =>
      sessionSummaries.where((s) => isSessionFlowing(s.sessionId)).length;

  int get otherFlowingSessionCount => sessionSummaries
      .where(
        (s) =>
            s.sessionId != cursorSessionId && isSessionFlowing(s.sessionId),
      )
      .length;

  /// Akan oturumlar üstte; PC'de çalışan en üstte.
  List<SessionSummary> get orderedSessionSummaries {
    final list = List<SessionSummary>.from(sessionSummaries);
    int rank(String sessionId) {
      final badge = liveBadgeForSession(sessionId);
      if (badge == null) return 10;
      switch (badge.kind) {
        case SessionLiveBadgeKind.working:
          return badge.onPc ? 0 : 1;
        case SessionLiveBadgeKind.queued:
          return 2;
        case SessionLiveBadgeKind.unread:
          return 3;
      }
    }

    list.sort((a, b) {
      final ra = rank(a.sessionId);
      final rb = rank(b.sessionId);
      if (ra != rb) return ra.compareTo(rb);
      final ta = a.lastTimestamp ?? '';
      final tb = b.lastTimestamp ?? '';
      return tb.compareTo(ta);
    });
    return list;
  }

  String? get activeSessionFlowHint {
    final sid = cursorSessionId;
    if (sid == null || sid.isEmpty) return null;
    final badge = liveBadgeForSession(sid);
    if (badge != null) return badge.label;
    final other = otherFlowingSessionCount;
    if (other == 1) return '1 başka oturum aktif';
    if (other > 1) return '$other başka oturum aktif';
    return null;
  }

  String get renameableActiveSessionId => _activeLocalId;

  bool get canRenameActiveSession => connected;

  String get activeSessionLabel => displayNameForSession(_activeLocalId);

  String displayNameForSession(String sessionId) {
    final custom = sessionNames[sessionId]?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    if (sessionId.startsWith('loc-')) {
      return _store.of(sessionId).displayLabel();
    }
    if (sessionId.length <= 12) return sessionId;
    return '${sessionId.substring(0, 12)}…';
  }

  bool _sessionBucketHasChat(String key) {
    return _registry.messagesFor(key).any(
          (m) => m.role == ChatRole.user || m.role == ChatRole.assistant,
        );
  }

  void _linkWireSession(String localId, String pcSessionId) {
    final pc = pcSessionId.trim();
    if (pc.isEmpty || !localId.startsWith('loc-')) return;
    _store.linkPcSession(localId, pc);
    _syncSessionNameAliases(forLocalId: localId);
  }

  /// Özel isim loc-* ve PC uuid altında aynı kalsın (yenile / liste çift satır önlemi).
  void _syncSessionNameAliases({String? forLocalId}) {
    var changed = false;
    void mirror(String a, String b) {
      final na = sessionNames[a]?.trim();
      final nb = sessionNames[b]?.trim();
      if (na != null && na.isNotEmpty && na != nb) {
        sessionNames[b] = na;
        changed = true;
      } else if (nb != null && nb.isNotEmpty && nb != na) {
        sessionNames[a] = nb;
        changed = true;
      }
    }

    final locals = forLocalId != null
        ? [forLocalId.trim()]
        : _store.localIds.toList();
    for (final loc in locals) {
      if (!loc.startsWith('loc-')) continue;
      final pc = _store.of(loc).pcSessionId?.trim();
      if (pc == null || pc.isEmpty) continue;
      mirror(loc, pc);
    }
    if (changed) {
      unawaited(_settings.saveSessionNames(sessionNames));
    }
  }

  void _pruneEmptyNamedOrphanBuckets() {
    final remove = <String>[];
    for (final loc in _store.localIds) {
      if (!loc.startsWith('loc-')) continue;
      if (_sessionBucketHasChat(loc)) continue;
      final pc = _store.of(loc).pcSessionId?.trim();
      if (pc == null || pc.isEmpty) continue;
      final owner = _store.findByPcSessionId(pc);
      if (owner != null &&
          owner.localId != loc &&
          _sessionBucketHasChat(owner.localId)) {
        remove.add(loc);
      }
    }
    for (final loc in remove) {
      sessionNames.remove(loc);
      _store.remove(loc);
    }
    if (remove.isNotEmpty) {
      unawaited(_settings.saveSessionNames(sessionNames));
    }
  }

  void _commitResolvedSession(String sessionRef) {
    final local = _sessions.resolve(
      sessionRef,
      historyEntries: _historyEntries,
    );
    if (cursorSessionId != local) cursorSessionId = local;
    _store.setActive(local);
  }

  String _resolveInboundBucketKey(Map<String, dynamic>? map) {
    final wire = map?['sessionId'] as String?;
    return _store.resolveInboundLocalId(
      wirePcSessionId: wire,
      dispatchBucketByMessageId: _dispatchBucketByLocalMessageId,
      pcBusyLocalId: _pcBusySessionKey,
    );
  }

  void _refreshSessionSummaries() {
    _syncSessionNameAliases();
    _pruneEmptyNamedOrphanBuckets();
    sessionSummaries = _buildSessionSummaries();
  }

  bool _isLocalOnlyActiveSession() {
    final sid = cursorSessionId?.trim();
    if (sid == null || sid.isEmpty) return true;
    final pc = _store.of(sid).pcSessionId?.trim();
    if (pc != null && pc.isNotEmpty) {
      return !extractSessionSummaries(_historyEntries)
          .any((s) => s.sessionId == pc);
    }
    return _sessionBucketHasChat(sid);
  }

  SessionSummary? _summaryFromLocalSession(String sessionId) {
    final msgs = _registry.messagesFor(sessionId);
    final chat = msgs
        .where(
          (m) =>
              m.role == ChatRole.user || m.role == ChatRole.assistant,
        )
        .toList();
    if (chat.isEmpty) return null;
    chat.sort((a, b) => b.at.compareTo(a.at));
    final latest = chat.first;
    final previewRaw = latest.text.trim();
    final preview = previewRaw.length > 60
        ? '${previewRaw.substring(0, 60)}…'
        : previewRaw.isEmpty
            ? '(boş)'
            : previewRaw;
    final pc = _store.of(sessionId).pcSessionId?.trim();
    return SessionSummary(
      sessionId: sessionId,
      preview: preview,
      lastTimestamp: latest.at.toIso8601String(),
      entryCount: chat.length,
      customName: sessionNames[sessionId],
    );
  }

  List<SessionSummary> _buildSessionSummaries() => buildSessionSummaries(
        store: _store,
        sessionNames: sessionNames,
        historyEntries: _historyEntries,
        registryKeys: _registry.sessionKeys,
        cursorSessionId: cursorSessionId,
        summaryFromLocalChat: _summaryFromLocalSession,
      );

  bool isSessionActiveInList(String listSessionId) => isListSessionActive(
        _store,
        listSessionId,
        cursorSessionId,
      );

  String _historyApplyLocalId(String raw) {
    if (_store.of(raw).isDraft || _sessionBucketHasChat(raw)) return raw;
    final resolved =
        _sessions.resolve(raw, historyEntries: _historyEntries);
    if (resolved != raw && !_sessionBucketHasChat(raw)) {
      cursorSessionId = resolved;
      _store.setActive(resolved);
      return resolved;
    }
    return raw;
  }

  Future<void> renameSession(String sessionId, String name) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      sessionNames.remove(sid);
      if (sid.startsWith('loc-')) {
        final pc = _store.of(sid).pcSessionId?.trim();
        if (pc != null && pc.isNotEmpty) sessionNames.remove(pc);
      } else {
        final linked = _store.findByPcSessionId(sid);
        if (linked != null) sessionNames.remove(linked.localId);
      }
    } else {
      sessionNames[sid] = trimmed;
      if (sid.startsWith('loc-')) {
        final pc = _store.of(sid).pcSessionId?.trim();
        if (pc != null && pc.isNotEmpty) sessionNames[pc] = trimmed;
      } else {
        final linked = _store.findByPcSessionId(sid);
        if (linked != null) sessionNames[linked.localId] = trimmed;
      }
    }
    await _settings.saveSessionNames(sessionNames);
    _syncSessionNameAliases(forLocalId: sid.startsWith('loc-') ? sid : null);
    _refreshSessionSummaries();
    notifyListeners();
  }

  bool get hasSessionList => sessionSummaries.isNotEmpty;

  DateTime? get waitingSince => _live.waitingSince;

  /// Yanıt beklerken geçen süre + PC'den son trafik (takılı mı çalışıyor mu).
  String get waitingStatusText {
    final live = _live;
    if (!live.waitingResponse || live.waitingSince == null) return '';
    final activityAt = live.lastPcActivityAt ?? lastPcActivityAt;
    return formatWaitingStatusText(
      waitingSince: live.waitingSince!,
      lastPcActivityAt: activityAt,
    );
  }

  /// Agent şeridi genişleyince: stream balonu veya birikmiş chunk metni.
  String? get activeAgentLiveStreamText {
    if (!isActiveSessionAwaitingAgent) return null;
    final live = _live;
    final streamId = live.streamingMessageId;
    if (streamId != null) {
      for (final m in _registry.messagesFor(_activeLocalId)) {
        if (m.id == streamId && m.text.trim().isNotEmpty) {
          return m.text;
        }
      }
    }
    final buf = live.agentLiveStreamText.trim();
    final prog = live.agentLiveProgressLine.trim();
    if (buf.isNotEmpty && prog.isNotEmpty) return '$buf\n$prog';
    if (buf.isNotEmpty) return buf;
    if (prog.isNotEmpty) return prog;
    final line = lastProgressLine?.trim();
    return line != null && line.isNotEmpty ? line : null;
  }

  /// PC `chat_response_chunk` içindeki `fullText` (parser'da `text`) — birikmiş anlık görüntü.
  /// Delta birleştirme yapma; yoksa token'lar yapışır: "A" + "hedef" → "Ahedef".
  static void _mergeAgentLiveStream(SessionLiveState live, String raw) {
    var cleaned = sanitizeAssistantTextForDisplay(raw).replaceAll('\r', '');
    if (cleaned.trim().isEmpty) return;

    // Tek paragraf önizleme: satır sonlarını boşluk (dikey harf dizisi olmasın).
    cleaned = cleaned.replaceAll(RegExp(r'[\n\r]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ').trim();
    if (cleaned.isEmpty) return;

    live.agentLiveStreamText = cleaned.length > 12000
        ? cleaned.substring(cleaned.length - 12000)
        : cleaned;
  }

  static void _setAgentLiveProgressLine(SessionLiveState live, String raw) {
    final cleaned = sanitizeAssistantTextForDisplay(raw).trim();
    if (cleaned.isNotEmpty) {
      live.agentLiveProgressLine = cleaned;
    }
  }

  void _markPcActivityForSession(String inboundSid) {
    final key = inboundSid.trim();
    final live = _registry.liveFor(key);
    final now = DateTime.now();
    live.lastPcActivityAt = now;
    if (key == _activeSessionKey || key == _pcBusySessionKey) {
      lastPcActivityAt = now;
    }
  }

  void _syncWaitDisplayTimer() {
    if (_anySessionWaitingResponse) {
      _startWaitDisplayTimer();
    } else {
      _stopWaitDisplayTimer();
    }
  }

  void _startWaitDisplayTimer() {
    if (_waitDisplayTimer != null) return;
    _waitDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_anySessionWaitingResponse) {
        _stopWaitDisplayTimer();
        return;
      }
      notifyListeners();
    });
  }

  void _stopWaitDisplayTimer() {
    _waitDisplayTimer?.cancel();
    _waitDisplayTimer = null;
  }

  void _cancelPostCompleteHistoryTimer() {
    _postCompleteHistoryTimer?.cancel();
    _postCompleteHistoryTimer = null;
  }

  /// Plan/CLI bazen önce boş `complete`, sonra `chat_response` gönderir.
  void _schedulePostCompleteHistorySync(String inboundSid) {
    _cancelPostCompleteHistoryTimer();
    _postCompleteHistoryTimer = Timer(const Duration(seconds: 2), () {
      _postCompleteHistoryTimer = null;
      if (!connected) return;
      final sid = inboundSid.trim();
      if (sid.isEmpty) return;
      if (_tryMaterializeLiveStreamReplyForSession(sid)) {
        notifyListeners();
        return;
      }
      final pc = historyFilterForLocal(_store, sid);
      if (pc == null) return;
      final live = _registry.liveFor(sid);
      final inflight = live.inFlight?.localMessageId ??
          live.awaitingReplyForUserId;
      if (inflight != null) {
        final sorted = _sortedChatMessagesFor(sid);
        if (userTurnHasVisibleAssistantReply(
          sorted,
          inflight,
          sameUserText: userMessagesLikelySame,
        )) {
          return;
        }
      }
      unawaited(
        loadChatHistory(
          sessionIdFilter: pc,
          forLocalSessionId: sid,
          replaceConversation: false,
          force: true,
        ),
      );
    });
  }

  void _upsertHistoryEntries(List<Map<String, dynamic>> entries) {
    for (final entry in entries) {
      final id = (entry['id'] as String? ?? '').trim();
      if (id.isNotEmpty) {
        _historyEntries.removeWhere((e) => (e['id'] as String? ?? '').trim() == id);
      }
      _historyEntries.add(Map<String, dynamic>.from(entry));
    }
    _historyEntries = normalizeHistoryEntries(_historyEntries);
  }

  void _cancelQueueFlushDebounce() {
    _queueFlushDebounce?.cancel();
    _queueFlushDebounce = null;
  }

  void _clearWaitingState(
    String forSessionKey, {
    bool flushQueue = false,
  }) {
    final live = _registry.liveFor(forSessionKey);
    final wasWaiting = live.waitingResponse;
    final finishedId = live.inFlight?.localMessageId;
    if (wasWaiting) {
      live.inFlight = null;
    }
    live.clearWaiting();
    if (finishedId != null) {
      _dispatchBucketByLocalMessageId.remove(finishedId);
    }
    if (_pcBusySessionKey == forSessionKey) {
      _pcBusySessionKey = null;
    }
    if (forSessionKey == _activeSessionKey) {
      lastPcActivityAt = null;
      lastProgressLine = null;
      _stopWaitDisplayTimer();
      _cancelResponseIdleTimer();
      _cancelPostCompleteHistoryTimer();
    }
    if (_hasFlushableQueuedGlobally) {
      _scheduleQueueFlushNext();
    } else if (!flushQueue && forSessionKey == _activeSessionKey) {
      _cancelQueueFlushDebounce();
    }
    _sanitizeQueueForSession(forSessionKey);
    _syncWaitDisplayTimer();
  }

  /// PC bazen aynı turda `chat_response_complete` + `chat_response` gönderir;
  /// debounce ile kuyruktan yalnızca bir sonraki mesaj gider.
  void _scheduleQueueFlushNext() {
    _cancelQueueFlushDebounce();
    _queueFlushDebounce = Timer(const Duration(milliseconds: 250), () {
      _queueFlushDebounce = null;
      _flushPromptQueue();
    });
  }

  ({QueuedPrompt prompt, String? sessionId})? _pickNextQueuedGlobally() =>
      pickNextQueuedGlobally(
        _registry,
        userMessagesLikelySame: userMessagesLikelySame,
      );

  void _flushPromptQueue() {
    if (!connected) return;
    final picked = _pickNextQueuedGlobally();
    if (picked == null) return;
    final next = picked.prompt;
    final sid = picked.sessionId;
    final live = _registry.liveFor(sid);
    final qi = live.queue.indexWhere(
      (q) => q.localMessageId == next.localMessageId,
    );
    if (qi >= 0) {
      live.queue.removeAt(qi);
    }
    _dispatchPromptToPc(
      next.text,
      agentMode: next.agentMode,
      attachments: next.attachments,
      userMessageId: next.localMessageId,
      sessionId: next.sessionId ?? sid,
      preempt: false,
    );
    _persistPromptQueue();
    notifyListeners();
  }

  Future<void> _persistPromptQueue() async {
    final all = <QueuedPrompt>[];
    for (final e in _registry.liveEntries) {
      for (final q in e.value.queue) {
        all.add(
          QueuedPrompt(
            text: q.text,
            agentMode: q.agentMode,
            queuedAt: q.queuedAt,
            localMessageId: q.localMessageId,
            sessionId: q.sessionId ?? e.key,
            attachments: q.attachments,
          ),
        );
      }
    }
    await _settings.savePromptQueue(all);
  }

  void _ensureQueuedBubble(QueuedPrompt q, String? sessionId) {
    final localId = (sessionId ?? q.sessionId)?.trim() ?? _activeLocalId;
    final list = _registry.messagesFor(localId);
    if (list.any((m) => m.id == q.localMessageId)) return;
    list.add(
      ChatMessage(
        id: q.localMessageId,
        role: ChatRole.user,
        text: formatUserMessageWithAttachments(q.text, q.attachments),
        at: q.queuedAt,
        kind: InboundKind.userPrompt,
        agentMode: q.agentMode,
        sessionId: localId,
      ),
    );
  }

  Future<void> _restorePersistedQueue() async {
    final restored = await _settings.loadPromptQueue();
    if (restored.isEmpty) return;
    for (final q in restored) {
      final live = _registry.liveFor(q.sessionId);
      if (live.queue.any((x) => x.localMessageId == q.localMessageId)) {
        continue;
      }
      live.queue.add(q);
      _ensureQueuedBubble(q, q.sessionId);
    }
  }

  void _requeueInFlightForSession(String forKey) {
    final live = _registry.liveFor(forKey);
    if (live.inFlightWireDispatched) return;
    final inflight = live.inFlight;
    if (inflight == null) return;
    live.inFlight = null;
    if (live.queue.any((q) => q.localMessageId == inflight.localMessageId)) {
      return;
    }
    final msgs = _registry.messagesFor(forKey);
    if (!msgs.any((m) => m.id == inflight.localMessageId)) {
      return;
    }
    live.queue.insert(0, inflight);
    unawaited(_persistPromptQueue());
  }

  void _requeueAllInFlightOnDisconnect() {
    for (final key in _registry.liveEntries.map((e) => e.key).toList()) {
      final live = _registry.liveFor(key);
      if (live.inFlight != null && live.inFlightWireDispatched) {
        continue;
      }
      _requeueInFlightForSession(key);
      live.clearWaiting();
    }
    final stillWaiting = _registry.liveEntries
        .where((e) => e.value.waitingResponse)
        .map((e) => e.key)
        .toList();
    if (stillWaiting.isEmpty) {
      _pcBusySessionKey = null;
    } else if (_pcBusySessionKey == null ||
        !_registry.liveFor(_pcBusySessionKey!).waitingResponse) {
      _pcBusySessionKey = stillWaiting.first;
    }
  }

  void _pruneAllQueues() {
    for (final key in _registry.liveEntries.map((e) => e.key).toList()) {
      _pruneOrphanQueueForSession(key);
    }
  }

  void _restoreQueuedBubblesForSession(String? sessionId) {
    for (final q in List<QueuedPrompt>.from(_registry.liveFor(sessionId).queue)) {
      _ensureQueuedBubble(q, sessionId);
    }
  }

  void _sanitizeQueueForSession(String? sessionId) {
    sanitizeQueueForSession(
      _registry,
      sessionId,
      userMessagesLikelySame: userMessagesLikelySame,
      onQueueChanged: () => unawaited(_persistPromptQueue()),
    );
    _restoreQueuedBubblesForSession(sessionId);
  }

  void _sanitizeAllSessionQueues() {
    sanitizeAllSessionQueues(
      _registry,
      userMessagesLikelySame: userMessagesLikelySame,
      onQueueChanged: () => unawaited(_persistPromptQueue()),
    );
    for (final key in _registry.liveEntries.map((e) => e.key).toList()) {
      _restoreQueuedBubblesForSession(key);
    }
  }

  String _statusWithQueueHint(String base) {
    final n = queuedPromptCount;
    if (n == 0) return base;
    return '$base · $n mesaj sırada';
  }

  /// Kayıtlı PC'ye bağlan; kuyruk varsa sırayı sürdür.
  void tryAutoConnect() {
    if (!autoReconnectEnabled) return;
    if (connected) {
      if (_hasFlushableQueuedGlobally) {
        _scheduleQueueFlushNext();
      }
      return;
    }
    if (!hasSavedConnection || isLinkInProgress) return;
    final qn = totalQueuedPromptCount;
    statusNote = qn > 0
        ? 'Yeniden bağlanılıyor… ($qn mesaj sırada)'
        : 'Yeniden bağlanılıyor…';
    notifyListeners();
    unawaited(connectWithSaved());
  }

  void handleAppResumed() {
    _foregroundSyncDebounce?.cancel();
    _foregroundSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_onAppForeground());
    });
  }

  void _completeHistoryLoadWaiter(String localId) {
    final c = _historyLoadWaiters.remove(localId);
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> _waitUntilConnected({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (connected) return;
      if (!_socketUp && !_connecting) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _onAppForeground() async {
    if (!autoReconnectEnabled) return;

    if (!connected) {
      if (hasSavedConnection && !_connecting) {
        await connectWithSaved();
      }
      if (!connected) {
        await _waitUntilConnected();
      }
    }

    if (connected) {
      await _syncForegroundFromPc();
      if (_hasFlushableQueuedGlobally) {
        _scheduleQueueFlushNext();
      }
      return;
    }

    if (hasSavedConnection && !_connecting) {
      tryAutoConnect();
    }
  }

  Future<void> _syncForegroundFromPc() async {
    if (!connected) return;
    final targets = collectForegroundHistorySyncTargets(
      registry: _registry,
      activeLocalId: _activeLocalId,
    );
    if (targets.isEmpty) return;

    for (final sid in targets) {
      await _loadChatHistoryAndWait(
        forLocalSessionId: sid,
        replaceConversation: false,
      );
      _reconcileWaitingFlagsForSession(sid);
      _reconcilePendingTurnAfterDisconnect(sid);
    }
    _sanitizeAllSessionQueues();
    notifyListeners();
  }

  /// Kopmada kuyruğa düşmüş ama PC'de hâlâ işlenen tur — yeniden gönderme.
  void _reconcilePendingTurnAfterDisconnect(String? sessionId) {
    final sid = sessionId?.trim() ?? _activeLocalId;
    if (_tryMaterializeLiveStreamReplyForSession(sid)) {
      notifyListeners();
      return;
    }
    final live = _registry.liveFor(sessionId);
    final result = reconcileUnansweredTurnFromQueue(
      live: live,
      sorted: _sortedChatMessagesFor(sessionId),
      userMessagesLikelySame: userMessagesLikelySame,
    );
    if (!result.restoredWaiting && result.removedFromQueue == 0) return;

    final key = sessionId?.trim() ?? _activeLocalId;
    if (result.restoredWaiting) {
      _pcBusySessionKey = key;
      if (key == _activeSessionKey) {
        _armResponseIdleTimer(key);
      }
      _syncWaitDisplayTimer();
    }
    if (result.removedFromQueue > 0) {
      unawaited(_persistPromptQueue());
    }
    notifyListeners();
  }

  Future<void> _loadChatHistoryAndWait({
    required String forLocalSessionId,
    bool replaceConversation = false,
  }) async {
    final local = forLocalSessionId.trim();
    if (local.isEmpty || !connected) return;

    final wire = historyFilterForLocal(_store, local);
    if (wire == null && _isDraftBucketKey(local)) return;

    final existing = _historyLoadWaiters[local];
    if (existing != null && !existing.isCompleted) {
      await existing.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      return;
    }

    final waiter = Completer<void>();
    _historyLoadWaiters[local] = waiter;
    await loadChatHistory(
      sessionIdFilter: wire,
      forLocalSessionId: local,
      replaceConversation: replaceConversation,
      force: true,
      silent: true,
    );
    if (waiter.isCompleted) return;
    if (_pendingHistorySessionFilter?.trim() != local) {
      _completeHistoryLoadWaiter(local);
      return;
    }
    try {
      await waiter.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      _completeHistoryLoadWaiter(local);
    }
  }

  Future<void> setAutoReconnectEnabled(bool value) async {
    autoReconnectEnabled = value;
    await _settings.saveAutoReconnectEnabled(value);
    if (value) {
      tryAutoConnect();
    }
    notifyListeners();
  }

  void clearPromptQueue() {
    if (_promptQueue.isEmpty) return;
    for (final q in _promptQueue) {
      _allMessages.removeWhere((m) => m.id == q.localMessageId);
    }
    _live.queue.clear();
    unawaited(_persistPromptQueue());
    notifyListeners();
  }

  void removeQueuedPrompt(String localMessageId) {
    final i =
        _promptQueue.indexWhere((q) => q.localMessageId == localMessageId);
    if (i < 0) return;
    _promptQueue.removeAt(i);
    _allMessages.removeWhere((m) => m.id == localMessageId);
    unawaited(_persistPromptQueue());
    notifyListeners();
  }

  void updateQueuedPrompt(
    String localMessageId, {
    required String text,
    List<PromptAttachment>? attachments,
  }) {
    final i =
        _promptQueue.indexWhere((q) => q.localMessageId == localMessageId);
    if (i < 0) return;
    final prev = _promptQueue[i];
    final trimmed = text.trim();
    final atts = attachments ?? prev.attachments;
    if (trimmed.isEmpty && atts.isEmpty) return;

    _promptQueue[i] = QueuedPrompt(
      text: trimmed,
      agentMode: prev.agentMode,
      queuedAt: prev.queuedAt,
      localMessageId: localMessageId,
      sessionId: prev.sessionId,
      attachments: atts,
    );

    final bi = _allMessages.indexWhere((m) => m.id == localMessageId);
    if (bi >= 0) {
      final bubbleText = formatUserMessageWithAttachments(trimmed, atts);
      final old = _allMessages[bi];
      _allMessages[bi] = ChatMessage(
        id: old.id,
        role: old.role,
        text: bubbleText,
        at: old.at,
        kind: old.kind,
        agentMode: old.agentMode,
        sessionId: old.sessionId,
      );
    }
    unawaited(_persistPromptQueue());
    notifyListeners();
  }

  /// Kuyrukta ve bu oturumun sohbet listesinde görünen mesaj.
  bool isQueuedUserMessage(String messageId) => _effectiveQueuedFor(cursorSessionId)
      .any((q) => q.localMessageId == messageId);

  /// PC'ye gitti, yanıt bekleniyor (sıra değil).
  bool isAwaitingReplyUserMessage(String messageId) {
    final live = _live;
    if (isQueuedUserMessage(messageId)) return false;
    if (live.inFlight?.localMessageId == messageId) return true;
    if (!live.waitingResponse) return false;
    return live.awaitingReplyForUserId == messageId ||
        live.pendingReplyForUserId == messageId;
  }

  /// Geçmiş yenilendiğinde kuyrukta kalan ama listede olmayan / uçuşta olan kayıtları at.
  void _pruneOrphanQueueForSession(String? sessionId) {
    final list = _registry.messagesFor(sessionId);
    final userIds = list
        .where((m) => m.role == ChatRole.user)
        .map((m) => m.id)
        .toSet();
    final live = _registry.liveFor(sessionId);
    final inflightId = live.inFlight?.localMessageId;
    final before = live.queue.length;
    live.queue.removeWhere(
      (q) =>
          !userIds.contains(q.localMessageId) ||
          q.localMessageId == inflightId,
    );
    if (before != live.queue.length) {
      unawaited(_persistPromptQueue());
    }
  }

  /// Sıradaki tek mesajı hemen gönder (çalışanı keser); yalnızca o balon için ⚡.
  void sendQueuedMessageNow(String localMessageId) {
    final i = _promptQueue.indexWhere((q) => q.localMessageId == localMessageId);
    if (i < 0 || !_ws.isConnected) return;
    final next = _promptQueue.removeAt(i);
    _cancelQueueFlushDebounce();
    final rawSid = next.sessionId ?? cursorSessionId;
    final local = rawSid != null && rawSid.trim().isNotEmpty
        ? resolveSelectionLocalId(
            _store,
            rawSid,
            historyEntries: _historyEntries,
          )
        : _activeLocalId;
    final busy = _pcBusySessionKey;
    final otherSessionBusy =
        isPcBusy && busy != null && busy.isNotEmpty && busy != local;
    _dispatchPromptToPc(
      next.text,
      agentMode: next.agentMode,
      attachments: next.attachments,
      userMessageId: next.localMessageId,
      sessionId: local,
      preempt: otherSessionBusy ||
          busySendPolicy == BusySendPolicy.interrupt,
    );
    unawaited(_persistPromptQueue());
    notifyListeners();
  }

  String? _replyTargetUserIdFor(SessionLiveState live) =>
      live.pendingReplyForUserId ?? live.awaitingReplyForUserId;

  void _finishPendingReply(SessionLiveState live, String? userId) {
    if (userId != null && live.pendingReplyForUserId == userId) {
      live.pendingReplyForUserId = null;
    }
  }

  String _resolveInboundSessionId(
    Map<String, dynamic>? map, {
    bool allowActiveUiFallback = true,
  }) {
    if (!allowActiveUiFallback) {
      return _resolveInboundBucketKey(map);
    }
    return resolveInboundSessionId(
      map: map,
      pcBusySessionKey: _pcBusySessionKey,
      liveEntries: _registry.liveEntries,
      cursorSessionId: cursorSessionId,
      allowActiveUiFallback: true,
    );
  }

  static bool _sessionActivelyWaiting(SessionLiveState live) =>
      live.waitingResponse &&
      (live.inFlight != null || live.inFlightWireDispatched);

  void _clearStaleWaitingIfNeeded(SessionLiveState live) {
    if (live.waitingResponse &&
        live.inFlight == null &&
        !live.inFlightWireDispatched) {
      live.clearWaiting();
    }
  }

  void _clearStaleWaitingAllSessions() {
    for (final e in _registry.liveEntries) {
      _clearStaleWaitingIfNeeded(e.value);
    }
  }

  /// Bağlıyken kuyruktaki mesajı hemen PC'ye gönder (debounce yok).
  void _flushQueuedWhenConnected({String? preferSessionId}) {
    if (!connected) return;
    _clearStaleWaitingAllSessions();
    _sanitizeAllSessionQueues();
    if (!_hasFlushableQueuedGlobally) return;
    if (preferSessionId != null) {
      final sid = preferSessionId.trim();
      final live = _registry.liveFor(sid);
      if (!_sessionActivelyWaiting(live)) {
        final pending = _effectiveQueuedFor(sid);
        if (pending.isNotEmpty) {
          final next = pending.first;
          final qi = live.queue.indexWhere(
            (q) => q.localMessageId == next.localMessageId,
          );
          if (qi >= 0) live.queue.removeAt(qi);
          _dispatchPromptToPc(
            next.text,
            agentMode: next.agentMode,
            attachments: next.attachments,
            userMessageId: next.localMessageId,
            sessionId: next.sessionId ?? sid,
            preempt: false,
          );
          unawaited(_persistPromptQueue());
          notifyListeners();
          if (_hasFlushableQueuedGlobally) {
            _scheduleQueueFlushNext();
          }
          return;
        }
      }
    }
    _cancelQueueFlushDebounce();
    _flushPromptQueue();
  }

  bool _tryMaterializeLiveStreamReplyForSession(String sessionId) {
    final sid = sessionId.trim();
    if (sid.isEmpty) return false;
    final live = _registry.liveFor(sid);
    final list = _registry.messagesFor(sid);
    final added = tryMaterializeLiveStreamReply(
      live: live,
      list: list,
      sessionId: sid,
      newMessageId: _id,
      sameUserText: userMessagesLikelySame,
      isDuplicateReply: _isDuplicateAssistantReplyForUser,
    );
    if (!added) return false;
    _clearWaitingState(sid, flushQueue: sid == _activeSessionKey);
    return true;
  }

  void _reconcileWaitingFlagsForSession(String? sessionId) {
    final sid = sessionId?.trim() ?? '';
    final live = _registry.liveFor(sid);
    _clearStaleWaitingIfNeeded(live);
    if (!live.waitingResponse) return;
    final uid =
        live.awaitingReplyForUserId ?? live.inFlight?.localMessageId;
    if (uid == null) return;
    final sorted = _sortedChatMessagesFor(sid);
    if (userTurnHasVisibleAssistantReply(
      sorted,
      uid,
      sameUserText: userMessagesLikelySame,
    )) {
      _clearWaitingState(sid, flushQueue: sid == _activeSessionKey);
      return;
    }
    _tryMaterializeLiveStreamReplyForSession(sid);
  }

  bool _shouldSurfaceReplyNotification(String sessionId) {
    final sid = sessionId.trim();
    if (sid.isEmpty) return false;
    return sid != _activeSessionKey || _appInBackground;
  }

  void _notifyBackgroundReply(String sessionId, String preview) {
    if (!_shouldSurfaceReplyNotification(sessionId)) return;
    final live = _registry.liveFor(sessionId);
    live.unreadReplies++;
    sessionAlertId = sessionId;
    final t = preview.trim();
    _sessionAlertPreview =
        t.length > 100 ? '${t.substring(0, 100)}…' : t;
    unawaited(
      SessionReplyNotification.show(
        sessionId: sessionId,
        sessionName: displayNameForSession(sessionId),
        preview: t,
      ),
    );
    final sid = sessionId.trim();
    if (sid.isEmpty || !connected) return;
    final pc = historyFilterForLocal(_store, sid);
    if (pc == null) return;
    final inflight = live.inFlight?.localMessageId ??
        live.awaitingReplyForUserId;
    if (inflight != null) {
      final sorted = _sortedChatMessagesFor(sid);
      if (userTurnHasVisibleAssistantReply(
        sorted,
        inflight,
        sameUserText: userMessagesLikelySame,
      )) {
        return;
      }
    }
    unawaited(
      loadChatHistory(
        sessionIdFilter: pc,
        forLocalSessionId: sid,
        replaceConversation: false,
        force: true,
      ),
    );
  }

  /// Yalnızca aynı kullanıcı turundaki önceki cevapla karşılaştır (harf sırası).
  bool _isDuplicateAssistantReplyForUser(
    List<ChatMessage> list,
    String cleaned,
    String userId,
  ) {
    final userIdx = list.indexWhere((m) => m.id == userId);
    if (userIdx < 0) return false;
    final insertAt = insertIndexAfterUserTurn(list, userId);
    for (var i = userIdx + 1; i < insertAt; i++) {
      final m = list[i];
      if (m.role == ChatRole.assistant &&
          normalizedAssistantBody(m.text) == normalizedAssistantBody(cleaned)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _init() async {
    final conn = await _settings.loadConnection();
    host = conn.host;
    port = conn.port;
    authToken = conn.authToken;
    responseIdleTimeoutMinutes =
        await _settings.loadResponseIdleTimeoutMinutes();
    deviceClientId = await _settings.loadOrCreateDeviceClientId();
    promptAgentMode = await _settings.loadPromptAgentMode();
    final f = await _settings.loadFilters();
    showLogs = f.showLogs;
    showSystem = f.showSystem;
    mergeStreamChunks = f.mergeStream;
    showProgress = f.showProgress;
    showStreamPreview = f.streamPreview;
    mobileOptimizedPrompts = await _settings.loadMobileOptimizedPrompts();
    composerUseFast = await _settings.loadComposerUseFast();
    busySendPolicy = await _settings.loadBusySendPolicy();
    autoReconnectEnabled = await _settings.loadAutoReconnectEnabled();
    sessionNames = await _settings.loadSessionNames();
    _restoredSessionId = await _settings.loadLastSessionId();
    await _restoreLocalCache();
    await _restorePersistedQueue();
    _pruneAllQueues();
    settingsReady = true;
    notifyListeners();
    tryAutoConnect();
  }

  bool get hasSavedConnection => host.trim().isNotEmpty;

  /// PC extension ile aynı PIN (boşsa LAN riski).
  bool get isAuthConfigured => authToken.trim().length >= 4;

  String get connectionLabel =>
      hasSavedConnection ? '$host:$port' : 'Adres girilmedi';

  /// Kayıtlı IP/port ile bağlanır (metin kutusuna yazmana gerek yok).
  Future<void> connectWithSaved() async {
    if (!hasSavedConnection) {
      statusNote = 'Önce PC adresini kaydedin (Bağlantı sekmesi)';
      notifyListeners();
      return;
    }
    if (isLinkInProgress) return;
    await connect();
  }

  Future<void> saveConnection(
    String h,
    int p, {
    String? authTokenValue,
  }) async {
    host = h.trim();
    port = p;
    if (authTokenValue != null) {
      authToken = authTokenValue.trim();
    }
    await _settings.saveConnection(host, port, authToken: authToken);
    notifyListeners();
  }

  Future<void> saveAuthToken(String token) async {
    authToken = token.trim();
    await _settings.saveAuthToken(authToken);
    notifyListeners();
  }

  Future<void> setPromptAgentMode(String mode) async {
    if (!{'agent', 'ask', 'plan'}.contains(mode)) return;
    promptAgentMode = mode;
    await _settings.savePromptAgentMode(mode);
    notifyListeners();
  }

  Future<void> setMobileOptimizedPrompts(bool value) async {
    mobileOptimizedPrompts = value;
    await _settings.saveMobileOptimizedPrompts(value);
    notifyListeners();
  }

  Future<void> setComposerUseFast(bool value) async {
    composerUseFast = value;
    await _settings.saveComposerUseFast(value);
    notifyListeners();
  }

  Future<void> setBusySendPolicy(BusySendPolicy policy) async {
    busySendPolicy = policy;
    await _settings.saveBusySendPolicy(policy);
    notifyListeners();
  }

  Future<void> setFilters({
    bool? logs,
    bool? system,
    bool? mergeStream,
    bool? progress,
    bool? streamPreview,
  }) async {
    if (logs != null) showLogs = logs;
    if (system != null) showSystem = system;
    if (mergeStream != null) mergeStreamChunks = mergeStream;
    if (progress != null) showProgress = progress;
    if (streamPreview != null) showStreamPreview = streamPreview;
    await _settings.saveFilters(
      showLogs: showLogs,
      showSystem: showSystem,
      mergeStream: mergeStreamChunks,
      showProgress: showProgress,
      streamPreview: showStreamPreview,
    );
    notifyListeners();
  }

  void _addTraffic(String direction, String summary, String body) {
    WsLogger.traffic(direction, summary, body);
    _traffic.insert(
      0,
      TrafficEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        direction: direction == 'out'
            ? TrafficDirection.outbound
            : TrafficDirection.inbound,
        summary: summary,
        body: body.length > 8000 ? '${body.substring(0, 8000)}…' : body,
        at: DateTime.now(),
      ),
    );
    if (_traffic.length > _maxTraffic) {
      _traffic.removeRange(_maxTraffic, _traffic.length);
    }
  }

  void clearTraffic() {
    _traffic.clear();
    notifyListeners();
  }

  Future<void> connect() async {
    final epoch = ++_connectEpoch;
    _connecting = true;
    statusNote = isAuthConfigured
        ? 'Bağlanılıyor…'
        : 'Bağlanılıyor… (Uyarı: Auth PIN boş — PC\'de token ayarlayın)';
    WsLogger.info('Bağlanılıyor: $host:$port');
    notifyListeners();

    await _tearDownConnection(silent: true, preserveConnectingState: true);
    if (epoch != _connectEpoch) return;

    try {
      await _ws.connect(
        host: host,
        port: port,
        authToken: authToken,
        onTraffic: _addTraffic,
        onMessage: _onRawMessage,
        onError: (e) {
          if (epoch != _connectEpoch) return;
          unawaited(
            _tearDownConnection(note: 'Hata: $e', scheduleReconnect: true),
          );
        },
        onDone: () {
          if (epoch != _connectEpoch) return;
          unawaited(
            _tearDownConnection(
              note: 'Bağlantı kapandı',
              scheduleReconnect: true,
            ),
          );
        },
      );
      if (epoch != _connectEpoch) {
        await _ws.disconnect();
        return;
      }
      _socketUp = true;
      _sessionReady = false;
      statusNote =
          'PC uzantısından onay bekleniyor… (Cursor Remote açık mı?)';
      WsLogger.info('Soket açık, connected/auth bekleniyor');
      _historyLoadedForConnection = false;
      _armHandshakeTimeout();
      notifyListeners();
    } catch (e, st) {
      if (epoch != _connectEpoch) return;
      await _tearDownConnection(note: 'Bağlanamadı: $e');
      WsLogger.error(e, st);
    } finally {
      if (epoch == _connectEpoch) {
        _connecting = false;
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    final handshaking = isHandshaking || _connecting;
    _connectEpoch++;
    _connecting = false;
    WsLogger.info('Bağlantı kesiliyor (handshaking=$handshaking)');
    notifyListeners();
    await _tearDownConnection(
      note: handshaking ? 'Bağlantı iptal edildi' : 'Bağlı değil',
    );
  }

  void _armHandshakeTimeout() {
    _cancelHandshakeTimeout();
    _handshakeTimer = Timer(
      const Duration(seconds: _handshakeTimeoutSeconds),
      () {
        if (_socketUp && !_sessionReady) {
          WsLogger.info('El sıkışma zaman aşımı');
          unawaited(
            _tearDownConnection(
              note:
                  'PC onayı gelmedi ($_handshakeTimeoutSeconds sn). '
                  'IP/port, Auth PIN, Windows güvenlik duvarı ve Cursor\'da '
                  'Remote sunucusu (Output\'ta port) kontrol edin.',
              scheduleReconnect: true,
            ),
          );
        }
      },
    );
  }

  void _cancelHandshakeTimeout() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
  }

  Future<void> _tearDownConnection({
    String? note,
    bool silent = false,
    bool scheduleReconnect = false,
    bool preserveConnectingState = false,
  }) async {
    _cancelHandshakeTimeout();
    _cancelResponseIdleTimer();
    _socketUp = false;
    _sessionReady = false;
    if (!preserveConnectingState) {
      _connecting = false;
    }
    await _ws.disconnect();
    _cancelQueueFlushDebounce();
    _requeueAllInFlightOnDisconnect();
    _historyLoadedForConnection = false;
    unawaited(_persistPromptQueue());
    if (!silent && note != null) {
      statusNote = _statusWithQueueHint(note);
    } else if (!silent) {
      statusNote = _statusWithQueueHint('Bağlı değil');
    }
    notifyListeners();
    if (scheduleReconnect) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!connected && !_connecting) {
          tryAutoConnect();
        }
      });
    }
  }

  void _onSessionReady() {
    _cancelHandshakeTimeout();
    _sessionReady = true;
    statusNote = 'Bağlı — $host:$port';
    WsLogger.info('Oturum hazır: $host:$port');
    notifyListeners();
    _scheduleHistoryLoadAfterConnect();
    _clearStaleWaitingAllSessions();
    _sanitizeAllSessionQueues();
    _flushQueuedWhenConnected();
  }

  void _armResponseIdleTimer(String forSessionKey) {
    _cancelResponseIdleTimer();
    final live = _registry.liveFor(forSessionKey);
    if (!live.waitingResponse) return;
    _responseIdleTimer = Timer(
      Duration(minutes: responseIdleTimeoutMinutes),
      () {
        final l = _registry.liveFor(forSessionKey);
        if (!l.waitingResponse) return;
        _clearWaitingState(forSessionKey);
        _addVisibleNotice(
          '⏱ $responseIdleTimeoutMinutes dk boyunca PC\'den yanıt gelmedi. '
          'Uzun işler sürebilir; agent PC\'de çalışıyor olabilir. '
          'Cursor Remote çıktısına bakın veya tekrar mesaj gönderin.',
        );
        notifyListeners();
      },
    );
  }

  void _touchResponseIdleTimer() {
    final key = _pcBusySessionKey;
    if (key != null && _registry.liveFor(key).waitingResponse) {
      _armResponseIdleTimer(key);
    }
  }

  void _cancelResponseIdleTimer() {
    _responseIdleTimer?.cancel();
    _responseIdleTimer = null;
  }

  void _addAssistantNotice(String text) {
    _allMessages.add(
      ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: text,
        at: DateTime.now(),
        kind: InboundKind.system,
      ),
    );
  }

  /// `showSystem` kapalı olsa da sohbette görünen bilgi/hata.
  void _addVisibleNotice(String text, {bool isError = false}) {
    _addAssistantNotice(isError ? '⚠️ $text' : text);
  }

  void _onRawMessage(String raw) {
    if (!_socketUp && !_connecting) return;

    Map<String, dynamic>? map;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        map = decoded;
        if (map['type'] == 'connected') {
          final requiresAuth = map['requiresAuth'] == true;
          if (requiresAuth) {
            if (authToken.isEmpty) {
              _addAssistantNotice(
                'PC\'de Auth PIN ayarlı. Bağlantı → Auth PIN alanına '
                'Cursor\'da üretilen 8 karakteri yazın.',
              );
              unawaited(
                _tearDownConnection(note: 'Auth PIN gerekli'),
              );
              return;
            }
            _ws.sendAuth(
              clientId: deviceClientId,
              onTraffic: _addTraffic,
            );
            statusNote = 'Auth PIN doğrulanıyor…';
          } else {
            _onSessionReady();
          }
          notifyListeners();
          return;
        }
        if (map['type'] == 'auth_result') {
          if (map['success'] == true) {
            _onSessionReady();
          } else {
            _addAssistantNotice('Kimlik doğrulama başarısız (token yanlış).');
            unawaited(_tearDownConnection(note: 'Auth başarısız'));
          }
          notifyListeners();
          return;
        }
        if (map['type'] == 'auth_required') {
          _addAssistantNotice(
            map['error'] as String? ?? 'Auth PIN gerekli',
          );
          notifyListeners();
          return;
        }
        if (map['type'] == 'connection_status' &&
            map['status'] == 'disconnected') {
          unawaited(
            _tearDownConnection(
              note: 'PC bağlantısı kesildi',
              scheduleReconnect: true,
            ),
          );
          return;
        }
        if (_handleCommandResult(map)) {
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    final wireSid = map != null && map['sessionId'] is String
        ? (map['sessionId'] as String).trim()
        : null;
    final inboundSid = _resolveInboundBucketKey(map);
    if (wireSid != null &&
        wireSid.isNotEmpty &&
        _isChatSessionWireMessage(map)) {
      _linkWireSession(inboundSid, wireSid);
    }

    final parsed = parseInboundJson(raw);

    _markPcActivityForSession(inboundSid);

    if (parsed.kind == InboundKind.agentProgress) {
      if (parsed.chatLines.isNotEmpty &&
          (inboundSid == _activeSessionKey ||
              inboundSid == _pcBusySessionKey)) {
        final line = parsed.chatLines.last.text;
        if (showProgress) lastProgressLine = line;
        _setAgentLiveProgressLine(_registry.liveFor(inboundSid), line);
      }
      if (_registry.liveFor(inboundSid).waitingResponse) {
        _touchResponseIdleTimer();
      }
      notifyListeners();
      return;
    }

    for (final line in parsed.chatLines) {
      if (line.role == ChatRole.assistant &&
          isGarbageAssistantText(line.text)) {
        continue;
      }
      _applyChatLine(inboundSid, line.role, line.text, line.kind);
    }

    if (parsed.systemLine != null && parsed.systemLine!.isNotEmpty) {
      _registry.messagesFor(inboundSid).add(
        ChatMessage(
          id: _id(),
          role: ChatRole.system,
          text: parsed.systemLine!,
          at: DateTime.now(),
          kind: parsed.kind,
          sessionId: inboundSid,
        ),
      );
    }

    final hasAssistantText = isMeaningfulAssistantInbound(parsed);
    if (parsed.kind == InboundKind.chatResponse ||
        parsed.kind == InboundKind.chatResponseComplete) {
      final preview = parsed.chatLines
          .where((l) => l.role == ChatRole.assistant)
          .map((l) => l.text)
          .join(' ');
      SessionTraceLog.inbound(
        kind: parsed.kind.name,
        wireSid: wireSid,
        activeSid: cursorSessionId,
        resolvedSid: inboundSid,
        preview: preview.isEmpty
            ? (parsed.chatLines.isNotEmpty
                ? parsed.chatLines.first.text
                : '')
            : preview,
      );
    }

    final targetKey = inboundSid;
    if (parsed.kind == InboundKind.chatResponse && hasAssistantText) {
      final preview = parsed.chatLines
          .where((l) => l.role == ChatRole.assistant)
          .map((l) => l.text)
          .join(' ');
      if (_shouldSurfaceReplyNotification(targetKey)) {
        _notifyBackgroundReply(inboundSid, preview);
      }
      _clearWaitingState(
        targetKey,
        flushQueue: targetKey == _activeSessionKey,
      );
      _logSessionSnapshot('cevap→$inboundSid');
      _reconcileWaitingFlagsForSession(inboundSid);
    } else if (parsed.kind == InboundKind.chatResponseComplete) {
      _reconcileWaitingFlagsForSession(inboundSid);
      final live = _registry.liveFor(inboundSid);
      if (hasAssistantText) {
        final preview = parsed.chatLines
            .where((l) => l.role == ChatRole.assistant)
            .map((l) => l.text)
            .join(' ');
        if (_shouldSurfaceReplyNotification(targetKey)) {
          _notifyBackgroundReply(inboundSid, preview);
        }
        _clearWaitingState(
          targetKey,
          flushQueue: targetKey == _activeSessionKey,
        );
        _logSessionSnapshot('complete(cevap)→$inboundSid');
      } else if (live.waitingResponse) {
        if (_tryMaterializeLiveStreamReplyForSession(inboundSid)) {
          _logSessionSnapshot('complete(stream)→$inboundSid');
        } else {
          _touchResponseIdleTimer();
          if (targetKey == _activeSessionKey) {
            lastProgressLine ??= 'Plan/yanıt hazırlanıyor…';
            _syncWaitDisplayTimer();
          }
          _schedulePostCompleteHistorySync(inboundSid);
          _logSessionSnapshot('complete(bekle)→$inboundSid');
        }
      }
    } else if (_registry.liveFor(inboundSid).waitingResponse) {
      _touchResponseIdleTimer();
    }

    notifyListeners();
  }

  bool _isChatSessionWireMessage(Map<String, dynamic>? map) {
    if (map == null) return false;
    final t = map['type'] as String?;
    return t == 'chat_response' ||
        t == 'chat_response_chunk' ||
        t == 'chat_response_complete';
  }

  void _applyChatLine(
    String sessionId,
    ChatRole role,
    String text,
    InboundKind kind,
  ) {
    final localId = sessionId.trim();
    final list = _registry.messagesFor(localId);
    final live = _registry.liveFor(localId);
    final tagSid = localId;

    if (kind == InboundKind.chatResponseChunk && mergeStreamChunks) {
      if (!showStreamPreview) {
        if (live.waitingResponse) {
          _touchResponseIdleTimer();
          final preview = sanitizeAssistantTextForDisplay(text).trim();
          if (preview.isNotEmpty) {
            _mergeAgentLiveStream(live, preview);
            if (localId == _activeSessionKey) {
              final short = preview.length > 100
                  ? '${preview.substring(0, 100)}…'
                  : preview;
              lastProgressLine = short;
            }
          }
        }
        return;
      }
      final streamId = live.streamingMessageId;
      final streamIdx =
          streamId == null ? -1 : list.indexWhere((m) => m.id == streamId);
      if (streamIdx >= 0) {
        list[streamIdx] = list[streamIdx]
            .copyWith(text: text, isStreaming: true, kind: kind);
      } else {
        final uid = _replyTargetUserIdFor(live);
        final streamMsg = ChatMessage(
          id: _id(),
          role: ChatRole.assistant,
          text: text,
          at: DateTime.now(),
          kind: kind,
          isStreaming: true,
          replyToUserId: uid,
          sessionId: tagSid,
        );
        if (uid != null) {
          insertAssistantAfterUser(list, streamMsg, uid);
          live.streamingMessageId = streamMsg.id;
        } else {
          list.add(streamMsg);
          live.streamingMessageId = streamMsg.id;
        }
      }
      return;
    }

    if (kind == InboundKind.chatResponseChunk) return;

    if (role == ChatRole.assistant &&
        (kind == InboundKind.chatResponse ||
            kind == InboundKind.chatResponseComplete) &&
        live.streamingMessageId != null) {
      final streamIdx =
          list.indexWhere((m) => m.id == live.streamingMessageId);
      if (streamIdx >= 0) {
        final cleaned = sanitizeAssistantTextForDisplay(text);
        final uid = list[streamIdx].replyToUserId ??
            _replyTargetUserIdFor(live);
        if (uid != null &&
            _isDuplicateAssistantReplyForUser(list, cleaned, uid)) {
          list.removeAt(streamIdx);
          live.streamingMessageId = null;
          _finishPendingReply(live, uid);
          return;
        }
        list[streamIdx] = list[streamIdx].copyWith(
          text: cleaned,
          kind: InboundKind.chatResponse,
          isStreaming: false,
          replyToUserId: uid ?? list[streamIdx].replyToUserId,
          sessionId: tagSid,
        );
        live.streamingMessageId = null;
        _finishPendingReply(live, uid);
        return;
      }
    }

    if (role == ChatRole.assistant &&
        (kind == InboundKind.chatResponse ||
            kind == InboundKind.chatResponseComplete)) {
      if (isGarbageAssistantText(text)) return;
      final cleaned = sanitizeAssistantTextForDisplay(text);
      if (cleaned.trim().isEmpty) return;
      final uid = _replyTargetUserIdFor(live);
      if (uid != null &&
          _isDuplicateAssistantReplyForUser(list, cleaned, uid)) {
        _finishPendingReply(live, uid);
        return;
      }
      final reply = ChatMessage(
        id: _id(),
        role: role,
        text: cleaned,
        at: DateTime.now(),
        kind: InboundKind.chatResponse,
        isStreaming: false,
        replyToUserId: uid,
        sessionId: tagSid,
      );
      if (uid != null) {
        insertAssistantAfterUser(list, reply, uid);
        _finishPendingReply(live, uid);
      } else {
        list.add(reply);
      }
      live.streamingMessageId = null;
      return;
    }

    list.add(
      ChatMessage(
        id: _id(),
        role: role,
        text: text,
        at: DateTime.now(),
        kind: kind,
        isStreaming: false,
        sessionId: tagSid,
      ),
    );
    if (role == ChatRole.assistant) {
      live.streamingMessageId = null;
    }
  }

  void _scheduleHistoryLoadAfterConnect() {
    Future<void> run() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!connected || _historyLoadedForConnection) return;
      if (_live.waitingResponse) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!connected || _historyLoadedForConnection) return;
        await loadChatHistory(replaceConversation: false);
        return;
      }
      final active = _activeLocalId;
      final pc = historyFilterForLocal(_store, active);
      if (pc != null) {
        await loadChatHistory(
          sessionIdFilter: pc,
          replaceConversation: !_sessionBucketHasChat(active),
        );
      } else if (!_sessionBucketHasChat(active)) {
        await loadChatHistory(replaceConversation: true);
      }
    }

    unawaited(run());
  }

  bool _isDeleteSessionCommandResult(Map<String, dynamic> data) =>
      isDeleteSessionCommandResult(data);

  String? _sessionIdFromDeleteResult(Map<String, dynamic> data) {
    final raw = data['data'];
    if (raw is! Map) return null;
    final sid = raw['sessionId'];
    if (sid is String && sid.trim().isNotEmpty) return sid.trim();
    return _pendingDeleteSessionId;
  }

  bool _handleCommandResult(Map<String, dynamic> data) {
    if (data['type'] != 'command_result') return false;

    final sessionRows = parseSessionInfoFromCommandResult(data);
    if (sessionRows.isNotEmpty) {
      final info = sessionRows.first;
      final sid = info['currentSessionId'] as String?;
      if (sid != null && sid.isNotEmpty && cursorSessionId != null) {
        _linkWireSession(cursorSessionId!, sid);
      }
    }

    final entries = parseHistoryEntriesFromCommandResult(data);
    if (entries.isNotEmpty) {
      final pendingLocal = _pendingHistorySessionFilter?.trim();
      if (pendingLocal != null && pendingLocal.isNotEmpty) {
        final replaceUi = _historyReplacePending;
        _pendingHistorySessionFilter = null;
        _historyReplacePending = false;
        loadingHistory = false;
        _historyLoadedForConnection = true;
        _upsertHistoryEntries(entries);
        _refreshSessionSummaries();
        final pendingTurns = filterPcHistoryForLocalBucket(
          _store,
          pendingLocal,
          _historyEntries,
        );
        HistoryTraceLog.pcRawEntries(pendingLocal, pendingTurns);
        applyHistoryEntriesToSession(
          pendingLocal,
          pendingTurns,
          replaceConversation: replaceUi,
        );
        _completeHistoryLoadWaiter(pendingLocal);
        SessionTraceLog.loadHistory(
          sessionId: pendingLocal,
          replace: replaceUi,
          force: true,
          silent: true,
          phase: 'pc-bitti',
          turns: pendingTurns.length,
        );
        if (pendingLocal == cursorSessionId) {
          _logRenderForSession(pendingLocal);
        }
        notifyListeners();
        return true;
      }
      HistoryTraceLog.pcRawEntries(cursorSessionId, entries);
      _onHistoryEntriesLoaded(
        entries,
        replaceConversation: _historyReplacePending,
      );
      _historyReplacePending = false;
      loadingHistory = false;
      _historyLoadedForConnection = true;
      return true;
    }

    if (data['command_type'] == 'clear_chat_history') {
      final raw = data['data'];
      final n = raw is Map && raw['deletedCount'] is num
          ? (raw['deletedCount'] as num).toInt()
          : 0;
      final ok = data['success'] == true;
      if (ok) {
        _clearLocalHistoryState();
      }
      if (_clearAllCompleter != null && !_clearAllCompleter!.isCompleted) {
        _clearAllCompleter!.complete(ok ? n : -1);
      }
      if (!ok) {
        _addVisibleNotice(
          'Geçmiş temizlenemedi: ${data['error'] ?? data['error_message'] ?? 'bilinmeyen'}',
          isError: true,
        );
      }
      notifyListeners();
      return true;
    }

    if (_isDeleteSessionCommandResult(data)) {
      final sid = (_pendingDeleteSessionId ?? _sessionIdFromDeleteResult(data))
          ?.trim();
      final deletedOnPc = parseDeletedCountFromCommandResult(data) ?? 0;
      final listBefore = sessionSummaries.length;
      if (sid != null && sid.isNotEmpty) {
        _applySessionRemovedLocally(sid);
      }
      final listAfter = sessionSummaries.length;
      final pcOk = data['success'] == true && deletedOnPc > 0;
      final localOk = listBefore > listAfter;
      final success = pcOk || localOk;

      if (!success) {
        _lastDeleteError =
            '${data['error'] ?? data['error_message'] ?? 'PC geçmişinde bu oturum bulunamadı'}';
      } else if (pcOk) {
        unawaited(
          loadChatHistory(replaceConversation: true, force: true),
        );
      }

      if (_deleteSessionCompleter != null &&
          !_deleteSessionCompleter!.isCompleted) {
        _deleteSessionCompleter!.complete(success);
      }
      _finishDeleteSessionWait(success);
      if (!success) {
        final hint = (_lastDeleteError ?? '').toLowerCase().contains('unknown')
            ? '\n\nPC: Cursor → Developer: Reload Window (extension güncellemesi).'
            : '';
        _addVisibleNotice(
          'Oturum silinemedi: $_lastDeleteError$hint',
          isError: true,
        );
      }
      notifyListeners();
      return true;
    }

    if (data['command_type'] == 'get_chat_history') {
      loadingHistory = false;
      _historyLoadedForConnection = true;
      final pendingLocal = _pendingHistorySessionFilter?.trim();
      if (pendingLocal != null && pendingLocal.isNotEmpty) {
        _pendingHistorySessionFilter = null;
        _historyReplacePending = false;
        _completeHistoryLoadWaiter(pendingLocal);
        _reconcileWaitingFlagsForSession(pendingLocal);
      }
      if (data['success'] != true) {
        _addVisibleNotice(
          'Geçmiş alınamadı: ${data['error'] ?? data['error_message'] ?? 'bilinmeyen'}',
          isError: true,
        );
      } else if (data['success'] == true && entries.isEmpty) {
        _historyEntries = [];
        if (_store.localIds.isEmpty) {
          sessionSummaries = [];
        } else {
          _refreshSessionSummaries();
        }
        statusNote =
            'Bağlı — geçmiş boş (bu workspace\'te uzaktan kayıt yok veya PC\'de proje açık değil)';
      }
      return true;
    }

    if (data['command_type'] == 'insert_text' && data['success'] != true) {
      final key = _pcBusySessionKey ?? _activeSessionKey;
      _clearWaitingState(key);
      _allMessages.add(
        ChatMessage(
          id: _id(),
          role: ChatRole.assistant,
          text:
              '❌ PC hatası: ${data['error'] ?? data['error_message'] ?? 'insert_text başarısız'}',
          at: DateTime.now(),
          kind: InboundKind.commandResult,
        ),
      );
      return true;
    }

    return data['command_type'] == 'get_session_info';
  }

  bool _historyReplacePending = false;

  void _onHistoryEntriesLoaded(
    List<Map<String, dynamic>> entries, {
    bool replaceConversation = false,
  }) {
    _historyEntries = normalizeHistoryEntries(entries);
    _refreshSessionSummaries();

    if (_historyRefreshListOnly) {
      _historyRefreshListOnly = false;
      notifyListeners();
      return;
    }

    // Henüz PC dosyasında olmayan oturum — geçmişle ekranı silme.
    if (_isLocalOnlyActiveSession()) {
      notifyListeners();
      return;
    }

    // Agent çalışırken tam replace yerine birleştir (son gönderilen balon kaybolmasın).
    final replaceUi = !_live.waitingResponse;

    final saved = _restoredSessionId?.trim();
    if (cursorSessionId == null || cursorSessionId!.isEmpty) {
      final restored = resolveRestoredLocalId(
        _store,
        saved,
        historyEntries: _historyEntries,
      );
      if (restored != null) {
        cursorSessionId = restored;
        _store.setActive(restored);
        if (saved != null &&
            !saved.startsWith('loc-') &&
            saved.isNotEmpty) {
          _linkWireSession(restored, saved);
        }
      }
    }

    if (cursorSessionId != null && cursorSessionId!.isNotEmpty) {
      applyHistoryForActiveSession(replaceConversation: replaceUi);
      _reconcileWaitingFlagsForSession(cursorSessionId);
      notifyListeners();
      return;
    }

    if (sessionSummaries.isNotEmpty) {
      cursorSessionId = sessionSummaries.first.sessionId;
      applyHistoryForActiveSession(replaceConversation: replaceUi);
      notifyListeners();
      return;
    }

    if (cursorSessionId != null && cursorSessionId!.trim().isNotEmpty) {
      applyHistoryForActiveSession(replaceConversation: replaceUi);
    }
    notifyListeners();
  }

  void applyHistoryForActiveSession({bool replaceConversation = false}) {
    final raw = cursorSessionId?.trim();
    if (raw == null || raw.isEmpty) return;
    final target = _historyApplyLocalId(raw);
    _applyHistoryForLocal(
      target,
      _historyEntries,
      replaceConversation: replaceConversation,
    );
  }

  void selectSession(String sessionId) {
    final prevSid = cursorSessionId;
    _commitResolvedSession(sessionId);
    final local = cursorSessionId!;
    HistoryTraceLog.selectSession(local, activeSessionLabel);
    unawaited(_settings.saveLastSessionId(local));
    _registry.liveFor(local).unreadReplies = 0;
    unawaited(SessionReplyNotification.cancel(local));
    if (sessionAlertId == local) {
      clearSessionActivityAlert();
    }
    var replaceHistory = !_store.of(local).isDraft &&
        !_sessionBucketHasChat(local);
    final cacheTurns =
        filterPcHistoryForLocalBucket(_store, local, _historyEntries).length;
    if (replaceHistory && _sessionBucketHasChat(local) && cacheTurns == 0) {
      replaceHistory = false;
    }
    applyHistoryForActiveSession(replaceConversation: replaceHistory);
    final pc = historyFilterForLocal(_store, local);
    if (pc != null && connected) {
      unawaited(
        loadChatHistory(
          sessionIdFilter: pc,
          forLocalSessionId: local,
          replaceConversation: replaceHistory,
          force: true,
          silent: cacheTurns > 0,
        ),
      );
    }
    SessionTraceLog.select(
      fromSid: prevSid,
      toSid: local,
      label: activeSessionLabel,
      cacheTurns: cacheTurns,
      pcRefresh: pc != null && connected,
    );
    _logRenderForSession(local);
    _reconcileWaitingFlagsForSession(local);
    _sanitizeAllSessionQueues();
    final purged = purgeForeignMessagesInBucket(
      _registry.messagesFor(local),
      local,
    );
    if (purged > 0) {
      SessionTraceLog.isolationPurge(local, purged);
    }
    if (_hasFlushableQueuedGlobally) {
      _scheduleQueueFlushNext();
    }
    _logSessionSnapshot('selectSession');
    notifyListeners();
  }

  void _logRenderForSession(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return;
    final rendered = buildDisplayMessagesForSession(sessionId);
    final last = rendered.isEmpty ? null : rendered.last;
    SessionTraceLog.renderBottom(
      sessionId: sessionId,
      count: rendered.length,
      bottomRole: last?.role,
      bottomId: last?.id,
    );
  }

  void _applySessionRemovedLocally(String sessionId) {
    final local = sessionId.trim();
    final pc = historyFilterForLocal(_store, local);
    _historyEntries.removeWhere((e) {
      final es = (e['sessionId'] as String? ?? '').trim();
      return es == local || (pc != null && es == pc);
    });
    sessionNames.remove(local);
    unawaited(_settings.saveSessionNames(sessionNames));
    sessionSummaries = _buildSessionSummaries();
    _store.remove(local);
    if (cursorSessionId == local) {
      cursorSessionId = null;
      _addVisibleNotice('Oturum silindi.');
    }
  }

  void _clearLocalHistoryState() {
    _historyEntries = [];
    sessionSummaries = [];
    cursorSessionId = null;
    _dispatchBucketByLocalMessageId.clear();
    _registry.clearAllConversation();
    _pcBusySessionKey = null;
    unawaited(LocalSessionCache.clear());
  }

  /// Tüm uzak geçmişi PC dosyasından siler.
  Future<int> clearAllSessions() async {
    if (!_ws.isConnected) return -1;
    if (_clearAllCompleter != null) return -1;

    _clearAllCompleter = Completer<int>();
    final sent = _ws.sendClearChatHistory(onTraffic: _addTraffic);
    if (!sent) {
      _clearAllCompleter = null;
      return -1;
    }

    try {
      final n = await _clearAllCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => -1,
      );
      if (n >= 0) {
        _clearLocalHistoryState();
        notifyListeners();
      }
      return n;
    } catch (_) {
      return -1;
    } finally {
      _clearAllCompleter = null;
    }
  }

  /// PC `sessionId` (yoksa null — yalnızca yerel kutu).
  String? historyWireSessionId(String? localSessionId) =>
      historyFilterForLocal(_store, localSessionId?.trim() ?? '');

  /// Sil ikonu: yerel taslak her zaman; PC kaydı için bağlantı gerekir.
  bool canDeleteSession(String sessionId) {
    final local = sessionId.trim();
    if (local.isEmpty) return false;
    if (historyFilterForLocal(_store, local) == null) return true;
    return _ws.isConnected;
  }

  /// Oturumu kaldır — PC geçmişi varsa extension, yoksa yalnızca telefon.
  Future<bool> removeSession(String sessionId) async {
    final local = sessionId.trim();
    if (local.isEmpty) return false;
    if (_deleteSessionCompleter != null) return false;

    final pc = historyFilterForLocal(_store, local);
    if (pc == null) {
      _applySessionRemovedLocally(local);
      unawaited(flushLocalCache());
      notifyListeners();
      return true;
    }

    if (!_ws.isConnected) return false;
    _pendingDeleteSessionId = pc;
    _lastDeleteError = null;
    _deleteSessionCompleter = Completer<bool>();
    final sent = _ws.sendDeleteSession(
      sessionId: _pendingDeleteSessionId!,
      clientId: deviceClientId,
      onTraffic: _addTraffic,
    );
    if (!sent) {
      _finishDeleteSessionWait(false);
      return false;
    }

    try {
      return await _deleteSessionCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _finishDeleteSessionWait(false);
          return false;
        },
      );
    } catch (_) {
      _finishDeleteSessionWait(false);
      return false;
    }
  }

  void _finishDeleteSessionWait(bool ok) {
    _deleteSessionCompleter = null;
    _pendingDeleteSessionId = null;
    _lastDeleteError = null;
    if (!ok) notifyListeners();
  }

  void startNewChat() {
    final newId = _store.beginDraftSession();
    cursorSessionId = newId;
    unawaited(_settings.saveLastSessionId(newId));
    _registry.messagesFor(newId).add(
      ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text:
            'Yeni oturuma geçildi — sonraki mesajınız PC\'de yeni agent sohbeti açar.',
        at: DateTime.now(),
        kind: InboundKind.system,
        sessionId: newId,
      ),
    );
    _refreshSessionSummaries();
    notifyListeners();
  }

  List<ChatMessage> _protectedMessagesDuringHistorySync(
    List<ChatMessage> current,
    String? sessionId,
  ) =>
      protectMessagesDuringHistorySync(
        current: current,
        live: _registry.liveFor(sessionId),
      );

  void _mergeProtectedIntoList(
    List<ChatMessage> list,
    List<ChatMessage> protected,
  ) {
    mergeProtectedIntoList(
      list,
      protected,
      localIsRicher: localUserBubbleIsRicher,
      messagesEquivalent: chatMessagesEquivalent,
      sortChronologically: sortChatMessagesChronologically,
    );
  }

  void applyHistoryEntries(
    List<Map<String, dynamic>> entries, {
    bool replaceConversation = false,
  }) {
    final raw = cursorSessionId?.trim();
    if (raw == null || raw.isEmpty) return;
    final target = _historyApplyLocalId(raw);
    _applyHistoryForLocal(
      target,
      entries,
      replaceConversation: replaceConversation,
    );
  }

  void _applyHistoryForLocal(
    String localId,
    List<Map<String, dynamic>> allEntries, {
    required bool replaceConversation,
  }) {
    final filtered = filterPcHistoryForLocalBucket(
      _store,
      localId,
      allEntries,
    );
    applyHistoryEntriesToSession(
      localId,
      filtered,
      replaceConversation: replaceConversation,
    );
  }

  void applyHistoryEntriesToSession(
    String? sessionId,
    List<Map<String, dynamic>> entries, {
    bool replaceConversation = false,
  }) {
    final sid = sessionId?.trim();
    if (sid == null || sid.isEmpty) return;
    final normalized = normalizeHistoryEntries(entries);
    SessionTraceLog.appliedPcTurns(
      targetSid: sid,
      label: activeSessionLabel,
      turns: normalized,
    );
    HistoryTraceLog.afterNormalize(sid, normalized);
    final list = _registry.messagesFor(sid);
    final protected = replaceConversation
        ? _protectedMessagesDuringHistorySync(list, sid)
        : const <ChatMessage>[];

    final hadChatBeforeReplace = list.any(isReplaceableConversationMessage);
    final imported = dedupeEquivalentUserMessages(
      entriesToChatMessages(normalized, alreadyNormalized: true)
          .map(
            (m) => ChatMessage(
              id: m.id,
              role: m.role,
              text: m.text,
              at: m.at,
              kind: m.kind,
              agentMode: m.agentMode,
              isStreaming: m.isStreaming,
              replyToUserId: m.replyToUserId,
              sessionId: sid,
            ),
          )
          .toList(),
    );
    if (replaceConversation &&
        imported.isEmpty &&
        hadChatBeforeReplace) {
      _sanitizeQueueForSession(sid);
      notifyListeners();
      return;
    }
    if (replaceConversation) {
      list.removeWhere(isReplaceableConversationMessage);
    }
    if (imported.isEmpty && replaceConversation) {
      if (protected.isNotEmpty) {
        list.addAll(protected);
      } else if (!hadChatBeforeReplace) {
        _addVisibleNotice('Bu oturumda kayıtlı sohbet geçmişi yok.');
      }
      _sanitizeQueueForSession(sid);
      notifyListeners();
      return;
    }
    if (replaceConversation) {
      list.addAll(imported);
      _mergeProtectedIntoList(list, protected);
      final merged = consolidateSessionChatMessages(list);
      if (merged.isEmpty && hadChatBeforeReplace && protected.isNotEmpty) {
        list
          ..clear()
          ..addAll(protected);
      } else {
        list
          ..clear()
          ..addAll(merged);
      }
    } else {
      for (final m in imported) {
        if (m.role == ChatRole.user) {
          final dupIdx = list.indexWhere(
            (x) =>
                x.role == ChatRole.user &&
                userMessagesLikelySame(x.text, m.text),
          );
          if (dupIdx >= 0) {
            final picked = pickPreferredUserBubble(list[dupIdx], m);
            if (list[dupIdx].id != picked.id) {
              rewireAssistantRepliesAfterUserIdChange(
                list,
                list[dupIdx].id,
                picked.id,
              );
            }
            list[dupIdx] = picked;
            continue;
          }
        } else if (m.role == ChatRole.assistant) {
          final dupIdx = list.indexWhere(
            (x) => x.role == ChatRole.assistant && chatMessagesEquivalent(x, m),
          );
          if (dupIdx >= 0) {
            if (m.text.trim().length >
                list[dupIdx].text.trim().length + 8) {
              list[dupIdx] = m;
            }
            continue;
          }
          final replyUid = m.replyToUserId;
          if (replyUid != null &&
              userTurnHasVisibleAssistantReply(
                list,
                replyUid,
                sameUserText: userMessagesLikelySame,
              )) {
            continue;
          }
        }
        list.add(m);
      }
      _reorderSessionChatByTurns(list);
      final consolidated = consolidateSessionChatMessages(list);
      list
        ..clear()
        ..addAll(consolidated);
    }
    _sanitizeQueueForSession(sid);
    _reconcileWaitingFlagsForSession(sid);
    final bottom = list.isEmpty ? null : list.last;
    HistoryTraceLog.applyHistory(
      sessionId: sid,
      replace: replaceConversation,
      rawTurns: entries.length,
      importedBubbles: imported.length,
      protectedCount: protected.length,
      listSizeAfter: list.length,
      bottomRole: bottom?.role.name,
      bottomPreview: bottom != null
          ? HistoryTraceLog.preview(bottom.text, 48)
          : null,
      bottomAt: bottom?.at.toLocal().toIso8601String(),
    );
    HistoryTraceLog.uiBubbleList(sid, list);
    if (sid == cursorSessionId) {
      HistoryTraceLog.uiRenderList(sid, buildDisplayMessagesForSession(sid));
    }
    final purged = purgeForeignMessagesInBucket(list, sid);
    if (purged > 0) {
      SessionTraceLog.isolationPurge(sid, purged);
    }
    notifyListeners();
  }

  bool _isDraftBucketKey(String sid) =>
      sid.startsWith('loc-') && !_store.of(sid).hasPcSession;

  Future<void> loadChatHistory({
    bool replaceConversation = false,
    int limit = defaultChatHistoryLimit,
    bool force = false,
    String? sessionIdFilter,
    String? forLocalSessionId,
    bool silent = false,
  }) async {
    if (!_ws.isConnected) return;
    if (loadingHistory && !force && !silent) return;
    final filterRaw = sessionIdFilter?.trim();
    final explicitLocal = forLocalSessionId?.trim();
    String? wireFilter = filterRaw;
    String? localApply = explicitLocal;
    if (localApply != null && localApply.isNotEmpty) {
      wireFilter = historyFilterForLocal(_store, localApply) ?? filterRaw;
    } else if (filterRaw != null && filterRaw.startsWith('loc-')) {
      localApply = filterRaw;
      wireFilter = historyFilterForLocal(_store, filterRaw);
    } else if (filterRaw != null && filterRaw.isNotEmpty) {
      localApply = _sessions.resolve(
        filterRaw,
        historyEntries: _historyEntries,
      );
      wireFilter = historyFilterForLocal(_store, localApply) ?? filterRaw;
    }
    final sw = Stopwatch()..start();
    SessionTraceLog.loadHistory(
      sessionId: localApply ?? wireFilter,
      replace: replaceConversation,
      force: force,
      silent: silent,
      phase: 'başla',
    );

    if (wireFilter != null && wireFilter.isNotEmpty && !force) {
      final cached = localApply != null
          ? filterPcHistoryForLocalBucket(
              _store,
              localApply,
              _historyEntries,
            )
          : strictFilterEntriesBySession(_historyEntries, wireFilter);
      if (cached.isNotEmpty && localApply != null) {
        HistoryTraceLog.loadChatHistory(
          sessionId: wireFilter,
          limit: limit,
          replace: replaceConversation,
          force: force,
          source: 'yerel_önbellek',
        );
        HistoryTraceLog.pcRawEntries(localApply, cached);
        applyHistoryEntriesToSession(
          localApply,
          cached,
          replaceConversation: replaceConversation,
        );
        SessionTraceLog.loadHistory(
          sessionId: localApply,
          replace: replaceConversation,
          force: force,
          silent: silent,
          phase: 'önbellek-bitti',
          ms: sw.elapsedMilliseconds,
          turns: cached.length,
        );
        if (localApply == cursorSessionId) _logRenderForSession(localApply);
        notifyListeners();
        return;
      }
    }

    if (!silent) {
      loadingHistory = true;
      notifyListeners();
    }
    _historyReplacePending = replaceConversation;
    _pendingHistorySessionFilter =
        (localApply != null && localApply.isNotEmpty) ? localApply : null;

    HistoryTraceLog.loadChatHistory(
      sessionId: wireFilter,
      limit: limit,
      replace: replaceConversation,
      force: force,
      source: silent ? 'pc_ws_sessiz' : 'pc_ws',
    );
    _ws.sendGetChatHistory(
      sessionId: wireFilter,
      limit: wireFilter != null && wireFilter.isNotEmpty ? limit : 500,
      onTraffic: _addTraffic,
    );
  }

  Future<void> refreshSessionsAndHistory() async {
    if (!_ws.isConnected) return;
    _historyRefreshListOnly = true;
    await loadChatHistory(
      replaceConversation: false,
      force: true,
      limit: defaultChatHistoryLimit,
    );
  }

  Future<void> sendPrompt(
    String text, {
    bool immediate = false,
    List<PromptAttachment> attachments = const [],
  }) async {
    final trimmed = text.trim();
    final atts = List<PromptAttachment>.from(attachments);
    if (trimmed.isEmpty && atts.isEmpty) return;

    _ensureActiveSession();
    final localId = _activeLocalId;

    final offline = !connected;

    final totalAttBytes = atts.fold<int>(0, (sum, a) => sum + a.byteLength);
    if (totalAttBytes > PromptAttachment.maxBytesPerFile * PromptAttachment.maxFiles) {
      _addVisibleNotice(
        'Ekler çok büyük; daha az veya küçük dosya seçin.',
        isError: true,
      );
      notifyListeners();
      return;
    }

    final mode = promptAgentMode;
    final msgId = _id();
    final bubbleText = formatUserMessageWithAttachments(trimmed, atts);
    final sessionList = _registry.messagesFor(localId);
    sessionList.add(
      ChatMessage(
        id: msgId,
        role: ChatRole.user,
        text: bubbleText,
        at: DateTime.now(),
        kind: InboundKind.userPrompt,
        agentMode: mode,
        sessionId: localId,
      ),
    );

    // Çevrimdışı veya bu oturumda gerçekten uçuşta tur varken sıraya al.
    final liveSend = _registry.liveFor(localId);
    _sanitizeQueueForSession(localId);
    _clearStaleWaitingIfNeeded(liveSend);
    final sessionActivelyWaiting = _sessionActivelyWaiting(liveSend);
    final queueInstead = !immediate &&
        (offline ||
            (busySendPolicy == BusySendPolicy.queue &&
                (_effectiveQueuedFor(localId).isNotEmpty ||
                    sessionActivelyWaiting)));

    if (queueInstead || (offline && immediate)) {
      _promptQueue.add(
        QueuedPrompt(
          text: trimmed,
          agentMode: mode,
          queuedAt: DateTime.now(),
          localMessageId: msgId,
          sessionId: localId,
          attachments: atts,
        ),
      );
      unawaited(_persistPromptQueue());
      _refreshSessionSummaries();
      if (!offline) {
        _flushQueuedWhenConnected(preferSessionId: localId);
      }
      _logSessionSnapshot(offline ? 'sıraya(çevrimdışı)' : 'sıraya');
      notifyListeners();
      return;
    }

    if (offline) return;

    _dispatchPromptToPc(
      trimmed,
      agentMode: mode,
      attachments: atts,
      userMessageId: msgId,
      sessionId: localId,
      preempt: immediate || busySendPolicy == BusySendPolicy.interrupt,
    );
    _refreshSessionSummaries();
    notifyListeners();
  }

  void _prepareDispatchToSession(String? sessionId, {required bool preempt}) {
    final key = sessionId?.trim() ?? _activeLocalId;
    if (preempt &&
        _pcBusySessionKey != null &&
        _pcBusySessionKey == key &&
        _registry.liveFor(key).waitingResponse) {
      _requeueInFlightForSession(key);
      _registry.liveFor(key).clearWaiting();
    }
    _pcBusySessionKey = key;
  }

  void _dispatchPromptToPc(
    String trimmed, {
    required String agentMode,
    List<PromptAttachment> attachments = const [],
    required String userMessageId,
    String? sessionId,
    bool preempt = false,
  }) {
    _prepareDispatchToSession(sessionId, preempt: preempt);
    final key = sessionId?.trim() ?? _activeLocalId;
    final live = _registry.liveFor(key);

    _dispatchBucketByLocalMessageId[userMessageId] = key;

    live.awaitingReplyForUserId = userMessageId;
    live.pendingReplyForUserId = userMessageId;
    live.waitingResponse = true;
    live.waitingSince = DateTime.now();
    live.agentLiveStreamText = '';
    live.agentLiveProgressLine = '';
    live.streamingMessageId = null;
    final now = DateTime.now();
    live.lastPcActivityAt = now;
    if (key == _activeSessionKey) {
      lastPcActivityAt = now;
    }
    lastProgressLine = null;
    if (key == _activeSessionKey) {
      _armResponseIdleTimer(key);
    }
    _syncWaitDisplayTimer();
    live.inFlight = QueuedPrompt(
      text: trimmed,
      agentMode: agentMode,
      queuedAt: DateTime.now(),
      localMessageId: userMessageId,
      sessionId: sessionId,
      attachments: attachments,
    );
    live.inFlightWireDispatched = false;
    notifyListeners();

    final record = _store.of(key);
    final newSession = record.isDraft;
    if (newSession) record.isDraft = false;

    final wireSessionId = wireSessionIdForSend(
      _store,
      sessionId ?? cursorSessionId,
      newSession: newSession,
    );
    HistoryTraceLog.sendPrompt(
      wireSessionId: wireSessionId,
      cursorSessionId: cursorSessionId,
      localMsgId: userMessageId,
      textPreview: HistoryTraceLog.preview(
        formatUserMessageWithAttachments(trimmed, attachments),
        40,
      ),
    );
    SessionTraceLog.sendPrompt(
      wireSid: wireSessionId,
      uiSid: cursorSessionId,
      localId: userMessageId,
      preview: HistoryTraceLog.preview(trimmed, 40),
    );
    final sent = _ws.sendPrompt(
      text: trimmed,
      agentMode: agentMode,
      clientId: deviceClientId,
      sessionId: wireSessionId,
      newSession: newSession,
      replyChannel: mobileOptimizedPrompts ? 'mobile' : null,
      composerUseFast: composerUseFast,
      attachments: attachments.map((a) => a.toWireJson()).toList(),
      onTraffic: _addTraffic,
    );
    if (!sent) {
      _clearWaitingState(key);
      _addVisibleNotice('Gönderilemedi: bağlantı yok.', isError: true);
      notifyListeners();
      return;
    }
    live.inFlightWireDispatched = true;
    if (attachments.isNotEmpty) {
      final n = attachments.length;
      _addVisibleNotice(
        '📎 $n ek PC\'ye gönderildi (workspace .cursor-remote-attachments)',
      );
    }
  }

  /// Bekleyen agent turunu iptal et — yalnızca aktif oturum.
  void stopPrompt() {
    final key = _activeSessionKey;
    final live = _registry.liveFor(key);
    if (!live.waitingResponse && live.inFlight == null) return;

    if (_ws.isConnected) {
      final wire = historyFilterForLocal(_store, key);
      _ws.sendStop(sessionId: wire, onTraffic: _addTraffic);
    }
    _cancelQueueFlushDebounce();
    live.pendingReplyForUserId = null;
    _clearWaitingState(key);
    statusNote = _ws.isConnected
        ? 'Agent durduruldu'
        : 'Yanıt beklemesi iptal edildi';
    notifyListeners();
  }

  bool get canStopWaitingAgent => isActiveSessionAwaitingAgent;

  static final _idRandom = Random();

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idRandom.nextInt(1 << 20)}';

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleAgentWorkNotificationSync();
    _scheduleLocalCacheSave();
  }

  void _scheduleLocalCacheSave() {
    if (!settingsReady) return;
    _localCacheDebounce?.cancel();
    _localCacheDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_persistLocalCache());
    });
  }

  Future<void> flushLocalCache() async {
    _localCacheDebounce?.cancel();
    await _persistLocalCache();
  }

  Future<void> _persistLocalCache() async {
    final snap = _store.exportSnapshot(
      activeSessionId: cursorSessionId,
      sessionNames: sessionNames,
    );
    await LocalSessionCache.save(snap);
    await _settings.saveSessionNames(sessionNames);
    final active = cursorSessionId?.trim();
    if (active != null && active.isNotEmpty) {
      await _settings.saveLastSessionId(active);
    }
  }

  Future<void> _restoreLocalCache() async {
    final snap = await LocalSessionCache.load();
    if (snap == null) return;
    _store.importSnapshot(snap);
    sessionNames.addAll(snap.sessionNames);
    final active = snap.activeSessionId?.trim();
    if (active != null && active.isNotEmpty) {
      _restoredSessionId = active;
      cursorSessionId = active;
      _store.setActive(active);
    }
    _refreshSessionSummaries();
  }

  void _scheduleAgentWorkNotificationSync() {
    _agentNotifDebounce?.cancel();
    _agentNotifDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_syncAgentWorkNotification());
    });
  }

  Future<void> _syncAgentWorkNotification() async {
    var active = 0;
    for (final e in _registry.liveEntries) {
      final live = e.value;
      if (live.waitingResponse ||
          effectiveQueuedFor(
            _registry,
            e.key,
            userMessagesLikelySame: userMessagesLikelySame,
          ).isNotEmpty) {
        active++;
      }
    }
    await AgentWorkNotification.sync(
      connected: connected,
      connecting: _connecting || isHandshaking,
      activeSessions: active,
      appInBackground: _appInBackground,
      detail: _live.waitingResponse ? waitingStatusText : null,
    );
  }

  @override
  void dispose() {
    _agentNotifDebounce?.cancel();
    _localCacheDebounce?.cancel();
    unawaited(flushLocalCache());
    unawaited(AgentWorkNotification.dispose());
    _foregroundSyncDebounce?.cancel();
    _cancelResponseIdleTimer();
    _cancelQueueFlushDebounce();
    _stopWaitDisplayTimer();
    _cancelPostCompleteHistoryTimer();
    for (final c in _historyLoadWaiters.values) {
      if (!c.isCompleted) c.complete();
    }
    _historyLoadWaiters.clear();
    _ws.disconnect();
    super.dispose();
  }
}
