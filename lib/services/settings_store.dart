import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/queued_prompt.dart';

class SettingsStore {
  static const _hostKey = 'pc_host';
  static const _deviceClientIdKey = 'device_client_id';
  static const _mobileOptimizedKey = 'mobile_optimized_prompts';
  static const _composerUseFastKey = 'composer_use_fast';
  static const _portKey = 'pc_port';
  static const _promptAgentModeKey = 'prompt_agent_mode';
  static const _showLogsKey = 'show_logs';
  static const _showSystemKey = 'show_system';
  static const _mergeStreamKey = 'merge_stream';
  static const _streamPreviewKey = 'stream_preview';
  static const _showProgressKey = 'show_progress';
  static const _authTokenKey = 'auth_token';
  static const _idleTimeoutMinKey = 'response_idle_timeout_min';
  static const _sessionNamesKey = 'session_display_names';
  static const _busySendPolicyKey = 'busy_send_policy';
  static const _promptQueueKey = 'pending_prompt_queue';
  static const _autoReconnectKey = 'auto_reconnect_enabled';
  static const _lastSessionIdKey = 'last_cursor_session_id';

  /// Meşgulken gönder: queue (sıraya al) | interrupt (hemen kes).
  Future<BusySendPolicy> loadBusySendPolicy() async {
    final p = await SharedPreferences.getInstance();
    return busySendPolicyFromString(p.getString(_busySendPolicyKey));
  }

  Future<void> saveBusySendPolicy(BusySendPolicy policy) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_busySendPolicyKey, busySendPolicyToString(policy));
  }

  Future<({String host, int port, String authToken})> loadConnection() async {
    final p = await SharedPreferences.getInstance();
    return (
      host: p.getString(_hostKey) ?? '',
      port: p.getInt(_portKey) ?? 8766,
      authToken: p.getString(_authTokenKey) ?? '',
    );
  }

  Future<void> saveConnection(String host, int port, {String? authToken}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_hostKey, host.trim());
    await p.setInt(_portKey, port);
    if (authToken != null) {
      await p.setString(_authTokenKey, authToken.trim());
    }
  }

  Future<String> loadAuthToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_authTokenKey) ?? '';
  }

  Future<void> saveAuthToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_authTokenKey, token.trim());
  }

  /// Cevap beklerken gelen trafik yoksa bu süre sonra uyarı (dakika).
  Future<int> loadResponseIdleTimeoutMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_idleTimeoutMinKey) ?? 45;
  }

  Future<void> saveResponseIdleTimeoutMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_idleTimeoutMinKey, minutes.clamp(5, 180));
  }

  /// Sohbetten gönderirken son seçilen mod (agent / ask / plan).
  Future<String> loadPromptAgentMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_promptAgentModeKey) ?? 'agent';
  }

  Future<void> savePromptAgentMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_promptAgentModeKey, mode);
  }

  Future<
      ({
        bool showLogs,
        bool showSystem,
        bool mergeStream,
        bool showProgress,
        bool streamPreview,
      })> loadFilters() async {
    final p = await SharedPreferences.getInstance();
    return (
      showLogs: p.getBool(_showLogsKey) ?? false,
      showSystem: p.getBool(_showSystemKey) ?? false,
      mergeStream: p.getBool(_mergeStreamKey) ?? true,
      showProgress: p.getBool(_showProgressKey) ?? true,
      streamPreview: p.getBool(_streamPreviewKey) ?? false,
    );
  }

  Future<void> saveFilters({
    required bool showLogs,
    required bool showSystem,
    required bool mergeStream,
    required bool showProgress,
    required bool streamPreview,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_showLogsKey, showLogs);
    await p.setBool(_showSystemKey, showSystem);
    await p.setBool(_mergeStreamKey, mergeStream);
    await p.setBool(_showProgressKey, showProgress);
    await p.setBool(_streamPreviewKey, streamPreview);
  }

  /// Uygulama yeniden açılsa da aynı kalır; PC geçmişi bu ID ile eşleşir.
  Future<bool> loadMobileOptimizedPrompts() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_mobileOptimizedKey) ?? true;
  }

  Future<void> saveMobileOptimizedPrompts(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_mobileOptimizedKey, value);
  }

  /// CLI --model: true = composer-2.5-fast, false = composer-2.5 (Fast kapalı).
  Future<bool> loadComposerUseFast() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_composerUseFastKey) ?? false;
  }

  Future<void> saveComposerUseFast(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_composerUseFastKey, value);
  }

  /// Oturum başlıkları yalnızca telefonda (sessionId → isim).
  Future<Map<String, String>> loadSessionNames() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_sessionNamesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), v.toString().trim()),
      )..removeWhere((_, v) => v.isEmpty);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSessionNames(Map<String, String> names) async {
    final p = await SharedPreferences.getInstance();
    final cleaned = <String, String>{};
    for (final e in names.entries) {
      final v = e.value.trim();
      if (v.isNotEmpty) cleaned[e.key] = v;
    }
    await p.setString(_sessionNamesKey, jsonEncode(cleaned));
  }

  Future<bool> loadAutoReconnectEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoReconnectKey) ?? true;
  }

  Future<void> saveAutoReconnectEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoReconnectKey, value);
  }

  Future<String?> loadLastSessionId() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_lastSessionIdKey)?.trim();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  Future<void> saveLastSessionId(String? sessionId) async {
    final p = await SharedPreferences.getInstance();
    final id = sessionId?.trim() ?? '';
    if (id.isEmpty) {
      await p.remove(_lastSessionIdKey);
      return;
    }
    await p.setString(_lastSessionIdKey, id);
  }

  Future<List<QueuedPrompt>> loadPromptQueue() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_promptQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <QueuedPrompt>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final id = item['localMessageId']?.toString() ?? '';
          if (id.isEmpty) continue;
          final q = QueuedPrompt.fromJson(item);
          if (q.text.trim().isEmpty && q.attachments.isEmpty) continue;
          out.add(q);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> savePromptQueue(List<QueuedPrompt> queue) async {
    final p = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await p.remove(_promptQueueKey);
      return;
    }
    await p.setString(
      _promptQueueKey,
      jsonEncode(queue.map((q) => q.toJson()).toList()),
    );
  }

  Future<String> loadOrCreateDeviceClientId() async {
    final p = await SharedPreferences.getInstance();
    final existing = p.getString(_deviceClientIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final rnd = Random();
    final suffix = List.generate(8, (_) => rnd.nextInt(36).toRadixString(36)).join();
    final id = 'mobile-$suffix';
    await p.setString(_deviceClientIdKey, id);
    return id;
  }
}
