# P154 TUR RAPORU — P142–160 brief'inin ilk turu

> Tarih: **2026-08-09** · Dal: `main` · Başlangıç: `ca6b5aa`
>
> Brief 13 aşama içeriyordu (A, 0–11). Bu tur **beşini tamamladı**, birini
> kısmen yaptı, yedisine **başlamadı**. Aşağısı ne yapıldığını, hangi
> kararların neden verildiğini ve **ne yapılmadığını** ayrı ayrı yazar.

---

## 1. TAMAMLANANLAR

| Aşama | Çıktı | Commit |
|---|---|---|
| **A** — Test sunucusu | `docs/test-sunucusu-kurulum.md` | `9722bf2` |
| **0** — Envanter + triyaj + çakışma haritası | `docs/envanter.md`, `docs/apsiyon-kapsam-triyaji.md` | `a3c00bc` |
| **1** — Tesis ID + çoklu yönetici | göç 0041 + 3 uç + panel kartı + 11 test | `24e1c44` |
| **2** — Mevcut kullanıcıların geçişi | `docs/goc-plani-tesis-kodu.md` | `c85a1e6` |
| **9 (araştırma)** — WhatsApp | `docs/whatsapp-arastirma.md` | `89c6bbd` |
| **11** — ERP yol haritası | `docs/erp-yol-haritasi.md` | `9701ef5` |
| **7.2 (kısmen)** — "Olaylar" 403'ü | rol kapısı + kilit testi | `915827f` |
| — | Rol matrisi kilidi (9 satır, hepsi yazılı) | `7412380` |

---

## 2. EN ÖNEMLİ BULGU — işin ağırlığı arka uçta değil

Brief, birçok ERP modülünü "muhtemelen yazılmış ama yüzeye çıkarılmamış"
diye tarif ediyordu. Ölçüm bunu **doğruladı ve fazlasını gösterdi**:

* 65 router, ~90 tablo. `kasa`, `gelir_gider_*`, `firma`, `personel`,
  `arac`, `sayac_*`, `finansal_hareket`, `icra_dosyasi`, `mesaj_sablonu`,
  `karar_defteri`, `tenant_dokuman` — **hepsinin** tablosu ve HTTP ucu var.
* Apsiyon raporundaki **77 maddenin 34'ü zaten çalışıyor**, 14'ü yalnız
  ekran bekliyor.

Bu, brief'in kova tanımına **üçüncü bir kova** ekletti: **A− = "arka uç
var, ekran yok"**. Sonraki turların planı buna göre kurulmalı.

### 2.1 Ölü BFF ucu sınıfı

`admin-web/lib/panel-vekil.ts` beyaz listesi sayfalarla karşılaştırıldı.
**Altı YAZMA ucu panele açık ama hiçbir ekran çağırmıyor:**
`icra-dosyalari`, `finans-tahsilat`, `finans-virman`, `finans-iade`,
`banka-eslestir`, `mesaj-gonder`.

Aşama 10 onları kullanacağı için **kaldırılmadılar**; ama kullanılmayan
bir yazma ucu, kimsenin bakmadığı bir yüzeydir ve burada kayda geçti.

---

## 3. ÖNLENEN ÇAKIŞMALAR (brief'in istediği tek satırlar)

| Aşama | "Bu aşamada hangi çakışmayı önledim" |
|---|---|
| **0** | Aşama 5 + Aşama 8 + Apsiyon §5/§28 birbirinden habersiz **üç ayrı Excel yükleyici** yazdırırdı — kodda çalışan bir **dördüncüsü** (`/site-aktar`) zaten vardı. Tek sahip Aşama 8 ilan edildi. |
| **1** | Tesis ID üreticisi (`kayit_kodu_uret` + tetikleyici) P148.1'de **zaten yazılmıştı**; sıfırdan yazılmadı, yalnız iki kusuru kapatıldı. |
| **2** | Mevcut tesislere ID üretme işi 0037'nin dolgu `UPDATE`'inde **zaten yapılmıştı**; ikinci bir dolgu göçü yazılmadı. |
| **9** | Netgsm **zaten bağlı** (P150); SMS sağlayıcı katmanı yeniden yazılmadı. Aşama 3'ün "geçici kodu e-postayla gönder" maddesi kendi e-posta kodunu yazdırırdı — Aşama 9'un ortak arayüzüne bağlandı. |
| **11** | Sekiz tasarımın **beşi yeni tablo istemiyor** (cari bir görünüm, çoklu satır zaten `idem_satir`, ters kayıt tek sütun, belge no mevcut alanı doldurur, rapor ayarı çalışan motora biner). "Yeni ERP modülü" diye planlamak, çalışan tek defteri ikinci bir defterle çatallandırırdı. |

---

## 4. VERİLEN KARARLAR VE GEREKÇELERİ

### 4.1 Üçüncü bir compose dosyası yazılmadı (Aşama A)
`docker-compose.prod.yml` zaten baştan sona env ile parametreli. Ayrı
dosya bugün kopya olur, yarın prod düzeltmesi ona işlenmez ve test
sunucusu sessizce farklı bir yazılım koşar. Tek fark yapılandırmadır:
ayrı `.env.test` + `-p yonetio-test`.

### 4.2 Çakışma eki rastgele oldu (kilitli kural 3)
P148.1 sıralı sayaç (`-2`, `-3`) koymuştu; brief "rastgele sayı" diyor ve
KİLİTLİ KURALLAR başlığı altında. **Takas dürüstçe:** sıralı ek daha
akılda kalıcıdır ve kodun tüm amacı akılda kalmaktır. Zararı küçük tutmak
için ek **iki hanelidir** (`OLTU-260715-47`); 20 denemeden sonra md5
tabanlı eke düşülür (sonsuz döngü tesis oluşturmayı kilitlerdi).

### 4.3 Kod üreticisi yerel bağımsız yapıldı
`upper()` veritabanı ctype'ına bağlıdır. Türkçe ctype'lı bir kurulumda
`upper('i')='İ'` döner ve `[^A-Z]` süzgeci onu **atar**:
"istanbul konakları" → `ISTA` yerine `STAN`. **Bugün patlamıyor, yarın
patlardı** — Aşama A yeni bir sunucu kuruyor ve `initdb` yerelini işletim
sisteminden alır.

**Davranışsız olduğu kanıtlandı:** eski/yeni gövde çalışan veritabanında
yan yana koşturuldu — 17 kenar durumu aynı çıktı, mevcut tesislerde fark
**0**.

### 4.4 Eski biçimli kodlar yeniden üretilmedi (Aşama 2)
Kod, sakinin **telefonda elle yazdığı** bir tanımlayıcıdır; değiştirmek
dün verilen kodun bugün tutmaması demektir. Ayrıca yeniden üretim rastgele
ek kullanır ve `downgrade` eski değeri **geri getiremez** — brief'in
"geri alınabilir olsun" şartını ihlal ederdi.

### 4.5 Yönetici silme sert ama korumalı (Aşama 1)
Yumuşak silme zaten `PATCH is_active` ile yapılabiliyor; iki düğmenin aynı
işi yapması kullanıcıyı yanıltırdı. Üç ayrı 409 var ve **üçünün de metni
farklı**, çünkü kullanıcıya *ne yapacağını* söyleyen şey metindir.

### 4.6 "Olaylar" sayfası yöneticiden kaldırıldı (Aşama 7.2)
Kök neden ölçüldü: `_READER` yöneticiyi içeriyor (sayfa açılıyor),
`_WRITER` içermiyor, sayfanın düğmesi `POST` yapıyor → **403**.
**Alternatif kayda geçti:** kusur okumada değil yazmadaydı; yalnız yazma
formunu gizlemek okuma yeteneğini korurdu. Brief açıkça "yöneticiden
kaldır" dediği için yazılı istek uygulandı.

### 4.7 `kayit_dogrulama`ya RLS **açılmadı** (bilinçli)
Tablo **kimlik öncesi** okunuyor: `auth.kayit_dogrula` ve
`telefon_kodu.kodu_dogrula` satırı **telefondan** bulur ve tenant o an
bilinmez. Tenant izolasyon politikası eklemek sakin kaydını ve parolasız
girişi **sessizce sıfır satıra** düşürürdü. Kapıyı yeşile boyamak için
akış kırılmadı; doğru çözüm bir `SECURITY DEFINER` çözücüdür.

---

## 5. BULUNAN GERÇEK KUSURLAR

### 5.1 GÜVENLİK — `tenant_id_by_kayit_kodu` PUBLIC EXECUTE'a açıktı
`SECURITY DEFINER` olduğu için **RLS'i bypass eder**; 0036'da
`REVOKE ... FROM PUBLIC` yazılmadığı için `proacl` NULL kalmış, yani
veritabanındaki **her role açık**. Ayrıca `search_path = public` +
nitelenmemiş `FROM tenant` taşıyordu — 0040'ın belgelediği kuralın tersi.

**Düzeltildi** (göç 0041) ve ekranda doğrulandı:
`herkes=f`, `app_rw=t`, `proconfig={search_path=""}`.

### 5.2 Beş hata kimliği katalogsuzdu
Arapça arayüzdeki sakin kaydolurken Türkçe bir **kimlik dizesi**
(`kayit_bilgileri_gecersiz`) görüyordu — cümle bile değil. Beşi de 7 dilde
yazıldı. Çeviriler **adımları ayırt ettirmeyen** belirsizliği korur:
daha yardımsever bir metin, kodun bilinçli olarak sakladığını açardı.

### 5.3 `kayit_dogrulama(tenant_id)` FK öncü kolon indeksi yoktu
Tesis silinirken referans bütünlüğü tetiği bu tabloyu seq scan ediyordu.
Eklendi.

### 5.4 KENDİ HATAM — 33 karakterlik revizyon kimliği
İlk revizyon adı `0041_tesis_kodu_ve_coklu_yonetici` = **33 karakter**;
`alembic_version.version_num` `varchar(32)`. Göç gövdesi kusursuz koşar ve
**her şey bittikten sonra** sürüm damgası yazılırken patlar — veritabanı
yarı yolda kalır, `alembic current` eski revizyonu gösterir, sonraki
çalıştırma aynı göçü **tekrar** uygular.

`infra/goc-uyum-dogrula.sh` kapısı yakaladı. Kimlik kısaltıldı ve sınıf
**kilitlendi**: `backend/tests/test_goc_kimlikleri.py` (32 karakter sınırı
+ kopuk `down_revision` zinciri + tek head). Veritabanı istemez, saniyeler
sürer.

---

## 6. KAPILAR

### 6.1 Tur başında ölçülen TABAN (`main` @ `ca6b5aa`)
Son tam koşum 2026-08-05'ti; aradan sekiz commit geçmişti.

| Kapı | Taban |
|---|---|
| `depo-izlenmeyen` | OK |
| `depo-alan-adi` | **HATA** — 5 bulgu |
| `web-tsc` / `web-vitest` / `web-build` | OK — 676 test |
| `mobil-analyze` / `mobil-test` / `mobil-apk` | OK — **1823 test** |
| `backend-pytest` | **HATA — 11 failed, 1462 passed** |

### 6.2 Tur sonu

| Kapı | Sonuç |
|---|---|
| `web-tsc` | **OK** (temiz) |
| `web-vitest` | **OK — 677** (676 → +1 yeni kilit) |
| `backend-pytest` | **2 failed, 1484 passed** (taban: 11 failed / 1462 passed) |
| Hedefli koşum (yetki + secdef + göç kimlikleri + çoklu yönetici) | **22/22** |
| `goc-uyum` / `goc-tersinir` | **ikisi de bulgu: 0** ✔ |
| `mobil-*` | **dokunulmadı** (mobil dosyası değişmedi) |

**Net:** taban 11 hatadan **9'u kapatıldı**, **yeni hata üretilmedi**,
+22 test eklendi. Göç kapılarının ikisi de sıfırlandı. Geriye tek bir
kusur sınıfı kaldı: `kayit_dogrulama` RLS'i (§4.7 — tasarım kararı).

### 6.3 KALAN KIRMIZILAR — hepsi bu turdan ÖNCE de kırmızıydı

| Test | Sebep | Neden bu turda kapatılmadı |
|---|---|---|
| `test_rls_kapsam` ×2 | `kayit_dogrulama` RLS'siz | §4.7 — açmak kayıt akışını kırardı; tasarım kararı gerekiyor |
| `depo-alan-adi` kapısı | 5 bulgu; en ciddisi `www.xn--ynetiyor-n4a.com` belgede vaat ediliyor ama Caddyfile'da yok → ziyaretçi **TLS el sıkışması düşmesi** görür | Düzeltmek **canlı Caddy yapılandırmasına** dokunmayı gerektiriyor; kilitli kural 6 yasaklıyor. Yalnız belgeyi düzeltmek, gerçek TLS kusurunu kapatmadan uyarıyı susturmak olurdu |
### 6.4 `goc-tersinir` — **KAPANDI** (Kerem'in kararıyla)

Tur başındaki koşumda bu kapı **benim 33 karakterlik revizyon kimliğim
yüzünden** referans upgrade'de patlıyordu (45 bulgu). Kimlik düzeltildikten
sonra:

| Adım | Sonuç |
|---|---|
| `goc-uyum` | **OK — bulgu: 0** ✔ (önceden HATA) |
| `goc-tersinir` [1] `downgrade base` sonrası şema boş | **OK** ✔ |
| `goc-tersinir` [2] gidiş-dönüş şeması düz `upgrade` ile **aynı** (7910 satır) | **OK** ✔ |
| `goc-tersinir` [3] salınım (head'ten N adım aşağı-yukarı) | **OK — bulgu: 0** ✔ |

**[3]'ün kök nedeni ölçüldü ve 0041'den bağımsız olduğu KANITLANDI.**
Tek kullanımlık taze bir veritabanına **yalnız 0036'ya kadar** göç
uygulanıp 0035'e indirildi — 0041 devrede bile değilken aynı hata:

```
Running upgrade 0035_sakin_bildirimleri -> 0036_sakin_kendi_kaydolur
>>> 0036 KURULDU
Running downgrade 0036_sakin_kendi_kaydolur -> 0035_sakin_bildirimleri
psycopg.errors.DependentObjectsStillExist:
  cannot drop function gen_kayit_kodu() because other objects depend on it
```

**Kusur:** `0036_sakin_kendi_kaydolur.py::downgrade()` fonksiyonu, ona
bağımlı sütundan **önce** düşürüyor:

```python
def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_id_by_kayit_kodu(text);")
    op.execute("DROP FUNCTION IF EXISTS public.gen_kayit_kodu();")   # ← 2. sıra
    op.drop_table("kayit_dogrulama")
    op.drop_constraint("uq_tenant_kayit_kodu", "tenant", type_="unique")
    op.drop_column("tenant", "kayit_kodu")   # ← DEFAULT public.gen_kayit_kodu()
```

`tenant.kayit_kodu` sütunu `DEFAULT public.gen_kayit_kodu()` taşır
(0036'nın kendi `upgrade`i koyar). PostgreSQL, kendisine bağımlı bir
varsayılan dururken fonksiyonu düşürmeyi reddeder.

**Düzeltme tek satırlık:** `drop_column`u fonksiyon düşürmelerinden
**önce** taşımak.

**KEREM'İN KARARIYLA DÜZELTİLDİ.** Politika normalde uygulanmış
revizyonlarda DDL'e dokunmayı yasaklıyordu (§2); Kerem `downgrade()`
gövdesinin bu kuralın dışında olduğuna karar verdi — gerekçe: prod'da
**hiç koşmadı ve koşmayacak**, dolayısıyla düzeltme uygulanmış hiçbir
durumu değiştirmez.

Karar `docs/MIGRATION-POLITIKASI.md`'ye **§3b** olarak yazıldı ve
**dar tutuldu** — üç şartı var: (a) `upgrade()` gövdesine dokunulmaz,
(b) düzeltme `goc-tersinirlik.sh`in **kırmızı** bir adımını yeşile
çevirmelidir (ölçülmüş kusur, tercih değil), (c) commit ve docstring
kusuru **ve nasıl ölçüldüğünü** yazar.

**Uygulanan değişiklik:** yalnız sıralama. `drop_column("tenant",
"kayit_kodu")` fonksiyon düşürmesinden **önceye** alındı; gövde aynı.

**Doğrulandı — üç ayrı ölçüm:**

| Ölçüm | Sonuç |
|---|---|
| Taze DB: `upgrade 0036 → downgrade 0035 → upgrade 0036 → downgrade base` | **dördü de temiz** |
| `goc-uyum` (taze şema ≡ göç etmiş şema) | **bulgu: 0** — yani `upgrade()` yolu bit bit aynı, §3b(a) şartı sağlandı |
| `goc-tersinir` (tam zincir + salınım) | **bulgu: 0** — tur başında 45'ti |

`goc-tersinir`in tamamen temiz gelmesi ayrıca şunu söylüyor: **başka
hiçbir revizyonda benzer bir `downgrade` sırası kusuru yok.**

> **Not — `DROP FUNCTION IF EXISTS` neden korumadı:** `IF EXISTS`
> yalnızca "nesne yok" durumunu susturur, "bağımlı nesne var" durumunu
> **değil**. Kusur tam da bu yüzden gözden kaçmıştı.

### 6.5 `test_sozlesme_sapmasi` + `test_denetci_salt_okuma` — **KAPANDI**

P148/P149'da yazılıp sözleşmeye işlenmeyen **8 uç** `contracts/openapi.yaml`'a
eklendi (kural 6: *"/contracts → openapi.yaml her uç/şema değişikliğinde
güncellenir"*). Şemalar **uydurulmadı** — her biri `routers/auth.py`,
`routers/kayit_basvurulari.py`, `routers/me.py` ve `schemas.py`'deki gerçek
imzadan okundu.

| Uç | Rol kapısı | Yanıt |
|---|---|---|
| `POST /auth/kayit/basla` | **yok** (kimlik öncesi) | `KayitBaslaResponse` — kod DÖNMEZ, telefon maskeli |
| `POST /auth/kayit/dogrula` | **yok** | `KayitDurumResponse` — **token DÖNMEZ**, başvuru onaya düşer |
| `POST /auth/giris/kod-iste` | **yok** | `KayitDurumResponse` — numara kayıtlı olmasa da **aynı** yanıt |
| `POST /auth/giris/kod-dogrula` | **yok** | `TokenPair` — oturum açar |
| `GET /kayit-basvurulari` | admin + yönetici | `KayitBasvuruListesi` |
| `POST /kayit-basvurulari/{id}/onayla` | admin + yönetici | `201 {user_id}` — **hesap burada açılır** |
| `POST /kayit-basvurulari/{id}/reddet` | admin + yönetici | `200 {durum: reddedildi}` |
| `POST /me/hesap-sil/kod-iste` | kimlik var, rol yok | `200 {durum: gonderildi}` |

`test_denetci_salt_okuma`'nın `KAPISIZ_MUTASYONLAR` kümesine 5 uç
**gerekçesiyle** eklendi: dördünün rol kapısı **olamaz** (isteği atanın
henüz hesabı/oturumu yok) ve hiçbiri tesisin kayıtlarına yazmaz —
`kayit/*` yalnız bekleyen bir başvuru yazar, **hesabı açan uç rol
kapılıdır**. Beşincisi (`/me/hesap-sil/kod-iste`) kişinin kendi hakkıdır.

**Zincirleme etki — beklenen ve doğru:** 8 uç artık sözleşmede olduğu için
**rol matrisi kilidine de girdiler**. Kilit yenilendi; git farkı tam olarak
o 8 satır. Satırlar doğrulandı: 4 public uç her role `IZIN`, 3 başvuru ucu
yalnız ilk iki sütunda `IZIN` (`_MANAGER = admin, yonetici`),
`/me/hesap-sil/kod-iste` her kimlikli role `IZIN`.

### 6.6 `test_sayfalama_siralamasi` — **KAPANDI**

Bu kapı bir **çırçır** (ratchet): kararsız sayfalı sorgu sayısı
azaltılabilir, **artırılamaz**. Sayı 3'ten 4'e çıkmıştı.

**Artan tek satır `kayit_basvurulari.py:66` idi** (P148). Diğer üçü
(`reports.py`, `transparency.py`, `kvkk.py`) testin kendi docstring'inde
**bilinçli** olarak açıklanmış: ilk ikisi toplulaştırma (`id` `GROUP BY`da
yok, eklenemez — kararlı kuyruk gruplama anahtarıdır), üçüncüsünde
`(tenant_id, surum)` zaten benzersiz.

**Kusurun bedeli soyut değildi:** onay kuyruğu yalnız `created_at` ile
sıralanıyordu ve orada eşitlik **nadir değil** — bir daireye ait sakinler
aynı anda kaydolur (aile, taşınma günü), seed toplu satır yazar. Kararsız
sıralamada yönetici ikinci sayfada aynı başvuruyu yeniden görür, bir
başkasını **hiç görmez** ve hiçbir yerde hata çıkmaz: **onaylanmayan bir
sakin sessizce beklerdi.**

`.order_by(created_at.asc(), id.asc())` eklendi; sayı 3'e döndü. Çırçırın
neden "azaltılabilir, artırılamaz" olduğunun kanıtı olarak testin
docstring'ine de yazıldı.

---

## 7. YAPILMAYAN AŞAMALAR — dürüst kayıt

Brief'in **yedi aşamasına başlanmadı.** Yarım iş bırakmamak için hiçbirine
kısmen girilmedi (brief'in kendi kuralı).

| Aşama | Neden başlanmadı | Aşama 0'dan hazır girdi |
|---|---|---|
| **3** — Rol seçimli kayıt | Mobil + web akış değişikliği; tek turda bitmezdi | `login-phone`, `telefon_kodu`, `kayit_basvurulari` **zaten var**; rol seçimi bunların **üstüne** kurulacak |
| **4** — OAuth (Google/Microsoft/Apple) | Üç sağlayıcı × iki platform + hesap birleştirme; en büyük tek kalem | Test sunucusu için geri dönüş adresleri `docs/test-sunucusu-kurulum.md` §8'de yazılı |
| **5** — Kullanıcı + yapı yönetimi | Aşama 6 ve 8'e bağımlı (modal + import) | Ölçülen 7 boşluk `docs/envanter.md`'de listeli (toplu daire web'de yok, kat silme yok, sürükle-bırak yok, daire tipi ataması web'de yok…) |
| **6** — Ortak UI altyapısı | Modal + liste + arama + ek = ~4 kalem, her biri günler | `/tanimlar`'daki **veri-sürücülü `Defter` deseni** genelleştirilecek; sıfırdan liste bileşeni yazılmayacak |
| **7.1/7.3/7.4** — Menü, onboarding, bağımlılık | 7.2'nin bir maddesi yapıldı | Menü **zaten gruplu ve katlanabilir** (`lib/menu.ts`); bağımlılık haritası 16 satır hazır |
| **8** — Import framework | `/site-aktar` üstüne kurulacak | Uç + şablon **zaten çalışıyor** |
| **9 (kod)** — Bildirim/şablon altyapısı | Araştırma yapıldı, kod yapılmadı | `POST /mesajlar/gonder` **var**, ekranı yok; WhatsApp için `mesaj_sablonu`ya 3 alan gerektiği ölçüldü |
| **10** — Apsiyon B kovası | 6'ya bağımlı | 14 A− maddesi listeli |

### 7.2'nin yapılmayan maddeleri
Parola göster/gizle · "Bağımsız bölüm tanımları" → "Daire Tipleri" ·
"Site sayfası" kaldırma · alt menü rol adları · mobil "+" düğmesi ·
gizli aksiyonların görünürlüğü · görev kategorisi kolaylaştırma.

> **"Site sayfası" için uyarı (Aşama 0'da ölçüldü):** `/portal`ı silmek
> **anketi de götürür** — `/anketler` uçları `routers/portal.py` altında
> ve anket uçtan uca çalışıyor, mobil karşılığı da var. Önce anket
> ayrılmalı.

---

## 8. KEREM'İN YAPMASI GEREKENLER

1. **Test sunucusu sağla** — Ubuntu 24.04, ≥4 GB RAM, ≥40 GB disk, genel IP.
   Sonra `docs/test-sunucusu-kurulum.md` baştan sona koşulabilir.
2. **DNS** — `test`, `api.test`, `panel.test`, `storage.test` A kayıtları.
3. **Karar: WhatsApp modeli A mı B mi** (`docs/whatsapp-arastirma.md` §3).
   Öneri A. Meta doğrulaması **30 güne kadar** sürüyor — WhatsApp bu turda
   planlanıyorsa **şimdi** başlamalı.
4. **Karar: "Olaylar"** yöneticiden tamamen kalksın mı, yoksa yalnız yazma
   formu mu gizlensin (§4.6)? Şu an brief'teki yazılı istek uygulandı.
5. **Karar: `+905777777777` denetçi** hesabı `demo_tenant.py`'ye kalıcı
   eklensin mi? Şu an depoda yok, canlıda elle açılmış.
6. ~~**Karar: göç politikası**~~ — **KARAR VERİLDİ:** `downgrade()`
   gövdesi "DDL'e dokunulmaz" kuralının dışında. Politikaya §3b olarak
   yazıldı, `0036` düzeltildi, `goc-tersinir` yeşile döndü (§6.4).

## 9. CİHAZDA DOĞRULANACAKLAR

Bu turda **hiçbir şey ekranda tıklanarak doğrulanmadı** — çalışan bir test
sunucusu yok ve canlıya dokunmak yasak. Sunucu kalkınca:

1. `panel.test.…/tenants/{id}` → **Yöneticiler** kartı görünüyor mu?
2. "Yönetici ekle" → tek seferlik kod kutusu çıkıyor mu, kod ile giriş
   yapılıp parola belirlenebiliyor mu?
3. Birincil yöneticide "Sil" düğmesi **yok**, yerinde açıklama var mı?
4. İkinci yöneticiyi silmeye çalışınca doğru **Türkçe** mesaj geliyor mu?
   (7 dilde de bakın — `Accept-Language`.)
5. Yeni tesis oluştur → kod `XXXX-YYAAGG` biçiminde mi?
6. Aynı ad + aynı gün ikinci tesis → ek **iki haneli** mi?
7. Yönetici rolüyle `/olaylar` menüde **görünmüyor** mu?
