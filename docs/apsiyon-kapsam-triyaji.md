# APSİYON KAPSAM TRİYAJI + ÇAKIŞMA HARİTASI — AŞAMA 0.2 / 0.3

> Kaynak: `docs/apsiyon_apis_video_analiz_raporu.md` (1225 satır, 31 bölüm).
>
> **Not — dosya adı:** brief `docs/apsiyon-analiz.md` diyor; depodaki
> gerçek ad `docs/apsiyon_apis_video_analiz_raporu.md`
> (commit `ca6b5aa`). Başka bir Apsiyon belgesi yok; bu belge okundu.
>
> **Karşılaştırma tabanı:** `docs/envanter.md` (Aşama 0.1). Buradaki her
> "VAR" iddiası oradaki ölçüme dayanır.

---

## KOVA TANIMLARI

| Kova | Anlam | Efor ölçeği |
|---|---|---|
| **A** | **Bizde ZATEN VAR** — tablo + uç + yüzey tam | 0 |
| **A−** | Arka uç var, **yüzey yok** — "ekran yaz" işi | 0,5–2 gün |
| **B** | **KÜÇÜK İŞ** — mevcut yapıya eklenir | 0,5–3 gün |
| **C** | **BÜYÜK İŞ** — ayrı modül/domain, veri modeli kararı gerektirir | 1–4 hafta |

**A− kovası brief'te yok; ölçüm onu ortaya çıkardı** ve triajın en kalabalık
kovası o. Bu, işin ağırlığını arka uçtan ön uca kaydıran tek bulgudur.

---

## 0.2 + 0.3 — TRİYAJ VE ÇAKIŞMA HARİTASI (tek tablo)

"Aşama" sütunu boş olan satırlar **kapsam dışıdır** ve en altta ayrıca
toplandı. Aşama yazan satırlar **o aşamada bir kez** yapılır; başka yerde
tekrar ele alınmaz.

### Bölüm 2 — Üst seviye uygulama yapısı

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Menü ağacı (kategorize, katlanabilir) | **A/B** | `lib/menu.ts` — 6 grup, `KATLI_GRUPLAR`, rol süzgeci **var** | **7.1** | 1 g (yeni öğeleri diziye ekle) |
| Global arama (üst bar) | **C** | **yok** | **6.3** | 4–6 g |
| Dashboard | **A** | `/dashboard` + `routers/dashboard.py` | — | 0 |
| Takvim / etkinlik | **A** | `etkinlik` + `/etkinlikler` + mobil | — | 0 |

### Bölüm 4 — Kişiler (CRM)

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Kişi listesi + CRUD | **A** | `/users` + `routers/users.py` | **5** (telefon güncelleme, silme eklenecek) | 1 g |
| Kişi Ekle formu | **A** | `/users` | **5** | — |
| Malik/kiracı/daire sakini ilişkisi | **B** | `unit_resident` tablosu var; **rol ayrımı (malik/kiracı) yok** | **5** | 2 g |
| Kişiye not / ek | **B** | — | **6.4** (ortak sistem) | — |
| Kişi işlem geçmişi | **A−** | `audit_log` var, kişi filtreli görünüm yok | **11** (tasarım) | — |

### Bölüm 5 + 28 — Excel ile veri aktarımı / Site Aktar

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Excel ile Site Aktar | **A−→B** | `POST /site-aktar` + `GET /site-aktar/sablon` **var**, `/yonetisim`'de çalışıyor | **8** | çerçeveye taşı |
| Şablon indirme | **A** | `site-aktar-sablon` | **8** | 0 |
| Kolon eşleme | **C→B** | yok | **8** | 3 g |
| Önizleme + hata raporu | **B** | yok | **8** | 2 g |
| **Geri alma** | **B** | yok | **8** | 2 g |
| Kişi/daire/bakiye/araç aktarımı | **B** | tek çerçeveden | **8** | 2 g |

> **ÇAKIŞMA:** Aşama 5'teki "Excel ile toplu sakin yükleme" **aynı iştir**.
> Aşama 5 kendi yükleyicisini yazmaz; Aşama 8'in çerçevesini çağırır.

### Bölüm 6 + 14 + 15 + 22 — Bağımsız bölümler, bloklar, gruplar, yapı ayarları

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Blok yönetimi | **A** | `building_block` + `/building-editor` | **5** | — |
| Bağımsız bölüm (daire) listesi + detay | **A** | `unit` + `/units` + `UnitDetail.tsx` | — | 0 |
| Bağımsız bölüm **grupları** | **A−** | `unit_grup` tablosu **var**, yüzey yok | **5** | 1 g |
| Daire tipleri | **A−** | `unit_tip` + mobil `unit_tanimlari`; **web'de atama yok** | **5** + **7.2** (ad: "Daire Tipleri") | 1 g |
| Toplu daire oluşturma | **A−** | **mobilde var**, web'de yok | **5** | 1 g (mobil deseni taşı) |
| Kat/başlangıç katı, kat silme, sürükle-bırak | **B** | yok (`sira` alanı var) | **5** | 3 g |
| Daire numarası aralık seçimi (`3,5,7-12`) | **B** | yok | **5** | 1 g |
| Blok toplu silme | **B** | tekli + cascade var | **5** | 0,5 g |
| Daireye not / ek | **B** | — | **6.4** | — |

### Bölüm 7 — Firmalar / Cari

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Firma kayıt defteri | **A** | `firma` + `/tanimlar` | — | 0 |
| **Cari hesap / bakiye / ekstre** | **C** | yok — çift taraflı cari defter gerekir | **11** (tasarım) | 2–3 h |

### Bölüm 8 + 27 — Toplu borçlandırma / borçlandırma parametreleri

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Toplu borçlandırma | **A** | `POST /borclandirma/toplu` + `/toplu/onizleme` + `/dues` | — | 0 |
| Gecikme/faiz parametresi | **A** | `GET/PATCH /borclandirma/gecikme-ayari` | — | 0 |
| Borçlandırma önizlemesi | **A** | `/toplu/onizleme` | — | 0 |

### Bölüm 9 — Finansal işlemler

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| 9.1 Borçlandırmalar listesi | **A** | `/dues` | — | 0 |
| 9.2 Tahsilat (tekli) | **A** | `POST /finans/tahsilat` + `/dues` | — | 0 |
| 9.2 **Toplu tahsilat** | **A−** | uç **var** (`/tahsilat/toplu`), ekran yok | **10** | 1 g |
| 9.3 Gider | **A−** | `POST /finans/hareketler` (tip=gider), ekran yok | **10** | 1 g |
| 9.4 Gelir | **A−** | aynı uç (tip=gelir), ekran yok | **10** | 1 g |
| 9.5 **Virman** | **A−** | `POST /finans/virman` + BFF açık, **ekran yok** | **10** | 1 g |
| 9.6 **Ödeme iadesi** | **A−** | `POST /finans/iade` + BFF açık, **ekran yok** | **10** | 1 g |
| 9.7 **Açılış fişi** | **A−** | `POST /finans/acilis` var, **BFF'te yok**, ekran yok | **10** | 1 g |
| Çoklu satır finansal işlem | ~~**B**~~ → **A** | **ÖLÇÜM DÜZELTMESİ (Aşama 10):** `POST /finans/hareketler` ZATEN çok satırlı (`HareketToplu.satirlar` + `idempotency_key`/`idem_satir`). Triyajda "tek satır" yazması hataydı. | — | 0 |
| Finansal belge numaralandırma | **C** | yok | **11** (tasarım) + **11 ilke** | 1 h |
| Finansal kayıt **silinmez**, ters kayıt | **B** | **YAPILDI (Aşama 10):** göç 0047 — `iptal` tipi + `ters_kayit_id` + `REVOKE DELETE` (hem göçte hem `setup_app_role`'da) | **10** | ✅ |
| Finansal denetim kaydı (eski/yeni değer) | ~~**B**~~ → **A** | **ÖLÇÜM DÜZELTMESİ (Aşama 10):** finans yazma uçlarının 9'undan 8'i `audit_user` çağırıyor; 9.'su (`banka-eslestir`) hiçbir şey **yazmıyor** (öneri üreticisi), denetlenecek bir mutasyon yok. İptal ucu eski/yeni değeri `meta`ya yazar. | — | 0 |

### Bölüm 10 — İcra dosyaları

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| İcra dosyası listesi + CRUD | **A−** | `icra_dosyasi` + 3 uç + BFF **açık**, **hiçbir sayfa çağırmıyor** | **10** (ekran) + **7.1** (menüde ayrı üst sekme) | 1,5 g |
| İcra takip süreci (safha, masraf, vekâlet) | **C** | yok | **11** (tasarım) | 2–3 h |

### Bölüm 11 + 20 — Sayaç

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Ana sayaç / bölüm sayacı tanımı | **A** | `sayac_ana`, `sayac_bolum` + `/tanimlar` | — | 0 |
| Sayaç okuma | **A** | `/sayac-okuma` | — | 0 |
| Sayaçla borçlandırma | **A** | `POST /borclandirma/sayac` | — | 0 |
| **Sayaç dağıtım sihirbazı** (dağıtım şekilleri) | **C** | yok | **11** (tasarım) | 2–3 h |
| Fatura kaydı | **C** | yok | **11** (tasarım) | 1–2 h |

### Bölüm 12 — İletişim

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| 12.1 SMS şablonları | **A** | `mesaj_sablonu` + `/mesajlar` | **9** (değişken/karakter sayacı eklenecek) | 1 g |
| 12.2 E-posta şablonları | **A−** | aynı tablo, `kanal` alanı; zengin metin yok | **9** | 2 g |
| **Gönderim** (alıcı segmenti, kuyruk, kota) | **A−** | `POST /mesajlar/gonder` **var**, **ekran yok** | **9** | 3 g |
| Gönderim geçmişi | **A** | `GET /mesajlar/gecmis` + ekran | — | 0 |
| Önizleme | **A** | `POST /mesajlar/onizleme` + ekran | — | 0 |
| WhatsApp | **C** | yok, **sağlayıcı seçilmedi** | **9** (araştırma) | araştırma |
| 12.3 İş takibi | **A** | `task` + `/tasks` + mobil | **7.1** (İLETİŞİM grubuna taşı) | 0 |
| 12.4 Karar defteri | **A** | `karar_defteri` + `/yonetisim` | **7.1** (İLETİŞİM'e taşı) | 0 |
| 12.5 Doküman yönetimi | **A** | `tenant_dokuman` + `/yonetisim` | **7.1** + **6.4** | 0 |
| 12.6 Geri bildirim | **A** | `complaint` | **0.5** (ad birleştirme) | — |

### Bölüm 13 + 16 + 17 + 18 + 19 — Tanımlar

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Kasa | **A** | `/tanimlar` defter #1 | **7.1** (TANIMLAR grubu) | 0 |
| Gelir/gider tanımları | **A** | defter #2, #3 | **7.1** | 0 |
| Personel | **A** | defter #5 | **7.1** | 0 |
| Araç | **A** | defter #6 | **7.1** | 0 |
| Sayaç | **A** | defter #7, #8 | **7.1** | 0 |
| Blok | **A** | `/building-editor` | **7.1** | 0 |
| Daire tipleri | **A−** | bkz. Bölüm 6 | **5** + **7.2** | — |

### Bölüm 21 + 23 — Ayarlar, rapor ayarları

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Genel ayarlar / parametreler | **A** | `/settings`, `tenant` alanları | — | 0 |
| İletişim ayarları | **A** | `config.py` SMS/FCM | **9** | 0 |
| İşlem geçmişi | **A** | `audit_log` + `/audit` | — | 0 |
| **Rapor motoru / rapor ayarları** | **A−** | `rapor_motoru.py` (katalog + `POST /raporlar/{kod}`) + `/raporlar`; **ayar ekranı yok** | **11** (tasarım) | 1–2 h |
| Excel/PDF çıktı | **A** | `RAPOR_BICIMLERI = tablo, excel, pdf` | — | 0 |

### Bölüm 24 + 25 — Yetki, erişim izinleri

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Yetki matrisi | **A** | `GET /yetki-matrisi` + `/yetki` (salt okuma) | **11** (yazılabilir matris tasarımı) | — |
| **API seviyesinde yetki** | **A** | `require_role` her uçta; 317 uçluk rol matrisi | — | 0 ✔ |
| Mobil/web görünürlük izinleri | **A** | `lib/yuzey.ts` — rol × yüzey kapısı | **7.1** | 0 |
| Erişim izinleri (daire bazlı) | **A** | `unit_access_permission` + `routers/unit_access.py` | — | 0 |

### Bölüm 26 — Evrak seri/sıra no

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Merkezî belge numaralandırma | **C** | yok | **11** (tasarım) + **11 ilkeleri** | 1 h |

### Bölüm 29 — UI/UX davranışları

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| Liste: kolon sıralama | **B** | yok | **6.2** | 1 g |
| Liste: kolon filtreleme | **B** | kısmen (`SUZGECLER`) | **6.2** | 1 g |
| Liste: **sayfa başına kayıt (10/25/50/100)** | **B** | yok | **6.2** | 0,5 g |
| Liste: sayfalama + toplam kayıt | **B** | `limit/offset` var, UI yok | **6.2** | 1 g |
| Liste: toplu seçim | **B** | yok | **6.2** | 1 g |
| Liste: üç nokta işlem menüsü | **B** | yok | **6.2** | 0,5 g |
| Liste: anlamlı boş durum | **A** | `EmptyState.tsx` | — | 0 |
| **Form: modal/pop-up** | **B** | sayfa üstünde alan açılıyor | **6.1** | 3 g |
| Form: ESC/dış tık/odak tuzağı | **B** | yok | **6.1** | (6.1 içinde) |
| Detay sayfası deseni | **A** | `UnitDetail.tsx` | — | 0 |
| Dosya yükleme | **A** | `routers/uploads.py` + MinIO presign | **6.4** | 0 |
| Notlar / ekler | **B** | yalnız `complaint_photo` | **6.4** | 3 g |

### Bölüm 30 + 31 — Veri modeli önerisi, workflow'lar

| Apsiyon maddesi | Kova | Bizdeki karşılığı | **Aşama** | Efor |
|---|---|---|---|---|
| İlişkisel ERP mimarisi önerisi | **C** | kısmen (finans/tanım tabloları var) | **11** | belge |
| Workflow: kişi oluştur | **A** | `/users` | **5** | — |
| Workflow: bağımsız bölüm oluştur | **A** | `/building-editor` | **5** | — |

---

## KOVA ÖZETİ

| Kova | Adet | Toplam efor |
|---|---|---|
| **A** (var, dokunma) | **34** | 0 |
| **A−** (arka uç var, ekran yok) | **14** | ~14 gün |
| **B** (küçük iş) | **21** | ~28 gün |
| **C** (büyük iş → Aşama 11 tasarım) | **8** | 8–15 hafta (bu turda **kod yok**) |

**Okuma:** rakip ürünün video analizinden çıkan 77 maddenin **34'ü zaten
bizde çalışıyor**, 14'ü yalnız ekran bekliyor. Gerçek yeni geliştirme
21 küçük + 8 büyük maddede.

---

## ÇAKIŞMA HARİTASI — "aynı işi iki kez yapma" kuralı

Aşağıdaki her satır, **birden fazla kaynakta geçen** bir işi ve onun
**tek sahibini** gösterir. Sahip aşama dışında hiçbir aşama bu işe
dokunmaz.

| İş | Kaynaklar | **TEK SAHİBİ** | Diğer aşamaların yapacağı |
|---|---|---|---|
| **Excel/import** | Apsiyon §5, §28 · brief Aşama 5 (sakin yükleme) · brief Aşama 8 · kodda `/site-aktar` | **Aşama 8** | Aşama 5 çerçeveyi **çağırır**, yazmaz |
| **Modal form** | Apsiyon §29 · brief Aşama 6.1 · her ekran | **Aşama 6.1** | Aşama 5/7/9/10 tek bileşeni **parametreyle** kullanır; çatallamaz |
| **Liste deseni** | Apsiyon §29 · brief Aşama 6.2 · kodda `Defter` + `tablo.tsx` | **Aşama 6.2** | `/tanimlar`'ın `Defter` deseni **genelleştirilir**; ikinci tablo bileşeni yazılmaz |
| **Global arama** | Apsiyon §2 · brief Aşama 6.3 | **Aşama 6.3** | Hiçbir ekran kendi aramasını yazmaz |
| **Not + ek (attachment)** | Apsiyon §4, §6, §29 · brief Aşama 6.4 | **Aşama 6.4** | Daire/kişi/görev/icra/doküman aynı sisteme **takılır** |
| **Menü ağacı** | Apsiyon §2 · brief Aşama 7.1 · kodda `lib/menu.ts` | **Aşama 7.1** | Yeni sayfalar `OGELER` dizisine satır ekler; ikinci menü kaynağı yok |
| **SMS/e-posta şablonu + gönderim** | Apsiyon §12.1, §12.2 · brief Aşama 3 (geçici kod e-postası) · brief Aşama 9 · kodda `mesaj_sablonu` + Netgsm | **Aşama 9** | Aşama 3 **kendi e-posta kodunu yazmaz**, ortak gönderim arayüzünü çağırır |
| **Blok/daire yönetimi** | Apsiyon §6, §14, §15, §22 · brief Aşama 5 | **Aşama 5** | Aşama 7.3 onboarding sihirbazı aynı ekranlara **yönlendirir**, kopyalamaz |
| **Doküman + karar defteri** | Apsiyon §12.4, §12.5 · brief Aşama 7.1 · kodda `/yonetisim` | **Aşama 7.1** (menü) + **6.4** (ek) | İkinci doküman ekranı yazılmaz |
| **Yetki modeli** | Apsiyon §24, §25 · brief Aşama 11 ilkeleri · kodda `require_role` + `/yetki` | **Aşama 11** (tasarım) | API zorlaması **zaten var**; menü gizleme `yuzey.ts`te — ikisi karıştırılmaz |
| **Bağımlılık yönlendirmesi** | brief Aşama 0.4 · Aşama 7.4 | **Aşama 7.4** | 16 satırlık bağımlılık haritası (envanter §0.4) tek bileşenle karşılanır |
| **Tesis ID üretimi** | brief kilitli kural 3 · Aşama 1 · Aşama 3 · kodda `kayit_kodu_uret()` | **Aşama 1** | Aşama 3 üretmez, **okur** |
| **Şikayet/öneri adı** | brief Aşama 0.5 · Aşama 7.2 | **Aşama 0.5** (karar) → **7.2** (uygulama) | `unit_complaint` **ayrı kalır** (envanter §0.5) |

---

## KAPSAM DIŞI — sonraki tur

Apsiyon raporunda geçen ve brief'in **hiçbir aşamasıyla eşleşmeyen**
maddeler:

| Madde | Neden kapsam dışı |
|---|---|
| **Web sitesi modülü** (Apsiyon §2, §3 00:18–00:27) | Brief Aşama 7.2 bizim `/portal`ı **kaldırmayı** söylüyor — özel alan adı hizmeti sunulmuyor. Yön ters; kapsam dışı. |
| **Cari hesap ekstresi** (§7) | C kovası; Aşama 11'de yalnız **tasarımı** yazılacak, kodu sonraki tur |
| **İcra takip süreci** (safha/masraf/vekâlet, §10) | C — Aşama 11 tasarımı |
| **Sayaç dağıtım motoru** (§11) | C — Aşama 11 tasarımı |
| **Fatura kaydı** (§11) | C — Aşama 11 tasarımı |
| **Evrak seri/sıra numaralandırma** (§26) | C — Aşama 11 tasarımı |
| **Rapor motoru ayarları** (§23) | C — Aşama 11 tasarımı |
| **Yazılabilir yetki matrisi** (§24) | C — Aşama 11 tasarımı |
| **OBS/kayıt başlangıcı** (§3 00:00–00:08) | Videonun kendisine ait; ürün özelliği değil |
| **Bağımsız bölüm grupları** (§15) | B ama düşük değer; Aşama 5'e **iliştirildi**, ayrı iş açılmadı |

---

## AŞAMA 11'E DEVREDİLEN TASARIM BAŞLIKLARI

`docs/erp-yol-haritasi.md` şu sekiz başlığı içerecek (kod değil, mimari):

1. Sayaç dağıtım motoru
2. Cari/firma hesap yönetimi
3. İcra takip süreci
4. Evrak seri-sıra numaralandırma (**merkezî**)
5. Rapor motoru ayarları
6. Yazılabilir yetki matrisi
7. Fatura kaydı
8. Çoklu satır finansal işlem + ters kayıt mekanizması

Her biri için: veri modeli · mevcut şemayla bağlantı · yapılma sırası.

---

## BU AŞAMADA HANGİ ÇAKIŞMAYI ÖNLEDİM

**Bir tanesi diğerlerinden pahalıydı:** Aşama 5, 8 ve Apsiyon §5/§28
birbirinden habersiz üç ayrı Excel yükleyici yazdırırdı — üstelik kodda
**çalışan bir dördüncüsü** (`/site-aktar`) zaten vardı. Tek sahip
Aşama 8 ilan edildi; diğer üçü onu çağıracak.

İkinci en pahalısı: Aşama 3'ün "geçici kodu e-postayla gönder" maddesi
kendi e-posta kodunu yazdırırdı; Aşama 9'un ortak gönderim arayüzüne
bağlandı.
