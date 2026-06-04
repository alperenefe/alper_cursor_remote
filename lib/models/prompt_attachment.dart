import 'dart:convert';

/// Mobil → PC `insert_text.attachments[]` öğesi.
class PromptAttachment {
  const PromptAttachment({
    required this.name,
    required this.mimeType,
    required this.base64,
  });

  final String name;
  final String mimeType;
  final String base64;

  static const int maxBytesPerFile = 4 * 1024 * 1024;
  static const int maxFiles = 5;

  bool get isImage => mimeType.startsWith('image/');

  int get byteLength {
    try {
      return base64Decode(base64).length;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toWireJson() => {
        'name': name,
        'type': mimeType,
        'base64': base64,
      };

  factory PromptAttachment.fromWireJson(Map<String, dynamic> json) {
    return PromptAttachment(
      name: json['name']?.toString() ?? 'file',
      mimeType: json['type']?.toString() ??
          json['mimeType']?.toString() ??
          'application/octet-stream',
      base64: json['base64']?.toString() ?? '',
    );
  }

  /// Sohbet balonunda gösterim.
  String get displayLabel => name;
}

String formatUserMessageWithAttachments(
  String text,
  List<PromptAttachment> attachments,
) {
  if (attachments.isEmpty) return text;
  final names = attachments.map((a) => a.displayLabel).join(', ');
  final prefix = '📎 $names';
  final body = text.trim();
  if (body.isEmpty) return prefix;
  return '$prefix\n\n$body';
}
