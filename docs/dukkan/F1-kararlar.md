# DUKKAN F1 — KARARLAR

> **Bu belge sonradan yazıldı.** F1'de kararları ayrı bir dosyaya değil,
> tasarım belgelerinin içine (`00-mimari.md` K1–K4, `06-yol-haritasi.md`
> Ö1–Ö5) işlemiştim. Kural "her faz için `F{n}-kararlar.md`" diyordu;
> diğer beş faz için uyuldu, F1 atlandı. Boşluk burada kapanıyor.

İskelet: `dukkan` şeması, `dukkan_app` rolü, lokasyon ağacı, kategori,
4 kamu ucu, `apps/dukkan-web` + BFF sözleşme kapısı.

---

## 1. Sınır **şema** değil **rol** ile zorlanıyor

Kısıt şuydu: *"Yönetiyor'un veritabanına doğrudan yazma."*

Ayrı şema bunu **zorlamaz** — yalnızca isimleri ayırır. `dukkan` şemasındaki
bir hata `public.app_user`'a pekâlâ yazabilirdi. Yorum satırıyla yazılmış bir
kural, kural değildir.

**`dukkan_app` rolünün `public` şemasında hiçbir tablo yetkisi yok.** Dukkan
modülü yalnız bu rolle bağlanan **ayrı bir engine** kullanıyor.

Kazanç: kısıt **test edilebilir** oldu. Kanıt:

```
dukkan_app → SELECT public.app_user  →  permission denied for table app_user
dukkan_app → UPDATE public.app_user  →  permission denied for table app_user
dukkan_app → INSERT dukkan.ulke      →  çalışıyor
app_rw     → SELECT dukkan.ulke      →  permission denied   (simetrik)
```

Kilit **kırılarak** doğrulandı: `GRANT SELECT ON public.app_user TO dukkan_app`
verince iki test kırmızı yandı. Katalog testi **gelecekte eklenecek** Yönetiyor
tablolarını da kapsıyor — tablo tablo bakan bir test yeni tabloyu görmezdi.

**Ayrı veritabanı seçilmedi:** tek Alembic zincirini, tek bağlantı havuzunu ve
tek yedekleme yolunu bölerdi. Tek sunucuda bağlantı kıt kaynak — P187'de
prod'da idle-in-transaction 90/100 ile acıyla ölçüldü.

---

## 2. Modül, ayrı konteyner değil

`/dukkan/*` router'ı mevcut `api` sürecinde.

Ayrı konteyner ikinci bir dağıtım yüzeyi demekti: kendi imajı, sağlık
kontrolü, env'i, Caddy upstream'i, **ağ tanımı**. P215'te `mediamtx`'i ağa
eklemeyi unuttuk ve hata **prod'a kadar gitti** — her yeni konteyner o sınıf
hatanın yeni bir fırsatı.

Ayrıca modül olunca Yönetiyor JWT'si **süreç içinde** doğrulanıyor; ayrı
konteynerde `JWT_SECRET`'ı iki servise yaymak gerekirdi.

**Dürüst maliyeti:** SEO bot trafiği Yönetiyor `api` süreçleriyle aynı havuzu
paylaşır. Azaltma yolu hazır ve ucuz (aynı imajdan ikinci replika), ama
**ölçülmüş bir yavaşlama üzerine** yapılmalı — şimdi değil.

---

## 3. Ölçümler tasarımı iki yerde değiştirdi

| Ölçüm | Sonuç | Ne değişti |
|---|---|---|
| `app_user.telefon` boş oranı | **837/3104 = %27** | SSO'da telefon sorma yolu "kenar durum" değil, **her dört kullanıcıdan biri**. Hata ekranı gibi değil, akışın doğal dalı olarak tasarlandı |
| `tenant.il` / `posta_kodu` | **1/2239** | Bölge ön-doldurmanın **ikinci şansı yok**. "En iyi çaba" kararı doğrulandı; boş hâl akışın **normal** hâli |
| İkinci Alembic zinciri gerekli mi | **Gerekmedi** | "Göçü owner koşar, uygulama kısıtlı rolle bağlanır" deseni **evde zaten var** (`setup_app_role.py`). Dukkan üçüncü rol olarak katıldı |

Üçüncüsü kendi tasarımımı **sadeleştirdi**: `00-mimari.md` K2 ayrı bir zincir
öngörüyordu; ölçüm gereksiz olduğunu gösterdi.

---

## 4. Lokasyon kaynağı — önerimi iki kez değiştirdim

Tasarım belgesinde `emreuenal` deposunu önermiştim. **GPL-3.0 ve son
güncellemesi Nisan 2021** çıktı; *"lisansı net + ticari kullanıma uygun"*
şartını karşılamıyordu → MIT olan `ferhat-mousavi`.

**Ama MIT olan veri de ham hâliyle kullanılamazdı:**

- 74.402 Türkçe adda **`ı` harfi sıfır kez** (Türkçede çok yaygın; imkânsız)
- adların **%83,6'sı** U+0307 birleşen nokta taşıyor (`"Mahallesi̇"`)
- il adları bile bozuk: `Balikesi̇r`, `Di̇yarbakir`

**Teşhis:** kaynak büyük harfti, Türkçe olmayan yerel ayarla küçültülmüş
(`'İ'.lower()` → `'i'`+U+0307, `'I'.lower()` → `'i'`).

Bozulma **deterministik** olduğu için birebir geri döndürüldü. Doğrulama
tahmin değil ölçüm: **81/81 il** ve **39/39 İstanbul ilçesi** bilinen doğru
adla eşleşti. Yükleme sonrası: 14.113 adda `ı` geri geldi, bozuk kayıt **0**.

**`Mevkii` (22.912) ve `Mezrası` (5.337) yüklenmedi:** usta hizmet alanı
olarak "mevki" seçmez; yüklemek seçiciyi 45.000 yerine 74.000 seçeneğe
çıkarır ve o sayfalar kalıcı olarak SEO eşiğinin altında kalırdı.

**Kaynak izi veritabanında** (`dukkan.veri_kaynagi`): URL, lisans, tarih,
sha256, onarım notu. Markdown'a yazmak yetmezdi — iki yıl sonra *"bu liste
nereden geldi"* diye soran kişi kodu değil **DB'yi** sorgular.

---

## 5. Veri dosyası depoya alındı — sonradan düzeltildi

İlk dağıtım notu operatörden dosyayı **indirmesini** istiyordu. Kullanıcı
haklı olarak sordu: *"depoda mı, indirmem mi gerekiyor?"*

**Yanlıştı, sadece eksik değil:** ham dosya GitHub'da `master` dalında ve
üstteki depo onu her an değiştirebilir. "İndir" talimatı, prod'a dev'de
**doğrulanmamış** bir veri gitmesi demekti — ve fark ancak binlerce SEO yolu
üretildikten sonra görünürdü.

Dosya `contracts/veri/tr-lokasyon.json` olarak depoya alındı. `contracts/`
zaten `migrate` ve `api`'ye mount'lu, dolayısıyla `docker cp` adımı da kalktı.

---

## 6. Kamu uçlarında yazma yok

Lokasyon ve kategori **elle** yükleniyor; HTTP üzerinden değiştirilemiyor.

Bu iki tablo SEO yollarının temeli; bir uçtan yanlışlıkla değiştirilebilir
olmaları, **canlı bağlantıların sessizce ölmesi** demekti. Bir test dört
yazma metodunun da **405** döndüğünü ölçüyor.

**`slug` kalıcı ve elle yönetiliyor:** addan her okumada türetmek, idari bir
ad değişikliğinde sessizce ölü bağlantı üretirdi.

---

## 7. BFF sözleşme kapısı gün 1'de

P173 ve P189'da **aynı kusur iki kez** ölçülmüştü: backend ucu mükemmel
çalışır ama BFF `route.ts` o metodu export etmezse web çağrısı **405** alır ve
backend testleri bunu **görmez** — kırılan **arada** kalan katmandır.

Kapı iki ayrı kırılma biçimiyle doğrulandı (rota yok / metot export
edilmemiş) ve ters yön de kapalı (sözleşmede karşılığı olmayan vekil = ölü
kod).

**Bu turda üç kez işe yaradı** — F3, F5 ve F6'da yeni uçların vekillerini
istedi. Sonuncusunda gerçekten atlamıştım.

---

## 8. Akışı sürerken bulunan kusur

Mahalle araması Türkçe harfsiz yazımda (`"catal"`) **hiçbir şey bulmuyordu**,
oysa "Çatalmeşe" oradaydı. Türkçe klavyesi olmayan biri hiçbir mahalle
bulamazdı — ve mahalle seçimi hem sakinin hem **ustanın hizmet alanı seçtiği**
yer.

Çözüm bedavaydı: `slug` sütunu zaten ASCII'ye katlanmış duruyordu (SEO için
üretilmişti); `unaccent` eklentisi gerekmedi.

---

## 9. Ölçemediklerim

1. **Lokasyon verisinin güncelliği** — üçüncü şahıs derlemesi; NVI'nin tek
   geliştiriciye resmî toplu erişim verip vermediğini doğrulayamadım.
2. **ISR önbellek davranışı prod'da** — tek sunucuda kalıcı ISR için ek
   yapılandırma gerekip gerekmediği ölçülmedi.
3. **RLS yerine açık kontrol kararının bedeli** — Dukkan verisinin çoğu
   tasarım gereği kamuya açık ve özel yüzey dar; ama bu, RLS'in son savunma
   hattı olduğu gerçeğini değiştirmiyor. V2'de `talep`/`teklif` üçlüsüne RLS
   eklemek doğru olabilir.
