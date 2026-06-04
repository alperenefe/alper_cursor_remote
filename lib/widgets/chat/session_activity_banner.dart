import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/design_tokens.dart';
import '../../navigation/home_tab_controller.dart';

/// Başka oturumda cevap / bekleme — aktif sohbeti kirletmez.
class SessionActivityBanner extends StatelessWidget {
  const SessionActivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final text = s.sessionActivityBannerText;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: DesignTokens.slate800,
      child: InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          HomeTabController.goToChat(context);
          if (s.sessionAlertId != null) {
            s.selectSession(s.sessionAlertId!);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                s.sessionAlertId != null
                    ? Icons.mark_chat_unread_outlined
                    : Icons.play_circle_outline,
                size: 20,
                color: DesignTokens.amber500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: DesignTokens.slate200,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (s.backgroundSessionAttentionCount > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DesignTokens.amber500.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${s.backgroundSessionAttentionCount}',
                    style: TextStyle(
                      color: DesignTokens.amber500,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Icon(
                Icons.chevron_right,
                color: DesignTokens.slate500,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
