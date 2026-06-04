# Mesaj filtreleme (cursor-remote referansı)

PC extension → Cursor `agent` CLI (`stream-json`). Telefonda **ham trafik** ayrı; **sohbet** filtrelenmiş.

## Gelen WebSocket tipleri

| `type` | Varsayılan sohbet | Açıklama |
|--------|-------------------|----------|
| `chat_response` | Göster | Nihai AI cevabı |
| `chat_response_complete` | Birleştir → cevap | Stream bitti |
| `chat_response_chunk` | Gizle (birleştir) | Kısmi token; extension çoğu zaman sadece final gönderir |
| `user_prompt` | Göster | Senin gönderdiğin istek (yerelde eklenir) |
| `log` | Gizle | Extension/CLI log |
| `system` / `connected` | Gizle | Bağlantı bilgisi |
| `command_result` | Gizle* | `get_chat_history` vb. — sadece hata göster |
| `connection_status` | Gizle | Yerel WS kopma |
| `thinking` | **Asla gösterme** | CLI stream-json içinde; extension zaten iletmiyor |

## CLI stream-json (extension tarafı)

- `thinking` → atılır (iç monolog)
- `assistant` + `message.content[].text` → cevap metni
- `result` → final metin
- `system`, `user` satırları → atılır

## Sohbet filtresi (bizim uygulama)

**Varsayılan açık:** Kullanıcı istekleri, AI cevapları  
**Varsayılan kapalı:** Loglar, sistem, ham chunk  
**Trafik sekmesi:** Tüm gönder/al JSON (filtre yok)

## Arama

- Tümü: prompt + cevap
- Yalnızca cevaplar

## Silinecek proje sonrası

`cursor-remote` silinmeden önce bu tablo yeterli; ek protokol `command-router.ts` / `cli-handler.ts` referansı.
