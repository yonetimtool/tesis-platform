# P209 — Gürültü eşiği tipe göre ayrı sayılıyor mu?

## ÖLÇÜM — istenen davranış BÜYÜK ÖLÇÜDE ZATEN VARDI

Koda bakıldı (`app/gurultu_akisi.py`, `app/routers/unit_complaints.py`):

| Soru | Ölçüm | Sonuç |
|---|---|---|
| Sayaç tipe göre mi ayrılıyor? | `acik_gurultu_sayisi` sorgusunda `UnitComplaint.kategori == "gurultu"` filtresi **vardı** | **Ayrılıyordu** — bir tip ötekinin sayacını hiç artırmıyordu |
| Eşik sonrası sıfırlama neyi kapatıyor? | `UPDATE ... WHERE kategori='gurultu' AND durum='acik'` | Yalnız gürültü satırları; görüntü/diğer **kapanmıyordu** |
| Harita/yoğunluk? | `/unit-complaints/density` **kategori filtresi yok** | Tüm tipler sayılıyor — **değişmedi** |
| Eşik hesabı ne zaman çağrılıyor? | Şikayet ucu, **kategori ne olursa olsun** `esik_kontrol` çağırıyordu | Tek gerçek eksik burasıydı |

Yani "5 görüntü şikayeti sesli anons tetikler mi?" sorusunun yanıtı
**hayır**dı — ama bunu söyleyen **hiçbir test yoktu**. Kural doğruydu ve
bir sonraki turda sessizce bozulabilirdi.

**Kategori listesi (gerçek enum, üç değil beş):** `gurultu`,
`goruntu_kirliligi`, `kapi_onu_ayakkabi`, `zarar_verme`, `diger`.
Sesli caydırıcı yalnız `gurultu`ya bağlı; kalan dördü normal şikayet
davranışını sürdürüyor.

## K1 — Kategori kapısı ÇAĞRI YERİNE taşındı

Tek kod değişikliği bu. `esik_kontrol` artık `kategori` alıyor ve
`gurultu` değilse **hemen dönüyor**; uç da `body.kategori`yi geçiriyor.

Davranış aynı (sayaç zaten kategoriye bağlıydı), değişen iki şey:
1. **Kapı okunur oldu**: "sesli caydırıcı yalnız gürültüye bağlıdır"
   cümlesi artık çağrı yerinde görünüyor, fonksiyonun içinde saklı değil.
2. **Boşuna sorgu koşmuyor**: görüntü/diğer şikayetinde beş sorgu
   (tenant, sayaç, susma, entegrasyon, sakin) artık hiç çalışmıyor.

`CAYDIRICI_KATEGORI` sabiti tek kaynak: sayaç, sıfırlama ve kapı aynı
değeri okuyor.

## K2 — P208 kuralları aynen duruyor

30 gün pencere, 7 gün susma, kimliksiz metin, sakin yoksa yalnız
yönetici, denetim kaydı — hiçbiri değişmedi (`test_p208_gurultu_sakin.py`
11 test + `test_gurultu_caydirici.py` 18 test yeşil).

## GÖRÜŞ — diğer tipler için eşik gerekir mi? (UYGULANMADI)

**Kısa yanıt: evet ama farklı biçimde — sesli anonsla değil.**

Gürültü eşiği "anlık, tekrarlayan ve rahatsız edici" bir davranışa
karşı kurulmuştu; sesli anons o yüzden anlamlı. Öteki tipler farklı:

| Tip | Ne anlatır | Önerilen tepki |
|---|---|---|
| `goruntu_kirliligi`, `kapi_onu_ayakkabi` | Süregelen bir **düzen** sorunu (bugün de yarın da orada) | Eşikte **yöneticiye görev/iş emri** — sesli anons değil |
| `zarar_verme` | Tek olayda bile ciddi; sayı beklemek yanlış | **İlk şikayette** yöneticiye bildirim (eşik yok) |
| `diger` | Tanımsız kümedir; ortak bir tepki üretilemez | Eşik **yok**; yalnız haritada birikir |

Gerekçe: ayakkabı için gece anonsu yapmak, aracı gülünç kılar ve gerçek
gürültü anonsunun ciddiyetini de tüketir. Doğru tepki **kalıcı bir iş**
üretmektir (görev + sorumlu + son tarih), anlık bir uyarı değil.

Bir tur ayrılırsa eklenmesi gereken şey: `unit_uyari`ya `kategori`
kolonu. Bugün gerekmiyor — uyarı kaydını **yalnız gürültü** üretiyor, bu
yüzden susma penceresi tipler arasında karışamaz. Ama ikinci bir tip
uyarı üretmeye başlarsa, kolon **eklenmeden** görüntü uyarısı gürültü
uyarısını 7 gün susturur. Spekülatif şema eklemedim; koşulu docs'a
yazdım.

## ÖLÇÜM — akış gerçekten sürüldü

`test_p209_kategori_sayaclari.py` **7 test**, istekteki üç senaryo dahil:

```
5 GÖRÜNTÜ şikayeti      -> uyarı YOK · gürültü sayacı 0 · görüntü satırları DURUYOR (5)
5 DİĞER şikayeti        -> uyarı YOK · gürültü sayacı 0
5 GÜRÜLTÜ şikayeti      -> uyarı VAR (sayaç 5) · sıfırlama YALNIZ gürültüyü kapattı
4 görüntü + 5 gürültü   -> sayaç 5 (9 DEĞİL) · görüntü satırları kapanmadı
3 gürültü + 3 görüntü   -> hiçbiri eşiği aşmadı · altı kayıt da duruyor
gürültü sayacı 5'teyken görüntü şikayeti gelirse -> uyarı ÜRETİLMEZ
harita (density)        -> 5 açık şikayetin HEPSİNİ sayıyor (değişmedi)
```

**Kilit kanıtı:** sayaçtaki kategori filtresi kaldırıldı (tipler
karışsın) → `GORUNTU_SIKAYETLERI_GURULTU_ESIGINI_ETKILEMEZ` ve
`UC_ARTI_UC_hicbir_esigi_ASMAZ` düştü, kalan 23 test geçti. Geri alındı.

**Ölçemediğim:** mobil/web şikayet formundan gönderilen kategorinin uçta
doğru değere düştüğü — testler kategoriyi doğrudan veritabanına yazıyor;
form → uç eşlemesi P24/P147'nin mevcut testlerinde ölçülüyor ve bu turda
dokunulmadı.
