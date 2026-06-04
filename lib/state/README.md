# Uygulama durumu (`lib/state`)

## Yapı

| Klasör / dosya | Sorumluluk |
|----------------|------------|
| `app_state.dart` | `ChangeNotifier` — WS, ayarlar, UI bildirimi; alt modülleri çağırır |
| `session_registry.dart` | Oturum başına mesaj listesi + `SessionLiveState` |
| `queue/` | Kuyruk sayımı, temizleme, global sıra seçimi |
| `inbound/` | Gelen WS: oturum çözümleme, anlamlı asistan metni |
| `chat/` | Tur sırası, balon eşleştirme, geçmiş birleştirme koruması |
| `waiting/` | «Agent çalışıyor» alt şerit metni |
| `display/` | Görünür mesaj filtresi (log/system/progress) |

## Test

Saf fonksiyonlar `test/state/` altında doğrudan `lib` import edilir.  
`AppState` entegrasyonu widget testlerinde (`test/chat_screen_widget_test.dart`).

## Genişletme

Yeni iş kuralı → önce ilgili alt modüle saf fonksiyon; `AppState` yalnızca kablolama yapsın.  
Bağlantı / ham WS işleme hâlâ `app_state.dart` içinde (sonraki adım: `handlers/`).
