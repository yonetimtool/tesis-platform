# DUKKAN — DURUM ÖZETİ

> Altı fazın tamamı yazıldı ve `main`'e push'landı.
> **`dukkan.yonetiyor.com` yayına açılmadı** — o karar sende.

---

## Fazlar

| Faz | İçerik | Göç | Durum |
|---|---|---|---|
| **F1** | Şema + `dukkan_app` rolü + lokasyon (44.719 mahalle) + kategori | 0113, 0114 | **prod'da**, doğrulandı |
| **F2** | Kimlik (telefon OTP + SSO), işletme kaydı, moderasyon | 0115 | **prod'da**, doğrulandı |
| SMS | Verimor entegrasyonu, çelişki düzeltmesi, sızıntı kilidi | 0116 | prod'a hazır |
| **F3** | SEO yüzeyi, arama, sıralama, sitemap + mobil | 0117 | prod'a hazır |
| **F4** | Talep, KVKK paylaşım tercihleri, teklif, iş | 0118 | prod'a hazır |
| **F5** | İki katmanlı yorum, kota, şikâyet, moderasyon paneli | 0119 | prod'a hazır |
| **F6** | Bildirim, mobil menü, panel sayfası | 0120 | prod'a hazır |
| **F6-ek** | Mobil bildirim ekranı + FCM kaydı, Dukkan push kanalı, ayrı tercih, web bildirim sayfası | 0121 | prod'a hazır |
| **F7** | Başarısız SMS kotayı yemesin + mobil telefon-OTP (jeton cihazda) | 0122 | prod'a hazır |
| **F8a** | Gelir modeli değişti: para akışı yok — `anlasmazlik` kaldırıldı, kısıt kilitlendi, metinler | 0123 | prod'a hazır |
| **F8b** | Reklam: paket/slot/bekleme, sponsorlu ayrı blok, gecelik bakım | 0124 | prod'a hazır |
| **F8c** | Ödeme altyapısı (sağlayıcıdan bağımsız), kart token, abonelik | 0125 | prod'a hazır |

Dağıtım notları: `F1-dagitim.md` … `F6-dagitim.md`, `F6-ek-dagitim.md`,
`F7-dagitim.md`, `F8-dagitim.md`, `SMS-entegrasyonu.md`.
**Sıralı uygulanmalı** — göç zinciri 0113→0125.

> **F6-ek mobil sürüm gerektirir.** Backend'i mobilden önce dağıtmak,
> eski sürümdeki cihazlarda Dukkan push'unu **sessizce düşürür**
> (kayıtsız kanal). Sıra ve gerekçe: `F6-ek-dagitim.md` §7.

---

## Test durumu

| Takım | Sonuç |
|---|---|
| backend | **3018+** passed, 38 skipped |
| admin-web | **1735** passed |
| dukkan-web | **63** passed (BFF sözleşme kapısı) |
| tanitim-web | **24** passed |
| mobil | **2103** passed |

Dukkan'a ait backend testleri: sınır (15), köprü (15), lokasyon (32),
uçlar (13), arama (16), IDOR + kimlik kapısı (30), KVKK (10), arz akışı
(23), güven (23), bildirim (12), **bildirim kanalı + tercih (15)**,
SMS (18), **para akışı yok (4)**, **reklam (17)**, **ödeme (18)**.
Mobil: jeton ayrımı (3), bildirim yönlendirmesi (9), **OTP jeton
deposu (6)**.

---

## Kalıcı güvenlik kilitleri

Hepsi **kırılarak** doğrulandı — kırıldığında kırmızı yandığı görüldü.

| Kilit | Ne korur |
|---|---|
| `test_dukkan_sinir` | `dukkan_app` `public` şemasına erişemez; katalog taraması **gelecek** tabloları da kapsar |
| `test_dukkan_kopru_siniri` | Dukkan modülleri Yönetiyor'u ithal edemez; köprü salt okunur ve **RLS'e tabi** |
| `test_dukkan_isletme_idor` | Her `/isletme/{id}/…` ucu için 403 testi **zorunlu**; testsiz uç eklenemez |
| `…KIMLIK_KAPISI_VAR` | Her Dukkan mutasyon ucu ya kamu beyanlı ya kimlik kapılı |
| `test_dukkan_kvkk` | Açık adres `is_kaydi` doğmadan **hiçbir yanıtta** yok |
| `denetim` append-only | Moderasyon kararı sonradan silinemez (göç + setup betiği, ikisi birden) |
| `test_beat_schedule` | Zamanlanmış iş kayıtsız kalamaz; kapsam `include`dan **kendini** okur |
| `test_dukkan_bildirim_kanal` | Dukkan push'u Yönetiyor kanalına düşemez; kanal **önekten** türetilir (liste değil); kapalı tercih push'u susturur ama **satırı silmez** |
| `dukkan_bildirim_yonlendirme_test` | Sunucudaki her bildirim tipinin mobil hedefi var **ve o hedef router'da tanımlı** (F4'te olmayan bir rotaya `push` ediliyordu) |
| BFF sözleşme kapısı | Vekili olmayan uç = web'de 405; **beş kez** işe yaradı (son ikisi F8'de, 10 vekil) |
| `test_dukkan_para_akisi_yok` | Talep/teklif/iş akışına ödeme ima eden sütun eklenemez; `anlasmazlik` yazılamaz (platform hakemlik etmez) |
| `test_KART_ALANI_HICBIR_TABLODA_YOK` | Kart numarası/CVV/son kullanma **hiçbir** Dukkan tablosunda olamaz — şemanın tamamını tarar |
| `test_REKLAM_SIRALAMA_PUANINI_DEGISTIRMEZ` | Reklam organik sıralamayı manipüle edemez — gelir modelinin dayandığı kilit |
| `test_YABANCI_KART_SILME_ABONELIGI_DURAKLATMAZ` | IDOR: yabancı istek başkasının aboneliğini duraklatamaz (güvenlik taramasında bulundu) |

---

## Açık maddeler

### Karar sende (baştan öyle anlaşıldı)

1. **GELİR MODELİ DEĞİŞTİ (F8).** Platform hizmet bedeline **hiç
   dokunmuyor** — sipariş, tahsilat, komisyon yok ve bu **kalıcı**
   (testle kilitli). Tek gelir: işletmelerden alınan **reklam bedeli**,
   doğrudan satış.
   **Kalan karar:** (a) **sanal POS sağlayıcısı** — karşılaştırma
   `08-odeme-saglayici-karsilastirma.md`, teklif isteme listesi §4;
   (b) **reklam fiyatları** — `reklam_paketi` tablosu boş, fiyat
   girilene kadar reklam satılamaz (bilinçli: fiyat kodda değil).
2. **Hukuk** — `07-hukuki-sorular.md`, 16 soru, öncelik sıralı. En
   muhafazakâr varsayımla kuruldu: ödeme yok, aracılık yok, şikâyet
   mekanizması ve kayıt saklama var.
3. **Dış hesaplar** — SMS başlığı onayı bekliyor (**tek satır**
   `SMS_BASLIK=`). Harita API'si **hiç gerekmedi** (eşleşme mahalle
   üzerinden; PostGIS yok). Sanal POS ve e-fatura V1 dışında.
4. **`dukkan.yonetiyor.com` yayına açılsın mı** — compose bloğu
   `F6-dagitim.md` §6'da hazır (`networks: [tesisnet]` dahil).

### Teknik açıklar

> Triyaj ve önerilen sıra: **`ONCELIK.md`**. Engelleyen iki madde
> (davet kotası, mobil OTP) **F7'de kapatıldı**; kalan beşi iyileştirme.

| Madde | Nerede yazılı |
|---|---|
| **Bildirim toplulaştırma (batching) yok** | F6 §13 |
| `bildirim` tablosunda **retention yok** | F6-dagitim §8 |
| **Web push yok** (service worker altyapısı kurulmadı) | F6-ek §7 |
| `talep.son_gecerlilik` var ama **kullanılmıyor** | F4 §14 |
| **İtiraz ucu yok** (denetim izi hazır, süreç e-posta ile) | F5 §14 |
| **Jeton `localStorage`'da** | F2 §11 — **ödeme geldi, bu madde artık ENGELLEYİCİ** (`ONCELIK.md` §7) |
| **Reklam tıklama/gösterim ölçümü yok** | Bilerek: ölçüm "gösterim garantisi" beklentisi yaratır ve sözleşmede taahhüde döner (hukuki S19) |
| **3DS dalı ölçülmedi** | Kodda var; sağlayıcı seçilince yeniden ölçülmeli |

---

## Ölçemediklerim — dürüst liste

1. **Gerçek push teslimi.** Dev'de `PUSH_PROVIDER=noop`; hiçbir bildirim
   gerçekten gönderilmedi. Ölçülen şey, `bildir()`in sağlayıcıya **doğru
   kanal ve sesi verdiği**; Android'in o kanalı çalıp çalmadığı değil.
   Prod ölçümü `F6-ek-dagitim.md` §4.3–4.4.
2. **Gerçek SMS teslimi.** Başlık onayı yok; Verimor'a hiç istek atılmadı.
3. **Sayfalama kararsızlığı** (F3 §6) — davranışsal olarak tetiklenemedi;
   kilit **yapısal**.
4. **Kota, eşik ve ağırlık sayıları tahmin** (F5 §15): `3 + 2×etkinlik`,
   "3 ödeme şikâyeti", `0.3` davetli ağırlığı, SEO eşiği `3`. İlk üç ayda
   gerçek veriyle ayarlanmalı.
5. **Şüpheli yorum tespiti IP tabanlı ve zayıf** — organize sahte yorum
   farklı ağlardan gelirse yakalanmaz.
6. **Kullanıcı davranışı**: KVKK paylaşım kutularının kaçının işaretleneceği
   ürünün çalışıp çalışmayacağını belirler ve **ancak gerçek trafikte**
   görülür.
7. **Mobil ekranların cihazdaki görünümü** — emülatör yok.
7b. **Gerçek tahsilat.** Sanal POS yok; hiçbir karta hiç dokunulmadı.
   Ölçülen şey akışın kendisi (sahte sağlayıcıyla) ve sağlayıcı bağlı
   değilken davranış (503). **3DS dalı hiç sürülmedi.**
7c. **Reklamın işe yarayıp yaramadığı.** Tıklama/gösterim ölçümü yok
   (bilerek — hukuki S19). Slot sayıları (1/2/3, %20) tahmin.
8. **Hukuki durum** — 6563/ETBİS kapsamı belirsiz; yazılımla kapatılamaz.

---

## Sonraki adım önerisi

Sırayla:

1. **SMS başlığı onayı** gelince `SMS_BASLIK` doldur → kimlik akışı çalışır.
2. **Avukat görüşmesi** → `07-hukuki-sorular.md` cevapları → sözleşme
   metinleri.
3. **F1–F6 dağıtımı** (sıralı) → `dukkan-web` servisi + Caddy → site açılır.
4. **İlk işletmeleri topla** (F2 arz tarafı hazır) — SEO sayfaları eşiği
   geçtikçe **kendiliğinden** doğar.
5. İlk üç ay: kota/eşik/ağırlık sayılarını **ölç ve ayarla**.
