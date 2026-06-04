import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import '../navigation/home_tab_controller.dart';

import '../services/session_trace_log.dart';

import '../state/app_state.dart';

import '../theme/design_tokens.dart';

import '../testing/e2e_flags.dart';

import '../testing/e2e_keys.dart';

import '../widgets/session/session_list_tile.dart';

import '../widgets/session_rename_dialog.dart';



/// Oturum listesi — kompakt kartlar.

void showSessionsSheet(BuildContext context) {

  showModalBottomSheet<void>(

    context: context,

    isScrollControlled: true,

    backgroundColor: DesignTokens.slate900,

    shape: const RoundedRectangleBorder(

      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),

    ),

    builder: (ctx) => const _SessionsSheetBody(),

  );

}



class _SessionsSheetBody extends StatelessWidget {

  const _SessionsSheetBody();



  static Future<void> _confirmClearAll(BuildContext context, AppState s) async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        backgroundColor: DesignTokens.slate800,

        title: const Text('Tüm geçmiş silinsin mi?'),

        content: const Text(

          'PC\'deki .cursor/CHAT_HISTORY.json tamamen boşalır.\n'

          'Listedeki tüm oturumlar gider. Geri alınamaz.',

        ),

        actions: [

          TextButton(

            key: E2eFlags.enabled ? E2eKeys.dismissClearAllHistory : null,

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Vazgeç'),

          ),

          FilledButton(

            key: E2eFlags.enabled ? E2eKeys.confirmClearAllHistory : null,

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Hepsini sil'),

          ),

        ],

      ),

    );

    if (ok != true || !context.mounted) return;

    final n = await s.clearAllSessions();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          n >= 0

              ? 'PC geçmişi temizlendi ($n kayıt silindi)'

              : 'Temizlenemedi — Reload Window + yeniden bağlan',

        ),

      ),

    );

  }



  static Future<void> _confirmDeleteSession(

    BuildContext context,

    AppState s,

    String sessionId,

    String preview,

  ) async {

    final label = preview.length > 40 ? '${preview.substring(0, 40)}…' : preview;

    final pcLinked = s.historyWireSessionId(sessionId) != null;

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        backgroundColor: DesignTokens.slate800,

        title: const Text('Oturumu sil?'),

        content: Text(

          pcLinked

              ? 'PC\'deki kayıtlı geçmişten kaldırılır:\n\n$label\n\n'

                  'Geri alınamaz.'

              : 'Bu oturum yalnızca telefonda — PC geçmişi yok.\n\n'

                  '$label\n\n'

                  'Yerel sohbet kutusu silinir.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Vazgeç'),

          ),

          FilledButton(

            key: E2eKeys.confirmSessionDelete,

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Sil'),

          ),

        ],

      ),

    );

    if (ok != true || !context.mounted) return;



    final before = s.sessionSummaries.length;

    final deleted = await s.removeSession(sessionId);

    if (!context.mounted) return;

    final after = s.sessionSummaries.length;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          deleted

              ? 'Oturum silindi (${before > after ? before - after : 1} kaldırıldı, listede $after)'

              : 'Silinemedi — PC\'de kayıt yok veya extension eski. Yenile / Reload Window.',

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final s = context.watch<AppState>();

    final bottom = MediaQuery.paddingOf(context).bottom;

    final count = s.orderedSessionSummaries.length;

    final initialSize = count <= 2

        ? 0.42

        : count <= 4

            ? 0.52

            : 0.58;



    return DraggableScrollableSheet(

      expand: false,

      initialChildSize: initialSize,

      minChildSize: 0.32,

      maxChildSize: 0.92,

      builder: (context, scrollController) {

        return Padding(

          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              Center(

                child: Container(

                  width: 40,

                  height: 4,

                  decoration: BoxDecoration(

                    color: DesignTokens.slate600,

                    borderRadius: BorderRadius.circular(2),

                  ),

                ),

              ),

              const SizedBox(height: 8),

              Row(

                children: [

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        const Text(

                          'Oturumlar',

                          style: TextStyle(

                            fontSize: 17,

                            fontWeight: FontWeight.w700,

                          ),

                        ),

                        Text(

                          '${s.activeSessionLabel} · $count kayıtlı',

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(

                            color: DesignTokens.slate400,

                            fontSize: 12,

                          ),

                        ),

                      ],

                    ),

                  ),

                  if (E2eFlags.enabled)

                    IconButton(

                      key: E2eKeys.closeSessionsSheet,

                      visualDensity: VisualDensity.compact,

                      onPressed: () => Navigator.pop(context),

                      icon: const Icon(Icons.close, size: 20),

                    ),

                  IconButton(

                    visualDensity: VisualDensity.compact,

                    tooltip: 'Yenile',

                    onPressed: s.connected && !s.loadingHistory

                        ? () => s.refreshSessionsAndHistory()

                        : null,

                    icon: const Icon(Icons.refresh, size: 20),

                  ),

                ],

              ),

              if (s.flowingSessionCount > 0)

                Padding(

                  padding: const EdgeInsets.only(bottom: 6),

                  child: Text(

                    s.flowingSessionCount == 1

                        ? '1 oturum aktif'

                        : '${s.flowingSessionCount} oturum aktif',

                    style: TextStyle(

                      color: DesignTokens.amber500,

                      fontSize: 11,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                ),

              Row(

                children: [

                  TextButton.icon(

                    key: E2eKeys.newSession,

                    onPressed: s.connected

                        ? () {

                            FocusManager.instance.primaryFocus?.unfocus();

                            s.startNewChat();

                            Navigator.pop(context);

                          }

                        : null,

                    icon: const Icon(Icons.add, size: 18),

                    label: const Text('Yeni'),

                    style: TextButton.styleFrom(

                      visualDensity: VisualDensity.compact,

                      padding: const EdgeInsets.symmetric(horizontal: 8),

                    ),

                  ),

                  TextButton.icon(

                    key: E2eFlags.enabled ? E2eKeys.clearAllHistory : null,

                    onPressed: s.connected

                        ? () => _confirmClearAll(context, s)

                        : null,

                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),

                    label: const Text('Tümü sil'),

                    style: TextButton.styleFrom(

                      visualDensity: VisualDensity.compact,

                      foregroundColor: DesignTokens.slate400,

                      padding: const EdgeInsets.symmetric(horizontal: 8),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 4),

              if (s.loadingHistory)

                const Padding(

                  padding: EdgeInsets.all(20),

                  child: Center(child: CircularProgressIndicator()),

                )

              else if (!s.hasSessionList)

                Padding(

                  padding: const EdgeInsets.all(12),

                  child: Text(

                    'Kayıtlı oturum yok. Bağlıysan Yenile\'ye bas.',

                    style: TextStyle(color: DesignTokens.slate400, fontSize: 13),

                  ),

                )

              else

                Expanded(

                  child: ListView.separated(

                    controller: scrollController,

                    itemCount: s.orderedSessionSummaries.length,

                    separatorBuilder: (_, _) => const SizedBox(height: 6),

                    itemBuilder: (context, i) {

                      final item = s.orderedSessionSummaries[i];

                      final active = s.isSessionActiveInList(item.sessionId);

                      final badge = s.liveBadgeForSession(item.sessionId);

                      final unread = s.unreadCountForSession(item.sessionId);



                      return SessionListTile(

                        key: E2eKeys.sessionTile(item.title),

                        summary: item,

                        active: active,

                        badge: badge,

                        unreadCount: unread,

                        onTap: () {

                          final sid = item.sessionId;

                          FocusManager.instance.primaryFocus?.unfocus();

                          HomeTabController.goToChat(context);

                          SessionTraceLog.listTap(

                            sessionId: sid,

                            title: item.title,

                            goToTabOk: true,

                          );

                          s.selectSession(sid);

                          Navigator.of(context, rootNavigator: true).pop();

                        },

                        onRename: () => showSessionRenameDialog(

                          context,

                          s,

                          sessionId: item.sessionId,

                        ),

                        onDelete: s.canDeleteSession(item.sessionId)

                            ? () => _confirmDeleteSession(

                                  context,

                                  s,

                                  item.sessionId,

                                  item.preview,

                                )

                            : null,

                      );

                    },

                  ),

                ),

            ],

          ),

        );

      },

    );

  }

}


