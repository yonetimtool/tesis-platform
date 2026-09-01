# P192 — Finans tutarlılığı ve otomasyon: kararlar ve gerekçeleri

Kaynak: `docs/finans-analiz.md` (P191 sonrası okuma turu).
Bu belge **ne yapıldığını değil, neden öyle yapıldığını** yazar. Ne
yapıldığı `docs/P192-dagitim.md`de; nasıl test edileceği
`docs/P192-test-yolharitasi.md`de.

---

## Bölüm 1 — Tek defter

### Karar: tek doğru kaynak `finansal_hareket` (para) + `dues_assessment` (borç)

Üç aday vardı ve üçü de aynı parayı yazıyordu:

| İşlem | `dues_payment` | `finansal_hareket` | `budget_entry` |
|---|---|---|---|
| `POST /dues/payments` | yazar | YAZMAZ | yazar |
| `POST /finans/tahsilat` (vezne) | YAZMAZ | yazar | YAZMAZ |
| Banka eşleştirme | yazar | yazar | YAZMAZ |

`finansal_hareket` seçildi çünkü diğer ikisinin **yapamadığı** şeyleri
zaten yapıyor:

* **Kasa bağı var** (`kasa_id`) — kasa bakiyesi ondan türetiliyor.
  `dues_payment`in kasa kavramı yoktu; kabul ölçütü 2'nin ("aidat ödemesi
  kasayı artırsın") başka türlü karşılanması mümkün değildi.
* **Silinemez.** `app_rw`nin DELETE yetkisi göç 0047'de geri alındı.
  `budget_entry` DELETE edilebiliyordu — bir para defteri için yanlış.
* **Düzeltme yolu modellenmiş:** `ters_kayit_id` (iptal, kayıt düzeltmesi)
  ve `iade_edilen_id` (iade, gerçek para dönüşü) **ayrı** alanlar.
* **Merkezi belge no** (`belge_no`) ve **idempotency** (`idempotency_key`,
  `idem_satir`) taşıyor.
* **Onay durumu** (`durum`) taşıyor.

Diğer ikisi bunların hiçbirini birlikte taşımıyordu; ikisi de
`finansal_hareket`in eksik birer kopyasıydı.

**Borç ayrı kaldı ve bu bilinçli.** `dues_assessment` bir *borç*tur, para
hareketi değildir. Bakiye = tahakkuk − ödenen; iki tablodan gelmesi
doğrudur, çünkü bir borç ile onu kapatan para aynı satır değildir.

### "Ödenen" tek bir yerde tanımlı

`app/defter.py::tahsilat_etkisi()`. Kural:

```
odenen = Σ işaret(yon) × tutar
         tip = 'tahsilat'                                   -> +
         tip ∈ ('iade','iptal') VE ilgili satır tahsilat    -> −
         yalnız durum = 'odendi'
```

İki tuzak vardı:

1. **Yön üzerinden ayırmak yetmezdi.** Bir *gelir iptali* de `cikis`
   yönlüdür; tahsilattan düşülseydi tahsilat toplamı yanlış çıkardı. Bu
   yüzden iade/iptal satırı, iptal ettiği satıra JOIN edilip onun tipine
   bakılıyor.
2. **Eski iade/iptal satırları borç atfı taşımıyordu.** `coalesce` ile
   atıf orijinal satırdan tamamlanıyor; ayrıca `/finans/iade` ve
   `/finans/hareketler/{id}/iptal` artık `assessment_id` + `donem`
   kopyalıyor. Kopyalamasaydı para kasadan çıkar, borç kapalı kalırdı —
   sakin ödemediği bir borcu ödenmiş sanırdı.

### Yanıt biçimleri korundu

`DuesPaymentOut` ve `BudgetEntryOut` aynen duruyor; defter satırı bu
biçimlere **çevriliyor** (`dues.py::_odeme_out`, `budget.py::_entry_out`).
Defteri tek kaynak yapmak bir **iç** karardır; mobil ve paneli aynı turda
kırmak değişimi gereksizce riskli kılardı.

Üç alan opsiyonelleşti (`unit_id`, `kaydeden_user_id`, `idempotency_key`,
`kategori_id`) çünkü defterde de opsiyoneller: vezneden girilen bir
tahsilat daireye bağlı olmayabilir.

### Aidat tahsilatı hâlâ "gelir"dir

Eskiden başarılı aidat ödemesi `budget_entry`e `kaynak='aidat_odeme'` bir
gelir satırı üretirdi ve şeffaflık raporunun "toplam gelir"i onu
içeriyordu. Tek deftere geçerken bu davranış **korundu**:
`defter.GELIR_TIPLERI = ('gelir', 'tahsilat')`. Dışarıda bıraksaydık
sitenin geliri bir gecede aidat kadar düşük görünürdü.

Kategori de korundu: `/dues/payments` ve banka eşleştirme, tahsilat
satırına `budget_category_id = "Aidat"` yazıyor (get-or-create). Böylece
bütçe kırılımı eskisi gibi çalışıyor ama **ayrı bir satır** üretmiyor.

### Banka eşleştirme artık pay başına satır yazıyor

P191'de bir transfer üç ayı kapatsa bile deftere **tek** satır yazılıyor,
borç kapanışı `dues_payment`te üç satırla izleniyordu. Tek defterde bu
mümkün değil: her pay kendi tahsilat satırını alıyor
(`idem_satir = 1..N`, aynı `idempotency_key`). Toplamları transferin
tutarına eşit olduğu için **kasa bakiyesi şişmiyor**, buna karşılık her
ayın kapanışı ayrı ayrı izlenebiliyor.

### DELETE artık ters kayıt

`DELETE /budget/entries/{id}` satır **silmiyor**, tam tutarlı bir ters
kayıt yazıyor (yanıt yine 204). Defterde DELETE yetkisi yok ve olmamalı:
silme, "bu para nereye gitti" sorusunu cevapsız bırakırdı. Listeler iki
satırı da göstermiyor (`defter.iptal_edilmis()`), toplamlar zaten
işaretle götürüyor.

### Göç 0083 geri alınabilir

Taşınan her satır `goc_kaynak` (`dues_payment` | `budget_entry`) ve
`kaynak_id` taşıyor; `downgrade()` tam olarak onları siliyor. Kaynak
tablolar **silinmedi**, yalnız yazılmaz oldu — geri dönüşte veri yerinde.

İki bilinçli sınır:

* `durum='iptal'` ödemeler taşınmadı: hiçbir zaman para hareketi
  olmamışlardı (kart sağlayıcıdan başarısız döndü).
* `kaynak='aidat_odeme'` bütçe satırları taşınmadı: aynı parayı ikinci
  kez yazarlardı — ödemenin kendisi zaten `tahsilat` olarak taşınıyor.

Kasası olmayan tesislere `KASA / Merkez Kasa` açıldı. Alternatif
`kasa_id=NULL` bırakmaktı; o zaman para defterde görünür ama **hiçbir kasa
bakiyesinde** görünmezdi — §2.1'in düzelttiği kusurun aynısı.

### `hareket_durum`a `iptal` eklendi

Kart ödemesi sağlayıcıdan başarısız dönünce satır `bekliyor`da kalsaydı,
hiçbir zaman gelmeyecek para sonsuza kadar "bekleyen tahsilat" görünürdü.

---

## Bölüm 2 — Kasa tutarlılığı

### 2.1 Banka hesabı = `banka_mi` olan kasa, ayrı bir tablo değil

Yeni bir `bank_account` tablosu **açılmadı**. `kasa` zaten `banka_mi`,
`iban`, `banka_adi`, `sube` taşıyor ve bir CHECK bu alanların yalnızca
banka kasasında dolmasını zorluyor. İkinci bir tablo, "bakiye nereden
hesaplanıyor" sorusunu ikiye bölerdi — Bölüm 1'in düzelttiği hatanın
aynısı.

Eksik olan şey **ekstrenin hangi hesaba ait olduğuydu**. Göç 0084
`bank_transaction.kasa_id` ekliyor; `/banka/ice-aktar` artık `kasa_id`
alıyor ve eşleştirme parayı **o hesaba** yazıyor. Bir tesisin iki banka
hesabı olabilir (site hesabı + demirbaş hesabı); ikisinin ekstresini aynı
kasaya yazmak bakiyeleri tek sayıya karıştırmak olurdu.

FK `ON DELETE SET NULL`: bir kasa kapatılırsa geçmiş ekstre satırları
kaybolmamalı. `RESTRICT` olsaydı kullanılmış bir kasa hiç silinemezdi.

### 2.2 Bakiye yalnız gerçekleşmiş hareketi sayar

`kasa_bakiyeleri` `durum` süzgeci **uygulamıyordu**. Onay bekleyen bir
gider ve sağlayıcıdan dönmemiş bir kart ödemesi bakiyeye anında
yansıyordu; yönetici onaylamadığı bir ödemeyi kasadan düşülmüş görüyordu.

Artık `bakiye = açılış + Σ(durum='odendi')`. Bekleyen tutar **kaybolmuyor**,
ayrı dönüyor: `bekleyen_cikis_kurus` / `bekleyen_giris_kurus` +
`bekleyen_cikis_toplam_kurus`. "Bakiye X, bekleyen Y" tek rakamdan daha
doğru bir tablo. Panelde de ayrı sütun.

`iptal` durumundakiler **bekleyende de yok**: gerçekleşmeyeceği belli olmuş
bir hareketi beklentide tutmak, hiç gelmeyecek parayı yöneticiye vaat
etmek olurdu.

Aynı süzgeç `rapor_motoru`nun kasa mutabakat raporuna da eklendi; yoksa
mutabakat tablosu ile kasa ekranı ayrışırdı. (Orada `docs/finans-analiz.md`nin
raporladığı bir **ölü satır** da temizlendi: sorgu çalıştırılıp sonucu
`and []` ile atılıyordu.)

### 2.3 Onay = gerçekleşti, red = hiç olmadı

`durum='onay_bekliyor'` P167'de eklendi, panel sayıyordu, **onaylayan uç
yoktu**. İki uç eklendi:

* `POST /finans/hareketler/{id}/onayla` → `odendi`. Hareket o an kasa
  bakiyesine girer.
* `POST /finans/hareketler/{id}/reddet` → `iptal`.

Red neden **ters kayıt değil**: ters kayıt *gerçekleşmiş* bir hareketi
düzeltir. Reddedilen gider hiç gerçekleşmedi, kasadan hiç çıkmadı. Ters
kayıt yazsaydık defterde birbirini götüren iki sahte satır olurdu.

Satır **silinmiyor**: "bu harcama talebi reddedildi" bilgisi denetimin
konusudur; silinirse bir daha sorulamaz. İki uç da ayrı denetim eylemi
yazıyor (`finans_hareket_onay` / `finans_hareket_red`) — "kim girdi" ile
"kim onayladı" aynı kayıtta toplanırsa onayı verenin kim olduğu denetimde
cevapsız kalırdı.

Ayrıca özet kartındaki "Borçlarım" sorgusu `durum != 'odendi'` diyordu;
`iptal` eklenince reddedilmiş bir harcama "borcum var" diye sayılacaktı.
`in ('bekliyor','onay_bekliyor')` olarak düzeltildi.
