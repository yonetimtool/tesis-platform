# Finans modülü — tam analiz (yalnız inceleme, kod yazılmadı)

> Tarih: 2026-08-31 · Yöntem: kod okundu, satır numaraları verildi.
> "İyi görünüyor" değil, "şu var / şu yok" yazıldı. Emin olmadığım yerler
> **[emin değilim]** ile işaretli.

---

## 0. Yönetici özeti — üç cümle

1. Finans tarafı **beklediğimden geniş**: 13 finans tablosu, ~40 uç, 16
   raporluk bir rapor motoru, banka ekstresi eşleştirme, icra takibi,
   şeffaflık yayını. Eksik olan şey "özellik" değil, **tutarlılık**.
2. **En büyük sorun mimari:** paranın kaydı **üç ayrı deftere** yazılıyor
   (`dues_payment`, `finansal_hareket`, `budget_entry`) ve bu üçü
   birbirine bağlı değil. Tahsilatı **hangi ekrandan girdiğinize göre**
   farklı ekranlar farklı rakam gösteriyor. Bu bir hata değil, bir
   **tasarım boşluğu** — ve bugün sahada yanlış rakam üretebilir.
3. Gecikme faizi **hesaplanıyor ama tahsil edilemiyor** (yalnız
   görüntüleme); dönem kapatma, borç yaşlandırma ve muhasebeciye
   dışa aktarım **yok**.

> **Rapor hakkında:** iki iddiamı yazdıktan sonra kodda doğrulayıp
> düzelttim (tahakkuk silme ucu **yok**; tahsilat ekranı idempotency
> anahtarı **göndermiyor** — ikisi de §5.6 ve §5.9'da). Kalan
> **[emin değilim]** işaretleri gerçekten doğrulanmamış noktalardır.

---

# 1. VERİ MODELİ

## 1.1 Tablo listesi

Tümü `backend/app/models.py` içinde. **Hepsinde RLS açık + FORCE**
(2026-08-31'de doğrulandı: `tenant_id` taşıyan 93 tablonun tamamı —
bkz. `docs/P192-tesis-izolasyonu.md`).

| Tablo | Satır | Ne tutar | Silinebilir mi |
|---|---|---|---|
| `dues_assessment` | 1335 | **Borç (tahakkuk)** — daire × dönem | Evet (uç var: `DELETE /dues/assessments/{id}` — bkz. §5.6) |
| `dues_payment` | 1382 | **Ödeme** — borç kapanışı | Uç yok; DB'de DELETE yetkisi var |
| `finansal_hareket` | 2991 | **Kasa defteri** — tahsilat/gider/gelir/virman/iade/açılış/iptal | **HAYIR** — `REVOKE DELETE` (infra/scripts/setup_app_role.py:102) |
| `kasa` | 2737 | Kasa/banka hesabı tanımı, açılış bakiyesi | Evet |
| `gelir_gider_grup` | 2771 | Kalem üst kırılımı | Evet |
| `gelir_gider_tanim` | 2792 | **Borçlandırma türü** + hedef kuralı + dağıtım şekli | Soft-delete (`aktif`) |
| `firma` | 2828 | Tedarikçi/hizmet firması | Evet |
| `budget_category` | 1436 | **Bütçe kategorisi** (ayrı sistem) | Soft-delete |
| `budget_entry` | 1463 | **Bütçe defteri** satırı (ayrı sistem) | [emin değilim] |
| `icra_dosyasi` | 3173 | Hukuki takip kaydı (para hareketi DEĞİL) | Evet |
| `bank_transaction` | 3079 | Ham banka hareketi (P191) | **HAYIR** — DELETE grant yok, `raw_data` tetikleyiciyle değişmez |
| `payment_match` | 3119 | Banka hareketi ↔ borç eşleşmesi | **HAYIR** — geri alma `durum='geri_alindi'` |
| `receipt` | 3151 | Makbuz (PDF anahtarı MinIO'da) | **HAYIR** |
| `sayac_ana` / `sayac_bolum` | 2929 / 2958 | Sayaç okuma → tüketim borçlandırması | Evet |
| `payment_webhook_event` | 1521 | Kart ödeme sağlayıcı olayı (bugün **atıl**) | — |
| `transparency_publication` | 2454 | Şeffaflık yayını (anonim özet) | — |

## 1.2 `finansal_hareket` tam olarak nedir?

**Kasa defteri** — "para kasaya/bankaya girdi/çıktı" kaydı.
`backend/app/models.py:2991-3068`:

* `tip`: `tahsilat | gider | gelir | virman | iade | acilis | iptal`
  (models.py:192-197)
* `yon`: `giris | cikis` — **tutar her zaman pozitif**, işaret `yon`da
  (models.py:2992-2994'teki gerekçe: negatif tutar "iade" ile "eksi
  gider"i ayırt edilemez kılardı)
* `kasa_id`, `user_id`, `unit_id`, `firma_id`, `gelir_gider_tanim_id`,
  `assessment_id` — hepsi **nullable**
* `belge_no` — merkezi seriden (`belge_no.py:49-71`, ön ekler TAH/GID/
  GEL/VIR/IAD/ACL/BRC/IPT/KRR)
* `virman_grup_id` (iki satır bir virman), `iade_edilen_id`,
  `ters_kayit_id` (iptal → iptal ettiği satırı gösterir)
* `idempotency_key` + `idem_satir` (models.py:3060-3061)
* `durum`: `odendi | bekliyor | onay_bekliyor` (models.py:208-211)

**Append-only mu?** Yarı: `DELETE` **veritabanı düzeyinde iptal edilmiş**
(app_rw'den `REVOKE DELETE`), ama `UPDATE` **açık** — yani bir satır
silinemez ama *değiştirilebilir*. Karşılaştırma: `audit_log`'da
`UPDATE, DELETE` birlikte iptal edilmiş (setup_app_role.py:87). Defterin
gerçekten değişmez olması isteniyorsa `UPDATE` de kapatılmalı.
**Bugün bunu kullanan bir uç görmedim** — yani pratikte append-only gibi
davranıyor, ama kural DB'de yazılı değil.

## 1.3 Aidat borcu nerede, nasıl üretiliyor?

`dues_assessment` (models.py:1335). Anahtar alanlar:

* `UNIQUE (tenant_id, unit_id, donem)` (1347-1349) — **daire × dönem tek
  satır.** Bu, "aynı ay iki farklı kalem" (aidat + otopark) yazmayı
  **engelliyor** (§4.3'e bakın).
* `tutar_kurus` (Integer, `> 0` CHECK)
* `donem` (metin, `YYYY-MM`) ve `tarih` (Date) **ayrı**: "Ocak dönemi
  borcu Şubat'ta açılabilir" (models.py:1370-1372)
* `gelir_gider_tanim_id` → borçlandırma türü
* `hedef_user_id` → borcun **kime** yazıldığı (NULL = daireye)
* `gecikme_uygula` (bool), `kaynak` (`tekil|toplu|sayac|ice_aktarim`)

## 1.4 `dues_payment` ↔ `finansal_hareket` ilişkisi

**İlişki YOK.** İki tablo birbirine hiç bakmıyor:

* `backend/app/routers/dues.py` içinde `FinansalHareket` **hiç geçmiyor**
  (grep: 0 sonuç).
* `backend/app/routers/finans.py` içinde `DuesPayment` yalnızca bir
  **yorumda** geçiyor (finans.py:235: *"`dues_payment` tablosuyla
  YARIŞMAZ"*), kodda kullanılmıyor.

Sonuçları §5.1'de.

## 1.5 Gider kaydı nerede?

**İki ayrı yerde** — ve ikisi birbirini görmüyor:

1. `finansal_hareket` (`tip='gider'`, `yon='cikis'`) →
   `POST /finans/hareketler` (finans.py:315). Kasa bakiyesini etkiler.
2. `budget_entry` (`tip='gider'`) → `POST /budget/entries`
   (routers/budget.py). Bütçe özetini ve **şeffaflık yayınını** etkiler
   (transparency.py:76), kasa bakiyesini **etkilemez**.

## 1.6 Bakiye nasıl hesaplanıyor?

**Hiçbir bakiye saklanmıyor; hepsi her okumada toplanıyor.** Bu doğru bir
karar (saklanan bakiye her yazma yolunda elle güncellenmek zorunda kalır),
ama **hangi kaynaktan** toplandığı yere göre değişiyor:

| Ekran / uç | Borç kaynağı | Tahsilat kaynağı | Dosya |
|---|---|---|---|
| Daire bakiyesi `/units/{id}/dues` | `dues_assessment` | **`dues_payment`** | dues.py:178-205 |
| Sakinin "Aidatım" `/me/dues` | `dues_assessment` | **`dues_payment`** | dues.py |
| Kasa bakiyesi `/finans/kasa-bakiyeleri` | — | `finansal_hareket` (**durum süzgeci YOK**) | finans.py:612-644 |
| Panel özeti `/finans/ozet` | `dues_assessment` | **`finansal_hareket`** | finans.py:884-916 |
| Borç-Alacak raporu | `dues_assessment` | **`finansal_hareket`** | rapor_motoru.py:333-359 |
| Tahsilat performansı raporu | `dues_assessment` | **`finansal_hareket`** | rapor_motoru.py:866-876 |
| Mobil "Tahsilat Oranı" `/reports/financial-summary` | `dues_assessment` | **`dues_payment`** | reports.py:43-56 |
| Bütçe özeti + şeffaflık | — | **`budget_entry`** | budget.py, transparency.py:76 |

Kasa bakiyesi formülü saf fonksiyonda: `finans.py:20-27`
(`acilis + Σ işaretli hareket`).

---

# 2. BUGÜN NE YAPILABİLİYOR

## 2.1 Yönetici — web paneli

Menü: `admin-web/lib/menu.ts:231-252`. Rol kapısı `lib/yuzey.ts:311-330`
(hepsi **admin + yönetici**; denetçi yalnız okuma uçlarında).

| Ekran | Yol | Ne yapılıyor | Uç |
|---|---|---|---|
| Aidat | `/dues` | Tahakkuk listesi, daire bazlı borç durumu | `/dues/assessments` |
| Borçlandırmalar | `/finans/borclandirmalar` | Tekil + **toplu** borçlandırma, önizleme, sayaçtan borçlandırma, içe aktarma | `/borclandirma/*` |
| Tahsilatlar | `/finans/tahsilatlar` | Tekil + **toplu** tahsilat (kasaya giriş) | `POST /finans/tahsilat[/toplu]` |
| Giderler | `/finans/giderler` | Gider fişi (çok satırlı, firma + kalem + belge no) | `POST /finans/hareketler` |
| Gelirler | `/finans/gelirler` | Aidat dışı gelir | aynı uç |
| Virman | `/finans/virman` | Kasalar arası aktarım (**iki satır, tek işlem**) | `POST /finans/virman` |
| İade | `/finans/iade` | Tahsilat iadesi (`iade_edilen_id` ile bağlı) | `POST /finans/iade` |
| Açılış | `/finans/acilis` | Açılış fişi | `POST /finans/acilis` |
| **Banka Entegrasyonu** | `/finans/banka` | Ekstre yükleme (CSV/Excel/MT940), eşleştirme, eşleşmeyenler, makbuz, geri alma | `/banka/*` (P191) |
| Finans defteri | `/finans` | Tüm hareketler, süzgeç | `GET /finans/hareketler` |
| İcra | `/icra` | İcra dosyası aç/güncelle/sil | `/finans/icra-dosyalari` |
| Raporlar | `/raporlar` | **16 rapor** + PDF/Excel | `/raporlar/*` |
| Tanımlar | `/tanimlar` | Kasa, gelir/gider grup+tanım, firma, daire tipi (varsayılan aidat), sayaç | `/muhasebe-tanimlari`, `/kasalar`, … |
| Şeffaflık | `/transparency` | Anonim aylık özet yayını | `/transparency` |

**Ayrıca uç var ama ekran [emin değilim]:** `POST /finans/banka-eslestir`
(P29'un eski öneri motoru, finans.py:649) — `admin-web/lib/panel-vekil.ts:80`
üzerinden hâlâ erişilebilir; P191'in `/banka/*` akışıyla **işlevi
çakışıyor**. Bkz. §5.5.

## 2.2 Yönetici — mobil

Mobilde finans **kısıtlı**: `mobile/lib/src/features/budget/` altında
`budget_screen.dart` (bütçe defteri: kategori + gelir/gider kaydı),
`financial_summary_screen.dart`, `site_budget_screen.dart`; ayrıca
`reports_screen.dart`. Kullandığı uçlar: `/budget/*`,
`/reports/financial-summary`.

**Mobilde YOK:** tahakkuk oluşturma, tahsilat girme, kasa/virman/iade,
banka eşleştirme, 16'lık rapor motoru. Yani mobil, finansın **bütçe**
ayağını görüyor; **aidat–kasa** ayağını görmüyor.

## 2.3 Sakin tarafı

| Ne | Nerede | Uç |
|---|---|---|
| Kendi borç/ödeme listesi ve bakiyesi | Web `/aidatim`, mobil "Aidatım" | `GET /me/dues` |
| "Öde" ekranı: tesisin IBAN'ı + **kendi ödeme kodu** + borç tutarı | Mobil `ode_screen.dart` | `GET /me/odeme-bilgileri` (sakin_odeme.py:125) |
| Kartla ödeme başlatma | Mobil | `POST /me/odeme/kart` — sağlayıcı `manual` olduğu için **bugün kapalı** |
| Site geneli anonim gelir/gider özeti | Mobil `site_budget_screen.dart` | `GET /budget/summary` (tüm roller) |
| Şeffaflık yayını | Web/mobil | `/transparency` |

Sakin **kendi ödeme geçmişini** görüyor (`/me/dues` ödemeleri de
döndürüyor), ama **makbuzunu göremiyor** (§4.9).

---

# 3. AİDAT TAHAKKUKU (ayrıntılı)

## 3.1 Aidat nasıl tanımlanıyor?

Üç yol var, üçü de `POST /borclandirma/toplu` üzerinden
(`routers/borclandirma_uc.py:143-185`):

1. **Elle tek tutar** — `body.tutar_kurus` verilirse tüm seçili dairelere
   aynı tutar (`_toplu_plan`, satır 154-155).
2. **Daire tipine göre** — `unit_tip.varsayilan_aidat_kurus`
   (models.py:1249-1272) her daireye kendi tipinin tutarını yazar
   (`tipe_gore_dagit`, borclandirma.py:120-133). Tipi olmayan daire için
   `yedek_tutar_kurus`; o da yoksa **daire atlanır** ("tutar_cozulemedi")
   — sessizce 0 yazmaz.
3. **Sayaçtan** — `POST /borclandirma/sayac`: ana sayaç ile daire
   sayaçları arasındaki fark ortak tüketim sayılır, isteğe bağlı yüzdeyle
   dairelere eşit dağıtılır (`sayac_tuketim_dagitimi`,
   borclandirma.py:135-164).

**Metrekare / arsa payı YOK.** `gelir_gider_dagitim` enum'u yalnız
`bagimsiz_bolumlere_esit` ve `tipe_gore` taşıyor; `arsa_payi` ve
`kisi_sayisi` **bilerek eklenmemiş** (models.py:179-185'teki not:
"enum'a koyup uygulamamak, SEÇİLEBİLİR ama YANLIŞ BORÇLANDIRAN bir seçenek
gösterirdi"). **Kat Mülkiyeti Kanunu md. 20 arsa payını esas alır** —
bu gerçek bir eksik, §4.1.

## 3.2 Aylık borç otomatik mi?

**Hayır — tamamen elle.** `celery_app.py:28-120`'deki `beat_schedule`
içinde tahakkukla ilgili **hiçbir görev yok** (devriye, vardiya, gürültü,
mesaj kuyruğu, gecelik retention var). Yönetici her ay
**Borçlandırmalar → Toplu** ekranını açıp çalıştırmak zorunda.

Önizleme mekanizması iyi kurulmuş: `POST /borclandirma/toplu/onizleme`
**hiçbir şey yazmadan** ne olacağını gösteriyor ve işleme aynı planı
kullanıyor (borclandirma_uc.py:236-256).

## 3.3 Farklı tutarlar (dükkân / daire / boş daire)

* **Daire tipi** üzerinden destekleniyor (yukarıda #2). Dükkân için ayrı
  bir tip açıp varsayılan aidatını girmek yeterli.
* **Süzgeç:** blok, daire tipi, daire grubu, ya da elle seçim
  (`_hedef_daireler`, borclandirma_uc.py:115-134).
* **Boş daire:** ayrı bir kavram **yok**. `unit.aktif` süzgeci var
  (sadece aktif daireler borçlanır) ama "boş ama aktif" daireye indirimli
  aidat yazma yolu yok — ayrı bir daire tipi açmak gerekir.

## 3.4 Ek tahakkuk (demirbaş, tadilat, olağanüstü)

**Kısmen var, ama bir kısıt engelliyor.** Farklı bir
`gelir_gider_tanim` ile ek borç yazılabilir (tür + hedef kuralı
tanımdan gelir: aidat/fatura → kiracı öncelikli, demirbaş/yatırım →
malik, models.py:2814-2820). **Ancak** `UNIQUE (tenant_id, unit_id, donem)`
yüzünden **aynı daireye aynı dönemde ikinci bir tahakkuk yazılamaz.**

Yani "2026-03 aidat + 2026-03 asansör tadilatı" **aynı ay için mümkün
değil**; farklı dönem etiketi kullanmak gerekir. Toplu borçlandırmada
çakışan satır sessizce atlanıyor (`_yaz`, borclandirma_uc.py:187-231:
benzersizlik ihlalinde `False` döner, `atlanan` sayacına gider).
**Bu, gerçek bir işlevsel sınırdır** — §4.3.

## 3.5 Gecikme faizi

* Oran **tesis ayarında**: `tenant.gecikme_aylik_yuzde`,
  `Numeric(5,2)` (models.py:402-404). Uç:
  `GET/PATCH /borclandirma/gecikme-ayari` (borclandirma_uc.py:460-489).
* Hesap: `borclandirma.py:78-105` — **basit faiz, tam ay üzerinden**
  (`_ay_farki`, satır 58-76: kısmi ay orantılanmaz). `Decimal` +
  `ROUND_HALF_UP` ile kuruşa yuvarlanır.
* **Nerede kullanılıyor:** yalnızca **okuma** yollarında —
  `dues.py:170` (tahakkuk listesine `gecikme_kurus` alanı eklenir) ve
  `rapor_motoru.py:386` (Borç-Alacak raporu).

**Kritik:** gecikme faizi **hiçbir yere yazılmıyor**. Bakiyeye
girmiyor (`_unit_status` yalnız tahakkuk − ödeme), tahsil edilebilir bir
kalem üretmiyor, sakinin "Aidatım" ekranındaki borcuna eklenmiyor.
Bugünkü hâliyle **bilgilendirme amaçlı bir sayı**. §4.4.

## 3.6 Dönem yönetimi

* `donem` serbest metin `YYYY-MM` — enum/tablo değil.
* Dönem **kapatma / kilitleme yok**: kapanmış bir aya geriye dönük
  tahakkuk ya da tahsilat yazmayı engelleyen bir kural yok.
* **Devir yok**: yıl sonunda bakiyeyi bir sonraki döneme taşıyan bir
  işlem yok; bakiye zaten "tüm zamanların toplamı" olarak hesaplanıyor.

---

# 4. EKSİKLER (asıl bölüm)

Öncelik ölçütüm: **(a)** yanlış rakam üretme riski, **(b)** yasal
zorunluluk, **(c)** günlük operasyonda tekrar eden acı.

## 4.1 Arsa payına göre dağıtım — ÖNCELİK: YÜKSEK

**Ne eksik:** aidat/gider dağıtımı yalnız "eşit" ve "daire tipine göre".
**Neden:** KMK md. 20, ana gayrimenkulün genel giderlerine katılımı
**arsa payı** oranında düzenler (aksi kararlaştırılmadıkça). Kapıcı/asansör
gibi kalemlerde farklı oranlar uygulanır. Bugün 120 m² dükkânla 60 m²
daire aynı aidatı ödüyor — tip açarak *yaklaşık* çözülüyor.
**İş:** `unit`e `arsa_payi` (Numeric) alanı + `gelir_gider_dagitim`
enum'una `arsa_payi` değeri + `esit_dagit`in yanına oransal dağıtım
fonksiyonu. Mevcut yapıya **oturur**; yeni tablo gerekmez. Göç + saf
fonksiyon + toplu borçlandırma dalı.

## 4.2 Borç yaşlandırma (aging) — ÖNCELİK: YÜKSEK

**Ne eksik:** "kim ne kadar süredir borçlu" görünümü (0-30 / 31-60 /
61-90 / 90+ gün).
**Neden:** icra kararı, ihtar ve tahsilat baskısı bu tabloya göre verilir.
Bugün Borç-Alacak raporu **tutar** veriyor, **yaş** vermiyor.
**Senaryo:** yönetici "3 aydan uzun borcu olan 7 daireye ihtar" diyemiyor;
tek tek bakıyor.
**İş:** Veri zaten var (`dues_assessment.son_odeme_tarihi` + ödemeler).
Yeni tablo **gerekmez**; rapor motoruna bir katalog kaydı + kova
hesabı. Orta büyüklükte iş.

## 4.3 Aynı döneme ikinci tahakkuk — ÖNCELİK: YÜKSEK

**Ne eksik:** `UNIQUE (tenant_id, unit_id, donem)` yüzünden aynı ay için
ikinci kalem yazılamıyor (§3.4).
**Senaryo:** Mart ayında hem aidat hem "çatı onarımı olağanüstü katkı"
tahakkuk edilmek isteniyor → ikincisi **sessizce atlanıyor** (toplu
işlemde `atlanan` sayısına düşüyor, kullanıcı nedenini görmüyor).
**İş:** Kısıtı `(tenant_id, unit_id, donem, gelir_gider_tanim_id)`
yapmak. Göç + `NULL` tanımlı eski satırların davranışı düşünülmeli
(Postgres'te NULL'lar UNIQUE'te çakışmaz — dikkat). Orta iş, **ama
davranış değişimi**: bugün "atlandı" olan senaryo yarın "iki satır"
olur.

## 4.4 Gecikme faizinin tahsil edilebilir hâle gelmesi — ÖNCELİK: YÜKSEK

**Ne eksik:** faiz hesaplanıyor ama borç değil (§3.5).
**Senaryo:** sakin 500 TL borcunu ödüyor; ekranda 40 TL gecikme yazıyor
ama ödediğinde bakiye sıfırlanıyor — faiz **kayboluyor**.
**İş:** İki seçenek: (a) faizi tahsilat anında ayrı bir tahakkuk satırı
olarak yazmak, (b) `dues_assessment`e `gecikme_kurus` alanı ekleyip
dondurmak. (a) mevcut yapıya daha iyi oturur (yeni tablo yok) ama
"faiz ne zaman kesinleşir" kararı gerekir. **Önce ürün kararı, sonra kod.**

## 4.5 Üç defterin birleştirilmesi — ÖNCELİK: EN YÜKSEK

Ayrıntı §5.1. **Yeni tablo gerekmez**, gereken şey **yazma yollarının
tek noktadan geçmesi**. Büyük iş ama en yüksek getirili olan bu:
diğer bütün raporların doğruluğu buna bağlı.

## 4.6 Borçlulara toplu hatırlatma — ÖNCELİK: ORTA-YÜKSEK

**Ne eksik:** borçlu listesinden seçip toplu e-posta/push gönderme.
**Var olan parçalar:** mesaj kuyruğu (`mesaj_kuyrugu` beat görevi),
`mesaj_sablonlari`, push altyapısı (P191), `{odeme_linki}` etiketi
(`PORTAL_BASE_URL`), Borç-Alacak raporu ve **İhtar Yazısı** raporu.
**Yani parçalar var, düğme yok.** Rapordan seçili kişilere mesaj
tetikleyen bir uç + ekran gerekiyor. Orta iş, yeni tablo gerekmez.

## 4.7 Kasa/banka ayrımı ve çoklu hesap — ÖNCELİK: DÜŞÜK (zaten var)

`kasa` tablosu birden çok kasa/banka hesabını, açılış bakiyesini, IBAN'ı
ve `banka_mi` ayrımını destekliyor; virman ile aralarında aktarım var.
**Eksik olan tek şey:** P191 banka eşleştirmesi kayıtları **kasasız**
yazıyor (`banka_servis.py:155` `kasa_id=None`, router hiç geçirmiyor) →
banka tahsilatları **hiçbir kasa bakiyesine girmiyor**. Küçük ama
gerçek bir hata; §5.4.

## 4.8 Dönem kapatma / devir — ÖNCELİK: ORTA

**Ne eksik:** bir dönemi kilitleyip geriye dönük kayıt girişini
engelleyen mekanizma.
**Senaryo:** denetimden geçmiş 2025 defterine bugün gider eklenebiliyor;
denetçiye verilen rapor ile bugünkü rapor **farklı** çıkabilir.
**İş:** `donem_kilit` tablosu (küçük) + yazma yollarında kontrol.
Orta iş, yeni tablo gerekir.

## 4.9 Makbuz/dekont arşivi — ÖNCELİK: ORTA

**Bugün:** makbuz **yalnız banka eşleştirmesinde** üretiliyor
(`receipt`, P191). Vezne tahsilatı (`/finans/tahsilat`) makbuz
üretmiyor; `dues_payment.makbuz_no` alanı var ama PDF yok. Sakin
makbuzunu **hiç göremiyor** (uç `/banka/makbuz/{id}` yalnız yönetim).
**İş:** makbuz üretimini tahsilat yollarının ortak noktasına almak
(§4.5 ile birlikte yapılırsa ucuz) + sakine okuma ucu.

## 4.10 Muhasebeciye dışa aktarım — ÖNCELİK: ORTA

**Bugün:** 16 rapor PDF/Excel veriyor (`rapor_ciktilari.py`), "İşletme
Defteri" ve "Hesap Ekstresi" raporları var. **Yok olan:** muhasebe
yazılımlarının beklediği biçimler (e-Defter/XML, Luca/Mikro CSV şablonu)
ve hesap planı eşlemesi. **İş:** rapor motoruna yeni çıktı biçimi;
hesap planı eşlemesi yeni bir tablo ister. Orta-büyük.

## 4.11 Harcama onay akışı — ÖNCELİK: ORTA

`durum='onay_bekliyor'` **enum'da var, panel özeti sayıyor**
(finans.py:951) ama **onaylayan bir uç yok** (§5.3). Yani yarım.
**Senaryo:** 50.000 TL'lik asansör bakımı denetim kuruluna onaylatılmadan
deftere girmesin. **İş:** `PATCH /finans/hareketler/{id}/durum` + rol
kapısı + audit. Küçük-orta; enum zaten var.

## 4.12 Karar defteri ile harcama bağı — ÖNCELİK: DÜŞÜK

`karar_defteri` modülü var (menüde, `KRR` belge serisi). Bir harcamayı
bir karara bağlayan alan **yok**. KMK denetiminde "bu harcama hangi
kararla yapıldı" sorusunun cevabı bugün elle. **İş:** `finansal_hareket`e
`karar_id` (nullable FK). Küçük.

## 4.13 Yıllık faaliyet raporu / KMK kayıtları — ÖNCELİK: ORTA

KMK md. 32-33 uyarınca **işletme projesi** (bütçe), **karar defteri** ve
**işletme defteri** tutulur. Bugün: işletme defteri raporu **var**, karar
defteri **var**, ama **işletme projesi** (yıllık tahmini bütçe ve daire
başı paylar) diye bir kavram yok — `budget_*` tabloları gerçekleşeni
tutuyor, **planlananı** değil. Bütçe-gerçekleşme karşılaştırması bu yüzden
yapılamıyor. **İş:** `budget_plan` benzeri bir tablo + karşılaştırma
raporu. Orta.

## 4.14 Sakinin borç geçmişi — ÖNCELİK: DÜŞÜK (kısmen var)

`/me/dues` tahakkuk + ödeme listesi veriyor. Eksik: dönem bazlı özet,
"hangi ödemem hangi borcu kapattı" eşleşmesi (banka akışında
`payment_match` var ama sakine gösterilmiyor), PDF ekstre.

---

# 5. SORUNLU YERLER

## 5.1 ÜÇ AYRI DEFTER — en ciddi bulgu

Yazma yolları ve etkileri:

| İşlem | `dues_payment` | `finansal_hareket` | `budget_entry` |
|---|---|---|---|
| `POST /dues/payments` (dues.py:207) | ✅ | ❌ | ✅ (`ensure_dues_income_entry`, budget.py:357) |
| `POST /finans/tahsilat` (finans.py:225) | ❌ | ✅ | ❌ |
| Banka eşleştirme (P191, banka_servis.py:150+) | ✅ | ✅ | ❌ |

Okuma tarafı §1.6'daki tabloda. **Somut sonuçlar:**

* Vezneden tahsilat girilirse **sakinin borcu kapanmaz** (`/me/dues`
  ve daire bakiyesi `dues_payment` okur) — sakin ödediği hâlde borçlu
  görünür.
* `/dues/payments` ile ödeme girilirse **kasa bakiyesi artmaz** ve
  Borç-Alacak raporunda tahsilat **görünmez**.
* Aynı metrik iki yerde farklı: **"tahsilat oranı"** mobil ana ekranda
  `dues_payment`ten (reports.py:43-56), web panelinde ve raporda
  `finansal_hareket`ten (finans.py:900, rapor_motoru.py:872) hesaplanıyor.
* Banka eşleştirmesi **bütçe gelirine yazmıyor** → şeffaflık yayını ve
  bütçe özeti banka tahsilatlarını görmüyor.

Bu bir "hata" değil, birbirinden bağımsız üç turda büyümüş üç ayrı
modelin yan yana durması. Ama sahada **yanlış rakam** üretir.

## 5.2 Para tipi — genel olarak DOĞRU, bir istisna

Para **her yerde tam sayı kuruş** (`Integer`/`BigInteger`); `models.py`de
para alanı için `Float`/`Numeric` **yok**. Dağıtımlarda kuruş kaybı
bilinçli olarak engellenmiş (`esit_dagit`, borclandirma.py:107-118:
kalan kuruşlar ilk dairelere birer birer dağıtılır).

**İstisna — sayaç:** `sayac_tuketim_dagitimi` (borclandirma.py:135-164)
tüketimi `float` alıyor ve
`fark = ana_tuketim - sum(bolum_tuketimleri)` ile
`fark * yuzde / 100.0` **float aritmetiği** yapıyor; sonra
`Decimal(str(fark))` ile kuruşa çeviriyor. DB'de okumalar
`Numeric(12,3)` (models.py:2982). Yani **veri doğru, ara hesap float**.
Pratik etkisi kuruş altı, ama bu modülün geri kalanındaki disiplinle
çelişiyor ve düzeltmesi ucuz (`Decimal`e çevirmek).

## 5.3 Yarım kalmış: harcama onayı

`durum` alanı üç değer alıyor, `POST /finans/hareketler` bunu **girişte**
kabul ediyor (schemas.py:5035), panel özeti "onay bekleyen" sayısını
gösteriyor (finans.py:951) — ama **durumu değiştiren bir uç yok**
(`/finans/hareketler` için PATCH tanımlı değil). Dahası **kasa bakiyesi
durumu hiç süzmüyor** (finans.py:619-626): onay bekleyen bir gider
bakiyeyi **şimdiden** düşürüyor. Yani özellik hem yarım hem yanıltıcı.

## 5.4 Banka tahsilatı kasasız

`banka_servis.karari_uygula` `kasa_id` parametresi alıyor ama
`routers/banka.py` onu **hiç geçirmiyor** → tüm banka tahsilatları
`kasa_id=NULL`. `kasa_bakiyeleri` yalnız `kasa_id IS NOT NULL` satırları
gruplandırıyor → **banka tahsilatları hiçbir kasada görünmüyor**, ama
`/finans/ozet`in "toplam tahsilat"ında **sayılıyor**. Kasa toplamı ile
defter toplamı bu yüzden ayrışır. (Bu, P191'de benim bıraktığım açık.)

## 5.5 Çakışan iki banka eşleştirme yolu

`POST /finans/banka-eslestir` (finans.py:649, P29/P30 öneri motoru) ile
`/banka/*` (P191 tam akış) aynı işi iki farklı olgunlukta yapıyor.
Eskisi hâlâ `panel-vekil.ts:80`'de kayıtlı. Bir ekranın onu çağırdığını
**görmedim** [emin değilim] — ölü kod adayı.

## 5.6 Tahakkuk düzeltme yolu yok (silme ucu da yok)

**Önce bir düzeltme:** ilk taslakta "tahakkuk silinebiliyor" yazmıştım;
**yanlıştı.** `dues.py` ve `borclandirma_uc.py` içinde `@router.delete`
**yok** — yanlış yazılmış bir tahakkuk **silinemiyor**.

Asıl sorun bunun tersi: **düzeltme yolu da yok.** `PATCH` ile tutar
değiştirilebiliyor mu, ekranda ne sunuluyor — bunu ayrıca incelemek
gerekir [emin değilim]. Bugünkü hâliyle yanlış tutarla açılmış bir
tahakkuk için görünen tek çıkış, aynı döneme düzeltici bir satır yazmak;
o da §4.3'teki `UNIQUE (tenant_id, unit_id, donem)` kısıtına takılıyor.

DB tarafında hazır olan güvenlik: `dues_payment.assessment_id` FK'si
`ON DELETE SET NULL` (models.py:1390-1395) — yani bir gün silme ucu
açılırsa ödeme satırı **yetim** kalır ve hangi borcu kapattığı kaybolur.
Silme ucu açılacaksa bu davranış önce değiştirilmelidir.

## 5.7 Denetim izi boşluğu

`audit_user` çağrı sayıları: `finans.py` 11, `muhasebe_tanimlari.py` 27,
`borclandirma_uc.py` 5, `banka.py` 5, `dues.py` 4, **`budget.py` 0**.
Yani **bütçe defterine** (gider/gelir kaydı, kategori değişikliği)
yazılan hiçbir şey denetim kaydına düşmüyor — oysa şeffaflık yayını ve
mobil özet o veriden besleniyor.

## 5.8 Atomiklik — genel olarak İYİ

* Virman **iki satırı tek işlemde** yazıyor (finans.py:395+), kısmi
  başarı yok.
* Toplu tahsilat "ya hepsi ya hiçbiri" (finans.py:269+ docstring).
* `_idem_yaz` (finans.py:175-197) idempotency anahtarını kontrol edip
  aynı gövdeyle tekrar gelirse mevcut satırları döndürüyor, farklı
  gövdede 409.
* Belge numarası **atomik ve kilitsiz** üretiliyor
  (`belge_no.py:88-93`: tek `INSERT ... ON CONFLICT DO UPDATE`).
* Toplu borçlandırmada her satır **SAVEPOINT** içinde
  (borclandirma_uc.py:187+): bir satırın çakışması tüm işlemi düşürmüyor.

**Zayıf nokta:** toplu borçlandırma kısmi başarıyı **atlanan** sayısıyla
bildiriyor ama **hangi dairenin neden atlandığı** işlem sonrası yanıtta
yok (önizlemede var). Yönetici 500 dairelik işlemde 3 atlananı
göremiyor.

## 5.9 Eşzamanlılık

* Kasa bakiyesi türetildiği için yarış yok.
* `dues_assessment` benzersizliği DB'de → aynı anda iki toplu
  borçlandırma çift satır yazamaz.
* **Banka eşleştirmede** eşzamanlı iki "Eşleştir" tıklaması P191-ek'te
  savepoint + idempotency ile ele alındı.
* `/finans/tahsilat` idempotency anahtarı **opsiyonel** (`_idem`,
  finans.py:141-146: başlık yoksa `None`). **Ölçüldü:**
  `admin-web/app/(protected)/finans/page.tsx:127` anahtar üretip
  gönderiyor, ama **asıl tahsilat ekranı**
  `finans/tahsilatlar/page.tsx:121` ve `:249` `apiSend(...)`i
  **anahtarsız** çağırıyor (`genIdempotencyKey` o dosyada hiç geçmiyor).
  Yani tahsilat ekranında **çift tıklama iki tahsilat yazabilir** —
  koruma sunucuda var, ekran onu kullanmıyor. Küçük ve net bir açık.

---

# 6. ÖNCELİK ÖNERİSİ (benim sıram)

| # | İş | Gerekçe |
|---|---|---|
| 1 | **Üç defteri tek yazma yolundan geçirmek** (§5.1) | Diğer her şeyin doğruluğu buna bağlı; bugün ekranlar birbirini yalanlıyor |
| 2 | Banka tahsilatına kasa bağlamak (§5.4) | Küçük iş, kasa/defter ayrışmasını bitirir |
| 3 | Gecikme faizini tahsil edilebilir yapmak (§4.4) | Para kaybı; ürün kararı gerektirir |
| 4 | Aynı döneme ikinci tahakkuk (§4.3) | Sessiz atlama üretiyor |
| 5 | Borç yaşlandırma + toplu hatırlatma (§4.2, §4.6) | Tahsilatı doğrudan artırır; parçalar hazır |
| 6 | Arsa payı dağıtımı (§4.1) | KMK uyumu |
| 7 | Tahsilat ekranına idempotency anahtarı (§5.9) | Tek satırlık iş, çift tahsilat riskini kapatır |
| 8 | Harcama onayı (§4.11) + bütçe audit (§5.7) | Yarım kalmışı tamamlamak, denetim izini kapatmak |
| 9 | Dönem kapatma (§4.8), işletme projesi (§4.13) | Denetim ve yıllık döngü |

---

# 7. DOĞRULAMA İÇİN DOSYA HARİTASI

| Konu | Dosya |
|---|---|
| Saf hesaplar (dağıtım, faiz, hedef seçimi) | `backend/app/borclandirma.py` (164 satır) |
| Kasa bakiyesi + banka eşleştirme puanı (eski) | `backend/app/finans.py` (155) |
| Belge numarası serisi | `backend/app/belge_no.py` (144) |
| Kasa defteri uçları | `backend/app/routers/finans.py` (976) |
| Tahakkuk + ödeme uçları | `backend/app/routers/dues.py` (505) |
| Toplu/sayaç borçlandırma | `backend/app/routers/borclandirma_uc.py` (489) |
| Bütçe modülü | `backend/app/routers/budget.py` (411) |
| Banka entegrasyonu (P191) | `backend/app/banka.py`, `banka_kaynak.py`, `banka_servis.py`, `routers/banka.py` |
| Rapor motoru (16 rapor) | `backend/app/routers/rapor_motoru.py`, `raporlar.py`, `rapor_ciktilari.py` |
| Tanımlar (kasa/kalem/firma/tip) | `backend/app/routers/muhasebe_tanimlari.py` (998) |
| Sakin ödeme ekranı ucu | `backend/app/routers/sakin_odeme.py` (192) |
| Web ekranları | `admin-web/app/(protected)/finans/*`, `/dues`, `/aidatim`, `/icra`, `/raporlar` |
| Mobil | `mobile/lib/src/features/budget/`, `dues/`, `reports/` |
