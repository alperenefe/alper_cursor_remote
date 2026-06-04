import 'prompt_attachment.dart';

/// PC meşgulken bekletilen kullanıcı mesajı.
class QueuedPrompt {
  const QueuedPrompt({
    required this.text,
    required this.agentMode,
    required this.queuedAt,
    required this.localMessageId,
    this.sessionId,
    this.attachments = const [],
  });

  final String text;
  final String agentMode;
  final DateTime queuedAt;
  /// Sohbet balonu ile eşleşir; ⚡ yalnızca bu balonda gösterilir.
  final String localMessageId;
  final String? sessionId;
  final List<PromptAttachment> attachments;

  Map<String, dynamic> toJson() => {
        'text': text,
        'agentMode': agentMode,
        'queuedAt': queuedAt.toIso8601String(),
        'localMessageId': localMessageId,
        if (sessionId != null && sessionId!.isNotEmpty) 'sessionId': sessionId,
        'attachments': attachments
            .map(
              (a) => {
                'name': a.name,
                'mimeType': a.mimeType,
                'base64': a.base64,
              },
            )
            .toList(),
      };

  factory QueuedPrompt.fromJson(Map<String, dynamic> json) {
    final rawAtts = json['attachments'];
    final attachments = <PromptAttachment>[];
    if (rawAtts is List) {
      for (final item in rawAtts) {
        if (item is Map<String, dynamic>) {
          attachments.add(
            PromptAttachment(
              name: item['name']?.toString() ?? 'file',
              mimeType: item['mimeType']?.toString() ?? 'application/octet-stream',
              base64: item['base64']?.toString() ?? '',
            ),
          );
        }
      }
    }
    return QueuedPrompt(
      text: json['text']?.toString() ?? '',
      agentMode: json['agentMode']?.toString() ?? 'agent',
      queuedAt: DateTime.tryParse(json['queuedAt']?.toString() ?? '') ??
          DateTime.now(),
      localMessageId: json['localMessageId']?.toString() ?? '',
      sessionId: json['sessionId']?.toString(),
      attachments: attachments,
    );
  }
}

/// Meşgulken gönder davranışı.
enum BusySendPolicy {
  /// Final cevap gelince sıradaki mesajı gönder.
  queue,

  /// Hemen gönder; PC'deki işi keser.
  interrupt,
}

BusySendPolicy busySendPolicyFromString(String? raw) {
  switch (raw) {
    case 'interrupt':
      return BusySendPolicy.interrupt;
    default:
      return BusySendPolicy.queue;
  }
}

String busySendPolicyToString(BusySendPolicy p) =>
    p == BusySendPolicy.interrupt ? 'interrupt' : 'queue';
