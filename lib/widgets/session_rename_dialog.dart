import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../testing/e2e_keys.dart';
import '../state/session_registry.dart';
import '../theme/design_tokens.dart';

/// Oturuma özel isim (yalnızca telefon; PC'ye gitmez).
Future<void> showSessionRenameDialog(
  BuildContext context,
  AppState s, {
  required String sessionId,
}) async {
  final isDraft = sessionId.startsWith('loc-');
  final ctrl = TextEditingController(
    text: s.sessionNames[sessionId] ?? '',
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DesignTokens.slate800,
      title: Text(isDraft ? 'Yeni oturuma isim ver' : 'Oturum adı'),
      content: SingleChildScrollView(
        child: TextField(
          key: E2eKeys.renameField,
          controller: ctrl,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(
            hintText: isDraft ? 'Örn. Müzik uygulaması fix' : 'Örn. Weekly planner',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
      ),
      actions: [
        if (s.sessionNames.containsKey(sessionId))
          TextButton(
            onPressed: () {
              ctrl.clear();
              Navigator.pop(ctx, true);
            },
            child: const Text('Adı kaldır'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: E2eKeys.renameSave,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await s.renameSession(sessionId, ctrl.text);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ctrl.text.trim().isEmpty
            ? 'Özel ad kaldırıldı'
            : 'Oturum adı kaydedildi (yalnızca bu telefon)',
      ),
    ),
  );
}
