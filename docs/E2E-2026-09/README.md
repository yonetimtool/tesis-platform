# E2E TEST TURU — 2026-09 (UÇTAN UCA TEST PLANI)

"YÖNETİYOR — Uçtan uca test planı"nın (§1–§13) dev ortamında
(192.168.20.101) koşturulması ve bulunan kusurların düzeltilmesi.

## Yöntem

- Her plan bölümü için ayrı bir test ajanı, **kendi temiz tesisinde**
  (2 blok × 10 daire, 10 rol hesabı: yönetici, güvenlik amiri, 2 güvenlik,
  tesis görevlisi, denetçi, malik, kiracı, malik-oturan, ikinci malik).
- Ölçüm: gerçek backend'e API çağrıları, gerçek Chromium (Playwright) ile
  web, DB'den bağımsız doğrulama (defter, bildirim, push_gonderim, audit),
  e-posta gövdeleri log'dan (`LOG_PII=1`, yalnız dev).
- Mobil: cihaz yok — kod okuması + widget testleri + mobilin gönderdiği her
  istek gövdesinin OpenAPI şemasıyla karşılaştırılması (309 Dio çağrısı).
- Rol × uç taraması: 214 GET × 10 rol × (kendi/başka tesis id) ve yasak
  (rol, mutasyon) çiftleri — **tesisler arası sızıntı 0, yasak yazma 0**.

## Bulgu dosyaları

| dosya | kapsam | bulgu |
|---|---|---|
| `kurulum.md` | §1 kurulum/onboarding, §13 platform paneli | KURULUM-01…15 |
| `yetki.md` | §2 kimlik/yetki, §11.4 oturum | YETKI-01…15 |
| `finans.md` | §4 finans (P192 yol haritası dahil) | FINANS-01…21 |
| `bildirim.md` | §3 e-posta/push/bildirim, §7 iletişim | BILDIRIM-01…19 |
| `guvenlik.md` | §5 kamera, NFC/devriye, vardiya, panik, araç/ziyaretçi | GUVENLIK-00…17 |
| `tesis.md` | §6 tesis operasyonu, §8 daire/sakin, §9 entegrasyonlar | TESIS-01…20 |
| `arayuz.md` | §10 arayüz/erişilebilirlik/arama, §11.1–11.3 dayanıklılık | ARAYUZ-1…17 |
| `mobil.md` | §12 mobil + mobil parite | MOBIL-1…13 |
| `ana.md` | kurulum sırasında görülenler | ANA-1…4 |

Her dosyada önce kontrol listesi (GEÇTİ / KALDI / KISMEN / ÖLÇÜLEMEDİ), sonra
bulgu ayrıntısı (adım, beklenen, olan, kök neden dosya:satır) var.

## Engelleyici bulgular (hepsi düzeltildi)

- Sakin SOS'u 500 — alarm hiç oluşmuyordu (`Unit.daire_no` yok).
- İlk vardiya hatırlatmasından sonra `GET /notifications` 500
  (`NOTIFICATION_TIP` modeli DB enum'unun gerisindeydi) → yeni kilit
  `test_enum_aynasi.py`.
- Panelden açılan yöneticiye davet gitmiyordu; panelin verdiği geçici kod
  web girişinde çalışmıyordu.
- Mobil sayaç okuma endeksi tüketim diye gönderiyordu (fahiş borç).
- Finans: daire seçilmeden alınan tahsilat borcu kapatmıyordu; bekleyen/
  reddedilen gideri iptal kasaya hayali para ekliyordu; kalemsiz tahsilat
  "ödenmemiş" sayılıp haksız faiz/yaşlandırma üretiyordu; tahsilat oranı
  %3 (gerçek ≈ %28) yayınlanıyordu.
- Web dev sunucusu: `npm run dogrula` içindeki `next build` çalışan
  `next dev`'in `.next`'ini eziyordu → artık `.next-dogrula`.

## Ölçülemeyenler (dev ortamı sınırı)

Gerçek iOS/Android cihaz, gerçek e-posta kutusuna teslim (Resend),
APNs/FCM teslimi ve ses, uygulama kapalıyken bildirim, gerçek kamera/diyafon/
akıllı ev donanımı, Google/Microsoft/Apple girişi (dev'de sağlayıcı yok),
ekran döndürme, düşük pil/bellek.

## Bilinçli olarak yapılmayanlar / sonraki tur

- Mobilde gelir kaydı, tekil tahakkuk, fazla mesai, virman/iade (finans
  düzeltmeleri sürerken ertelendi) — `docs/web-mobil-esitlik.md`.
- Bilinçli fark: icra, SMS/e-posta mesajları, NVR kayıt oynatma, denetim
  kaydı mobilde yok (gerekçeler aynı belgede).
- PDF'te CJK/emoji/Arapça şekillendirme (glifsiz karakter "?" olur).
- Mobilden PDF yükleme (`file_picker` bağımlılığı yok).
- Bildirim tercihlerinde TİP bazında kapatma (P167 kararı: kanal bazında).
- Düzenleme uçlarında iyimser kilit (kaybolan güncelleme) — para uçlarında
  `Idempotency-Key` var; genel kilit ayrı bir tasarım işi.
- `kvkk-metinler` sayfası tesis seçimi için hâlâ tüm listeyi çekiyor.
- Diyafon/köprü sağlık yoklaması prod sunucunun konteyner dışı LAN IP'sini
  hâlâ yoklayabilir; kalıcı çözüm yoklamayı saha köprü ajanına taşımak
  (`contracts/auth.md`).

## Prod dağıtım notları

- Göçler: `0149_bildirim_kisi_durumu` → `0150_e2e_finans` →
  `0151_e2e_tesis` → `0152_e2e_duyuru_hedef`. 0150'deki veri onarımları tek
  yönlüdür (downgrade yalnız FK ve kolon tipini geri alır). 0151 çakışan NFC
  UID'lerini düzeltmez, `RAISE WARNING 'e2e_tesis NFC cakismasi'` ile
  raporlar — göç günlüğüne bakılmalı.
- Yeni ortam değişkeni: `DAVET_BASE_URL` (varsayılan
  `https://yonetiyor.com`). `.env.prod` `PORTAL_BASE_URL`'i IDN olarak
  ayarlıyorsa davet bağlantıları artık ondan değil bundan üretilir
  (derin bağlantı uygulamayı açsın diye).
- `SAHA_LOOPBACK_SERBEST` YALNIZ dev compose'da; prod'da TANIMLANMAMALI.
- Kamera canlı yayın sınırı artık tesis başı (`kamera_canli_sinir`) + genel
  (`kamera_canli_genel_sinir=30`).
- Mobil: yeni ekranlar (davetler, gürültü uyarıları, e-posta kodu ile giriş,
  şifremi unuttum) ve push yönlendirme değişiklikleri yeni sürüm gerektirir.
