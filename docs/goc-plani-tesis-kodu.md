# GÖÇ PLANI — mevcut kullanıcıların geçişi (AŞAMA 2)

> Brief: *"Mevcut tesislere kural gereği ID üret. Mevcut kullanıcılar mevcut
> kimlik bilgileriyle girmeye devam etsin. Göç geri alınabilir olsun. Göç
> planını UYGULAMADAN ÖNCE raporla."*
>
> **Bu belge planı uygulamadan önce yazıldı ve ilk bulgusu şudur: göç
> zaten yapılmış.**

---

## 1. ÖLÇÜM — bugünkü durum

Çalışan geliştirme veritabanında ölçüldü (46 tesis):

| Ölçüm | Sonuç |
|---|---|
| `kayit_kodu` NULL olan tesis | **0** |
| Sütun kısıtı | `NOT NULL` |
| Benzersizlik | `uq_tenant_kayit_kodu UNIQUE (kayit_kodu)` |
| Üretim kuralı | `public.kayit_kodu_uret(ad, tarih)` + `BEFORE INSERT` tetikleyicisi |

**Sebep:** göç `0037_akilda_kalir_tesis_kodu` (P148.1) yalnız kuralı
kurmakla kalmamış, **mevcut tüm tesisleri de doldurmuş**:

```sql
WITH y AS (
    SELECT id, public.kayit_kodu_uret(ad, created_at::date) AS taban,
           row_number() OVER (PARTITION BY ... ORDER BY created_at, id) AS sira
    FROM tenant)
UPDATE tenant t SET kayit_kodu = CASE WHEN y.sira = 1 THEN y.taban
                                      ELSE y.taban || '-' || y.sira::text END
  FROM y WHERE y.id = t.id;
```

Yani Aşama 2'nin "mevcut tesislere ID üret" işi **P148.1'de tamamlandı**.
Yeniden yazılmadı — bu, Aşama 0'ın çakışma haritasındaki
*"Aşama 1 sahibi, Aşama 3 okur"* kuralının ikinci uygulamasıdır.

---

## 2. KARAR — eski biçimli kodlar YENİDEN ÜRETİLMEYECEK

Ölçümde 46 tesisin 19'unun kodu **eski sıralı ek** taşıyor
(`OLTU-260715-2`, `SINA-260807-3` …). P154 çakışma ekini rastgeleye
çevirdi (kilitli kural 3). Soru: bunlar yeni biçime dönüştürülsün mü?

**HAYIR.** Gerekçe:

1. **Kod bir tanımlayıcıdır ve dışarıya verilmiştir.** Sakin, kaydolurken
   tesis kodunu **telefonda elle yazar**. Kodu değiştirmek, dün verilen
   kodun bugün tutmaması demektir; destek çağrısı üretir ve kayıt akışını
   sessizce kırar.
2. **Eski biçim yanlış değil, sadece eski.** `OLTU-260715-2` kilitli kural
   3'ün ana biçimine (`ilk 4 harf + '-' + YYAAGG`) uyar; farklı olan
   yalnız çakışma ekidir ve o ek zaten **nadir** bir yoldur.
3. **Geri alınamaz olurdu.** Yeniden üretim rastgele ek kullanır;
   `downgrade` eski değeri **geri getiremez** çünkü rastgele sayı
   kaydedilmemiştir. Bu, brief'in "göç geri alınabilir olsun" şartını
   ihlal ederdi.

Bu karar koda **yazılı olarak** gömülü: `tenant_kayit_kodu_ata()` yalnız
`BEFORE INSERT` ve yalnız `kayit_kodu IS NULL` iken çalışır; göç 0041
0037'nin dolgu `UPDATE`'ini **tekrar koşturmaz**.

> Ölçülen 19 kayıt hepsi geliştirme/test artığıdır (`Sinama t-…`,
> tekrar eden `Oltu Sitesi`). Üretimde eski ekli kod olup olmadığı
> **ölçülemedi** — geliştirme makinesinden canlıya erişim yok (yalnız
> 80/443). Karar her iki durumda da aynı olduğu için bu bir engel değil.

---

## 3. KİLİTLİ KURAL 1 — mevcut kullanıcılar erişim kaybetmez

**Neden kaybetmiyorlar:** `tenant.kayit_kodu` bir **kimlik bilgisi
değildir**. Giriş yollarının hiçbiri onu okumaz:

| Giriş yolu | Anahtar | `kayit_kodu` okunuyor mu |
|---|---|---|
| `POST /auth/login` (web) | `tenant_slug` + `email` + `password` | **hayır** |
| `POST /auth/login-phone` (mobil) | `phone` (global benzersiz) + parola/geçici kod | **hayır** |
| `POST /auth/giris/kod-iste` (parolasız) | `phone` | **hayır** |
| `POST /auth/kayit/basla` (sakin **kaydı**) | **`tesis_kodu`** + daire + telefon | **evet** |

Yani kod yalnız **yeni kayıt** akışında kullanılır. Var olan bir hesabın
girişini etkilemez. P154 zaten hiçbir mevcut kodu değiştirmediği için bu
yol da etkilenmez.

**Doğrulandı (kanıt):** `test_tenants.py` (mevcut giriş akışları) ve
`test_sakin_kaydi.py` (kod ile kayıt) P154 sonrası **yeşil** — 77/77.

---

## 4. GERİ ALINABİLİRLİK — ölçüldü

Göç 0041 `downgrade` → `upgrade` çemberi çalışan veritabanında **üç kez**
koşturuldu, üçünde de hatasız:

```
INFO  Running downgrade 0041_kod_ve_coklu_yonetici -> 0040_tetikleyici_search_path
INFO  Running upgrade   0040_tetikleyici_search_path -> 0041_kod_ve_coklu_yonetici
```

`downgrade` neyi geri alır:

| Değişiklik | Geri alınıyor mu | Not |
|---|---|---|
| `kayit_kodu_uret` yerel bağımsızlığı | ✔ tek `translate`'e döner | |
| Çakışma eki (rastgele → sıralı) | ✔ | **Üretilmiş kodlar değişmez** — trigger yalnız yeni INSERT'e bakar |
| `tenant_yoneticiler` / `add_` / `remove_tenant_yonetici` | ✔ `DROP FUNCTION` | Eklenmiş yönetici **kayıtları** silinmez (veri kaybı yok) |
| `tenant_id_by_kayit_kodu` REVOKE + `search_path=''` | ✔ 0036 hâline döner | **Bilerek:** downgrade'in işi şemayı önceki revizyona eşitlemektir, iyileştirmeyi saklamak değil |
| `ix_kayit_dogrulama_tenant_id` | ✔ `DROP INDEX` | |

**Veri kaybı yoktur:** 0041 hiçbir satır silmez, hiçbir sütun düşürmez,
hiçbir mevcut değeri güncellemez. Yalnız fonksiyon gövdeleri, yetkiler ve
bir indeks.

---

## 5. UYGULAMA — canlıya ne zaman, nasıl

**Bu turda canlıya UYGULANMADI** (kilitli kural 6). Uygulandığında:

```bash
# Test sunucusunda (bkz. docs/test-sunucusu-kurulum.md)
DC="docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test"

# 1) ÖNCE yedek (geri dönüş yolu)
bash infra/backup.sh

# 2) Göç — KOD TASIYAN DORT SERVIS BIRLIKTE.
#    Yalniz `migrate` kurmak, gocun YENI ama `api`/`worker` imajinin ESKI
#    kalmasi demektir; sema ilerler, kod geride kalir. Tersi de olur:
#    yeni goc, eski imajda olmayan bir modulu/bagimliligi arar ve DUSER
#    (P171, 2026-08 — ortam tamamen erisilemez oldu).
$DC up -d --build migrate api admin-web worker
$DC logs migrate | tail -20

# 3) KANIT — varsayma
set -a; . .env.test; set +a
$DC exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT version_num FROM alembic_version;"            # 0041_kod_ve_coklu_yonetici

$DC exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT count(*) FILTER (WHERE kayit_kodu IS NULL) AS bos, count(*) FROM tenant;"
#   bos = 0 olmalı

$DC exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT p.proname, p.proconfig,
          has_function_privilege('public', p.oid, 'EXECUTE') AS herkes
     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='tenant_id_by_kayit_kodu';"
#   herkes = f  ve  proconfig = {search_path=""}
```

**Geri dönüş** (gerekirse):

```bash
$DC run --rm --entrypoint sh migrate -c \
  "alembic -c /contracts/db/alembic.ini downgrade -1"
```

---

## 6. GÖÇ ÖNCESİ / SONRASI KARŞILAŞTIRMA SORGUSU

Kodların **değişmediğini** kanıtlamak için göçten önce ve sonra aynı
sorguyu koşup çıktıları karşılaştırın:

```sql
SELECT md5(string_agg(id::text || ':' || kayit_kodu, ',' ORDER BY id))
  FROM tenant;
```

İki özet **aynı** olmalı. Farklıysa 0041 beklenmedik biçimde dolgu
yapmıştır — durun ve `downgrade` edin.

---

## 7. NE YAPILMADI

* **Canlıya uygulanmadı** — kilitli kural 6.
* **Üretimdeki kod dağılımı ölçülmedi** — geliştirme makinesinden canlıya
  erişim yok. §2'deki karar her iki durumda da aynı.
* **Eski sıralı ekli kodlar dönüştürülmedi** — §2'deki gerekçeyle,
  bilinçli.
