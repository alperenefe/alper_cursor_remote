# cursor-remote temizlik planı

Yeni uygulama hazır ve test edildikten sonra.

## Tutulacak (şimdilik)

- `cursor-remote/cursor-extension` — PC WebSocket sunucusu + CLI köprüsü
- İsteğe bağlı: `cursor-extension` kaynak referans için arşiv zip

## Silinebilir

| Yol | Neden |
|-----|--------|
| `cursor-remote/mobile-app/` | Yerine `alper_cursor_remote` |
| `cursor-remote/relay-server/` | Kişisel kullanımda Tailscale; relay yok |
| `cursor-remote/pc-server/` | Kullanılmıyorsa |
| `C:\Users\alper\Desktop\Cursor_Remote_Kurulum.md` | Eski relay kurulumu |
| Workspace’teki `extension-output-jaloveeye...` dosyası | Sanal log; Create File ile oluşmuşsa sil |
| Telefonda `cursor-remote` APK | Kaldır |

## Extension Output hatası

“Unable to open … file not found” → **Cancel**. Log: View → Output → Cursor Remote.

## Öğrenilenler (özet)

- **Göster:** `chat_response`, birleştirilmiş chunk, kullanıcı prompt
- **Gizle:** `log`, `system`, `command_result` (iç), `thinking` (CLI’da bile extension atmıyor)
- **Trafik sekmesi:** filtre yok, debug için
