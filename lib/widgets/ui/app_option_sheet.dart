import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Seçenek satırı — başlık + isteğe bağlı alt metin.
class AppSheetOption<T> {
  const AppSheetOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
}

/// Kompakt alt sayfa seçici (Hick: az seçenek, net hiyerarşi).
Future<T?> showAppOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppSheetOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: DesignTokens.slate900,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom > 0 ? 4 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: DesignTokens.slate600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.slate200,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: DesignTokens.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: DesignTokens.borderSubtle.withValues(alpha: 0.6),
                  ),
                _AppOptionTile<T>(
                  option: options[i],
                  selected: selected != null && options[i].value == selected,
                  onTap: () => Navigator.pop(ctx, options[i].value),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _AppOptionTile<T> extends StatelessWidget {
  const _AppOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSheetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? DesignTokens.blue600.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 18,
                  color: selected
                      ? DesignTokens.blue600
                      : DesignTokens.slate500,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? DesignTokens.slate200
                            : DesignTokens.slate400,
                      ),
                    ),
                    if (option.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: DesignTokens.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check,
                  size: 18,
                  color: DesignTokens.blue600,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
