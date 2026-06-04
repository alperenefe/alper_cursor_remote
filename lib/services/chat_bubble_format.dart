import 'assistant_text_sanitize.dart';

final _mobilEklerLine = RegExp(
  r'^[-*]?\s*(?:Görsel|Metin dosyası|Dosya)\s+(.+?)\s*:\s*@',
  caseSensitive: false,
);

final _mobilEklerPathOnly = RegExp(
  r'^[-*]?\s*@\.cursor-remote-attachments/',
  caseSensitive: false,
);

bool _isMobilEklerHeader(String line) {
  final t = line.trim();
  return t.startsWith('[Mobil ekler');
}

/// PC prompt / geçmiş metninden ek dosya adlarını çıkarır.
List<String> extractMobilAttachmentNames(String text) {
  final names = <String>[];
  var inBlock = false;
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (_isMobilEklerHeader(t)) {
      inBlock = true;
      continue;
    }
    if (!inBlock) continue;
    final att = _mobilEklerLine.firstMatch(t);
    if (att != null) {
      var name = att.group(1)!.trim();
      if (name.contains('/')) name = name.split('/').last;
      if (name.isNotEmpty) names.add(name);
      continue;
    }
    if (_mobilEklerPathOnly.hasMatch(t)) continue;
    if (t.startsWith('@') || t.isEmpty) continue;
    inBlock = false;
  }
  return names;
}

String _stripMobilEklerBlock(String body) {
  if (!body.contains('[Mobil ekler')) return body;

  final lines = body.split(RegExp(r'\r?\n'));
  final attachmentNames = extractMobilAttachmentNames(body);
  final rest = <String>[];
  var inBlock = false;

  for (final line in lines) {
    final t = line.trim();
    if (_isMobilEklerHeader(t)) {
      inBlock = true;
      continue;
    }
    if (inBlock) {
      if (_mobilEklerLine.hasMatch(t) ||
          _mobilEklerPathOnly.hasMatch(t) ||
          t.startsWith('@') ||
          t.isEmpty) {
        continue;
      }
      inBlock = false;
    }
    rest.add(line);
  }

  final parts = <String>[];
  if (attachmentNames.isNotEmpty) {
    parts.add('📎 ${attachmentNames.join(', ')}');
  }
  final userText = rest.join('\n').trim();
  if (userText.isNotEmpty) parts.add(userText);
  return parts.isNotEmpty ? parts.join('\n\n') : '';
}

String _stripMobileRemoteWrapper(String body) {
  var out = body.replaceAll(RegExp(r'<!--/mobile-remote-->'), '');
  final mobIdx = out.indexOf('[Mobil uzaktan]');
  if (mobIdx >= 0) out = out.substring(0, mobIdx).trim();
  return out.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Sohbet balonunda gösterilecek metin (PC geçmişi / ham kayıt → mobil sade).
String formatUserBubbleForDisplay(String text) {
  var body = text.trim();
  if (body.isEmpty) return body;

  if (body.contains('[Mobil ekler')) {
    body = _stripMobilEklerBlock(body);
  }

  return _stripMobileRemoteWrapper(body);
}

/// Agent balonu: mobil kanal notlarını kırp + gürültü satırları.
String formatAssistantBubbleForDisplay(String text) {
  var body = sanitizeAssistantTextForDisplay(text);
  if (body.contains('[Mobil ekler')) {
    body = _stripMobilEklerBlock(body);
  }
  return _stripMobileRemoteWrapper(body);
}

bool assistantBubbleNeedsCollapse(String text, {int threshold = 1200}) =>
    text.length > threshold;
