# P190 — Dağıtım notları

Kararlar ve gerekçeler `docs/P190-kararlar.md`. Her bölüm ayrı commit;
prod dağıtımı + cihaz testi kullanıcıda.

## Dağıtım adımları (prod, 192.168.1.105)

```bash
docker compose -f docker-compose.prod.yml build migrate api admin-web worker
docker compose -f docker-compose.prod.yml up migrate          # göç 0076 (ui_tema)
docker compose -f docker-compose.prod.yml up -d mediamtx api admin-web worker beat
```

Notlar:
- **api imajı büyüdü** (~+250 MB): ffmpeg eklendi (kamera karesi sunucuda
  çekiliyor).
- **Yeni servis `mediamtx`** (RTSP→HLS geçidi): public port AÇMAZ; yalnız iç
  ağdan backend erişir. Prod compose'ta env varsayılanları dolu
  (`MEDIAMTX_URL=http://mediamtx:8888`, `MEDIAMTX_API_URL=http://mediamtx:9997`,
  `KAMERA_CANLI_SINIR=3`) — ekstra .env girdisi gerekmez; canlı izlemeyi
  kapatmak istersen `MEDIAMTX_URL=` (boş) ver.
- Göç 0076: `app_user.ui_tema` (varsayılan `system`) — geri alınabilir.

## Bölüm bölüm değişenler (commit sırasıyla)

1. **AAB / Play üretim** (`62fecf52`): mobil sürüm `1.1.0+3`;
   `/home/kerem/yonetio-1.1.0+3-release.aab` (67 MB) upload anahtarıyla
   imzalı (SHA-256 `DD:1F:59:64:C4:A9:CC:56...` doğrulandı; debug değil).
   targetSdk=36 (Play şartı ≥35 karşılanıyor). KGP uyarıları (flutter_web_
   auth_2, nfc_manager) yalnız uyarı — release derlemesini KIRMADI; tek
   kırılma `key.properties` storeFile yolunun yanlış olmasıydı (düzeltildi,
   git dışı dosya). Play sürüm notu bu dosyanın sonunda.
2. **§1 panel yönlendirme** (`a29373c5` ilk): middleware konak-ötesi 307 +
   /kayit yüzeyi. Yalnız admin-web.
3. **§4 bildirim rozeti** (`a29373c5` ikinci): global mutate. Yalnız web.
4. **§5 tema** (`63c15520` ilk): göç 0076 + `PATCH /me/tema` + çerez/SSR.
   Backend + web.
5. **§3 duyuru/kural** (`63c15520` ikinci): web oluşturma + kural görseli.
   Yalnız web (backend/mobil zaten tamdı).
6. **§6 RTSP** (bu commit): backend kare+canlı uçları, ffmpeg, MediaMTX
   servisi, web ızgara/oynatıcı, mobil kare/canlı.

## Test durumu

- Backend tam takım: bölüm commit'lerinde koşuldu (1963 → §6 sonrası sayı
  commit mesajında). Kamera testleri: maskeleme, kare 502/422/404 görünürlük,
  canlı 503 (yapılandırılmamış dal).
- admin-web tam takım: 1439+ (yeni middleware/kamera testleri dahil).
- Flutter: tam takım (mobil §6 değişiklikleri dahil — commit mesajında).

## Cihazda / prod'da doğrulanacaklar (burada üretilemez)

1. **Gerçek SSO** (Google/Microsoft/Apple) ile mobil yönetici girişi (§2 —
   kod izi + testler doğrulandı; canlı sağlayıcı ve gerçek hesap burada yok).
2. **Gerçek RTSP kamera** ile: ızgara karesi (ffmpeg gerçek kameraya
   bağlanır — testler yalnız "bağlanamadı" dalını ölçebildi), tıkla-canlı
   (MediaMTX gerçek akış), eş-zamanlılık sınırı davranışı, HLS gecikmesi
   (~5-10 sn beklenir).
3. Tema: iki tarayıcıda aynı hesapla aynı temanın gelmesi; panel+app çerez
   paylaşımı (`.yönetiyor.com` alan çerezi).
4. Panel→app yönlendirmesi prod alan adlarıyla (`panel.yönetiyor.com` →
   `app.yönetiyor.com`; punycode konaklar dahil).
5. AAB'nin Play Console'a yüklenmesi (üretim kanalı, sürüm kodu 3).

## Play sürüm notları (≤500 karakter, kopyala-yapıştır)

```
Bu sürümdeki yenilikler:
• Kayıt artık e-posta ile: yöneticinizden gelen davet e-postasındaki Tesis Kimliği ile kolayca kaydolun.
• Google, Microsoft veya Apple hesabınızla giriş yapabilirsiniz.
• Bildirim tercihleri ekranı: hangi bildirimleri alacağınızı seçin.
• Duyuru ve site kurallarında görseller.
• Yenilenen uygulama simgesi, hata düzeltmeleri ve performans iyileştirmeleri.
```
(~370 karakter)
