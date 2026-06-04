import 'package:flutter/material.dart';

import '../../models/session_live_badge.dart';
import '../../models/session_summary.dart';
import '../../theme/design_tokens.dart';
import '../chat/session_live_badge_chip.dart';

/// Kompakt oturum satırı — sheet listesinde düşük yükseklik.
class SessionListTile extends StatelessWidget {
  const SessionListTile({
    super.key,
    required this.summary,
    required this.active,
    required this.badge,
    required this.unreadCount,
    required this.onTap,
    required this.onRename,
    this.onDelete,
  });

  final SessionSummary summary;
  final bool active;
  final SessionLiveBadge? badge;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  static String formatRelativeTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return '${d.day}.${d.month}';
  }

  static String shortSessionId(String id) {
    if (id.startsWith('loc-')) {
      final tail = id.length > 8 ? id.substring(id.length - 6) : id;
      return 'loc-$tail';
    }
    if (id.length <= 10) return id;
    return '${id.substring(0, 8)}…';
  }

  @override
  Widget build(BuildContext context) {
    final preview = summary.preview.trim();
    final showPreview = preview.isNotEmpty &&
        preview != '(yeni oturum)' &&
        preview != summary.title;

    return Material(
      color: active
          ? DesignTokens.blue600.withValues(alpha: 0.12)
          : DesignTokens.slate800,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                width: active ? 3 : 0,
                color: active
                    ? DesignTokens.blue600
                    : Colors.transparent,
              ),
              top: BorderSide(
                color: badge != null
                    ? _borderColor(badge!)
                    : DesignTokens.borderSubtle.withValues(alpha: 0.5),
              ),
              right: BorderSide(
                color: DesignTokens.borderSubtle.withValues(alpha: 0.5),
              ),
              bottom: BorderSide(
                color: DesignTokens.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _StatusDot(badge: badge, active: active),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (summary.lastTimestamp != null)
                          Text(
                            formatRelativeTime(summary.lastTimestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: DesignTokens.slate500,
                            ),
                          ),
                      ],
                    ),
                    if (showPreview) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: DesignTokens.slate400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (badge != null)
                          SessionLiveBadgeChip(
                            badge: badge!,
                            compact: true,
                          ),
                        if (badge != null) const SizedBox(width: 6),
                        Text(
                          '${summary.entryCount} mesaj',
                          style: TextStyle(
                            fontSize: 10,
                            color: DesignTokens.slate500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          shortSessionId(summary.sessionId),
                          style: TextStyle(
                            fontSize: 10,
                            color: DesignTokens.slate600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                _UnreadBadge(count: unreadCount),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(SessionLiveBadge badge) {
    switch (badge.kind) {
      case SessionLiveBadgeKind.working:
        return badge.onPc
            ? DesignTokens.blue600.withValues(alpha: 0.35)
            : DesignTokens.amber500.withValues(alpha: 0.35);
      case SessionLiveBadgeKind.queued:
        return DesignTokens.blue600.withValues(alpha: 0.25);
      case SessionLiveBadgeKind.unread:
        return DesignTokens.slate500.withValues(alpha: 0.35);
    }
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DesignTokens.slate800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('İsim ver / düzenle'),
              onTap: () {
                Navigator.pop(ctx);
                onRename();
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: DesignTokens.slate400),
                title: const Text('Oturumu sil'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.badge, required this.active});

  final SessionLiveBadge? badge;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Color color = DesignTokens.slate500;
    if (active) {
      color = DesignTokens.green500;
    } else if (badge != null) {
      switch (badge!.kind) {
        case SessionLiveBadgeKind.working:
          color = badge!.onPc
              ? DesignTokens.green500
              : DesignTokens.amber500;
        case SessionLiveBadgeKind.queued:
          color = DesignTokens.blue600;
        case SessionLiveBadgeKind.unread:
          color = DesignTokens.slate400;
      }
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}
