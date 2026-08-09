# Migrasyon politikası — yerinde düzenleme DEVRE DIŞI

> **Tek cümle:** Dağıtılmış bir ortam var olduğu andan itibaren şemayı
> değiştiren her şey **yeni bir revizyon** olarak yazılır; mevcut revizyon
> dosyaları bir daha **yerinde düzenlenmez**.

## Neden bu politika var

Bu depoda uzun süre "kanonik migrasyon" kuralı geçerliydi: şema değişiklikleri
yeni revizyon açmak yerine **mevcut revizyon dosyaları yerinde düzenlenerek**
yazılıyordu. Gerekçe makuldü — tek bir okunabilir şema tanımı, geçmişi
kalabalıklaştıran onlarca küçük ALTER revizyonu yok.

Bu kural **tek bir varsayıma** dayanıyordu: veritabanı her zaman sıfırdan
kurulabilir. Dev'de doğruydu. Prod bir kez göç ettiği anda **yanlış** oldu.

Sonuç, prod'da şu hatayla ortaya çıktı:

```
sqlalchemy.exc.ProgrammingError: (psycopg.errors.UndefinedColumn)
column "cikis_zamani" does not exist
[SQL: CREATE INDEX IF NOT EXISTS ix_visitor_tenant_cikis
      ON visitor (tenant_id, cikis_zamani DESC) WHERE cikis_zamani IS NOT NULL;]
File "/contracts/db/migrations/versions/0009_akis_indeksleri.py", line 65
```

`visitor.cikis_zamani`, prod göç ettikten **sonra** kanonik `0001` dosyasına
yerinde eklenmişti. Alembic `0001`i uygulanmış saydığı için o kolon prod'a hiç
gitmedi; ona bağımlı olan `0009` da patladı.

Git geçmişinden ölçüldü: **yalnız iki dosya** yerinde düzenlenmişti —
`0001_initial_schema.py` (48 commit) ve `0005_home_gorsel.py` (2 commit).
Diğer sekiz revizyon hiç değişmemiş.

## Kural

1. **Şemayı etkileyen değişiklik = yeni revizyon.** Tablo, kolon, tip, indeks,
   kısıt, politika, fonksiyon — hepsi. `alembic revision -m "..."` ile yeni
   dosya açılır.
2. **Mevcut revizyon dosyalarında yalnız şu değişiklikler yapılabilir:**
   yorum/docstring düzeltmesi, biçimlendirme, yazım hatası. DDL'e dokunulmaz.
3. **İstisna — hiçbir ortama uygulanmamış revizyon.** Henüz hiçbir yere
   (prod dahil) uygulanmamış bir revizyon düzeltilebilir. Bu istisnayı
   kullanan commit, *neden* hiçbir ortamda uygulanmamış olduğunu yazmak
   zorundadır. (Örnek: `0009`un `down_revision`ı `0008b` eklenirken
   değiştirildi; gerekçe dosyanın docstring'inde — prod'un başarısız koşumu
   tek işlemde atomik geri alınmıştı, yani `0009` hiçbir yerde uygulanmamıştı.)
3b. **İstisna — uygulanmış bir revizyonun `downgrade()` gövdesi.** (P154,
   Kerem'in kararı.) `downgrade()` prod'da **hiç koşmadı ve koşmayacak**;
   dolayısıyla oradaki bir hatayı düzeltmek **uygulanmış hiçbir durumu
   değiştirmez**. Bu istisna DARDIR ve üç şartı vardır:
   * `upgrade()` gövdesine **dokunulmaz** — taze kurulan şema bit bit aynı
     kalmalı, `infra/goc-uyum-dogrula.sh` bunu doğrular;
   * düzeltme, `infra/goc-tersinirlik.sh`in **kırmızı** bir adımını yeşile
     çevirmelidir (yani ortada ölçülmüş bir kusur vardır, tercih değil);
   * commit ve dosya docstring'i, kusuru ve **nasıl ölçüldüğünü** yazar.

   (Örnek: `0036`, `gen_kayit_kodu()`u ona `DEFAULT` ile bağımlı olan
   `tenant.kayit_kodu` sütunundan **önce** düşürüyordu →
   `DependentObjectsStillExist`. Sıra değişti, gövde aynı kaldı.
   `DROP FUNCTION IF EXISTS` bu hatayı yutmaz: `IF EXISTS` yalnızca
   "nesne yok" durumunu susturur, "bağımlı nesne var" durumunu değil.)

4. **Geri alma (`downgrade`) yazılır.** `infra/goc-tersinirlik.sh` zinciri
   head'ten base'e indirip şemayı düz `upgrade` ile karşılaştırıyor; yeni
   revizyon bu kontrolü geçmek zorunda.
5. **Yeni revizyon ekleyen her değişiklikten sonra
   `infra/goc-uyum-dogrula.sh` koşulur.** Bu betik "taze kurulan şema" ile
   "zaten göç etmiş + yeni revizyonlar" şemasını karşılaştırır; fark boş
   olmalı. Yerinde düzenleme yeniden sızarsa bu betik yakalar.

## Neden `docker-compose*.yml`'deki "CANONICAL" ibaresi hâlâ duruyor

Orada "kanonik" kelimesi **başka** bir şeyi anlatıyor: göçlerin tek kaynağı
`/contracts/db`dir ve `backend/` altında ikinci bir migrasyon ağacı
üretilmez. O kural geçerli. Devre dışı kalan şey, *dosyaları yerinde
düzenleyerek* şema geliştirmektir.

## Zaten göç etmiş bir veritabanını uyumlamak

`0008b_uyum_yakalama` bunun örneğidir: tamamen ekleyici, `IF NOT EXISTS`
muhafızlı, tekrar koşmaya güvenli ve `downgrade`i bilinçli no-op (nesnelerin
sahibi `0001`/`0005`). Benzer bir durum bir daha çıkarsa desen aynıdır — ama
politika gereği **çıkmaması** gerekir.

Doğrulama kanıtı ve prod komutları: `infra/RUNBOOK-PROD.md` §14.
