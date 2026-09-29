# Dış başvurular — durum ve sonraki adım

Bu dosya, kod dışında bir kurumun onayını bekleyen işleri tutar. Her
başvuruda kod tarafının **şimdiden hazır olduğu yer** ve **onay gelince
değişecek tek yer** yazılıdır. Durum değişince bu dosya güncellenir.

---

## Apple Critical Alerts entitlement

- **Başvuru tarihi:** 25 Eylül 2026
- **Request ID:** A5HC6338GM
- **App:** Yönetiyor, `site.yonetio.app`, Team G4NG3BV4NL
- **Beyan:** yalnız deprem, yangın, gaz kaçağı, tahliye. **Tatbikatlar
  critical DEĞİL.**
- **Durum:** bekliyor
- **4 hafta içinde cevap gelmezse** (22 Ekim 2026): aynı bilgilerle formu
  yeniden doldur (Apple'ın önerdiği yol).
- **İzin gelince:**
  1. App ID'de Critical Alerts'i etkinleştir.
  2. Yeni provisioning profile oluştur.
  3. Xcode'da + Capability → Critical Alerts ekle.
  4. Kodda P249 kararlarında yazan **tek yeri** aç:
     `mobile/ios/Runner/Runner.entitlements` →
     `com.apple.developer.usernotifications.critical-alerts` = `true`
     (`docs/P249-kararlar.md` §1c).
- **Kod tarafı beyanla uyumlu:** sunucu kritik ses yükünü yalnız
  `panik_kategori_{deprem,yangin,gaz,tahliye}` kimliklerinde ve yalnız
  izni açık iOS cihazlara gönderir (`push_kanal.KRITIK_UYARI_KIMLIKLERI`).
  Tatbikat (`panik_tatbikat_*`) ve yardım çağrıları kritik değildir;
  `test_KRITIK_UYARI_YALNIZ_APPLE_BEYANINDAKI_KATEGORILERDE` bunu
  kilitliyor. Kapsam genişletilecekse **önce bu başvuru güncellenmeli**.

---

## Google Play — tam ekran bildirim (USE_FULL_SCREEN_INTENT) beyanı

- **Neden:** P249 §1c ile uygulama SOS alarmını kilit ekranında tam ekran
  açmak için bu izni bildiriyor. Android 14+ hedefleyen ve izni bildiren
  uygulamalardan Play Console → Uygulama içeriği bölümünde beyan
  isteniyor.
- **Durum:** **doldurulmadı.** Form ve gerekçe metni hazır:
  `docs/P249-kararlar.md` §1c "Play Console 'Tam ekran amacı' beyanı".
- **Sonraki adım:** P249 değişikliklerini içeren ilk paket (1.8.0)
  yüklenirken beyanı doldur.
  - Temel işlev olarak "arama" ya da "çalar saat" **seçme**. Yönetio
    bunlardan biri değil; yanlış beyan uygulamanın kaldırılmasına yol
    açabilir.
  - Beklenen sonuç: izin Android 14+'da **otomatik verilmez**. Kullanıcı
    uygulamadaki "SOS alarm ayarları" kartından açar.
  - İzin kapalıyken de alarm yüksek öncelikli bildirim olarak gelir.

---

## Verimor — SMS gönderici başlığı

- **Neden:** SOS'un son çare kanalı (güvenlik ve yönetime SMS, P240) ve
  Dükkân telefon OTP'si SMS'e bağlı.
- **Durum:** **onay yok.** Kod hazır ama kapalı: `SMS_AKTIF=false`
  (`backend/app/config.py`). Bu yüzden bugün hiçbir SMS gönderilmiyor ve
  sonuç "yapılandırılmadı" olarak kaydediliyor. Verimor'a hiç gerçek istek
  atılmadı (`docs/dukkan/DURUM.md`).
- **Başvuru tarihi ve takip numarası depoda kayıtlı değil.** Başvuru
  yapıldıysa bu dosyaya ekle.
- **Sonraki adım:** başlık onayını al.
- **Onay gelince değişecek yer:** prod ortam değişkenleri, kod değişmez:
  `SMS_AKTIF=true`, `SMS_SAGLAYICI=verimor`, `SMS_KULLANICI`,
  `SMS_PAROLA`, `SMS_BASLIK=<onaylı başlık>`.
- **İlk gerçek gönderim bir test numarasına yapılmalı:** gerçek SMS
  teslimi bugüne kadar hiç ölçülmedi.

---

## Sanal POS (Dükkân ödeme)

- **Neden:** Dükkân F7 tahsilat akışı sağlayıcıya bağlanmayı bekliyor.
  Bugün sağlayıcı bağlı değilken ödeme ucu 503 döner. Hiçbir karta
  dokunulmadı, 3DS dalı hiç sürülmedi.
- **Durum:** **sağlayıcı seçilmedi.** Karşılaştırma hazır:
  `docs/dukkan/08-odeme-saglayici-karsilastirma.md`.
- **Sonraki adım:**
  1. Karşılaştırmadaki §4 "Teklif isterken sor" listesiyle sağlayıcılardan
     teklif iste.
  2. Seçim yapılınca aynı belgedeki §5 "Seçim yapıldığında ne olacak"
     adımları uygulanır.
  3. Hukuki soruların (`docs/dukkan/07-hukuki-sorular.md`, özellikle
     6563/ETBİS kapsamı) cevabı ödeme açılmadan önce gelmeli.

---

## Teknokent

- **Durum: depoda kayıt yok.** Başvurunun hangi teknokente yapıldığı,
  tarihi, aşaması (ön başvuru / proje değerlendirme / sözleşme) ve
  beklenen belgeler hiçbir belgede geçmiyor. Uydurmamak için boş
  bırakıldı.
- **Sonraki adım:** başvuru bilgilerini (kurum, tarih, takip no, istenen
  belgeler, son tarih) bu başlığa yaz. Proje tanımı için kaynak olarak
  `docs/MASTER-PLAN.md` ve `docs/REKABET-YOL-HARITASI.md` kullanılabilir.
