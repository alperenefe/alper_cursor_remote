import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../services/chat_bubble_format.dart';
import '../../testing/e2e_flags.dart';
import '../../theme/design_tokens.dart';

/// Balon içi metin: kullanıcı düz metin, agent markdown.
class BubbleMessageBody extends StatefulWidget {
  const BubbleMessageBody({
    super.key,
    required this.text,
    required this.isUser,
    required this.baseStyle,
    this.highlight = '',
    this.isStreaming = false,
  });

  final String text;
  final bool isUser;
  final TextStyle baseStyle;
  final String highlight;
  final bool isStreaming;

  @override
  State<BubbleMessageBody> createState() => _BubbleMessageBodyState();
}

class _BubbleMessageBodyState extends State<BubbleMessageBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final display = widget.isUser
        ? formatUserBubbleForDisplay(widget.text)
        : formatAssistantBubbleForDisplay(widget.text);

    if (display.isEmpty) {
      return Text(
        widget.isStreaming ? '…' : '(boş)',
        style: widget.baseStyle.copyWith(
          color: DesignTokens.slate500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final collapse = !widget.isUser &&
        !_expanded &&
        assistantBubbleNeedsCollapse(display);

    final shown = collapse ? _truncateForPreview(display) : display;

    final body = widget.isUser
        ? _PlainBubbleText(
            text: shown,
            highlight: widget.highlight,
            style: widget.baseStyle,
          )
        : _MarkdownBubbleText(text: shown, baseStyle: widget.baseStyle);

    if (!collapse) {
      return _e2eSemantics(display, widget.isUser, body);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(top: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: DesignTokens.blue600,
          ),
          onPressed: () => setState(() => _expanded = true),
          child: const Text('Tamamını göster', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _e2eSemantics(String display, bool isUser, Widget body) {
    if (!E2eFlags.enabled || !isUser || display.isEmpty) return body;
    return Semantics(
      label: display,
      container: true,
      child: body,
    );
  }

  String _truncateForPreview(String text) {
    const max = 900;
    if (text.length <= max) return text;
    var cut = text.substring(0, max);
    final lastNl = cut.lastIndexOf('\n');
    if (lastNl > max ~/ 2) {
      cut = cut.substring(0, lastNl);
    }
    return '$cut\n\n…';
  }
}

class _PlainBubbleText extends StatelessWidget {
  const _PlainBubbleText({
    required this.text,
    required this.highlight,
    required this.style,
  });

  final String text;
  final String highlight;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final q = highlight.trim().toLowerCase();
    if (q.isEmpty) {
      return SelectableText(text, style: style);
    }
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = lower.indexOf(q, start);
      if (i < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(
        TextSpan(
          text: text.substring(i, i + q.length),
          style: style.copyWith(
            backgroundColor: DesignTokens.amber500.withValues(alpha: 0.35),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = i + q.length;
    }
    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}

class _MarkdownBubbleText extends StatelessWidget {
  const _MarkdownBubbleText({
    required this.text,
    required this.baseStyle,
  });

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: baseStyle,
      h1: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h2: baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      h3: baseStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
      em: baseStyle.copyWith(fontStyle: FontStyle.italic),
      code: baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
        backgroundColor: DesignTokens.slate800,
      ),
      codeblockDecoration: BoxDecoration(
        color: DesignTokens.slate800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.borderSubtle),
      ),
      blockquote: baseStyle.copyWith(color: DesignTokens.slate400),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: DesignTokens.blue600, width: 3),
        ),
      ),
      listBullet: baseStyle,
      tableHead: baseStyle.copyWith(fontWeight: FontWeight.w600),
      tableBody: baseStyle,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: DesignTokens.borderSubtle),
        ),
      ),
    );

    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
      styleSheet: sheet,
    );
  }
}
