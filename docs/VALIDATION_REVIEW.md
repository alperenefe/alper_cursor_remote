# Doğrulama özeti (cursor-remote karşılaştırması)

Tarih: 2026-05-19

## Otomatik testler

| Dosya | Ne doğrular |
|-------|-------------|
| `test/message_parser_test.dart` | Temel parse |
| `test/protocol_fixtures_test.dart` | Extension JSON örnekleri |
| `test/widget_test.dart` | Uygulama açılışı |

`flutter test` → hepsi geçmeli.

## Protokol uyumu (giden)

| Alan | cursor-remote mobil | alper_cursor_remote | Durum |
|------|---------------------|---------------------|--------|
| `type` | `insert_text` | `insert_text` | OK |
| `prompt` + `execute` | true | true | OK |
| `agentMode` auto | `"auto"` (PC detect) | `"auto"` | OK (düzeltildi) |
| `clientId` | var | var | OK |
| `stop_prompt` | var | var | OK |

## Protokol uyumu (gelen)

| type | Eski uygulama | Bizim | Durum |
|------|---------------|-------|--------|
| `chat_response` | Göster + divider | Tek balon | OK |
| `chat_response_chunk` | Birleştir | Birleştir | OK |
| `chat_response_complete` | Stream bitir | Finalde balon güncelle | OK (düzeltildi) |
| `agent_mode_selected` | SnackBar | Sistem satırı (filtre) | OK |
| `log` | Filtre kapalı | Aynı | OK |
| `thinking` | Yok (extension atmaz) | Yok | OK |

## Bilinen eksikler (MVP sonrası)

1. **Bağlantı onayı:** `connected=true` WS açılır açılmaz; gerçek hata async gelebilir (eski app benzer).
2. ~~**Geçmiş:** `get_chat_history` gönderilmiyor.~~ → **Eklendi** (bağlanınca + saat simgesi).
3. **Yeni oturum:** `newSession` flag yok.
4. **Arama:** Sohbet içi arama yok.
5. **Canlı E2E:** Bu review otomatik fixture; PC+telefon elle test şart.

## Canlı test checklist

- [ ] PC extension Start, port 8766
- [ ] Tailscale IP ile Bağlan
- [ ] Trafik: `connected` GELEN
- [ ] Prompt gönder → GELEN `chat_response`
- [ ] Durdur → `stop_prompt` GİDEN
- [ ] Wi‑Fi kapat (sadece mobil veri) → hâlâ bağlı (Tailscale)

## Güvenlik (kişisel)

- Relay yok, trafik doğrudan PC.
- `.gitignore` secret dosyaları kapsıyor.
