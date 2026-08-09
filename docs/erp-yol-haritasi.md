# ERP YOL HARİTASI — büyük modüllerin mimarisi (AŞAMA 11)

> **Bu belge kod değildir ve kod içermez.** Aşama 11'in kuralı: C kovasına
> düşen sekiz modül için *veri modeli · mevcut şemayla bağlantı · yapılma
> sırası* yazılır, uygulama sonraki turlara bırakılır.
>
> Girdi: `docs/apsiyon-kapsam-triyaji.md` (C kovası) ve `docs/envanter.md`.
> Her tasarım **mevcut tabloların üstüne** oturur; sıfırdan şema önerilmez.

---

## 0. TEMEL — mevcut finans defterinin ne olduğu

Tasarımların hepsi tek bir şeye yaslanıyor, o yüzden önce o ölçüldü.

`finansal_hareket` **tek defterdir** (P29) ve şu kararları zaten taşır:

| Karar | Nasıl | Neden bizim için önemli |
|---|---|---|
| Altı işlem tipi **tek** tabloda (`tip`: tahsilat/gider/gelir/virman/iade/açılış) | `HAREKET_TIP` enum | "Kasa bakiyesi = hareket toplamı" ancak tek kaynakta **kanıtlanabilir** |
| Tutar **daima pozitif**, işaret `yon`da | `tutar_kurus` + `HAREKET_YON` | Negatif tutar, "iade" ile "eksi gider"i ayırt edilemez kılardı |
| Virman **iki satır** | `virman_grup_id` | Çift kayıt ilkesi zaten yerinde |
| İade **neyi** iade ettiğini gösterir | `iade_edilen_id` | Ters kayıt altyapısının yarısı hazır |
| Çift yazma koruması | `idempotency_key` + `idem_satir` (kısmi unique, 0028) | Toplu işlemler güvenli |
| **Boş duran kancalar** | `belge_no` (serbest metin), `firma_id`, `unit_id`, `gelir_gider_tanim_id`, `assessment_id` | Aşağıdaki tasarımların **çoğu yeni sütun istemiyor** |

**Sonuç:** ERP'ye geçiş bir yeniden yazım değil, **var olan kancaların
doldurulmasıdır.** Sıralama bölümü buna göre kuruldu.

---

## RAPORDAN ZORUNLU TASARIM İLKELERİ — durum

Brief bu beşini "şimdi uygulanacak" diyor. Gerçek durum:

| İlke | Durum | Nerede |
|---|---|---|
| Finansal kayıtlar **silinmez**, ters kayıt kullanılır | 🟡 **Yarım** — `iade` var ve `iade_edilen_id` taşıyor; ama genel bir "iptal/ters kayıt" yok ve `DELETE` engelli değil | §8 |
| Finansal denetim kaydı (kim/ne zaman/eski/yeni) | 🟡 **Yarım** — `audit_log` **append-only** (0002, `setup_app_role` REVOKE) ve `kaydeden_user_id` var; finans yazmaları audit'e **bağlanmamış** | §8 |
| **Merkezî** belge numaralandırma | 🔴 **Yok** — `belge_no` serbest metin, üreten kimse yok | §4 |
| Yetki **API seviyesinde** | 🟢 **Var** — her uçta `require_role`; 317 uçluk rol matrisi + `test_yetki_kapsam` kilidi | §6 |
| Not ve ek sistemi **ortak** | 🔴 **Yok** — yalnız `complaint_photo` | Aşama 6.4 (bu belgede değil) |

> Üçü kod işidir ve Aşama 11'in kapsamı **tasarım**. Bu yüzden §4 ve §8
> aşağıda **uygulanabilir ayrıntıda** yazıldı: bir sonraki tur onları
> doğrudan göçe çevirebilir.

---

## 1. SAYAÇ DAĞITIM MOTORU

**Bugün:** `sayac_ana`, `sayac_bolum` tabloları + `/tanimlar` ekranı +
`POST /borclandirma/sayac` var. Eksik olan **dağıtım şeklidir**: ana
sayaçtan gelen toplam tüketimin dairelere hangi kurala göre bölüneceği.

**Veri modeli (yeni 2 tablo):**

```
sayac_donem
  id, tenant_id, sayac_ana_id
  donem_baslangic date, donem_bitis date
  ana_ilk_endeks numeric, ana_son_endeks numeric   -- ana sayaç okuması
  fatura_tutar_kurus bigint                        -- gelen faturanın tutarı
  kayip_kacak_yontem  enum(esit|tuketim_orani|pay_yok)
  durum enum(taslak|dagitildi|borclandirildi)
  UNIQUE (sayac_ana_id, donem_baslangic)

sayac_dagitim_satiri
  id, tenant_id, sayac_donem_id
  sayac_bolum_id, unit_id
  ilk_endeks numeric, son_endeks numeric
  tuketim numeric                                  -- son - ilk
  pay_kurus bigint                                 -- hesaplanan tutar
  kayip_pay_kurus bigint                           -- kayıp/kaçak payı, AYRI
  UNIQUE (sayac_donem_id, sayac_bolum_id)
```

**Dağıtım şekilleri** (`kayip_kacak_yontem` + satır hesabı):

1. **Tüketim oranı** — `pay = fatura × (tuketim / Σtuketim)`.
2. **Eşit** — kayıp/kaçak daire sayısına eşit bölünür, tüketim payı ayrı.
3. **Pay yok** — yalnız kendi tüketimi; fark yönetime gider.

**Kritik tasarım kararı — `kayip_pay_kurus` AYRI SÜTUN.** Tek bir
`pay_kurus`ta toplamak, sakinin "benim tüketimim bu kadar değildi"
itirazını yanıtlanamaz kılardı. İki sütun, faturada iki satır demektir.

**Yuvarlama:** `Σ pay_kurus` **fatura tutarına eşit olmak zorundadır.**
Oransal bölme kuruş artığı bırakır; artık **en büyük tüketimli daireye**
eklenir ve bu kural koda yazılır. Artığı yok saymak, kasa bakiyesini
faturadan farklı kılardı.

**Mevcut şemayla bağlantı:** `durum='dagitildi'` olduğunda mevcut
`POST /borclandirma/sayac` ucu her satır için `dues_assessment` üretir —
**yeni bir borçlandırma yolu yazılmaz.**

**Efor:** 2–3 hafta. **Sıra:** §4'ten sonra (belge no gerekiyor).

---

## 2. CARİ / FİRMA HESAP YÖNETİMİ

**Bugün:** `firma` tablosu + `/tanimlar` kayıt defteri var.
`finansal_hareket.firma_id` **zaten duruyor** ama hiçbir ekran doldurmuyor.

**Veri modeli: YENİ TABLO YOK.** Cari hesap bir **görünümdür**:

```sql
CREATE VIEW firma_cari AS
SELECT firma_id, tenant_id,
       sum(tutar_kurus) FILTER (WHERE yon = 'cikis') AS borc_kurus,
       sum(tutar_kurus) FILTER (WHERE yon = 'giris') AS alacak_kurus
  FROM finansal_hareket WHERE firma_id IS NOT NULL
 GROUP BY firma_id, tenant_id;
```

**Neden görünüm, neden bakiye sütunu değil:** bakiyeyi `firma` tablosunda
bir sütunda tutmak, "bakiye = hareket toplamı" tutarlılığını her yazmada
elle korumayı gerektirir ve bir yolu unutmak **sessiz** bir fark üretir —
tam olarak `finansal_hareket`in tek defter olma gerekçesi.

**Gereken tek şema değişikliği:** `finansal_hareket.firma_id` için FK ve
indeks (bugün ham `uuid`, kısıtsız). Ekstre = `firma_id` filtreli hareket
listesi + yürüyen bakiye (`sum() OVER (ORDER BY tarih, id)`).

**Efor:** 1 hafta (çoğu ekran işi). **Sıra:** en erken — en ucuz kazanç.

---

## 3. İCRA TAKİP SÜRECİ

**Bugün:** `icra_dosyasi` tablosu + 3 uç + BFF beyaz listesi **açık**;
**hiçbir sayfa çağırmıyor** (envanter §0.1.2). Yani modül %100 arka uç.

**Aşama 10'da yapılacak:** ekranı yaz — o **A− kovası işidir**, tasarım
gerektirmez.

**Bu belgenin konusu SÜREÇ:**

```
icra_safha           -- tenant başına yapılandırılabilir safha tanımı
  id, tenant_id, ad, sira, varsayilan_mi

icra_dosya_safha     -- dosyanın safha GEÇMİŞİ (durum sütunu DEĞİL)
  id, tenant_id, icra_dosyasi_id, icra_safha_id
  giris_tarihi, cikis_tarihi, not_metni

icra_masraf          -- avukat/harç/tebligat; PARA HAREKETİ ÜRETİR
  id, tenant_id, icra_dosyasi_id, tur, tutar_kurus, tarih
  finansal_hareket_id   -- gider hareketine BAĞ
```

**Kritik karar — safha bir GEÇMİŞ tablosudur, bir sütun değil.** İcra
süreci "hangi safhadayız" kadar "ne zaman geçtik"le de ilgilidir (zaman
aşımı, faiz başlangıcı). Tek sütun bu bilgiyi silerdi.

**Kritik karar — masraf `finansal_hareket`e BAĞLANIR.** Masrafı yalnız
icra tablosunda tutmak, kasa bakiyesinin dışında ikinci bir para defteri
açardı.

**Efor:** 2–3 hafta. **Sıra:** §2 ve §4'ten sonra.

---

## 4. EVRAK SERİ-SIRA NUMARALANDIRMA (**merkezî**) — ÖNCELİK 1

Brief'in zorunlu ilkesi: *"Belge numaralandırma MERKEZÎ olmalı, her modül
kendi numarasını üretmemeli."*

**Bugün:** `finansal_hareket.belge_no` **serbest metin** ve NULL. Üreten
yok. Yani bugün numaralandırma **yok**, dağınık bile değil.

**Veri modeli:**

```
belge_serisi
  id, tenant_id
  tur enum(borclandirma|tahsilat|gelir|gider|virman|iade|acilis|fatura)
  seri text            -- 'A', '2026'
  sonraki_sira bigint  -- BURADA, uygulamada DEĞİL
  bicim text           -- '{seri}-{sira:06d}'
  UNIQUE (tenant_id, tur, seri)
```

**Numara üretimi VERİTABANINDA, `SECURITY DEFINER` bir fonksiyonda:**

```
belge_no_al(p_tenant_id, p_tur) -> text
  UPDATE belge_serisi SET sonraki_sira = sonraki_sira + 1
   WHERE ... RETURNING format(bicim, seri, sonraki_sira)
```

**Neden `UPDATE ... RETURNING` ve neden `SEQUENCE` değil:**

* `SEQUENCE` **tenant başına** olamaz (her tesis 1'den başlamalı) ve
  **geri sarmaz**; iptal edilen bir numarayı boşlukta bırakır. Mali
  belgelerde numara **kesintisiz** olmalıdır.
* `UPDATE ... RETURNING` satır kilidi alır, yani aynı anda iki tahsilat
  aynı numarayı **alamaz**. Uygulama katmanında `max()+1` okumak tam da
  bu yarışı üretirdi.
* Fonksiyon `SET search_path = ''` taşır ve `REVOKE ... FROM PUBLIC` +
  `GRANT ... TO app_rw` ile açılır — 0041'de `tenant_id_by_kayit_kodu`
  için düzeltilen kuralın aynısı.

**Mevcut şemayla bağlantı:** `finansal_hareket.belge_no` **zaten var**;
yalnız doldurulur. Geçmiş kayıtlar NULL kalır — geriye dönük numara
üretmek, hiç var olmamış bir belgeyi varmış gibi göstermek olurdu.

**Efor:** 1 hafta. **Sıra: İLK.** §1, §3, §7 buna bağlı.

---

## 5. RAPOR MOTORU AYARLARI

**Bugün:** `rapor_motoru.py` — `GET /raporlar/katalog` + `POST
/raporlar/{kod}`, çıktı `tablo|excel|pdf`, `/raporlar` ekranı **çalışıyor**.
Eksik olan **ayar**: hangi kolonlar, hangi sıra, kayıtlı süzgeç.

**Veri modeli:**

```
rapor_ayari
  id, tenant_id, rapor_kodu, ad
  kolonlar jsonb        -- ['daire_no','tutar','son_odeme']
  suzgecler jsonb       -- {'durum': 'odenmedi'}
  siralama jsonb
  paylasilan bool       -- tenant geneli mi, kişiye mi ait
  olusturan_user_id
```

**Kritik karar — `kolonlar` bir BEYAZ LİSTEYE karşı doğrulanır.** Katalog
her rapor için izinli kolon kümesini **kodda** tutar; jsonb'den gelen ad
doğrudan SQL'e girmez. Aksi hâlde rapor ayarı bir SQL enjeksiyon yüzeyi
olurdu. (`panel-vekil.ts`in beyaz liste gerekçesiyle aynı kural.)

**Kritik karar — rapor çıktısı ROL SÜZGECİNDEN geçer.** Kayıtlı bir ayar,
onu oluşturan kişinin göremeyeceği bir kolonu **açmamalıdır**. Süzgeç
rapor motorunda, ayar katmanında değil.

**Efor:** 1–2 hafta. **Sıra:** bağımsız; ne zaman olsa olur.

---

## 6. YAZILABİLİR YETKİ MATRİSİ

**Bugün:** `GET /yetki-matrisi` + `/yetki` sayfası **salt okuma**. Gerçek
zorlama `require_role` ile **her uçta** yapılıyor ve `test_yetki_kapsam`
kilidi matrisi dondurup değişikliği gözden geçirmeye zorluyor.

**Bu, güçlü bir yerdir ve tasarım onu KORUMALIDIR.**

**Öneri: yetki matrisi yazılabilir olsun ama ROL TANIMI değil, ROL
ATAMASI seviyesinde.**

```
tenant_rol_izin
  tenant_id, rol, izin_kodu, acik bool
  UNIQUE (tenant_id, rol, izin_kodu)
```

`izin_kodu` **kodda tanımlı bir sabit kümedir** (`finans.tahsilat.yaz`,
`daire.sil` …). Uç şöyle sorar: `require_role(...)` **ve** `izin_var(...)`.

**Neden serbest izin adı YOK:** panelde yazılan bir dizeyi izin kabul
etmek, bir uçta yazım hatası olduğunda o ucun **sessizce herkese açık**
kalması demektir. İzinler kodda, açık/kapalı durumu veritabanında.

**Neden `require_role` KALIR:** `tenant_rol_izin` yalnız **daraltır**,
genişletmez. Bir tesis yöneticisi kendine `admin` yetkisi veremez. Kilit
budur ve testle zorlanmalıdır.

**Efor:** 2 hafta. **Sıra:** §4'ten sonra, §1/§3'ten önce olabilir.

---

## 7. FATURA KAYDI

**Bugün:** yok. Sayaç dağıtımının girdisi (§1) ve firma cari hareketinin
kaynağı (§2).

```
fatura
  id, tenant_id, firma_id
  fatura_no text, fatura_tarihi date, vade_tarihi date
  tutar_kurus bigint, kdv_kurus bigint
  gelir_gider_tanim_id
  finansal_hareket_id   -- ödendiğinde gider hareketine BAĞ
  sayac_donem_id        -- sayaç faturasıysa (§1)
  durum enum(bekliyor|odendi|kismi|iptal)
```

**Kritik karar — fatura bir PARA HAREKETİ DEĞİLDİR.** Fatura bir
**yükümlülüktür**; para ancak ödendiğinde hareket eder. İkisini tek
tabloda birleştirmek, "borcum var ama ödemedim" durumunu kasa bakiyesine
sızdırırdı. `icra_dosyasi`nın "PARA HAREKETİ DEĞİL, hukuki süreç kaydı"
kararıyla aynı ilke.

**Efor:** 1–2 hafta. **Sıra:** §2 ve §4'ten sonra, §1'den önce.

---

## 8. ÇOKLU SATIR İŞLEM + **TERS KAYIT** (zorunlu ilke)

Brief: *"Finansal kayıtlar SİLİNMEZ; iptal/ters kayıt mekanizması
kullanılır"* ve *"finansal işlemlerde denetim kaydı: kim, ne zaman, ne
yaptı, eski değer, yeni değer."*

### 8.1 Ters kayıt

**Mevcut yarım altyapı:** `iade` tipi + `iade_edilen_id`.

**Öneri — genelleştir, yeni tablo AÇMA:**

* `finansal_hareket.ters_kayit_id uuid` (yeni sütun) — bu hareketi
  **iptal eden** satırı gösterir.
* Yeni `tip = 'iptal'`.
* İptal satırı: aynı tutar, **ters `yon`**, `ters_kayit_id` = iptal edilen.
* **`DELETE` veritabanı düzeyinde engellenir:**
  `REVOKE DELETE ON finansal_hareket FROM app_rw` — `audit_log`un
  append-only yapıldığı yolun (0002, `setup_app_role`) aynısı.

**Neden `DELETE` engelini uygulama katmanına bırakmıyoruz:** bugün hiçbir
uç silmiyor; yarın biri yazarsa kimse fark etmez. Yetkiyi geri almak,
kuralı **kanıtlanabilir** kılar (`test_secdef_kapsam`in yaptığı gibi).

### 8.2 Finansal denetim kaydı

`audit_log` zaten append-only ve `audit_user` yardımcısı **aynı işlemde**
yazıyor (KVKK turu). Gereken: finans yazma yollarının o yardımcıyı
çağırması.

**Kritik karar — eski/yeni değer `meta jsonb`e yazılır, ayrı sütuna
değil.** `audit_log` şeması genel; finans için sütun eklemek onu tek bir
modülün tablosuna çevirirdi. *(Bilinen tuzak: `meta`ya Python `set`
konulamaz — JSON serileşmez.)*

### 8.3 Çoklu satır işlem

**Yeni tablo GEREKMİYOR.** `idempotency_key` + `idem_satir` zaten "bir
işlem = N satır"ı modelliyor (virman 2, toplu tahsilat N). Çok satırlı
gider fişi aynı deseni kullanır: tek `idempotency_key`, artan `idem_satir`.

**Efor:** 1–2 hafta. **Sıra:** §4 ile birlikte — ikisi de defterin
bütünlüğüyle ilgili.

---

## YAPILMA SIRASI (bağımlılıklara göre)

```
1. §4  Merkezî belge numaralandırma        ← her şey buna bağlı
2. §8  Ters kayıt + DELETE kilidi + audit  ← defterin bütünlüğü
3. §2  Cari/firma (görünüm + FK)           ← en ucuz kazanç
4. §7  Fatura                              ← §2 + §4 gerektirir
5. §1  Sayaç dağıtım motoru                ← §4 + §7 gerektirir
6. §3  İcra süreci                         ← §2 + §4 gerektirir
7. §6  Yazılabilir yetki matrisi           ← bağımsız
8. §5  Rapor ayarları                      ← bağımsız
```

**Toplam kaba efor: 11–17 hafta.** Bu, Apsiyon triyajındaki C kovasının
tamamıdır ve **bu turda hiç kod yazılmadı** — Aşama 11'in kuralı budur.

---

## BU AŞAMADA HANGİ ÇAKIŞMAYI ÖNLEDİM

Sekiz tasarımın **beşi yeni tablo istemiyor**: cari bir görünüm (§2),
çoklu satır zaten `idem_satir` (§8.3), ters kayıt tek sütun (§8.1), belge
no mevcut `belge_no` alanını dolduruyor (§4), rapor ayarı çalışan motorun
üstüne biniyor (§5). Bunları "yeni ERP modülü" diye planlamak, çalışan
tek defteri (`finansal_hareket`) ikinci bir defterle çatallandırırdı — ve
o çatal, kasa bakiyesinin kanıtlanabilirliğini bitirirdi.
