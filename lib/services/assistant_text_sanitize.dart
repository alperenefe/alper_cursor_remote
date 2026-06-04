/// Ham CLI / NDJSON satırı — sohbet balonunda gösterme.
bool isGarbageAssistantText(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  if (t.startsWith('{') &&
      (t.contains('"type"') ||
          t.contains('"type":') ||
          t.contains('session_id'))) {
    return true;
  }
  if (RegExp(r'\{"type"\s*:\s*"system"', caseSensitive: false).hasMatch(t)) {
    return true;
  }
  return false;
}

/// PC agent cevaplarını telefonda okunur hale getir.
String sanitizeAssistantTextForDisplay(String text) {
  if (text.trim().isEmpty) return text;
  final kept = <String>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (t.isEmpty) {
      if (kept.isNotEmpty && kept.last.isNotEmpty) kept.add('');
      continue;
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:', caseSensitive: false).hasMatch(t)) {
      continue;
    }
    if (t.startsWith('{') && t.contains('"type"')) continue;
    final low = t.toLowerCase();
    if (low.contains('istek metni görünmüyor') ||
        low.contains('mesajda metin yok') ||
        low.contains('mesajda istek') ||
        low.contains('somut bir görev') ||
        low.contains('işaretleyici') ||
        (low.contains('kontrol ediyorum') &&
            (low.contains('workspace') ||
                low.contains('chat geçmiş') ||
                low.contains('sohbet geçmiş') ||
                low.contains('dağıtım')))) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

