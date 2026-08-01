# Ölçülmeyen durumlar — beşinci envanter (tur 73)

Dördüncü envanter (tur 68) tur 72'de büyük ölçüde kapandı. Bu beşinci envanter
farklı bir soruyla açılıyor: **var olan ölçümler neyi ölçmüyor?** Yani boş
alanları değil, *ölçümlerin kendi kör noktalarını* arıyor.

İlk bulgu bu soruyu doğruladı.

---

## KAPANDI (tur 73) — RLS kapsamı elle yazılmış bir listeyle ölçülüyordu

`backend/tests/test_rls_isolation.py` cross-tenant izolasyonu **davranışsal**
olarak doğruluyor. Ama yalnız elle yazılmış tablolar üzerinde:

```python
@pytest.mark.parametrize("tablo", ["vehicle_pass", "violation"])
```

ve dosyanın kendi yorumu şöyle diyordu:

> "Tablo eklenip `_enable_rls` listesine yazılmayı UNUTMAK sessiz bir
> cross-tenant sızıntısıdır; bu test onu yakalar."

**Yakalamıyordu.** Yeni tabloyu `_enable_rls` listesine yazmayı unutan kişi,
aynı tabloyu bu testin `parametrize` listesine de yazmayı unutur. Ölçüm,
ölçtüğü hatanın *aynısına* maruzdu. Sayıldı: şemada **48 tablo**, testlerin
baktığı **6**.

**Ölçüm sonucu: sızıntı YOK.** 48 tablonun tamamında RLS `ENABLE` + `FORCE`,
her birinde tam bir politika (`polcmd='*'`, hem `USING` hem `WITH CHECK`,
hepsi `app.current_tenant_id` üzerinden), `app_rw` rolünde ne `SUPERUSER` ne
`BYPASSRLS`. `tenant` tablosu tek `tenant_id`'siz tablo ve kendi `id`'si
üzerinden izole.

**Kalıcı çıktı:** `backend/tests/test_rls_kapsam.py` — **hiçbir tablo adı
içermez**. Her şey `pg_class`/`pg_policy` katalogundan okunur; yeni bir tablo
eklenip RLS'i kurulmazsa test kendiliğinden kırmızıya döner. Altı değişmez:

| # | Değişmez | Neden |
|---|---|---|
| 1 | `ENABLE` **ve** `FORCE` | FORCE olmadan tablo *sahibi* politikaları atlar |
| 2 | Politika var, `polcmd='*'`, `USING` + `WITH CHECK` | Yalnız `USING` = okuma korunur, **INSERT ile başka tenant'a yazılabilir** |
| 3 | İfade `app.current_tenant_id` kullanıyor | Sabit/yanlış predicate'i yakalar |
| 4 | `app_rw`: `rolsuper=false`, `rolbypassrls=false` | Aksi halde 48 politika süslemedir |
| 5 | `app_rw` her tabloda `SELECT` yetkili | İzolasyon **yetki yokluğundan** değil politikadan gelmeli; yetkisiz tablo davranışsal testte de "sızıntı yok" görünür (yanlış nedenle yeşil) |
| 6 | Tablo sayısı ≥ 40 | Katalog sorgusu boş dönerse 1–5 **boşa geçer** |

**Dedektörün kendisi sınandı** — geçici bir veritabanına yedi kusur enjekte
edildi, her birinde *doğru* test kırmızı döndü:

| Enjeksiyon | Kırmızı dönen |
|---|---|
| `camera` RLS `DISABLE` | 1 |
| `camera` `NO FORCE` | 1 |
| politika silindi | 2 |
| politika `WITH CHECK`'siz kuruldu | 2 + 3 |
| `REVOKE SELECT ... FROM app_rw` | 5 |
| `APP_DSN` rolü `BYPASSRLS` | 4 (+5) |
| `RLS_TABAN_TABLO=999` | 6 |

Substring tuzağı (kayda geçiyor): oturum değişkeninin **adı**
(`app.current_tenant_id`) `tenant_id` dizgisini içeriyor. İlk koşumda
`tenant` tablosunun doğru politikası yanlış bildirildi; kolon araması artık
değişken adını önce çıkarıyor.

---

## KAPANDI (tur 74) — yetkilendirme, sözleşmeden türetilerek ölçüldü

Aynı hata sınıfı, bir katman yukarıda. Depoda 401 iddiası içeren **26**, 403
içeren **180** satır var — hepsi **elle seçilmiş** uç/rol çiftleri. "Yeni uç
yazıp auth bağımlılığını koymayı unutmak" sessizce public bir uç demektir ve
hiçbir ölçüm bunu aramıyordu.

Sözleşme global `security: [bearerAuth]` ilan ediyor; bir operasyon
`security: []` yazarak public olduğunu **beyan eder**. Bu, elle liste tutmadan
iki yönlü bir değişmez verir.

**Ölçüm: 201 operasyon.** Sonuç: 195'i kimliksiz istekte 401/403 veriyor,
5'i sözleşmede public beyan edilmiş ve gerçekten erişilebilir. **Tek sapma:**
`GET /health` kimliksiz 200 dönüyordu ama beyan edilmemişti — sözleşmeye
`security: []` eklendi (public op 5 → 6). Yani gerçek bir açık uç yok, ama
*beyan ile davranış* arasındaki tek boşluk kapandı.

**İkinci ölçüm — rol matrisi kilidi.** Hangi rolün hangi uca erişeceği
sözleşmede yazılı değil, dolayısıyla "doğru" cevap bilinemez. Ama **değişiklik**
yakalanabilir: 5 rol × 201 operasyon sürüldü ve
`backend/tests/yetki/rol-matrisi.txt` içine kilitlendi (tur 60'taki yerleşim
kilidiyle aynı desen). Dağılım:

| Desen (admin·yönetici·security·görevli·sakin) | Sayı |
|---|---|
| IZIN IZIN RED RED RED (yalnız yönetim) | 79 |
| IZIN IZIN IZIN IZIN IZIN (hepsi) | 36 |
| IZIN RED RED RED RED (yalnız admin) | 24 |
| IZIN IZIN IZIN IZIN RED (sakin hariç) | 18 |
| RED RED RED RED IZIN (yalnız sakin) | 8 |

**Bu ölçümün ölçmediği şey** (ilk kilidin ortaya çıkardığı): `IZIN` "aynı
veriyi görüyor" demek değil. Beş role açık 36 ucun üçünde erişim açık ama
**içerik role göre farklı**: `/reports/financial-summary` `tahsilat` bloğunu
yalnız yönetime ekliyor, `/budget/summary` bilinçli olarak agregat,
`/cameras` sakin/görevli için yalnız aktif+görünür satırları veriyor. Yani
kilit yetkilendirmeyi **erişilebilirlik** düzeyinde kilitler; handler içinde
role göre içerik daraltmayı görmez. O katman ayrı bir ölçüm ister.

Kilit üretimi iki adımlı (imaj kodu bake ediyor): konteynerde üret, `docker
compose cp` ile depoya al. Kopyalamayı atlamak "kilidi güncelledim" sanıp eski
kilidi sürdürmek demektir — dosyanın başında yazılı.

## KAPANDI (tur 75) — `SECURITY DEFINER` yüzeyi: izolasyonun tek gerçek deliği

Tur 73'ün ölçümü 48 tablonun politikalarını doğruladı — ama `SECURITY DEFINER`
fonksiyonlar o politikaların **tamamını** atlar: owner yetkisiyle koşarlar ve
owner'da `rolbypassrls=true`. Yani bu fonksiyonlar çok-kiracılı izolasyonun tek
gerçek deliği ve tur 73 onlara **hiç bakmıyordu**.

Sayıldı: **13 fonksiyon**. Üç bağımsız hata sınıfı ölçüldü, üçü de **temiz**:

| Ölçüm | Sonuç |
|---|---|
| `search_path` sabitlenmiş mi (klasik SECURITY DEFINER açığı) | 13/13 `search_path=""` |
| `EXECUTE` PUBLIC'e açık mı | hiçbiri; yalnız owner + `app_rw` |
| Çağıran ucun rol kapısı | 10'u `require_role("admin")`, 3'ü bilinçli kimlik-öncesi |

Kimlik-öncesi üçü: `tenant_id_by_slug` / `tenant_id_by_phone` (girişte kullanıcı
henüz kimliklenmemiş, tenant'ı çözmek için bypass şart; ikisi de yalnız bir uuid
döner) ve `payment_tenant_by_ref` (imzayla doğrulanan sağlayıcı webhook'u).

**Kalıcı çıktı:** `backend/tests/test_secdef_kapsam.py`. Katalogdan
(`pg_proc.prosecdef`) türer ve dosyadaki **ENVANTER** ile iki yönlü
karşılaştırır: envanterde olmayan yeni bir `SECURITY DEFINER` fonksiyonu
şemaya giremez, envanterde olup şemada olmayan kayıt da ölü sayılır. Envanter
süsleme kalmasın diye `admin` kapısı **davranışsal** olarak da doğrulanıyor:
yönetici rolü, o on ucun her birinde **başka tenant'ın id'siyle** 403 alıyor.

**Dedektörler ayrıştırılarak sınandı** (geçici veritabanı):

| Enjeksiyon | Kırmızı dönen |
|---|---|
| `search_path`'siz + PUBLIC `EXECUTE` + envanter dışı fonksiyon | 1 + 2 + 3 |
| `search_path` sabit, PUBLIC `EXECUTE` | 2 + 3 |
| `search_path` sabit, `EXECUTE` PUBLIC'ten alınmış | yalnız 3 |

Sondanın "her şeye 403 diyor" olmadığı da gösterildi: aynı yönetici token'ı ile
`GET /audit` → 403, `GET /support` → 200.

**Bu ölçümün ölçmediği şey:** `admin` bu uçlarda tenant sınırını **bilinçli**
geçer (panelin işi tam olarak bu). Ölçülen şey admin'in kısıtlanması değil,
admin *olmayan* hiçbir rolün bu yüzeye erişememesi.

## KAPANDI (tur 76) — yabancı anahtar indeksleri; ve ölçüm aracının kendisi üç kez yanlıştı

Postgres bir yabancı anahtar tanımlarken **referans eden** taraf için indeks
oluşturmaz. İndeks yoksa üst satır silinince RI tetiği referans eden tabloyu
seq scan eder (`delete_tenant` 47 tabloya dokunuyor) ve o kolon üzerinden her
join veri büyüdükçe doğrusal yavaşlar. Veri küçükken **görünmeyen** bir sınıf.

**Ölçüm (108 yabancı anahtar):** 69'unun kolon *kümesini* tam kapsayan indeksi
var, 39'unun **öncü kolonunu** kapsayan indeksi var (hepsi `(<x>_id, tenant_id)`
biçimi bileşik FK; `(<x>_id)` üzerindeki tek-kolon indeks RI sorgusunda
kullanılır, kalan kolon filtreyle elenir), **0 tanesi indekssiz**. Kusur yok;
`backend/tests/test_indeks_kapsam.py` durumu kilitliyor — yeni bir FK
indekssiz eklenirse test kırılır (enjeksiyonla doğrulandı: indekssiz FK →
kırmızı, indeks eklenince → yeşil).

**Bu turun asıl bulgusu ölçüm aracıydı.** Sorgu üç kez yanlış yazıldı:

1. **İlk hâli sıra-duyarlıydı** — `(a,b)` FK'sını yalnız `(a,b)` sıralı indeks
   karşılıyor sandım. Oysa RI sorgusu `WHERE a=$1 AND b=$2`, yani küme yeter.
2. **Küme karşılaştırmasına geçtim, sayı değişmedi (78/108)** — bu bir uyarı
   işaretiydi ve ilk anda öyle okumadım.
3. **Gerçek hata:** `pg_index.indkey` bir `int2vector`'dür ve dizi olarak
   **0-tabanlıdır**. `(indkey::int2[])[1:n]` yazmak **ilk kolonu atlar**. Doğru
   dilim `[0:n-1]`. Bu off-by-one, "108 FK'nin 78'i indekssiz" gibi tamamen
   uydurma ama tamamen makul görünen bir sayı üretti.

Yakalanmasının tek yolu **tek bir satırı elde doğrulamak** oldu: `scan_event`
için `pg_indexes`'e bakıldığında `ix_scan_tenant ON (tenant_id)` apaçık
duruyordu, oysa araç o FK'yı "indekssiz" diye bildiriyordu. Yani sayıyı değil,
sayının bir örneğini bağımsız kaynakla karşılaştırmak kurtardı — tur 69'daki
(erişim günlüğü ile kapsam raporu) ve tur 68'deki (bilinen-test-edilmiş dosya)
aynı yöntem.

Not: **indeks kullanımı** (EXPLAIN, gerçek veri hacmiyle) hâlâ ölçülmedi.
Şemada indeks *var mı* sorusu ile sorgunun onu *kullanıyor mu* sorusu ayrı;
ikincisi temsil edici hacim gerektiriyor.

## KAPANDI (tur 77) — indeks KULLANIMI: `/activity` tek istekte 350.000 satır okuyordu

Tur 76 şemadaki indeksleri doğruladı ama **kullanımı** ölçmedi. Dev
veritabanında ölçmek işe yaramaz: tablolarda 2–8 satır var ve o hacimde
Postgres zaten seq scan seçer — orada tam tarama kusur *değildir*. Bu yüzden
tek-kullanımlık bir veritabanına **762.555 satır** sentetik hacim yazıldı,
API'nin geçici bir örneği ona yönlendirildi ve tüm GET uçları sürülerek
`seq_tup_read` sayaçları **uca atfedildi**.

**BULGU — `GET /activity` tek istekte 350.000 satır okuyordu.** 13 kaynak
`UNION ALL` ile birleşiyor ve `LIMIT` **yalnız dış sorguda** uygulanıyordu;
Postgres her kaynağın tamamını materyalize edip sıralıyordu.
`EXPLAIN ANALYZE`: `Parallel Seq Scan on scan_event`, top-N heapsort tüm
birleşim üzerinde, 21 satır döndürmek için 350.000 satır üretiliyor. Bu, mobil
ana ekranın akış ucu.

**Düzeltme:** sıralama + `LIMIT` her dala itildi. Doğruluk argümanı:
`(zaman, id) DESC` sıralamasında global ilk N satırın her biri, kendi dalının
aynı sıralamadaki ilk N'i içinde olmak *zorundadır*. Ayrıca dal sıralaması
**indekslenebilir kolonlara** çevrildi — `tur || ':' || id::text` ifadesi hiçbir
indeksin sağlayamadığı bir anahtardı ve asıl engel buydu. Eksik altı dal
indeksi migrasyon **0009** ile eklendi.

**Sonuç:** aynı ölçüm sonrasında 3 istek toplam **4 satır** sıralı okuma;
`scan_event` 200.000 seq → 22 satır indeks getirmesi. `/activity` listeden düştü.

Üç kolonlu indeks *gerekmedi* ve bu ölçüldü: iki kolonlu indeks tam sırayı
vermez, Postgres `Incremental Sort` ile tamamlar; planlayıcı bunu küçük tabloda
maliyetli bulup seq scan seçse de tablo büyüdükçe kendiliğinden çevirir
(`dues_payment` 50 binde seq scan, 200 binde `Incremental Sort + Index Scan`).
13 tabloya üçüncü kolon eklemenin yazma maliyeti bu yüzden alınmadı.

### Ölçülen ama DEĞİŞTİRİLMEYEN: `meta.total` O(tablo)

Kalan beş uç bir tam tarama yapıyor ve **mekanizma tek**: sayfalı liste uçları
`select(func.count()).select_from(X).where(...)` ile **tam sayım** yapıyor.

| Uç | Sıralı okunan | Tür |
|---|---|---|
| `/dues/payments` | 200.000 | liste + total |
| `/reports/financial-summary` | 200.000 + 12.000 | agregat (SUM) — tam tarama **doğru plan** |
| `/notifications` | 100.000 | liste + total |
| `/tasks` | 100.000 | liste + total |
| `/dues/assessments` | 24.000 | liste + total |
| `/transparency` | 12.000 | agregat |

`meta.total` bir **API sözleşmesi özelliği**; kaldırmak ya da yaklaşık sayıma
çevirmek istemci davranışını değiştirir. Tek taraflı değiştirilmedi — ölçümle
bildiriliyor. (İlginç olan, `/activity`in kendi docstring'inin `meta.total`ı
"13 kaynağın birleşik sayımı her istekte tam tarama demektir" diye **bilinçli
olarak dışarıda bıraktığını** yazması: aynı gerekçe diğer liste uçlarında
uygulanmamış.)

**Kalıcı çıktı:** `infra/tarama-olcumu.sh` + `infra/hacim-verisi.sql` — ölçüm
tek komutla yeniden koşulabilir. Ve `backend/tests/test_activity_sayfalama.py`:
eşit zamanlı olaylarda sayfalama kaybı/tekrarı arar.

**İki ölçüm tuzağı kayda geçti:**

1. **`pg_stat` flush yarışı.** Sayaçlar asenkron yazılır (~500 ms). Reset ile
   istek arasında beklenmezse bir ucun taraması *başkasına* atfedilir. İlk
   koşumda `/dues/payments` 125.754 + `/budget/categories` 74.246 = tam
   200.000 çıktı — bir tablonun tamamı iki uca **bölünmüş** görünüyordu.
   Beklemeler eklenince `/budget/categories` listeden düştü.
2. **Dedektörün kendisi kördü.** Sayfalama testi ilk hâlinde `ADET=5` eşit
   zamanlı olayla kuruluyordu ve dal sıralamasından tie-break'i **kaldırdığım
   deneyde bile yeşil kaldı** (5 eşitten keyfi 3'ü tesadüfen doğru sırayla
   çakışıyordu). `ADET=40` ile aynı deney **59 olayın kaybolduğunu** gösterdi.
   Ayrıca ilk muhakememde "kayıp olmaz, yalnız sıra bozulur" demiştim; deney
   bunun da yanlış olduğunu gösterdi.

## KAPANDI (tur 78) — hacim kapsamı 8 tablodan **tüm şemaya**; `/dashboard/live` 200.000 satır okuyordu

Tur 77'nin ölçümü yalnız 8 tabloya hacim yazıyordu. Kalan ~40 tablo **boştu** ve
boş tabloda tam tarama 0 satır okur — yani o uçlar için "bulgu yok" **kanıt
değildi**. `infra/hacim-uret.py` şemayı kendisi okuyup eksik tabloları
dolduruyor: FK bağımlılıklarına göre topolojik sıra, ebeveyn id'lerinden dizi
indeksiyle FK değerleri (satır başına alt sorgu O(N×M) olurdu), gerçek enum
etiketleri, açıkça dağıtılmış zaman damgaları. **Boş kalan tablo: yok.**

Kapsam genişleyince yeni bir sınıf çıktı — ve bu `meta.total` sınıfından
farklıydı:

**`GET /dashboard/live` tek istekte 200.000 `scan_event` okuyordu.** Panelin
*pollanan* canlı özeti. `_AKTIF_TURLAR_SQL` okutmaları
`s.checkpoint_id = c.id AND s.okutma_zamani ∈ [pencere)` ile birleştiriyor;
mevcut indekslerden `ix_scan_checkpoint (checkpoint_id)` zaman aralığını
taşımıyor (bir checkpoint'in tüm geçmişini getirir),
`ix_scan_okutma_zamani (tenant_id, okutma_zamani)` checkpoint'e göre
daraltmıyor. Planlayıcı bu yüzden tabloyu tamamen tarıyordu.

Migrasyon **0010**: `(tenant_id, checkpoint_id, okutma_zamani)`.

| | seq scan | Index Only Scan |
|---|---|---|
| 200 bin okutma, 1434 pencere | **784,9 ms** | **43,7 ms** (~18×) |

Aynı erişim deseni **üç yerde**: `dashboard.py` (pollanan), `me_patrol.py`
(görevlinin penceresi) ve `scheduler/service.py` (periyodik pencere tespiti,
checkpoint *başına* aralık sorgusu). Tek indeks üçünü karşılıyor.

Ölçüm sonrası: `/dashboard/live` **0**, `/patrol-windows` 200.000+60.000 → **0**.

**Kalan 29 ucun karakterizasyonu** (kusur listesi *değil*): hiçbiri artık kendi
dışındaki büyük bir tabloyu sıralı okumuyor. Hepsi ya (a) `meta.total` için tam
`COUNT` — ürün kararı, tur 77'de bildirildi — ya da (b) 20 binlik boyut
tablolarına hash join (kategori, ortak alan, plan-checkpoint). İkisi de bu
boyutlarda doğru plan; ikisi de doğrusal büyüyor.

**Üreticinin sınırı açıkça yazılı:** rastgele CHECK kısıtlarını genel bir üretici
sağlayamaz. Üretilen dosya `ON_ERROR_STOP` kullanmaz; kısıtı karşılanamayan
tablo atlanır ve betik **atlananları listeler**. İlk koşumlarda beş tablo
takıldı (`ck_*_ceviri_dil`, `ck_vehicle_pass_plaka`, `ck_rezervasyon_aralik`,
`ck_etkinlik_bitis`) ve alan-özel ipuçlarıyla (dil listesi, plaka formatı,
"bitiş" kolonlarına ileri damga) kapatıldı.

**Üreticinin kendi hatası kayda geçiyor:**
`information_schema.constraint_column_usage` bileşik FK'larda kolon
**çiftleşmesini korumaz**. `(olusturan_user_id, tenant_id) REFERENCES
app_user(id, tenant_id)` kısıtında adla eşleştirmek `tenant_id`'yi
`app_user.tenant_id`'ye bağlıyor, `olusturan_user_id`'yi ise hiçbir şeye — ilk
üretimde o kolona `gen_random_uuid()` yazıldı. Doğru eşleme
`pg_constraint.conkey`/`confkey` **sıralarından** gelir.

## Açık kalanlar

1. **Canlı prod yığın sürüşü** (tur 72'den devir). Prod compose'u yerelde
   (`.localhost` + Caddy iç CA'sı, ayrı proje/volume) kaldırıp TLS, güvenlik
   başlıkları, HTTP→HTTPS ve **presigned PUT/GET zinciri** (Host korunuyor mu
   → s3v4 imzası geçerli mi) ölçülecekti; `up -d --build` izin katmanı
   tarafından engellendi. Statik denetim (`infra/prod-denetimi.py`) yapıldı.
2. **Kare bütçesi / jank.** Gerçek cihaz ya da `flutter drive` + emülatör
   gerektiriyor.
3. ~~**Panel UI birim kapsamı %26,8.**~~ **ALTYAPI KURULDU (P43, tur 89)**:
   jsdom + Testing Library, aynı koşumda iki ortam (`node` + dosya başındaki
   `@vitest-environment jsdom`). Kurulum üç gerçek engelde ölçümle ilerledi:
   `@vitejs/plugin-react` **`next build`i kırdı** (test bağımlılığı ürün
   derlemesini kıramaz → JSX yerine `createElement`); `esbuild` anahtarı yok
   sayılıyor (Vitest 4 = rolldown/**oxc**); **SWR önbelleği testler arası
   taşınıyordu** ve "uç düştü" senaryosu yanlışlıkla geçiyordu.
   **Kapsam sayısı:** ifade **%9,66 (322/3 330)** — %26,8'den *düşük* çünkü
   payda P40'ın ~2 000 ifadesiyle büyüdü. Bu turda eklenen şey altyapı + en
   yeni üç sayfanın davranış testleridir; kapsamı yükseltmek ayrı ve sürekli
   bir iştir.
4. ~~**Yetkilendirme matrisi.**~~ **KAPANDI (tur 74)** — yukarıya bakın.
   ~~Kalan alt katman: **handler içinde role göre içerik daraltma** (aynı uç,
   farklı gövde).~~ **KAPANDI (P42, tur 88)**:
   `backend/tests/test_icerik_daraltma.py` altı daraltmayı tek tek sürüyor
   (finansal özet `tahsilat` bloğu, `/activity` kaynak kümesi, gizli kamera,
   kendi-kapsamlı talepler, anket sonucu, harita sayım/renk). Aynı turda
   **latent bir 500 tuzağı** bulundu: `/activity` kaynak kümesini
   `_ROL_KAYNAKLARI[user.role]` ile seçiyor ve uca yeni bir rol eklenip
   sözlüğe satır eklenmezse `KeyError → 500` dönerdi — yetki kilidi 500'ü
   "IZIN" saydığı için hiçbir ölçüm bunu yakalamazdı. Artık `require_role`un
   `izinli_roller` özniteliğiyle (P41) doğrulanıyor.
   **Ölçümün sınırı:** kapsam otomatik değil; "hangi uç daraltmalı" bir ürün
   kararı olduğu için dosya bir envanterdir.
5. ~~**Sıcak sorgularda indeks KULLANIMI.**~~ **KAPANDI (tur 77)** — yukarıya
   bakın. Kalan: `meta.total` tam sayımı (ürün kararı) ve hacmin yazılmadığı
   40 tablo — o uçlar için "bulgu yok" kanıt değil.

## Öneri sırası

1. ~~`SECURITY DEFINER` fonksiyonları~~ — **kapandı, tur 75**; üçü de temiz.
2. **`meta.total` kararı** — beş liste ucunda tam sayım O(tablo). Yaklaşık
   sayıma geçmek ya da `total`ı kaldırmak istemci sözleşmesini değiştirir;
   karar kullanıcıya ait.
3. ~~Hacim kapsamının genişletilmesi~~ — **kapandı, tur 78**; boş kalan tablo
   yok, `/dashboard/live` bulgusu bu sayede çıktı.
4. Canlı prod sürüşü (1) — izin gerektiriyor.
5. Kare bütçesi (2) — ortam kurulumu gerektiriyor.
