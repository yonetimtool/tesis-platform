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
4. **Yetkilendirme matrisi.** Her uç × her rol için 403 beklentisi sistematik
   değil; testler seçilmiş uç/rol çiftlerini kapsıyor. RLS kapsamıyla aynı
   sınıf: *liste tabanlı* ölçüm, *katalog tabanlı* olmalı (uçlar OpenAPI
   sözleşmesinden türetilebilir — `test_sozlesme_sapmasi.py` zaten okuyor).
5. **Sıcak sorgularda indeks kullanımı.** `EXPLAIN` hiçbir ölçümde yok; N+1
   ya da seq-scan regresyonu görünmez.

## Öneri sırası

1. **Yetkilendirme matrisi** (4) — RLS kapsamıyla birebir aynı hata sınıfı ve
   sözleşme dosyası zaten parse ediliyor; en yüksek getiri.
2. **Sıcak sorgu indeksleri** (5) — ölçülebilir, kalıcı çıktı üretir.
3. Canlı prod sürüşü (1) — izin gerektiriyor.
4. Kare bütçesi (2) — ortam kurulumu gerektiriyor.
