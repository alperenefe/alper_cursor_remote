import 'package:flutter/material.dart';

import '../../models/queued_prompt.dart';
import '../../theme/design_tokens.dart';
import 'app_option_sheet.dart';

String agentModeLabel(String mode) => switch (mode) {
      'agent' => 'Agent',
      'ask' => 'Sor',
      'plan' => 'Plan',
      _ => mode,
    };

String busyPolicyShortLabel(BusySendPolicy policy) => switch (policy) {
      BusySendPolicy.queue => 'Sıra',
      BusySendPolicy.interrupt => 'Kes',
    };

/// Agent modu — kompakt tetikleyici + alt sayfa (eski menü hissi, büyük popup yok).
class ComposerAgentModeMenu extends StatelessWidget {
  const ComposerAgentModeMenu({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const _modes = [
    (id: 'agent', label: 'Agent', subtitle: 'Görevleri otomatik yürütür'),
    (id: 'ask', label: 'Sor', subtitle: 'Soru–cevap, düzenleme yapmaz'),
    (id: 'plan', label: 'Plan', subtitle: 'Önce plan, sonra onayla uygula'),
  ];

  static IconData _iconFor(String id) => switch (id) {
        'agent' => Icons.all_inclusive,
        'ask' => Icons.help_outline,
        'plan' => Icons.account_tree_outlined,
        _ => Icons.tune,
      };

  Future<void> _open(BuildContext context) async {
    final next = await showAppOptionSheet<String>(
      context: context,
      title: 'Mod',
      selected: selected,
      options: [
        for (final m in _modes)
          AppSheetOption(
            value: m.id,
            title: m.label,
            subtitle: m.subtitle,
            icon: _iconFor(m.id),
          ),
      ],
    );
    if (next != null) onSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(selected),
                  size: 15,
                  color: DesignTokens.slate400,
                ),
                const SizedBox(width: 4),
                Text(
                  agentModeLabel(selected),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DesignTokens.slate400,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: DesignTokens.slate500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Meşgulken gönder — kısa chip, ayrıntı alt sayfada.
class ComposerBusyPolicyChip extends StatelessWidget {
  const ComposerBusyPolicyChip({
    super.key,
    required this.policy,
    required this.onSelected,
    this.enabled = true,
  });

  final BusySendPolicy policy;
  final bool enabled;
  final ValueChanged<BusySendPolicy> onSelected;

  Future<void> _openSheet(BuildContext context) async {
    final next = await showAppOptionSheet<BusySendPolicy>(
      context: context,
      title: 'Meşgulken gönder',
      selected: policy,
      options: const [
        AppSheetOption(
          value: BusySendPolicy.queue,
          title: 'Sıra',
          subtitle: 'Cevap bitince otomatik gönderilir',
          icon: Icons.schedule,
        ),
        AppSheetOption(
          value: BusySendPolicy.interrupt,
          title: 'Kes',
          subtitle: 'Yeni mesaj çalışan işi durdurur',
          icon: Icons.stop_circle_outlined,
        ),
      ],
    );
    if (next != null) onSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: DesignTokens.slate900,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? () => _openSheet(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesignTokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  policy == BusySendPolicy.queue
                      ? Icons.schedule
                      : Icons.flash_on,
                  size: 13,
                  color: DesignTokens.slate500,
                ),
                const SizedBox(width: 4),
                Text(
                  busyPolicyShortLabel(policy),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.slate400,
                  ),
                ),
                const Icon(
                  Icons.expand_more,
                  size: 14,
                  color: DesignTokens.slate600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
