# BİRLEŞİK ENVANTER — AŞAMA 0

> **Bu belge tek doğruluk kaynağıdır.** P142–P160'ın sonraki her aşaması
> buraya bakarak çalışır. Amacı bir şeyi iki kez yazmayı önlemektir.
>
> Yöntem: iddia yok, **ölçüm** var. Her satır ya bir dosya yolundan ya bir
> uç listesinden ya bir tablo adından okundu. Ölçülemeyenler "ölçülmedi"
> diye yazıldı.
>
> Ölçüm tarihi: **2026-08-09**, `main` @ `9722bf2`.

---

## ÖZET — TEK CÜMLELİK BULGU

**Arka uç sanılandan çok daha dolu; boşluk neredeyse tamamen YÜZEYDE.**
Briefte "muhtemelen yazılmış ama yüzeye çıkarılmamış" diye geçen modüllerin
**tamamının** tablosu, şeması ve HTTP ucu var. Eksik olan; web sayfası,
mobil ekran ve menü girişi. Bu, sonraki aşamaların **ağırlığını arka
uçtan ön uca kaydırır**.

Sayılarla:

| Katman | Ölçüm |
|---|---|
| Backend router modülü | **65** (`backend/app/routers/`) |
| SQLAlchemy modeli | **~90** tablo (`backend/app/models.py`) |
| Göç | **0040** (head) |
| admin-web sayfası | **54** (`app/**/page.tsx`) |
| admin-web menü öğesi | **41** (`lib/menu.ts`) |
| Mobil özellik dizini | **42** (`lib/src/features/`) |
| Mobil dart dosyası | **305** |

---

## 0.1 MEVCUT DURUM — briefteki modüllerin ölçümü

Sütunlar: **Tablo** (veritabanı) · **Uç** (backend HTTP) · **Web**
(sayfa var mı) · **Menü** (kenar çubuğunda görünüyor mu) · **Mobil** ·
**Roller** (web tarafı, `lib/yuzey.ts:ROTA_ROLLERI`).

| Modül | Tablo | Uç | Web sayfası | Menü | Mobil | Roller | DURUM |
|---|---|---|---|---|---|---|---|
| **icra_dosyasi** | `icra_dosyasi` ✔ | `GET/POST/PATCH /finans/icra-dosyalari` ✔ | **YOK** | yok | yok | — | 🔴 **Arka uç tam, yüzey SIFIR.** BFF beyaz listesinde okuma **ve** yazma açık (`lib/panel-vekil.ts`) ama hiçbir sayfa çağırmıyor. |
| **karar_defteri** | `karar_defteri`, `karar_uyesi` ✔ | `GET/POST /karar-defteri` ✔ | `/yonetisim` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟢 Web'de çalışıyor; **mobilde yok**. PDF çıktısı `app/api/panel/karar-pdf` ile ayrı. |
| **finansal_hareket** | `finansal_hareket` ✔ | `GET/POST /finans/hareketler`, `/tahsilat`, `/tahsilat/toplu`, `/virman`, `/iade`, `/acilis`, `/kasa-bakiyeleri`, `/banka-eslestir`, `/ozet` ✔ | `/finans` ✔ | Finans ✔ | yok | admin, yonetici | 🟡 Sayfa **yalnız 3 ucu** okuyor (`finans-ozet`, `kasa-bakiyeleri`, `finans-hareketler`). Virman/iade/açılış/toplu tahsilat BFF'te açık ama **ekranı yok**. |
| **gelir_gider_grup** | ✔ | `GET/POST/PATCH/DELETE /gelir-gider-gruplari` ✔ | `/tanimlar` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟢 Çalışıyor (`DEFTERLER` #2). |
| **gelir_gider_tanim** | ✔ | `.../gelir-gider-tanimlari` ✔ | `/tanimlar` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟢 Çalışıyor (`DEFTERLER` #3). |
| **kasa** | ✔ | `GET/POST/PATCH/DELETE /kasalar` ✔ | `/tanimlar` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟢 Çalışıyor (`DEFTERLER` #1). |
| **iletisim_mesaji** | `iletisim_mesaji` ✔ | `routers/tanitim.py` ✔ | `/` (tanıtım) ✔ | — | — | herkese açık | 🟢 **Farklı iş:** tanıtım sitesinin iletişim formu. Tesis-içi mesajlaşma **değil** — Aşama 9 ile karıştırılmamalı. |
| **dis_hizmet** | `dis_hizmet` ✔ | `routers/external_services.py` ✔ | `/dis-hizmetler` ✔ | Tesis ✔ | `features/dis_hizmet` ✔ | admin, yonetici | 🟢 Uçtan uca çalışıyor. |
| **sayaç okuma** | `sayac_ana`, `sayac_bolum` ✔ | `.../sayaclar/ana`, `.../sayaclar/bolum`, `POST /borclandirma/sayac` ✔ | `/sayac-okuma` + `/tanimlar` ✔ | Finans + Yönetim ✔ | yok | admin, yonetici | 🟡 Tanım ve okuma var; **dağıtım sihirbazı yok** (Apsiyon §11 — C kovası). |
| **doküman yönetimi** | `tenant_dokuman` ✔ | `GET/POST /dokumanlar` ✔ | `/yonetisim` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟡 Web'de var, **mobilde yok**. Ortak "ek" sistemi değil, tesise özel tek liste. |
| **borçlandırma** | `dues_assessment` ✔ | `/borclandirma/toplu`, `/toplu/onizleme`, `/sayac`, `/gecikme-ayari` ✔ | `/dues` ✔ | Finans ✔ | `features/dues` ✔ | admin, yonetici | 🟢 Çalışıyor. Önizleme ucu **var**. |
| **tahsilat** | `dues_payment`, `finansal_hareket` ✔ | `POST /finans/tahsilat`, `/tahsilat/toplu` ✔ | `/dues` (tekli) | Finans ✔ | `features/dues` ✔ | admin, yonetici | 🟡 Tekli var; **toplu tahsilat ekranı yok**. |
| **virman** | `finansal_hareket` (çift kayıt) ✔ | `POST /finans/virman` ✔ | **YOK** | yok | yok | — | 🔴 Uç + BFF açık, ekran yok. |
| **ödeme iadesi** | `finansal_hareket` ✔ | `POST /finans/iade` ✔ | **YOK** | yok | yok | — | 🔴 Uç + BFF açık, ekran yok. |
| **açılış fişi** | `finansal_hareket` ✔ | `POST /finans/acilis` ✔ | **YOK** | yok | yok | — | 🔴 Uç açık (BFF'te **yok**), ekran yok. |
| **firma/cari** | `firma` ✔ | `GET/POST/PATCH/DELETE /firmalar` ✔ | `/tanimlar` ✔ | Yönetim ✔ | yok | admin, yonetici | 🟡 Kayıt defteri var; **cari hesap ekstresi / bakiye yok** (C kovası). |
| **araç** | `arac_kayit` ✔ | `.../arac-kayitlari` ✔ | `/tanimlar` ✔ | Yönetim ✔ | `features/vehicle_pass` (ayrı iş) | admin, yonetici | 🟢 Tanım çalışıyor. `vehicle_pass` **başka** bir modüldür (kapı geçişi). |
| **personel** | `personel_kayit` ✔ | `.../personel-kayitlari` ✔ | `/tanimlar` ✔ | Yönetim ✔ | `features/staff` ✔ | admin, yonetici | 🟢 Çalışıyor. |
| **anket** | `anket`, `anket_secenek`, `anket_oy` ✔ | `GET/POST /anketler` ✔ | `/portal` + `/site/[slug]` ✔ | İletişim ✔ | `features/anket` ✔ | admin, yonetici | 🟢 Uçtan uca çalışıyor. |
| **etkinlik** | `etkinlik`, `etkinlik_katilim` ✔ | `routers/events.py` ✔ | `/etkinlikler` ✔ | Tesis ✔ | `features/etkinlik` ✔ | (rol listesi boş → tesis rolleri) | 🟢 Uçtan uca çalışıyor. |

### 0.1.1 "Çalışıyor mu?" — dürüst kayıt

Yukarıdaki 🟢 işaretleri **kod yolunun tam olduğunu** söyler (tablo → uç →
sayfa → menü). **Ekranda tıklanarak doğrulanmadı**: bu turda çalışan bir
test sunucusu yok (Aşama A rehber olarak yazıldı, makine henüz yok) ve
canlıya dokunmak yasak. Cihaz/ekran doğrulaması Aşama A'daki sunucu
kalktıktan sonra yapılacak.

Otomatik kapılar bu ölçümle **paralel** koşturuldu; sonuçları raporun
sonunda.

### 0.1.2 En büyük tek bulgu — "ölü BFF ucu" sınıfı

`admin-web/lib/panel-vekil.ts` bir **beyaz listedir**: panelin arka uca
ulaşabildiği her kaynak orada yazılıdır. Listeyi sayfalarla karşılaştırdım:

| BFF kaynağı | Yön | Kullanan sayfa |
|---|---|---|
| `icra-dosyalari` | oku **+ yaz** | **HİÇBİRİ** |
| `finans-tahsilat` | yaz | **HİÇBİRİ** |
| `finans-virman` | yaz | **HİÇBİRİ** |
| `finans-iade` | yaz | **HİÇBİRİ** |
| `banka-eslestir` | yaz | **HİÇBİRİ** |
| `mesaj-gonder` | yaz | **HİÇBİRİ** (`/mesajlar` yalnız şablon + geçmiş + önizleme yapıyor) |
| `site-aktar-sablon` | oku | `/yonetisim` ✔ |
| `site-aktar` | yaz | `/yonetisim` ✔ |

**Altı yazma ucu panele açılmış ama hiçbir ekran onları çağırmıyor.** Bu
hem bir fırsat (Aşama 10'un işi büyük ölçüde "ekran yaz"a iner) hem bir
risk: kullanılmayan bir yazma ucu, kimsenin bakmadığı bir saldırı yüzeyidir.

---

## 0.4 BAĞIMLILIK HARİTASI

Aşama 7.4 "bağımlılık yönlendirmesi" bileşenini **bu tablodan** üretecek.
Her satır: *X eklemek için önce Y tanımlanmalı*; "Kanıt" sütunu bunu
zorlayan kodu gösterir.

| Eklenmek istenen | Önce gereken | Kanıt | Bugün ne oluyor |
|---|---|---|---|
| **Daire** (`unit`) | **Blok** | `routers/blocks.py:8` — blok zorunlu bağ; `unit.blok` metin bağı | Blok yoksa daire açılamaz |
| **Blok silme** | İçinde daire olmaması | `blocks.py:155` — `cascade=false` → **409** | 409 döner; UI onay ister |
| **Görev** (`task`) | **Görev kategorisi** (bütçe kategorisi) | `tasks.py:158` — `422 butce_kategori_bulunamadi`; `:160` — `422 gorev_pasif_kategoriye_yazilamaz` | 422; kullanıcı nereye gideceğini bilmiyor |
| **Toplu borçlandırma** | **Gelir/gider tanımı** | `borclandirma_uc.py:76` — `422 gelir_gider_tanim_yok` | 422 |
| **Bölüm sayacı** (`sayac_bolum`) | **Daire** + **Ana sayaç** | `tanimlar/page.tsx` — `referans` tipi alan, `kaynakUcu` ile daire listesi çeker; `sadeceOlustur` | Boş açılır liste |
| **Sayaçla borçlandırma** | Bölüm sayacı + okuma + gelir/gider tanımı | `POST /borclandirma/sayac` | 422 |
| **Tahsilat** | **Kasa** | `POST /finans/tahsilat` gövdesinde `kasa_id` | Kasa yoksa akış tamamlanamaz |
| **Virman** | En az **iki kasa** | `POST /finans/virman` — çift kayıt | Tek kasayla anlamsız |
| **Rezervasyon** | **Ortak alan** | `ortak_alan` FK | Boş liste |
| **Devriye planı** | **NFC noktası** (`checkpoint`) | `patrol_plan_checkpoint` FK | Boş liste |
| **Vardiya ataması** | **Kullanıcı** (personel rolü) | `shift_assignment` → `app_user` | Boş liste |
| **Sakin hesabı** | **Daire** (dolayısıyla **Blok**) | `unit_resident` FK; *daire başına 1 hesap* kuralı | Daire yoksa sakin açılamaz |
| **Mesaj gönderimi** | **Mesaj şablonu** (+ alıcı segmenti) | `POST /mesajlar/gonder` | Şablon yoksa gönderilemez |
| **Aidat** (`dues_assessment`) | **Daire** + gelir/gider tanımı | `dues_assessment` FK | 422 |
| **Şeffaflık yayını** | Yayın kapısı (finansal veri) | `transparency_publication` | Boş özet |
| **Daire tipi ataması** | **Daire tipi tanımı** (`unit_tip`) | `unit.unit_tip_id` FK | Web'de **atama arayüzü yok** (§0.1) |

**Aşama 7.4'ün girdisi budur.** 16 satırın hepsi tek bir
`<BagimlilikUyarisi>` bileşeniyle karşılanacak: *uyarı cümlesi + ilgili
tanım ekranına götüren düğme + iş bitince geri dönüş*. Her ekrana ayrı
çözüm yazılmayacak.

---

## 0.5 İSİMLENDİRME — ÖLÇÜM SONUCU: **BİRLEŞTİRME KISMEN YAPILAMAZ**

Brief: *"'Şikayetler', 'Öneriler' ve karttaki 'Geri Bildirim' TEK ekranda
birleşecek, adı 'Şikayet ve Öneriler' olacak. Önce ölç: bina şemasındaki
'Şikayetler' aynı veri modeline mi bakıyor? Farklıysa birleştirme veri
kaybı yapar — ayrı adlandır ve raporla."*

### Ölçüm

**İKİ AYRI VERİ MODELİ VAR. Aynı şey değiller.**

| | **`complaint`** | **`unit_complaint`** |
|---|---|---|
| Anlam | Sakin → **yönetim** talep/şikayet/öneri kanalı | Sakin → **komşu dairesi** şikayeti |
| Kaynak | `models.py:1433` — *"Sikayet/oneri — sakin -> yonetim talep kanali"* | `models.py:1998` — *"Sakin -> HEDEF DAIRE sikayeti (D1). TAM ANONIM."* |
| Anonimlik | **Yok** — açan görünür (`acan_user_id`) | **Tam anonim** — `complainant_user_id` hiçbir serializer tarafından döndürülmez; yönetici/admin dahil kimse göremez |
| Hedef | Yönetim | Bir **daire** (`target_unit_id`) |
| Backend | `routers/complaints.py` | `routers/unit_complaints.py` |
| Web ucu | `/api/complaints` | `/api/unit-complaints` |
| Web sayfası | `/complaints` (yönetim), `/taleplerim` (sakin) | `/schematic` — **"Şikayet Haritası"** |
| Yan tablolar | `complaint_photo`, `complaint_status_history` | `unit_complaint_okuma` |

**Bina şemasındaki "Şikayetler" `unit_complaint`e bakıyor**
(`app/(protected)/schematic/page.tsx:97` → `/api/unit-complaints`),
`/complaints` ise `complaint`e. Bunları tek ekranda birleştirmek:

1. **Anonimliği kırardı.** `unit_complaint` tasarımı gereği açanı
   gizler; `complaint` göstermek zorundadır (yönetim cevap yazar). Tek
   listede birleştirmek ya birini ifşa eder ya diğerini sakatlar.
2. **Hedef alanını kaybederdi.** `unit_complaint.target_unit_id`
   zorunlu; `complaint`in böyle bir alanı yok.
3. **Veri kaybı yapardı** — brief'in uyardığı tam olarak bu.

### KARAR

| Yüzey | Bugünkü ad | Yeni ad | Model |
|---|---|---|---|
| Yönetim talep listesi (web `/complaints`) | "Talepler" | **"Şikayet ve Öneriler"** | `complaint` |
| Sakin kendi talepleri (web `/taleplerim`) | "Taleplerim" | **"Şikayet ve Önerilerim"** | `complaint` |
| Mobil modül karosu | "Şikayet / Öneri" (`modulSikayetOneri`) | **"Şikayet ve Öneriler"** | `complaint` |
| Mobil sakin listesi | "Şikayetlerim" (`kartSikayetlerim`, `modulSikayetlerim`) | **"Şikayet ve Önerilerim"** | `complaint` |
| Bina şeması (web `/schematic`, mobil) | "Şikayet Haritası" | **"Daire Şikayetleri"** — **ayrı kalır** | `unit_complaint` |
| Mobil "Geri Bildirim" karosu | `kartGeriBildirim` | **kaldırılır** (P147'de Bildirimler devraldı; ARB anahtarı artıkta kalmış) | — |
| Gürültü şikayeti (`kartGurultuSikayeti`) | — | **dokunulmaz** — üçüncü bir akış (`violation` / `unit_uyari`) | ayrı |

**Gerekçe tek cümle:** "Şikayet ve Öneriler" *yönetime* yazmaktır; "Daire
Şikayetleri" *komşuya* dairdir ve anonimdir. İki farklı iş, iki farklı ad.

---

## KAPILAR — bu ölçümle paralel koşturuldu

`infra/kapilar.sh` (kural 6) tam koşum, `main` @ `ca6b5aa` üzerinde
başlatıldı. Son tam koşum **2026-08-05**'ti ve aradan sekiz commit geçmişti
(Android paket adı değişikliği `51ad46b`, tetikleyici düzeltmesi `f3b6712`
dahil) — yani bu ölçüm gecikmişti.

| Kapı | Sonuç |
|---|---|
| `depo-izlenmeyen` | **OK** — bulgu 0; yapı yapılandırmasının referans verdiği her dosya izleniyor |
| `depo-alan-adi` | **HATA** — bulgu 5 (aşağıda) |
| `web-tsc` | **OK** — çıktı yok (sessiz başarı) |
| `web-vitest` | **OK** — 84 dosya, **676 test** geçti |
| `web-build` | koştu (aşağıdaki nota bakın) |
| `mobil-analyze` / `mobil-test` / `mobil-apk` / `backend` / `göç` | koşum sürüyordu; sonucu bu belgeden **sonra** raporlanacak |

### ⚠ `depo-alan-adi` — beş bulgu, hepsi BELGE-KOD TUTARSIZLIĞI

Bu kapı Caddyfile'daki konak listesi ile belgedeki listeyi karşılaştırır.
Beş uyuşmazlık var ve **hiçbiri bu turda üretilmedi** — P149'un alan adı
geçişinden kalma:

1. `www.xn--ynetiyor-n4a.com` belgede vaat ediliyor, Caddyfile'da **yok**
   → ziyaretçi temiz 404 değil, **TLS el sıkışması düşmesi** görür.
2–5. `yonetiyor.com`, `www.yonetiyor.com`, `app.yonetiyor.com`,
   `panel.yonetiyor.com` Caddyfile'da **sunuluyor** ama belgedeki konak
   listesinde yok.

**Bu turda düzeltilmedi.** Gerekçe: düzeltme ya Caddyfile'a (canlı
yapılandırma) ya alan adı belgesine dokunmayı gerektirir; kilitli kural 6
canlıya deploy etmeyi yasakladığından yalnız **belge** tarafı
düzeltilebilirdi ve bu, gerçek TLS kusurunu (madde 1) kapatmadan uyarıyı
susturmak olurdu. Aşama A'nın test sunucusu kalktıktan sonra madde 1
orada denenip düzeltilmeli. **Kayıt altına alındı, susturulmadı.**

---

## SONRAKİ AŞAMALARA GİRDİ — ne YENİDEN YAZILMAYACAK

Bu bölüm tek başına bir çakışma önleme listesidir.

| Sonraki aşamanın "yaz" dediği şey | ZATEN VAR | Yapılacak iş |
|---|---|---|
| **Aşama 1** — Tesis ID üretimi (ilk 4 harf + `-` + YYAAGG, çakışmada ek) | `public.kayit_kodu_uret(text, date)` + `tenant_kayit_kodu_ata()` tetikleyicisi (P148.1, göç 0037/0040) | **Sıfırdan yazma.** Yalnız kenar durumlarını (Türkçe `i/I`, <4 harf, noktalama, rakamla başlama, çakışma biçimi) ölç ve eksikse tamamla |
| **Aşama 3** — tesis kodu ile sakin kaydı | `routers/kayit_basvurulari.py` + göç 0036/0038 (sakin kendi kaydolur, yönetici onayı) | Rol seçimli akışı **üstüne** kur |
| **Aşama 3** — telefonla giriş | `POST /auth/login-phone` (`phone` + `password`) | Yeniden yazma |
| **Aşama 3** — geçici kod | `telefon_kodu.py`, `odeme_kodu.py`, göç 0039 (kod amacı); kaba kuvvet sayacı P148'de düzeltildi | Yeniden yazma; **e-posta ile gönderim** eksik → Aşama 9 altyapısına bağla |
| **Aşama 5** — Excel toplu yükleme | `POST /site-aktar` + `GET /site-aktar/sablon`, `/yonetisim` sayfasında **çalışıyor** | Aşama 8 framework'ünü bunun **üstüne** kur; ikinci yükleyici yazma |
| **Aşama 6.2** — liste deseni | `components/tablo.tsx` + `/tanimlar`daki **veri-sürücülü `Defter` deseni** (8 kayıt defteri tek bileşenle) | `Defter`i genelleştir: sıralama, filtre, toplu seçim, **sayfa başına kayıt** ekle |
| **Aşama 6.4** — ek/attachment | `routers/uploads.py` + MinIO presign + `complaint_photo` | Genel `ek` tablosuna genişlet; her modüle ayrı yükleyici yazma |
| **Aşama 7.1** — kategorize, katlanabilir menü | `lib/menu.ts` — 6 grup, `KATLI_GRUPLAR`, rol süzgeci | **Yeniden yazma.** Yeni öğeleri diziye ekle; FİNANS/İLETİŞİM/İCRA/TANIMLAR gruplarını mevcut `GrupId` kümesine yerleştir |
| **Aşama 9** — SMS sağlayıcı | **Netgsm bağlı** (`config.py:165-172`, P150). Yapılandırma yoksa sağlayıcı `LOG` | Yeniden yazma |
| **Aşama 9** — şablon + gönderim + geçmiş + önizleme | `mesaj_sablonu`, `mesaj_gonderim` tabloları; `POST /mesajlar/gonder`, `/onizleme`, `GET /gecmis` | **Gönderim ekranı** yaz (uç var, yüzey yok); kanal eklentisi ve kota ekle |
| **Aşama 9** — push | `routers/notifications.py`, `push.py`, `user_device`, FCM | Ortak gönderim arayüzüne **kanal olarak** bağla |
| **Aşama 11** — denetim kaydı | `audit_log` + göç 0002 (**append-only**, `setup_app_role` REVOKE) | Yeniden yazma; finansal işlemleri bu tabloya bağla |
| **Aşama 11** — yetki matrisi | `GET /yetki-matrisi` + `/yetki` sayfası (salt okuma) | Yeniden yazma; **API seviyesinde zorlama zaten var** (`require_role`) |

---

## AŞAMA 7.2 — ÖLÇÜLEN KUSURLAR (uygulama Aşama 7'de)

Brief'teki UI temizlik maddelerinin **kök nedenleri** ölçüldü:

### "Olaylar yetki hatası veriyor" — KÖK NEDEN BULUNDU

| Katman | Bulgu |
|---|---|
| Web rota rolü | `ROTA_ROLLERI["/olaylar"] = ["admin", "yonetici"]` → sayfa yöneticiye **görünüyor** |
| Okuma ucu | `violations.py:43` — `_READER = require_role("admin","yonetici","security")` → yönetici **okuyabiliyor** |
| Yazma ucu | `violations.py:42` — `_WRITER = require_role("admin","security")` → yönetici **yazamıyor** |
| Sayfanın yaptığı | `olaylar/page.tsx:87` — "Olay bildir" düğmesi `POST /api/violations` |

**Yani:** yönetici sayfayı açıyor, listeyi görüyor, düğmeye basıyor ve
**403** alıyor. Rapor edilen hata tam olarak budur, tahmin değil.

`security` rolü bu ucu **gerçekten kullanıyor** (mobil olay bildirimi).
Brief'in kuralı — *"başka roller kullanabiliyorsa yalnız yöneticiden
kaldır"* — geçerli. **Karar:** `/olaylar` rota rolünden `yonetici`
çıkarılacak, `admin` kalacak.

### "Site sayfası kaldırılacak"

`/portal` sayfası + `routers/portal.py` + `tenant_portal`, `portal_galeri`
tabloları + `/site/[slug]` genel sayfası + `portal-galeri`,
`portal-iletisim` BFF kaynakları. **Anket bu modülün İÇİNDE**
(`/anketler` uçları `routers/portal.py` altında) ve anket uçtan uca
çalışıyor, mobil karşılığı da var.

**Uyarı:** "Site sayfası"nı ölü koda bırakmadan silmek **anketi de
götürür**. Aşama 7.2'de anket önce `portal.py`'den ayrılacak, sonra portal
kaldırılacak. Aksi hâlde çalışan bir özellik sessizce kaybolur.

### Diğer ölçülmüş boşluklar (Aşama 5)

| İstenen | Bugün |
|---|---|
| Web'de **toplu daire oluşturma** | **Yok.** Mobilde **var** (`binaTopluDaireEkle`, önizlemeli: `binaTopluOnizleme`) → mobil deseni web'e taşı |
| **Başlangıç katı** seçimi (-2, -1, 0, zemin, 1…) | Kat alanı serbest sayı; başlangıç katı seçici yok |
| **Kat silme** | Yok (yalnız daire silme, blok silme) |
| Katlarda **sürükle-bırak** sıralama | Yok (`sira` alanı **var**, elle yazılıyor) |
| Web'de **daire tipi değiştirme** | **Yok** — `building-editor` `unit_tip_ad`'ı yalnız **gösteriyor** (renk + kısaltma), atama arayüzü yok. Mobilde `features/unit_tanimlari` var |
| Virgülle **toplu daire seçme** (`3,5,7-12`) | Yok |
| **Blok toplu silme** | Yok (tekli silme + cascade onayı var) |

---

## KAPSAM DIŞI / SONRAKİ TUR

Ölçüm sırasında görülen, brief'in hiçbir aşamasına düşmeyen işler:

1. **`depo-alan-adi` kapısının 5 bulgusu** (yukarıda) — canlı Caddy
   yapılandırması gerektirdiği için bu turda kapalı.
2. **Kullanılmayan altı BFF yazma ucu** — ekranları yazılana kadar
   beyaz listeden çıkarılmaları güvenlik açısından daha doğru olurdu;
   ama Aşama 10 onları kullanacağı için **bırakıldı** ve burada kayda
   geçti.
3. **`kartGeriBildirim` ARB artığı** — P147'de karo kaldırıldı, çeviri
   anahtarı 7 dilde duruyor. Aşama 7.2'de temizlenecek.
4. **`+905777777777` denetçi hesabının depoda olmaması** — bkz.
   `docs/test-sunucusu-kurulum.md` §6.5.
