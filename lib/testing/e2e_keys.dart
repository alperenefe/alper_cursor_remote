import 'package:flutter/material.dart';

/// Entegrasyon testi — yalnızca `RUN_E2E=1` ile çalıştırılır.
abstract final class E2eKeys {
  static const tabChat = Key('e2e_tab_chat');
  static const openSessions = Key('e2e_open_sessions');
  static const chatRename = Key('e2e_chat_rename');
  static const newSession = Key('e2e_new_session');
  static const chatComposer = Key('e2e_chat_composer');
  static const sendMessage = Key('e2e_send_message');
  static const renameField = Key('e2e_rename_field');
  static const renameSave = Key('e2e_rename_save');
  static const confirmSessionDelete = Key('e2e_confirm_session_delete');
  static const closeSessionsSheet = Key('e2e_close_sessions_sheet');
  static const clearAllHistory = Key('e2e_clear_all_history');
  static const confirmClearAllHistory = Key('e2e_confirm_clear_all_history');
  static const dismissClearAllHistory = Key('e2e_dismiss_clear_all_history');

  static Key sessionTile(String title) => Key('e2e_session_$title');
  static Key sessionEdit(String title) => Key('e2e_session_edit_$title');
  static Key sessionDelete(String title) => Key('e2e_session_delete_$title');
}
