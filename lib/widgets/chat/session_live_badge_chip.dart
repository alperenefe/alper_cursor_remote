import 'package:flutter/material.dart';

import '../../models/session_live_badge.dart';
import '../../theme/design_tokens.dart';

/// Oturum satırında / başlıkta canlı durum etiketi.
class SessionLiveBadgeChip extends StatelessWidget {
  const SessionLiveBadgeChip({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final SessionLiveBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (badge.kind) {
      SessionLiveBadgeKind.working => (
          badge.onPc
              ? DesignTokens.blue600.withValues(alpha: 0.22)
              : DesignTokens.amber500.withValues(alpha: 0.18),
          badge.onPc ? DesignTokens.blue600 : DesignTokens.amber500,
          badge.onPc ? Icons.smart_toy_outlined : Icons.hourglass_top,
        ),
      SessionLiveBadgeKind.queued => (
          DesignTokens.amber500.withValues(alpha: 0.15),
          DesignTokens.amber500,
          Icons.schedule,
        ),
      SessionLiveBadgeKind.unread => (
          DesignTokens.blue600.withValues(alpha: 0.18),
          DesignTokens.blue600,
          Icons.mark_chat_unread_outlined,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge.kind == SessionLiveBadgeKind.working && badge.onPc)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: compact ? 10 : 12,
                height: compact ? 10 : 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: fg,
                ),
              ),
            )
          else
            Icon(icon, size: compact ? 12 : 13, color: fg),
          SizedBox(width: compact ? 3 : 4),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
