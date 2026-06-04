import 'chat_message.dart';
import 'chat_message_json.dart';

/// Telefonda saklanan oturum + sohbet (PC geçmişinden bağımsız).
class LocalSessionSnapshot {
  const LocalSessionSnapshot({
    this.version = currentVersion,
    this.activeSessionId,
    this.sessionNames = const {},
    this.sessions = const [],
  });

  static const currentVersion = 1;

  final int version;
  final String? activeSessionId;
  final Map<String, String> sessionNames;
  final List<PersistedSessionRecord> sessions;

  Map<String, dynamic> toJson() => {
        'version': version,
        if (activeSessionId != null) 'activeSessionId': activeSessionId,
        'sessionNames': sessionNames,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory LocalSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final namesRaw = json['sessionNames'];
    final names = <String, String>{};
    if (namesRaw is Map) {
      for (final e in namesRaw.entries) {
        final v = e.value?.toString().trim() ?? '';
        if (v.isNotEmpty) names[e.key.toString()] = v;
      }
    }
    final sessionsRaw = json['sessions'];
    final sessions = <PersistedSessionRecord>[];
    if (sessionsRaw is List) {
      for (final item in sessionsRaw) {
        if (item is Map<String, dynamic>) {
          sessions.add(PersistedSessionRecord.fromJson(item));
        }
      }
    }
    return LocalSessionSnapshot(
      version: json['version'] is int ? json['version'] as int : 1,
      activeSessionId: json['activeSessionId']?.toString(),
      sessionNames: names,
      sessions: sessions,
    );
  }
}

class PersistedSessionRecord {
  const PersistedSessionRecord({
    required this.localId,
    this.pcSessionId,
    this.isDraft = false,
    required this.createdAt,
    this.messages = const [],
  });

  final String localId;
  final String? pcSessionId;
  final bool isDraft;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        if (pcSessionId != null && pcSessionId!.isNotEmpty)
          'pcSessionId': pcSessionId,
        'isDraft': isDraft,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory PersistedSessionRecord.fromJson(Map<String, dynamic> json) {
    final msgsRaw = json['messages'];
    final messages = <ChatMessage>[];
    if (msgsRaw is List) {
      for (final item in msgsRaw) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessageJson.fromJson(item));
        }
      }
    }
    return PersistedSessionRecord(
      localId: json['localId']?.toString() ?? '',
      pcSessionId: json['pcSessionId']?.toString(),
      isDraft: json['isDraft'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: messages,
    );
  }
}
