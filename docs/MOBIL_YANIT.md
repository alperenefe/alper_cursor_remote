# Mobil CLI yanıtları

Telefondan giden her `insert_text` isteğinde (ayar açıksa) PC extension, agent CLI promptunun başına **uzaktan kontrol + mobil okuyucu** talimatı ekler (`replyChannel: mobile`).

- **Yeni oturum** (`newSession`): agent’a “yeni uzaktan oturum” denir.
- **Devam** (`--resume`): “telefon kanalından devam” denir.
- `clientId` `mobile-…` ise `replyChannel` olmasa da uygulanır.

## Ne sağlar?

- Grafik / canvas / HTML önizleme yerine **metin özeti**
- Uzun kod yerine **kısa özet + dosya yolu**
- Geniş tabloların bölünmesi / özetlenmesi

## Ne sağlamaz?

- Telefonda gerçek grafik çizimi (uygulama yalnızca metin gösterir)
- PC’de Composer paneli ile otomatik sync

## Ayar

**Bağlantı** → **Mobil için optimize yanıt** (varsayılan: açık)

## Kalıcı kural (isteğe bağlı)

Projede her zaman geçerli olsun istersen `.cursor/rules/cursor-uzaktan-mobile.mdc` ekleyebilirsin; şu an talimat yalnızca **telefondan gelen** isteklere eklenir, PC’de doğrudan yazdığın sohbeti etkilemez.
