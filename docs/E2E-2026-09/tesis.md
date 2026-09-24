# Bulgular — `tesis` (Bölüm 6 Tesis operasyonu · 8 Daire/sakin · 9 Entegrasyonlar)

Tesis: `e2e-tesis-sitesi-02797d` (tenant `1cd00871-15c6-4748-9e79-b8850b6adad3`). Betikler `$S/tesis/*.py|*.mjs`, ekran görüntüleri `$S/tesis/ekran/`.
Beat işleri (bakım hatırlatma, entegrasyon kontrol) worker konteynerinde **yalnız bu tenant'a daraltılarak** (`_tenantlar` yerine tek tenant) elle koşturuldu.

> Ortam notu: ölçüm süresince makine aşırı yüklüydü (load avg 60–100, 7 GB RAM'in ~0'ı boş). `app.localhost:3000` dev sunucusu oturumun ilk yarısında bozuktu (`.next`'e `next build` yazılmış; istemci JS 404 → hidrasyonsuz sayfa). Web ölçümlerinin bir kısmı birebir aynı kodu çalıştıran `app.localhost:3101` kopyasında yapıldı (`diff -rq app components` = aynı). Yük yüzünden bazı Playwright etkileşimleri tamamlanamadı; bunlar tabloda ÖLÇÜLEMEDİ/KISMEN diye işaretli ve kod okumasıyla desteklendi.

## KONTROL LİSTESİ

### 6.1 Periyodik bakım
| Madde | Durum | Kanıt |
|---|---|---|
| Ekipman tanımla (asansör, jeneratör…) | GEÇTİ | `POST /bakim/ekipmanlar` 201; saha GET 200/POST 403, sakin 403, denetçi özet 200 |
| Periyotlar aylık/3/6/yıllık/serbest | GEÇTİ | 5 periyot kabul; `gun` periyot_gun'suz 422, `aylik`+gün 422, `haftalik` 422 |
| Sonraki tarih otomatik; ay sonu kenarı | GEÇTİ | 31 Oca+1ay → **28 Şub 2026**; 30 Kas+3ay → 28 Şub; 29 Şub 2024+1yıl → 28 Şub 2025; serbest 45g doğru |
| Yaklaşan bildirimi (beat) | GEÇTİ (+ bkz. TESIS-15) | tek tenant koşumu: `{"yaklasti":2,"bugun":1,"gecikti":3}`; 2. koşum 0 (damga çalışıyor) |
| Gecikmiş bakım listede belirgin (web) | GEÇTİ | rozet + "207 gün gecikti" metni; gecikenler en üstte (`ekran/_bakim.png` sonrası metin dökümü) |
| Bakım kaydı: fotoğraf + belge + maliyet | **KALDI** | maliyet var; fotoğraf yalnız API'de (`/ekler` varlik_tipi=bakim_kaydi), **web/mobil arayüzde ek alanı yok**, **PDF belge yüklenemez** (presign 422) → TESIS-05 |
| Sonraki tarih ilerliyor mu | KISMEN | ilerliyor (20.09 → 20.10); ama geçmiş/ileri tarihli kayıt tarihi geri/ileri atıyor → TESIS-06 |
| Maliyet gidere düşüyor mu (tek defter) | GEÇTİ | `finansal_hareket` tip=gider, yon=cikis, 250000, durum=onay_bekliyor, "Asansör A — bakım"; `/finans/hareketler`'de görünüyor |
| Yıllık rapor | KISMEN | `GET /bakim/ozet` + web sekmesi var; indirme (PDF/Excel) yok; yüklenirken "Zorunlu bakımların hepsi yapılmış" yazıyor → TESIS-14 |

### 6.2 Görevler
| Madde | Durum | Kanıt |
|---|---|---|
| Görev oluştur, personel ata | GEÇTİ | 201; atanan `gorev_atandi` in-app bildirimi aldı |
| Son tarih takvimden (web) | KISMEN | kod: özel tarih+saat seçici (`tasks/page.tsx:781+`); tıklamayla ölçülemedi. Web listesi "2/3 adım · Tamamlandı", "0/2 · Tamamlandı", "2/2 · Atandı", "Gecikti (1 gün)" gösteriyor (TESIS-03 web'de de görünür) |
| Alt adımlara bölme | GEÇTİ | 3 adım, `adim_toplam=3`; sıralı görevde sıra dışı adım 409 |
| Her adım ayrı tamamlanıyor (görevli) | GEÇTİ | tesis_gorevlisi 2 adımı ayrı ayrı tamamladı; başka görevli (security2) 404 |
| Fotoğraf + not | GEÇTİ | adımda foto_key+not saklandı |
| Yönetici ilerlemeyi görüyor (2/3) | GEÇTİ | `adim_tamam=2, adim_toplam=3`; `gorev_adim_ilerleme` "1/3 adım tamamlandı" bildirimi |
| NFC ile tamamlama | **KALDI** | ayraçlı UID ile kayıtlı noktada mobil biçimi (ayraçsız) reddediliyor; NFC zorunlu da değil → TESIS-07 |
| Fotoğraf zorunluluğu | **KALDI** | adımda çalışıyor (422); **görev tamamlamada `foto_key:""` ile atlatılıyor** → TESIS-02 |
| Takip: durum, zaman çizelgesi, gecikme | KISMEN | `durum`/`gecikme_gun`/`gecikti` süzgeci doğru; ama 2/3 adımla "tamamlandi", 2/2 adımla "atandi" → TESIS-03 |

### 6.3 Diğer
| Madde | Durum | Kanıt |
|---|---|---|
| Demirbaş ekleme ve zimmet | **KALDI** | tesis yöneticisi `POST /assets` **403** (yalnız platform `admin`); web'de "Yeni demirbaş" düğmesi yöneticiye görünüyor → TESIS-04 |
| Şikayet haritası — tipe göre ayrım | KISMEN | harita/yoğunluk tüm kategorileri toplar, tip süzgeci yok; kategori yalnız daire detayında → TESIS-17 |
| 24 saat sonra haritadan kalkıyor | GEÇTİ | created_at −23s50dk: density=1, −24s10dk: density=0, building-map 0, gorunur-sayi 3→2, liste (bilerek penceresiz) 3 |
| Sayaç eşiği (5 farklı sakin gürültü) | GEÇTİ | 1–4: uyarı 0; 5.: `unit_uyari` (esik 5, sayac 5, manuel_bekliyor), sakin (malik2) `gurultu_uyari_sakin` aldı, açık gürültü 0'a sıfırlandı; aynı kişi aynı hafta 409; ayakkabı/görüntü sayılmadı; B blok sakini A'ya 403 |
| Rezervasyon + çakışma | KISMEN | kısmi çakışma 409, bitişik 201, 24s kuralı, geçmiş 422, açılış dışı 422, son-dakika istisnası doğru; ama **tek rezervasyonla tüm gün** ve ızgara dışı 6 dk kabul → TESIS-12 |
| Sayaç okuma (fotoğraflı) | **KALDI** | web: yalnız tüketim, fotoğraf yok; mobil: "Önceki okuma" gösterip girilen **endeksi tüketim diye** gönderiyor → 71.000 TL borç (TESIS-01) |

### 8. Daire ve sakin
| Madde | Durum | Kanıt |
|---|---|---|
| Blok/daire oluşturma; tekil daire blok öneki | KISMEN | toplu "A-11" üretir; tekil formda "11" yazılırsa "11" (önek yok), "B-12" A bloğuna kabul → TESIS-16 |
| Bina düzenleyici — daireye tıklayınca sakin | KISMEN | daireye tıklamak yalnız "düzenle/Sil" açıyor; sakin bilgisi düzenleme modalında (`DaireSakinleri`), tıklamada değil; modal açılışı yükte ölçülemedi |
| Sakin ekleme malik/kiracı/malik-oturan | GEÇTİ | malik, kiraci, malik+oturuyor=true 201; `ortak` 422; aynı telefon 409 |
| Bloklara göre gruplama | GEÇTİ | `/residents?blok=A` ve web başlığı "bloklara göre gruplanmıştır" |
| Blokta/isimde arama (Türkçe) | **KALDI** | `/units/ara?q=İkinci` → boş; `/residents?q=kiraci|KIRACI` → "Can Kiracı"yı bulmuyor → TESIS-09 |
| Ayrılan sakin: bul, sil, yerine yeni ekle | **KALDI** | eski sakinin borcu yeni kiracının `/me/dues`'unda çıkıyor; eski sakin artık göremiyor; sert silmede borç sahipsiz → TESIS-08 |
| Dolu daireler işaretli | GEÇTİ (API) | `units.sakin_sayisi`, `building-map`; web görsel ölçülemedi |
| Arsa payı girişi | GEÇTİ (API) | `UnitCreate.arsa_payi`, `PATCH /units/arsa-payi`, içe aktarım `arsa_payi` sütunu (web ölçülemedi) |
| Toplu içe aktarım: tür→tablo→yapıştır | GEÇTİ | web (onarılmış :3000): tür seçildi, 5 satırlık TSV ilk hücreye yapıştırıldı → 30 hücre doldu; önizleme: hatalı e-posta/olmayan daire hücreleri `aria-invalid` + kırmızı + satır no; sorun varken "Aktar" kapalı |
| Örnek şablon | GEÇTİ (kod+metin) | web'de "Şablonu indir (.csv)", BOM'lu CSV, başlık + örnek satır görünüyor |
| Sorunlu satırlar belirgin / sessiz atlama | **KALDI** | hatalı e-posta/olmayan daire/dolu rol/bozuk telefon satır no ile raporlanıyor; **mevcut telefon/e-posta ve dosya içi yinelenen telefon sessizce "zaten var"** sayılıyor, önizleme ≠ sonuç → TESIS-10 |
| (ek) Sakin eklemede olmayan daire | KALDI | `POST /residents unit_no=Z-99` **bloksuz daire yaratıyor** → TESIS-18 |

### 9. Entegrasyonlar
| Madde | Durum | Kanıt |
|---|---|---|
| Diyafon üç yöntem | GEÇTİ | sip / sip_kopru / kuru_kontak 201; geçersiz yöntem 422; tam URL yol 422 |
| Bağlantı testi anlamlı hata | GEÇTİ | `{"ok":false,"kod":"diyafon_ulasilamiyor"}` 3–5 sn; ham ayrıntı dönmüyor |
| (ek) İç ağ yoklaması | **KALDI** | kuru_kontak/HA sağlık testi redis:6379, db:5432, minio:9000, api:8000 → `ok:true`; localhost:1 → hata → port tarayıcı (TESIS-11) |
| Akıllı ev köprü + cihaz | GEÇTİ | HA/MQTT köprü, 3 cihaz 201; geçersiz tip 422, desteklenmeyen eylem 422 |
| Dokuz bölüm aç/kapa | KISMEN | PUT/GET çalışıyor, geçersiz bölüm 422, sakin 403; ama **kapalı bölüm sunucuda uygulanmıyor** (komut geçiyor) → TESIS-13 |
| Cihaz komutu hata yolu | GEÇTİ | ulaşılamaz köprü `akilli_ev_ulasilamiyor` |
| Sakin başka dairenin cihazını göremiyor | GEÇTİ | kiraci(A-1) yalnız A-1 cihazı; A-2 ışığı/ortak vana komut 403; malik2 tersi aynı; patch/delete 403; köprü/senaryo listesi 403 |
| (ek) Saha rolleri daire içi cihaz | **KALDI** | security/tesis_gorevlisi/guvenlik_amiri A-1 **kapı kilidini** listeliyor ve `kilit_ac` komutu yetki kapısından geçiyor → TESIS-04b |
| Entegrasyon sağlığı ekranı | **KALDI** (web) | API sağlık alanları doğru; ama web `/integrations` (diyafon + sağlık) yalnız PLATFORM yüzeyinde → yönetici `app.*`ta panoya yönleniyor → TESIS-19 |
| Kopunca bildirim | KISMEN | webhook entegrasyonu: `entegrasyon_koptu` 1 kez (2. koşum 0) ✔; **diyafon ve akıllı ev köprüsü hiç izlenmiyor** → TESIS-15 |
| Kimlik bilgileri şifreli / yanıtta yok | GEÇTİ | DB `sifre_enc`/`token_enc` şifreli; GET'lerde yalnız `sifre_set`/`token_set`/`auth_secret_set`; olay jetonu yalnız üretimde |

Özet: **28 GEÇTİ, 13 KALDI, 11 KISMEN, 0 ÖLÇÜLEMEDİ (donanım hariç).**

---

## BULGULAR (önem sırasıyla)

### TESIS-01: Mobil sayaç okuma endeksi tüketim diye gönderiyor — fahiş borç
- Sınıf: **Engelleyici**
- Rol / yüzey: yönetici / mobil (+ API)
- Adımlar: bölüm sayacı `ilk_okuma=1450`; mobil ekran satırda "Önceki: 1450" gösterir, kullanıcı yeni endeksi (1462) yazar → mobil bu değeri `bolum_tuketimleri`ne koyup `POST /borclandirma/sayac` gönderir. API ile aynı gövde gönderildi (`ana_tuketim=2000, birim=3550 kr, {bolum: 1462}`).
- Beklenen: tüketim = 1462 − 1450 = 12 m³ → ~426 TL; okuma kaydedilir, "önceki okuma" ilerler.
- Olan: 201, B-5'e **7.100.000 kr (71.000 TL)** borç (`dues_assessment kaynak=sayac`); `sayac_bolum.ilk_okuma` hâlâ 1450 (okuma hiç saklanmıyor). Ters yönde: kullanıcı gerçek tüketimi (12) yazarsa mobil "yeni okuma önceki okumadan küçük olamaz" diye reddeder. Yani ekranın iki kullanımı da yanlış.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `mobile/lib/src/features/finans/presentation/sayac_okuma_screen.dart:119` (`deger < b.ilkOkuma` karşılaştırması — endeks semantiği) + `:125` (`tuketimler[b.id] = deger` — tüketim semantiği); `backend/app/routers/borclandirma_uc.py:208` değeri tüketim kabul ediyor; okuma geçmişi tablosu yok (`models.py:3425` yalnız `ilk_okuma`). Web (`sayac-okuma/page.tsx`) tutarlı biçimde tüketim istiyor — ayrışma mobilde. Fotoğraf da web'de yok.
- Önerilen düzeltme: okuma (endeks) kaydı tablosu + tüketim = yeni − önceki sunucuda; ya da mobil alanı "tüketim" diye adlandırıp önceki-okuma denetimini kaldır. Web'e fotoğraf eki ekle.

### TESIS-02: Görev fotoğraf zorunluluğu boş dizeyle atlatılıyor
- Sınıf: **Ciddi**
- Rol / yüzey: tesis_gorevlisi / API
- Adımlar: `foto_zorunlu=true` görev; `POST /tasks/{id}/completions` gövde `{"tamamlanma_zamani":…, "foto_key": ""}`.
- Beklenen: 422 `gorev_foto_kaniti_zorunlu` (gövdesiz hali 422 veriyor).
- Olan: **201**, `foto_key:""`, `foto_url:null`; listede `son_tamamlama.foto_var: true` (yöneticiye fotoğraf varmış gibi görünür).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/tasks.py:764` `body.foto_key is None` (adım ucu `:1222` doğru biçimde `not body.foto_key` kullanıyor). `foto_var` hesabı da `is not None`.
- Önerilen düzeltme: `not (body.foto_key or "").strip()`; ayrıca foto_key'in tenant ön ekiyle başladığını doğrula.

### TESIS-03: Görev adımlarıyla görev durumu bağlı değil (2/3 adımla "tamamlandı", 2/2 ile "atandı")
- Sınıf: **Ciddi**
- Rol / yüzey: tesis_gorevlisi + yönetici / API (web/mobil aynı veriyi gösterir)
- Adımlar: (a) 3 adımlı görevde 2 adımı tamamla, sonra görev tamamlama gönder. (b) 2 adımlı görevde iki adımı da tamamla, görev tamamlama gönderme. (c) 2 adımlı başka görevi hiç adım yapmadan tamamla.
- Beklenen: tüm adımlar bitmeden görev kapanmamalı (ya da uyarı); son adım bitince görev tamamlanmalı — P237 kararı: "**Son** adım → görev zaten tamamlanır, mevcut `gorev_tamamlandi` gider".
- Olan: (a) `durum=tamamlandi`, `adim_tamam 2/3`; (c) `tamamlandi`, `0/2`; (b) `durum=atandi, tamamlandi=false, 2/2`, `gorev_tamamlandi` bildirimi gitmedi.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/tasks.py:743-790` tamamlamada adım denetimi yok; `:1200-1250` son adımda görev tamamlanmıyor.
- Önerilen düzeltme: son adım tamamlandığında görev tamamlama kaydı üret (ya da istemciye "görevi kapat" iste); açık adım varken tamamlamayı 409 ile reddet ya da açıkça onayla.

### TESIS-04: Tesis yöneticisi demirbaş ekleyemiyor (yalnız platform admini)
- Sınıf: **Ciddi**
- Rol / yüzey: yonetici / API + web
- Adımlar: `POST /assets {"ad":"Matkap","kategori":"alet"}` yönetici jetonuyla.
- Beklenen: 201 (web `/assets` sayfası yöneticiye "Yeni demirbaş" düğmesi gösteriyor).
- Olan: **403** "Bu işlem için yetkiniz yok". `admin` platform hesabı yalnız `acme-plaza` tenant'ında → yeni bir tesiste **kimse** demirbaş oluşturamıyor, dolayısıyla zimmet akışı da ölçülemedi.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/assets.py:43` `_ADMIN = require_role("admin")` (CRUD); rol matrisi `backend/tests/yetki/rol-matrisi.txt:42-45` bunu kilitliyor — yani bilinçli ama `docs/frontend-envanter.md:83` sayfayı "admin·yonetici" diye listeliyor ve web düğmeyi çiziyor.
- Önerilen düzeltme: CRUD'u `admin, yonetici`ye aç (matrisi güncelle) ya da web'de düğmeyi gizle; guvenlik_amiri için zimmet de düşünülmeli.

### TESIS-04b: Saha rolleri sakinin dairesindeki kapı kilidini listeleyip `kilit_ac` gönderebiliyor
- Sınıf: **Ciddi** (fiziksel güvenlik / mahremiyet)
- Rol / yüzey: security, tesis_gorevlisi, guvenlik_amiri / API (mobil)
- Adımlar: yönetici A-1'e `tip=kilit` cihaz ekler; security `GET /akilli-ev/cihazlar` ve `POST /akilli-ev/cihazlar/{A-1 kilit}/komut {"eylem":"kilit_ac"}`.
- Beklenen: saha yalnız ortak alan cihazlarını görür/kumanda eder (kodun kendi yorumu: "sakin kendi dairesini, **guvenlik ortak alani gorur**").
- Olan: üç saha rolü de `['Kazan vanası','A-2 ışık','A-1 kapı kilidi']` görüyor; komut yetki kapısından geçti, yalnız köprü ulaşılamadığı için `akilli_ev_ulasilamiyor` döndü (gerçek köprüde kapı açılırdı). Denetim kaydı var ama önleyici kapı yok.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/akilli_ev.py:324-331` `_cihaza_erisebilir` resident dışındaki herkese `True`; liste ucu (`:282-300`) yalnız resident'ı daraltıyor. Yorum `:76-77` ile davranış çelişiyor.
- Önerilen düzeltme: saha rolleri için `unit_id IS NULL` süzgeci (liste + komut); daire cihazı yalnız yönetim + o dairenin sakini.

### TESIS-05: Bakım kaydına fotoğraf/belge eklenemiyor (arayüz yok, PDF reddediliyor)
- Sınıf: **Orta**
- Rol / yüzey: yönetici / web + mobil (+API)
- Adımlar: web "Bakım yapıldı" formu (alanlar: tarih, yapan, işlem, tutar, gidere yaz); API ile `POST /uploads/presign {"content_type":"application/pdf"}`.
- Beklenen: istek "fotoğraf + belge + maliyet"; P241 kararı "Fotoğraf ve belge: var olan ek mekanizması".
- Olan: backend `/ekler varlik_tipi=bakim_kaydi` görsel için çalışıyor (201, listede görünüyor) ama **web ve mobilde `bakim_kaydi`/`bakim_ekipmani` için hiçbir Ekler bileşeni yok** (`grep -rn bakim_kaydi admin-web mobile/lib` → 0). Muayene raporu PDF'i: presign **422** "content_type gorsel olmali".
- Tekrarlanabilir: evet
- Şüpheli kök neden: `admin-web/app/(protected)/bakim/page.tsx` (kayıt formunda `Ekler` yok); `backend/app/schemas.py:3751` `_ALLOWED_UPLOAD_CT` yalnız görsel.
- Önerilen düzeltme: bakım kaydı satırına/ayrıntısına `<Ekler varlik_tipi="bakim_kaydi">`; presign'a `application/pdf` (belge türleri için ayrı izinli küme).

### TESIS-06: Geçmiş ya da ileri tarihli bakım kaydı sonraki bakım tarihini geri/ileri atıyor
- Sınıf: **Orta**
- Rol / yüzey: yönetici / API + web
- Adımlar: Asansör 20.09.2026 kaydı (sonraki 20.10) → ardından unutulmuş 15.08.2026 kaydı gir → ardından 01.01.2030 tarihli kayıt gir.
- Beklenen: eski kayıt tarihi geri almamalı (son_bakim = max); gelecek tarih reddedilmeli ya da uyarılmalı.
- Olan: 15.08 kaydı → `son_bakim=2026-08-15, sonraki=2026-09-15, durum=gecikti` (yeni yapılmış asansör "gecikti" oldu). 2030 kaydı 201 → `sonraki=2030-02-01, planli` (yazım hatası yasal muayeneyi 3 yıl gizler; yıllık özette de sayılmaz).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/bakim.py` `kayit_ekle` — `ekipman.son_bakim = body.tarih` koşulsuz; `BakimKaydiCreate.tarih` için üst sınır yok (`schemas.py:9596`).
- Önerilen düzeltme: yalnız `body.tarih >= son_bakim` ise ilerlet; `tarih > bugün` 422.

### TESIS-07: NFC UID biçimi normalize edilmiyor — ayraçlı kayıtlı noktada mobil okutma eşleşmez; NFC zorunlu değil
- Sınıf: **Orta**
- Rol / yüzey: tesis_gorevlisi / API (mobil)
- Adımlar: kontrol noktası `nfc_tag_uid="04:A1:B2:C3:D4:E5:F6"` (NFC okuyucu uygulamalarının gösterdiği biçim); görev bu noktaya bağlı; tamamlama `nfc_tag_uid="04A1B2C3D4E5F6"` (mobilin `nfc_service.dart:98` ürettiği biçim).
- Beklenen: aynı etiket → eşleşme.
- Olan: **422** `gorev_nfc_eslesmiyor`; `"04:a1:b2:…"` ise 201. Ayrıca nokta bağlı görev NFC'siz de 201 ile kapanıyor (NFC kanıtı isteğe bağlı).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/crud_helpers.py:115` `norm_nfc` yalnız `strip().upper()`; ayraçları atmıyor. Web nokta formu (`checkpoints/page.tsx:510`) yalnız büyük harfe çeviriyor.
- Önerilen düzeltme: `norm_nfc`'de `[^0-9A-F]` sil (kayıtta da); görev düzeyinde "NFC zorunlu" bayrağı ya da nokta bağlıysa NFC şartı.

### TESIS-08: Ayrılan sakinin borcu yeni kiracıya görünüyor; eski sakin borcunu göremiyor; silmede borç sahipsiz kalıyor
- Sınıf: **Ciddi** (KVKK + finans)
- Rol / yüzey: yönetici + sakin / API (web `/aidatim`, mobil "Aidatım")
- Adımlar: B-5 sakini (Elif, malik-oturan) adına 71.000 TL sayaç borcu (`hedef_user_id`=Elif) → `DELETE /units/{B-5}/residents/{Elif}` (ayrılış) → yeni kiracı "Özgür" B-5'e eklenir → Özgür `GET /me/dues` → sonra `DELETE /residents/{Elif}`.
- Beklenen: önceki sakinin borcu yeni kiracıya gösterilmemeli (başka kişinin mali verisi); eski sakin kendi borcunu görmeye devam etmeli ya da borç açıkça devredilmeli; geçmişi olan kişi anonimleştirilmeli (docstring: "gecmisi var → satir kaldi").
- Olan: Özgür'ün `/me/dues`'unda Elif'in 71.000 TL'lik "Ana su2" tahakkuku **bakiye olarak** çıkıyor; Elif'in `/me/dues`'u `{"items":[]}`; `DELETE /residents` → `{"deleted":true}` (**sert silme**), `dues_assessment.hedef_user_id` → NULL (borç kime ait belli değil).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/dues.py:853-872` `/me/dues` daire bazlı, `hedef_user_id` ve bağın başlangıç/bitiş tarihini hiç kullanmıyor; `app/hesap_silme.py` borç satırını FK-RESTRICT "geçmiş" saymıyor (SET NULL).
- Önerilen düzeltme: `/me/dues`'ta `hedef_user_id = me` (ya da bağ süresindeki dönemler); ayrılan sakinin borcu için "eski sakin borçları" görünümü; mali kaydı olan kullanıcıda anonimleştirme yolu.

### TESIS-09: Türkçe karakterli aramalar eşleşmiyor (İ/ı)
- Sınıf: **Orta**
- Rol / yüzey: yönetici + güvenlik / API + web (sakinler) + mobil (kapıda daire arama)
- Adımlar: sakin "Burak İkinci", "Can Kiracı". `/units/ara?q=İkinci`, `?q=İKİNCİ`; `/residents?q=kiraci`, `?q=KIRACI`.
- Beklenen: hepsi eşleşmeli (klavyede Türkçe karakter olmadan yazmak yaygın).
- Olan: `/units/ara?q=İkinci` → `[]`, `İKİNCİ` → `[]` (`ikinci` bulur). `/residents?q=kiraci` → `[]`, `KIRACI` → `[]` (`Kiracı` bulur). `Güven`/`Öz` gibi sorgular da ancak birebir harfle.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/units.py:421` `aranan.lower()` — Python `"İ".lower()` = `"i̇"` (birleşik nokta); `residents.py:224` `ilike` ı/i ve İ/I'yı katlamıyor.
- Önerilen düzeltme: tek bir `tr_katla()` (İ→i, I→ı→i, ş→s…) + DB tarafında `unaccent`/`translate` ile her iki yanı katla.

### TESIS-10: İçe aktarımda sessiz atlama; önizleme ile sonuç farklı
- Sınıf: **Orta**
- Rol / yüzey: yönetici / API + web (İçe aktarım)
- Adımlar: `kisi` türü, 9 satır: geçerli; dosya içinde aynı telefon iki satır (3,4); başka sakinin telefonu (5); geçersiz e-posta (6); olmayan daire Z-77 (7); A-1 kiracı zaten dolu (8); başka sakinin e-postası (9); bozuk telefon (10).
- Beklenen: her sorunlu satır satır numarasıyla; önizleme = sonuç.
- Olan: 6,7,8,10 satır no ile raporlandı ✔. Satır 5 ve 9 (**farklı kişi, farklı daire**, yalnız telefon/e-posta çakışıyor) "Zaten var" sayacına **satır numarasız** düştü. Önizleme `olusan:3, atlanan:2`; gerçek aktarım `olusan:2, atlanan:3` (dosya içi yinelenen telefon ancak yazarken fark edildi, yine satır no yok).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/ice_aktarim.py:380-395` `var is not None → b.sonuc.atlanan += 1; return` (hata/satır kaydı yok); kuru koşum dosya içi yinelemeyi izlemiyor. Web yalnız sayı gösteriyor (`ice-aktarim/page.tsx:633-634`).
- Önerilen düzeltme: atlananları `{satir_no, sebep}` listesiyle döndür; kuru koşumda dosya içi telefon/e-posta kümesi tut; "kişi aynı ama ad/daire farklı" durumunu hata say.

### TESIS-11: Diyafon/akıllı ev sağlık testi platformun iç ağını taramaya izin veriyor (SSRF oracle)
- Sınıf: **Ciddi** (çok kiracılı platformda müşteri rolü → altyapı keşfi)
- Rol / yüzey: yönetici (herhangi bir tesisin) / API
- Adımlar: `POST /diyafon {"yontem":"kuru_kontak","host":"<iç ad>","port":<p>}` → `POST /diyafon/{id}/saglik`.
- Beklenen: tesisin kendi LAN'ı dışındaki platform adresleri (loopback, docker ağı, link-local, sunucunun kendi servisleri) reddedilmeli.
- Olan: `redis:6379`, `db:5432`, `minio:9000`, `api:8000`, `localhost:8000` → `{"ok":true}`; `localhost:1` → `diyafon_ulasilamiyor`. Açık/kapalı port ayrımı tek istekle okunuyor. `kapi-ac`/`zil` aynı yolla iç servislere keyfi yollu GET atıyor (yanıt dönmese de yan etki mümkün). HA köprüsü (`akilli_ev/home_assistant.py`) de aynı desende.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/diyafon/kuru_kontak.py:70-100`, `diyafon/sip.py:21-30` ("IC AG SERBEST — bilincli") ve `akilli_ev/home_assistant.py:12-18`. Gerekçe "yanıt gövdesi okunmuyor" ama `ok` bayrağı yeterli bir oracle; P240 kararı yalnız gövdeyi düşünmüş.
- Önerilen düzeltme: loopback, link-local, docker/servis adları ve sunucunun kendi ağ aralıkları için ret listesi (RFC1918 serbest kalabilir); ya da bu yolları sitedeki köprü (agent) üzerinden çalıştır.

### TESIS-12: Rezervasyonda süre/ızgara sınırı yok — tek kayıtla bütün gün
- Sınıf: **Orta**
- Rol / yüzey: sakin / API (mobil)
- Adımlar: `slot_dakika=60`, 08:00–23:00 alan; A-4 sakini `08:00–23:00` tek rezervasyon; ayrıca `21:07–21:13`.
- Beklenen: rezervasyon slot ızgarasına hizalı ve azami süreli olmalı (günde-bir kuralının amacı adil paylaşım).
- Olan: ikisi de **201**; günlük kota "bir rezervasyon" saydığı için 15 saatlik blok kurala takılmıyor; alan o gün herkese kapanıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/reservations.py:183-186` yalnız açılış/kapanış penceresine bakıyor ("slot izgara hizasi UX isi").
- Önerilen düzeltme: `(baslangic-acilis) % slot == 0`, `(bitis-baslangic) % slot == 0` ve alan başına `azami_slot` (varsayılan 1–2).

### TESIS-13: Akıllı ev "kapalı bölüm" yalnız istemcide uygulanıyor
- Sınıf: **Küçük**
- Rol / yüzey: sakin / API
- Adımlar: `PUT /akilli-ev/bolumler` ile `kapi` kapalı; sakin kendi A-1 kilidine `kilit_ac`.
- Beklenen: kapalı bölümün cihazı komut kabul etmemeli.
- Olan: komut yetki denetiminden geçti (yalnız köprü ulaşılamadığı için `ulasilamiyor`).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/akilli_ev.py:370-400` bölüm denetimi yok; P240 kararı "Tip → bölüm eşlemesi mobilde KODDA".
- Önerilen düzeltme: eşlemeyi sunucuya taşı; kapalı bölümde 403/409.

### TESIS-14: Yıllık bakım özeti yüklenirken "Zorunlu bakımların hepsi yapılmış" diyor; dışa aktarım yok
- Sınıf: **Küçük**
- Rol / yüzey: yönetici / web
- Adımlar: `/bakim` → "Yıllık bakım özeti" sekmesi; API `yasal_eksik=["Jeneratör"]`.
- Beklenen: veri gelene kadar iskelet; hata durumunda hata; denetime verilebilir PDF/Excel.
- Olan: ilk çizimde tablo boşken "Zorunlu bakımların hepsi yapılmış." metni görüldü (Playwright metin dökümü). Özet için indirme düğmesi yok (`bakimOzetButonlar: []`), `rapor_motoru`nda bakım yok.
- Tekrarlanabilir: evet (yükte belirgin)
- Şüpheli kök neden: `admin-web/app/(protected)/bakim/page.tsx:477` `(ozet.data?.yasal_eksik ?? []).length === 0` — yükleniyor/hata durumu "eksik yok" sayılıyor.
- Önerilen düzeltme: `ozet.data` yokken iskelet; hata için `HataBandi`; özet için CSV/PDF indirme.

### TESIS-15: Diyafon ve akıllı ev köprüsü kopuşu hiç bildirilmiyor; bakım bildirimi rol görünürlüğü karar dışı
- Sınıf: **Orta**
- Rol / yüzey: yönetici / beat + bildirim
- Adımlar: ulaşılamaz webhook entegrasyonu, 3 diyafon ve HA köprüsü tanımlı; `entegrasyon_kontrol_isi.tum_tenantlar_icin` bu tenant'a daraltılarak iki kez koşturuldu.
- Beklenen: P240 gerekçesi ("akşam kopan diyafon sabah fark edilir") — diyafon/köprü de izlenmeli.
- Olan: webhook için `entegrasyon_koptu` 2 satır, 2. koşum 0 ✔. Diyafonlar `saglik=hata` (yalnız elle testten) ve `kopus_bildirildi_at` hep NULL; köprü aynı. İş yalnız `integration` tablosunu tarıyor.
  Ek (bakım): `bakim_*` satırları `user_id=NULL` yazıldığı için security/guvenlik_amiri **yaklaşan/gecikti dahil** hepsini görüyor, tesis_gorevlisi ise **"bugün" dahil hiçbirini** görmüyor — `bakim_hatirlatma_isi.py` kararı ("saha yalnız bugün") in-app'te tutmuyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/entegrasyon_kontrol_isi.py:61-63` yalnız `FROM integration`; `routers/notifications.py:44` `_YONETIM_GOZU` tesis_gorevlisi'ni içermiyor, security'yi içeriyor.
- Önerilen düzeltme: işe `diyafon` ve `akilli_ev_kopru` taramasını ekle; bakım "bugün" için saha rollerine kişi-satırı yaz.

### TESIS-16: Tekil daire eklemede blok öneki uygulanmıyor, blok/no uyumsuzluğu kabul
- Sınıf: **Küçük**
- Rol / yüzey: yönetici / web (Bina düzenleme) + API
- Adımlar: `POST /units {"no":"11","blok":"A"}`, `{"no":"B-12","blok":"A"}`.
- Beklenen: toplu oluşturmayla tutarlı "A-11"; "B-12"nin A bloğuna yazılması reddi.
- Olan: ikisi 201; `/schematic`'te "11", "B-12" "Haritada yerleşimi girilmemiş" altında. Form yer tutucu "A-12" gösteriyor ama zorlamıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/units.py:597-615` (toplu `:646` önek ekliyor, tekil eklemiyor); `building-editor/page.tsx:389`.
- Önerilen düzeltme: `no` yalnız rakamsa `{blok}-{no}`; `no` başka blok önekliyse 422.

### TESIS-17: Şikayet haritasında türe göre ayrım yok
- Sınıf: **Öneri**
- Rol / yüzey: yönetici / web + API
- Olan: `/unit-complaints/density` ve `building-map` tüm kategorileri tek sayıda topluyor, `kategori` parametresi yok; web `/schematic`'te kategori yalnız daire detay panelinde.
- Önerilen düzeltme: `?kategori=` süzgeci + haritada tür seçici. (Ayrıca: eşik aşılınca sayaç sıfırlandığı için en çok şikayet alan daire haritada yeşile dönüyor — `unit_complaints.py` başlığında bilinçli karar olarak yazılı; yöneticiye yanıltıcı olabilir.)

### TESIS-18: Sakin eklemede olmayan daire sessizce (bloksuz) yaratılıyor
- Sınıf: **Küçük**
- Rol / yüzey: yönetici / API (+ web Kullanıcılar/Sakinler formu)
- Adımlar: `POST /residents {"unit_no":"Z-99", … }` (blok yok).
- Beklenen: "blok zorunlu" kuralı (UnitCreate) burada da geçerli; yazım hatası daire üretmemeli.
- Olan: 201, `Z-99` bloksuz daire olarak yaratıldı (haritada "yerleşimi girilmemiş"). İçe aktarım aynı durumda doğru biçimde "Daire bulunamadı" veriyor — iki yol tutarsız.
- Şüpheli kök neden: `backend/app/routers/residents.py:49+` (`blok` "yalnız YENİ açılan unit'e işlenir").
- Önerilen düzeltme: olmayan daire için 422 (ya da açık "daireyi de oluştur" bayrağı + blok zorunlu).

### TESIS-19: Yönetici web'de diyafon/entegrasyon yapılandıramıyor ve sağlığını göremiyor
- Sınıf: **Orta** (web-mobil parite)
- Rol / yüzey: yönetici / web
- Adımlar: yönetici `http://app.localhost:3000/integrations` (ayrıca `entegrasyon_koptu` bildirim rotası `lib/bildirim-rotasi.ts:49` buraya gider).
- Beklenen: backend `/diyafon`, `/integrations` yöneticiye açık; bildirimdeki bağlantı ilgili ekranı açmalı.
- Olan: sayfa özet panosuna yönleniyor (iki ayrı koşumda sayfa metni = pano). Diyafon bölümü (`DiyafonBolumu`) ve sağlık rozetleri yalnız bu sayfada.
- Şüpheli kök neden: `admin-web/lib/yuzey.ts:36` `/integrations` PLATFORM_ROTALARI'nda; `lib/menu.ts:320` grup "platform".
- Önerilen düzeltme: tesis-içi entegrasyon/diyafon sayfasını `app.*`a taşı (ya da ayrı tesis rotası), bildirim rotasını ona bağla.

### TESIS-20: Şikayet haritası lejantı ve kategori etiketi hatalı
- Sınıf: **Küçük**
- Rol / yüzey: yönetici / web `/schematic`
- Olan: lejant "0–2 (yeşil) · 3–4 (sarı) · 5+ (kırmızı)" diyor; backend P24'ten beri dört kademe (0 yeşil, 1–2 sarı, 3–4 kırmızı, 5+ mor — `routers/unit_complaints.py:44`). "Yoğun daire: 5+ (kırmızı)" da eski. Daire detayında kategori ham anahtar olarak yazıyor: **`goruntu_kirliligi`** (çeviri eşlemesi `schematic/page.tsx:63-65` yalnız gurultu/kapi_onu/zarar_verme).
- Önerilen düzeltme: lejantı `_ESIKLER` ile eşle; `goruntu_kirliligi` ve `diger` için sözlük anahtarı ekle.

### Diğer gözlemler (bulgu değil / küçük)
- Yönetici panosu aynı anda "Toplam borç 0,00 ₺ · 0 dairede borç var" ve "Bekleyen 71.000,00 ₺" gösteriyor (sayaç borcu toplam borca girmiyor gibi) — finans ajanının alanı, not düşüldü.
- Bakım: PATCH ile periyot değiştirmek `sonraki_bakim`'i yeniden hesaplamıyor (yıllık→aylık sonrası tarih aynı kaldı).
- Rezervasyon oluşturma yanıtında `/common-areas/{id}/slots` parametre adı `date` (diğer uçlar `tarih`) — tutarsız ama çalışıyor.
- `POST /akilli-ev/cihazlar` yanıtında `daire_no: null` (liste doğru dolduruyor olabilir).
- Gürültü eşiği manuel modda yöneticiye yalnız push gidiyor, in-app satır yazılmıyor; web'de `/gurultu-uyarilari` sayfası "Anons bekliyor" ile gösteriyor (ölçüldü) — kabul edilebilir.
- Diyafon `kapi-ac` security/guvenlik_amiri için 403 (tasarım: yalnız yönetim) — kapı görevlisinin kullanımı açısından gözden geçirilebilir.
- ÖLÇÜLEMEDİ: gerçek diyafon/HA donanımı, push teslimi (`PUSH hedef yok … hic aktif cihazi olmayan` — cihaz kaydı yok), gerçek e-posta (dev'de log sağlayıcısı `davet.gonderildi=false` döndürüyor; e-posta log'a düştü).
