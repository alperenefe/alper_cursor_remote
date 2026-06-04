import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/local_session_snapshot.dart';

/// Uygulama verisi: oturumlar, balonlar, isimler (`adb install -r` ile kalır).
class LocalSessionCache {
  LocalSessionCache._();

  static const _fileName = 'local_sessions_v1.json';

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<LocalSessionSnapshot?> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LocalSessionSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(LocalSessionSnapshot snapshot) async {
    try {
      final file = await _cacheFile();
      final sessions = snapshot.sessions
          .where((s) => s.localId.trim().isNotEmpty)
          .toList();
      if (sessions.isEmpty &&
          snapshot.sessionNames.isEmpty &&
          snapshot.activeSessionId == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      final payload = LocalSessionSnapshot(
        activeSessionId: snapshot.activeSessionId,
        sessionNames: snapshot.sessionNames,
        sessions: sessions,
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload.toJson()),
      );
    } catch (_) {
      // Sessiz — sohbet akışı kesilmesin.
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
