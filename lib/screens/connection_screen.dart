import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_update_card.dart';
import '../widgets/branding/app_logo.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _authCtrl = TextEditingController();
  final _hostFocus = FocusNode();
  final _portFocus = FocusNode();
  bool _editAddress = false;
  bool _promptedEmptyAddress = false;
  bool _pinVisible = false;
  String? _syncedHost;
  int? _syncedPort;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _authCtrl.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    super.dispose();
  }

  void _syncFieldsFromState(AppState s) {
    if (!s.settingsReady) return;
    if (_hostFocus.hasFocus || _portFocus.hasFocus) return;
    if (_syncedHost == s.host && _syncedPort == s.port) return;
    _hostCtrl.text = s.host;
    _portCtrl.text = '${s.port}';
    _authCtrl.text = s.authToken;
    _syncedHost = s.host;
    _syncedPort = s.port;
  }

  Future<void> _saveFieldsToState(AppState s) async {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port 1–65535 arasında olmalı')),
      );
      return;
    }
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PC adresi boş olamaz')),
      );
      return;
    }
    await s.saveConnection(
      host,
      port,
      authTokenValue: _authCtrl.text,
    );
    _syncedHost = host;
    _syncedPort = port;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    _syncFieldsFromState(s);
    if (s.settingsReady && !s.hasSavedConnection && !_promptedEmptyAddress) {
      _promptedEmptyAddress = true;
      _editAddress = true;
    }

    if (!s.settingsReady) {
      return const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ayarlar yükleniyor…'),
            ],
          ),
        ),
      );
    }

    final linkBusy = s.isLinkInProgress;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: AppLogo(size: 80, showLabel: true)),
          const SizedBox(height: 8),
          Text(
            'Kişisel — Tailscale IP + PC extension (port 8766)',
            textAlign: TextAlign.center,
            style: TextStyle(color: DesignTokens.slate400, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const AppUpdateCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        s.connected
                            ? Icons.cloud_done
                            : linkBusy
                                ? Icons.sync
                                : Icons.cloud_off,
                        color: s.connected
                            ? DesignTokens.green500
                            : linkBusy
                                ? DesignTokens.amber500
                                : DesignTokens.slate500,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.statusNote ?? (s.connected ? 'Bağlı' : 'Bağlı değil'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (s.settingsReady && s.hasSavedConnection) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.slate800,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DesignTokens.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmark,
                            size: 18,
                            color: DesignTokens.slate400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kayıtlı: ${s.connectionLabel}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!s.isAuthConfigured) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.amber500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: DesignTokens.amber500.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: DesignTokens.amber500,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Auth PIN boş. PC extension\'da token yoksa '
                              'Tailscale ağındaki herkes komut gönderebilir. '
                              'PIN kaydedin ve PC\'de aynı değeri kullanın.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: DesignTokens.slate200,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: !s.settingsReady || s.connected || linkBusy
                        ? null
                        : () async {
                            if (_editAddress) {
                              await _saveFieldsToState(s);
                              if (!s.hasSavedConnection) return;
                            }
                            await s.connectWithSaved();
                          },
                    icon: linkBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      linkBusy
                          ? 'Bağlanılıyor…'
                          : s.hasSavedConnection
                              ? 'Bağlan (${s.connectionLabel})'
                              : 'Bağlan',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: s.canDisconnect ? () => s.disconnect() : null,
                    icon: const Icon(Icons.link_off),
                    label: Text(
                      linkBusy ? 'İptal et' : 'Bağlantıyı kes',
                    ),
                  ),
                  if (linkBusy) ...[
                    const SizedBox(height: 8),
                    Text(
                      s.isHandshaking
                          ? 'El sıkışılıyor… Takılırsa İptal et veya en fazla '
                              '${AppState.handshakeTimeoutSeconds} sn bekleyin.'
                          : 'Bağlanılıyor… İptal etmek için aşağıdaki düğmeye basın.',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.slate500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Otomatik yeniden bağlan'),
                    subtitle: const Text(
                      'Uygulama açılınca / arka plandan dönünce kayıtlı PC\'ye bağlan; kuyruk korunur',
                    ),
                    value: s.autoReconnectEnabled,
                    onChanged: linkBusy ? null : (v) => s.setAutoReconnectEnabled(v),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: s.connected
                        ? null
                        : () => setState(() => _editAddress = !_editAddress),
                    icon: Icon(
                      _editAddress ? Icons.expand_less : Icons.edit_outlined,
                    ),
                    label: Text(
                      _editAddress ? 'Adresi gizle' : 'Adresi değiştir',
                    ),
                  ),
                  if (_editAddress && !s.connected) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hostCtrl,
                      focusNode: _hostFocus,
                      decoration: const InputDecoration(
                        labelText: 'PC adresi',
                        hintText: '100.x.x.x (Tailscale)',
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portCtrl,
                      focusNode: _portFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '8766',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _authCtrl,
                      obscureText: !_pinVisible,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Auth PIN (PC ile aynı, 8 karakter)',
                        hintText: 'Örn. AB3K9P2X',
                        prefixIcon: const Icon(Icons.pin),
                        suffixIcon: IconButton(
                          tooltip: _pinVisible ? 'PIN gizle' : 'PIN göster',
                          onPressed: () =>
                              setState(() => _pinVisible = !_pinVisible),
                          icon: Icon(
                            _pinVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _saveFieldsToState(s),
                      child: const Text('Adresi ve PIN kaydet'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uzun agent işleri: ${s.responseIdleTimeoutMinutes} dk sessizlik '
                      'sonrası uyarı (cevap sürebilir).',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sohbet filtreleri',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Logları göster'),
                    subtitle: const Text('Extension / CLI log satırları'),
                    value: s.showLogs,
                    onChanged: (v) => s.setFilters(logs: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sistem mesajları'),
                    subtitle: const Text('Bağlantı, komut hataları'),
                    value: s.showSystem,
                    onChanged: (v) => s.setFilters(system: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mobil için optimize yanıt'),
                    subtitle: const Text(
                      'Agent\'a uzaktan kontrol + mobil format (yeni/eski oturum dahil)',
                    ),
                    value: s.mobileOptimizedPrompts,
                    onChanged: (v) => s.setMobileOptimizedPrompts(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Composer Fast'),
                    subtitle: Text(
                      s.composerUseFast
                          ? 'CLI: composer-2.5-fast (hızlı)'
                          : 'CLI: composer-2.5 (Fast kapalı, Edit ile aynı)',
                    ),
                    value: s.composerUseFast,
                    onChanged: (v) => s.setComposerUseFast(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ara adımlar (todo özeti)'),
                    subtitle: const Text(
                      'Yalnızca üstte kısa satır; tool/thinking sohbete yazılmaz',
                    ),
                    value: s.showProgress,
                    onChanged: (v) => s.setFilters(progress: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stream birleştir'),
                    subtitle: const Text(
                      'Parçalı chunk\'ları tek cevapta birleştir',
                    ),
                    value: s.mergeStreamChunks,
                    onChanged: (v) => s.setFilters(mergeStream: v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cevap önizlemesi (stream)'),
                    subtitle: const Text(
                      'Kapalı: yazı balonda dönmez; cevap bitince tam metin gelir',
                    ),
                    value: s.showStreamPreview,
                    onChanged: (v) => s.setFilters(streamPreview: v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
