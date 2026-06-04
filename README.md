# Cursor Uzaktan (kişisel)

Tailscale + PC’de **Cursor Remote extension** (WebSocket `8766`) ile telefondan Cursor `agent` kontrolü.

## Kurulum

1. PC: Cursor → extension **Cursor Remote** → Start (port 8766).
2. PC + telefon: **Tailscale** aynı hesap.
3. PC Tailscale IP’sini al (`100.x.x.x`).
4. Bu uygulama → **Bağlantı** → IP + port `8766` → **Bağlan**.

## Güvenlik (Auth PIN — 8 karakter)

PC ve telefon **panosu paylaşılmaz**. PIN **oturumda değişmez**; sadece yeniden üretirsen değişir.

1. Cursor: `Ctrl+Shift+P` → **Cursor Remote: Generate 8-char auth PIN**
2. Açılan kutudaki **8 harfi** telefonda yaz **veya** USB ile: **Telefona yapıştır (adb)**
3. Telefon: **Bağlantı** → **Auth PIN** → kaydet → **Bağlan**
4. PC: **Developer: Reload Window** (extension güncellediysen)

Auth boş = kapalı (sadece tailnet için kabul edilebilir).

## Debug (telefon logları)

USB ile bağlıyken tüm WebSocket trafiği logcat'e yazılır:

```bash
adb logcat | findstr CursorUzaktan
```

## Sekmeler

| Sekme | İşlev |
|-------|--------|
| Sohbet | Prompt gönder / AI cevabı (filtrelenmiş) |
| Bağlantı | IP, port, filtreler, ajan modu |
| Trafik | Ham WebSocket JSON (request/response) |

## Filtreleme

Bkz. [docs/FILTRELEME.md](docs/FILTRELEME.md) — `thinking` extension’da zaten atılır.

## Eski proje

`cursor-remote` mobil uygulaması silinebilir; PC extension şimdilik aynı kalır (protokol uyumlu).

## Gizlilik

- Relay yok; trafik doğrudan PC’ye.
- `.env` / keystore commit etme.

## Derleme

```bash
cd alper_cursor_remote
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
