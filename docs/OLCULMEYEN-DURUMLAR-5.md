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

## Açık kalanlar

1. **Canlı prod yığın sürüşü** (tur 72'den devir). Prod compose'u yerelde
   (`.localhost` + Caddy iç CA'sı, ayrı proje/volume) kaldırıp TLS, güvenlik
   başlıkları, HTTP→HTTPS ve **presigned PUT/GET zinciri** (Host korunuyor mu
   → s3v4 imzası geçerli mi) ölçülecekti; `up -d --build` izin katmanı
   tarafından engellendi. Statik denetim (`infra/prod-denetimi.py`) yapıldı.
2. **Kare bütçesi / jank.** Gerçek cihaz ya da `flutter drive` + emülatör
   gerektiriyor.
3. **Panel UI birim kapsamı %26,8.** React bileşenlerini jsdom ile test etmek
   ayrı bir altyapı kararı (bilinçli yapılmamıştı).
4. ~~**Yetkilendirme matrisi.**~~ **KAPANDI (tur 74)** — yukarıya bakın.
   Kalan alt katman: **handler içinde role göre içerik daraltma** (aynı uç,
   farklı gövde). Kilit bunu görmüyor.
5. **Sıcak sorgularda indeks kullanımı.** `EXPLAIN` hiçbir ölçümde yok; N+1
   ya da seq-scan regresyonu görünmez.

## Öneri sırası

1. **`SECURITY DEFINER` fonksiyonları.** 0001 migrasyonu owner yetkisiyle
   koşan ve **RLS'i bypass eden** fonksiyonlar tanımlıyor (`tenant_detail`,
   `list_all_tenants`, `update_tenant_*`, `delete_tenant`,
   `create_tenant_with_yoneticis`, `payment_tenant_by_ref`). RLS kapsamı
   ölçümü bunlara BAKMIYOR — politika bypass edildiğinde 48 politikanın
   hiçbiri devrede değil. Her çağırıcının rol kapısı doğrulanmalı.
2. **Sıcak sorgu indeksleri** (5) — ölçülebilir, kalıcı çıktı üretir.
3. Canlı prod sürüşü (1) — izin gerektiriyor.
4. Kare bütçesi (2) — ortam kurulumu gerektiriyor.
