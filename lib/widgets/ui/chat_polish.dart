import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../testing/e2e_keys.dart';
import '../../theme/design_tokens.dart';
import '../chat/session_live_badge_chip.dart';

/// Üst çubuk: bağlantı durumu.
class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final (String label, Color fg, Color bg, IconData icon) = switch ((
      s.connected,
      s.isHandshaking,
      s.isConnecting,
    )) {
      (true, _, _) => (
          'Bağlı',
          DesignTokens.green500,
          DesignTokens.green500,
          Icons.link,
        ),
      (_, true, _) => (
          'El sıkışılıyor',
          DesignTokens.amber500,
          DesignTokens.amber500,
          Icons.hourglass_top,
        ),
      (_, _, true) => (
          'Bağlanıyor',
          DesignTokens.amber500,
          DesignTokens.amber500,
          Icons.sync,
        ),
      _ => (
          'Bağlı değil',
          DesignTokens.slate500,
          DesignTokens.slate600,
          Icons.cloud_off,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aktif oturum seçici (liste + yeniden adlandır).
class SessionSelectorTile extends StatelessWidget {
  const SessionSelectorTile({
    super.key,
    required this.state,
    required this.onOpenSessions,
    required this.onRename,
  });

  final AppState state;
  final VoidCallback onOpenSessions;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final flow = s.activeSessionFlowHint;
    final badge = s.liveBadgeForSession(s.renameableActiveSessionId);

    return Material(
      color: DesignTokens.slate800,
      borderRadius: DesignTokens.radiusMd,
      child: InkWell(
        onTap: onOpenSessions,
        borderRadius: DesignTokens.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.activeSessionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (flow != null && flow.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        flow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: DesignTokens.slate400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                SessionLiveBadgeChip(badge: badge, compact: true),
              ],
              IconButton(
                key: E2eKeys.chatRename,
                tooltip: 'Oturum adı',
                visualDensity: VisualDensity.compact,
                onPressed: s.canRenameActiveSession ? onRename : null,
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: DesignTokens.slate400,
              ),
              const Icon(Icons.chevron_right, color: DesignTokens.slate500),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sohbet boşken gösterilen durum.
class ChatEmptyStateView extends StatelessWidget {
  const ChatEmptyStateView({
    super.key,
    required this.state,
    required this.searchActive,
    required this.onReconnect,
  });

  final AppState state;
  final bool searchActive;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    if (searchActive) {
      return Text(
        'Arama sonucu yok',
        style: TextStyle(color: DesignTokens.slate500),
      );
    }

    final bodyColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          state.connected ? Icons.chat_outlined : Icons.wifi_off,
          size: 48,
          color: DesignTokens.slate600,
        ),
        const SizedBox(height: 16),
        Text(
          state.connected
              ? 'İlk mesajınızı yazın'
              : 'PC\'ye bağlanın',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DesignTokens.slate200,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.connected
              ? 'Agent modu ve ekler composer\'da.'
              : 'Bağlantı sekmesinden IP kaydedin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DesignTokens.slate400, fontSize: 13),
        ),
        if (!state.connected) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: state.settingsReady ? onReconnect : null,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Bağlan'),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= 220) return bodyColumn;
        return SingleChildScrollView(child: bodyColumn);
      },
    );
  }
}

/// Agent çalışıyor şeridi — dokun: genişlet/küçült; akış kaydırılabilir.
class AgentWorkingStrip extends StatefulWidget {
  const AgentWorkingStrip({super.key, required this.state});

  final AppState state;

  @override
  State<AgentWorkingStrip> createState() => _AgentWorkingStripState();
}

class _AgentWorkingStripState extends State<AgentWorkingStrip> {
  bool _expanded = false;
  bool _userScrolledAway = false;
  final ScrollController _scrollCtrl = ScrollController();
  String _lastStreamSnapshot = '';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _userScrolledAway = false;
      }
    });
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(force: true));
    }
  }

  void _scrollToEnd({bool force = false}) {
    if (!_expanded || !_scrollCtrl.hasClients) return;
    if (!force && _userScrolledAway) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    _scrollCtrl.jumpTo(max);
  }

  bool _handleScrollNotification(ScrollNotification n) {
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final atBottom = n.metrics.pixels >= n.metrics.maxScrollExtent - 24;
      if (!atBottom && mounted) {
        setState(() => _userScrolledAway = true);
      }
    }
    if (n is ScrollEndNotification) {
      final atBottom = n.metrics.pixels >= n.metrics.maxScrollExtent - 24;
      if (atBottom && mounted && _userScrolledAway) {
        setState(() => _userScrolledAway = false);
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(AgentWorkingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.isActiveSessionAwaitingAgent && _expanded) {
      _expanded = false;
    }
    final stream = widget.state.activeAgentLiveStreamText ?? '';
    if (_expanded && stream.length > _lastStreamSnapshot.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
    _lastStreamSnapshot = stream;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.isActiveSessionAwaitingAgent) {
      return const SizedBox.shrink();
    }

    final status = widget.state.waitingStatusText;
    final stream = widget.state.activeAgentLiveStreamText?.trim() ?? '';
    final collapsedHint = widget.state.lastProgressLine?.trim() ?? '';
    final maxExpandHeight = MediaQuery.sizeOf(context).height * 0.38;
    final linkDown = !widget.state.connected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: DesignTokens.amber500.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.radiusSm,
          side: BorderSide(
            color: DesignTokens.amber500.withValues(
              alpha: _expanded ? 0.45 : 0.25,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleExpanded,
                    borderRadius: DesignTokens.radiusSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DesignTokens.amber500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: DesignTokens.amber500,
                                  ),
                                ),
                                if (linkDown) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bağlantı koptu — Tekrar dene veya bekleyin',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: DesignTokens.amber500
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ] else if (!_expanded &&
                                    collapsedHint.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    collapsedHint,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: DesignTokens.slate500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (linkDown && widget.state.hasSavedConnection)
                            TextButton(
                              onPressed: widget.state.settingsReady &&
                                      !widget.state.isLinkInProgress
                                  ? () => widget.state.connectWithSaved()
                                  : null,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                widget.state.isLinkInProgress
                                    ? '…'
                                    : 'Tekrar dene',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (widget.state.canStopWaitingAgent)
                            TextButton(
                              onPressed: () {
                                widget.state.stopPrompt();
                                if (_expanded) {
                                  setState(() => _expanded = false);
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: DesignTokens.slate400,
                              ),
                              child: const Text(
                                'İptal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Icon(
                            _expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 22,
                            color: DesignTokens.amber500,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: DesignTokens.amber500.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: Scrollbar(
                      controller: _scrollCtrl,
                      thumbVisibility: true,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: maxExpandHeight),
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          primary: false,
                          child: Text(
                            stream.isNotEmpty
                                ? stream
                                : 'Henüz metin gelmedi — agent PC\'de çalışıyor olabilir.',
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: stream.isNotEmpty
                                  ? DesignTokens.slate200
                                  : DesignTokens.slate500,
                              fontStyle: stream.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (stream.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Canlı akış — başlığa dokun',
                    style: TextStyle(
                      fontSize: 10,
                      color: DesignTokens.slate500.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
