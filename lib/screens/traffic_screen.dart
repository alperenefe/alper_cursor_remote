import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/traffic_entry.dart';
import '../state/app_state.dart';
import '../theme/design_tokens.dart';

class TrafficScreen extends StatelessWidget {
  const TrafficScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final fmt = DateFormat('HH:mm:ss');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ham trafik',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: s.traffic.isEmpty ? null : s.clearTraffic,
                  child: const Text('Temizle'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tüm WebSocket gönder/al — filtre yok. Thinking burada da görünmez (PC extension atmıyor).',
              style: TextStyle(fontSize: 12, color: DesignTokens.slate400),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: s.traffic.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz trafik yok.\nBağlanıp mesaj gönderin.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: s.traffic.length,
                    itemBuilder: (context, i) {
                      final e = s.traffic[i];
                      final out = e.direction == TrafficDirection.outbound;
                      return Card(
                        child: InkWell(
                          onLongPress: () {
                            Clipboard.setData(ClipboardData(text: e.body));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Panoya kopyalandı')),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: out
                                            ? DesignTokens.blue600
                                                .withValues(alpha: 0.3)
                                            : DesignTokens.green500
                                                .withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        out ? 'GİDEN' : 'GELEN',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      e.summary,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      fmt.format(e.at),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: DesignTokens.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  e.body,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: DesignTokens.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
