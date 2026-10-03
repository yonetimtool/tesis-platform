# P253 — Mobil tam eşitlik (Aşama 0) ve şikâyet gizliliği: kararlar

Plan: `docs/P253-mobil-esitlik-plani.md` (onaylandı 2026-10-03). Bu tur:
Aşama 0 (§B), şikâyet gizliliği (§D), saat dilimi (§E). Aşama 1 kullanıcının
"devam"ıyla başlar.

## §A — Plan kararları (planın §5'i, onaylandı)

| # | Karar | Ne zaman |
|---|---|---|
| 1 | Denetçi mobilde **salt okuma** | Aşama 2 |
| 2 | Platform admin mobil menüsü kapsam dışı | — |
| 3 | Demirbaş: ayrı **Envanter** (yönetici) / **Zimmet** (saha) sekmeleri; aynı ekranda karışmaz | Aşama 3 |
| 4 | 3D sahne ve site planı mobile gelmez; tabloda `yapisal` | — |
| 5 | Tablo araçları (sütun gizleme, sayfa boyu): kart + sırala/süz yeterli; `yapisal` | — |
| 6 | Paylaşım hedefi Android Aşama 3, iOS share extension ayrı tur. iOS'ta Dosyalar'dan seçim share extension'sız da mümkün; içe aktarım onunla yapılır | Aşama 3 |
| 7 | Web mesaj gönderim kusuru | Aşama 0 (§B) |
| 8 | Harita karo kaynağı web ve mobil için **birlikte** değerlendirilir. OSM'nin karo politikası yoğun/ticari kullanımı yasaklar. Seçenekler: MapTiler, Stadia, kendi karo sunucusu (maliyet, lisans, boyut). Öneri Aşama 2 başında; **onaysız bağımlılık eklenmez** | Aşama 2 başı |

## §C — Finans işlemleri kuralı (Aşama 1–2'de uygulanacak)

Telefonda yanlış dokunma kolay, finans hatası pahalı. Mobilde şu işlemlerin
hepsi bu kurala uyar:

* onayla / reddet;
* iptal (ters kayıt);
* toplu tahakkuk;
* virman;
* iade;
* toplu tahsilat.

1. **Onay diyaloğu:** her biri ayrı bir onay adımından geçer. Diyalogda
   **tutar** ve **hedef** açıkça yazılı. Örnek: "A-12 · Ahmet YILMAZ ·
   1.250,00 ₺ tahsilatını iptal et". Genel "Emin misiniz?" yasak.
2. **Sebep zorunlu:** iptal, ters kayıt ve redde. Boş sebeple düğme
   etkin olmaz; sunucu da reddeder (web'le aynı uç ve kural).
3. **Sunucu kuralları aynen geçer:** mobil için ayrı uç ya da gevşetilmiş
   doğrulama yazılmaz. Web'le aynı uç çağrılır.
4. **Geri al:** mümkün olan yerde işlemden sonra "Geri al" görünür. Toplu
   tahakkukta ters kayıt partisi, virmanda ters virman. Geri alınamayan
   işlemde (örneğin onaylanmış ve kasaya girmiş tahsilat iadesi) bu durum
   onay diyaloğunda **önceden** söylenir.
5. **Denetim kaydında yüzey:** her finans eyleminin denetim kaydına
   `yuzey: "web" | "mobil"` yazılır.
   * Kaynak: istek başlığı `X-Istemci-Yuzey`. Mobil Dio istemcisi
     ekler, web BFF ekler.
   * Başlıksız istek `bilinmiyor` olarak yazılır.
   * Aşama 1'in ilk işi; ortak `audit_user` yardımcısında tek yerden.

## §B — Aşama 0

### Web toplu mesaj gönderimi

**Ölçüm: web'den toplu mesaj hiç gönderilemiyordu.** Üç kusur üst üste
biniyordu:

1. "Gönderim" sekmesinde **gönder düğmesi yoktu**. `mesaj-gonder` BFF beyaz
   listesinde duruyordu ama hiçbir ekran çağırmıyordu.
2. Sekmedeki **önizleme de çalışmıyordu**.
   * Web sunucuya yalnız `sablon_id` gönderiyordu; sunucu `govde`
     istediği için **her önizleme 422 dönüyordu**.
   * Yanıt biçimi de uyuşmuyordu: web sayacı üst düzeyde, sunucu `sms`
     altında veriyor.
   * DOM testi sahte yanıtla geçtiği için kimse görmedi.
3. Sunucuda sağlayıcı **yapılandırılmamışken** dönen `yapilandirilmadi`
   sonucu **"gönderildi" sayacına** ekleniyordu. API'den gönderen, gitmeyen
   mesajı gitti sanırdı. Kayıt satırı doğru yazılıyordu, sayaç yanlıştı.

**Düzeltme:**

* **Yeni uç `POST /mesajlar/alicilar`:** gönderim **öncesi** özet; hiçbir
  şey göndermez. Döndürdükleri: toplam, gönderilecek, rıza yok, adres yok,
  kanal hazır mı, kalan kota.
  * Gönderimle **aynı** sınıflandırma (`_hedefler`): onay ekranındaki sayı
    gerçek olmalı.
* **Web akışı:** şablon → kime (tüm sakinler / blok / borçlular / rol) →
  önizle → "Gönder…" → **onay penceresi**.
  * Pencere: "247 kişiye E-posta gidecek. Onaylıyor musunuz?", atlananlar,
    önizleme.
  * Kanal hazır değilse ya da kota aşılıyorsa onay düğmesi kapalı.
  * Gönderince sonuç: gönderildi / kuyrukta (yeniden denenecek) /
    gönderilemedi (kanal yapılandırılmamış) / rıza yok / adres yok.
* **Sonuç sayaçları:** `kuyrukta` ve `gonderilemedi` ayrıldı. `basarisiz`
  geriye uyumluluk için ikisinin toplamı.
* **Kota** artık **gönderilecek** sayısıyla ölçülür: rızası ya da adresi
  olmayanlar kotadan yemez.

**"Gönderdim sanılıp gitmeyen gönderim olmuş mu?"**

* **Web'den:** hayır. Web'de gönder düğmesi yoktu, önizleme de hata
  veriyordu; kullanıcı "gönderildi" diyen bir ekran görmedi. Ama beklenen
  duyuruların **hiç gitmemiş** olması mümkün.
* **API'den:** olmuş olabilir. Kanal yapılandırılmamış bir tesiste gönderen
  "gönderildi: N" görüyordu.
* Geliştirme veritabanında elle gönderimlerin 765 satırı `yapilandirilmadi`,
  1'i gerçekten gönderilmiş; bunlar test koşularından.
* **Prod ölçümü kullanıcıda:** `docs/P253-mesaj-olcumu.sql` (salt okuma;
  kişi ya da adres seçmez).

**Kilit:**

* `tests/p253-mesaj-gonderim.dom.test.ts`: onay ekranı, aynı süzgeç, sonuç
  sayıları, kanal yok ya da kota aşılıyorsa düğme kapalı.
* Eski `mesaj.dom.test.ts` artık **gerçek sunucu biçimiyle** sahteliyor ve
  önizleme isteğinin `govde` taşıdığını doğruluyor.
* Backend `test_p253_mesaj_gonderim.py`: özet hiçbir şey göndermez ve
  gönderimle aynı sayıyı verir; kanal yoksa `gonderildi == 0`.
* "Gönderildi" bekleyen iki eski test kusurun kendisine dayanıyordu;
  kapsama ölçecek biçimde düzeltildi.

### Yönetici mobil menüsünde araç geçişi

* **Ölçüm:** yöneticinin "Otopark ve araç geçişleri" girişi yalnız agrega
  doluluk ekranını açıyordu. Araç giriş/çıkış listesi (doluluk bandı
  dahil) yalnız amirin menüsündeydi. Sunucu ise yöneticiye listeyi,
  girişi ve çıkışı zaten açıyor (`rol-matrisi`).
* **Karar:** aynı giriş artık araç geçişi ekranını açar. Web'deki aynı adlı
  sayfanın (liste + doluluk) karşılığı budur. Ayrı ikinci menü öğesi
  açılmadı; menü tablosundaki eşleşme (`/arac-gecisleri` ↔ `otopark`)
  aynen kalır.
* **Kilit:** `mobile/test/p253_arac_gecisi_menusu_test.dart`.

### Hiçbir role açık olmayan web sayfaları

`/ziyaretciler`, `/kargolar`, `/gorevlerim` **kaldırıldı** (1.150 satır sayfa
+ testleri).

* **Gerekçe:**
  * P129'da "park" edilmişlerdi: rol listesi boştu, satırlar "rol geri
    açılırsa" diye tutuluyordu.
  * Saha rolleri ve sakin P129/P248'den beri mobil-yalnız.
  * Yöneticiye açmak da doğru değil: sunucu `/visitors` ve `/kargo`'yu
    yöneticiye **kapatıyor**. Yönetici bir dairenin kayıtlarını yalnız
    sakinin onayıyla, Görüntüleme izni'nden görür; mobilde de aynı.
* **Ölçümde çıkan iki yan kusur:**
  * **Web bildirim haritası** kargo ve ziyaretçi bildirimlerini bu kapalı
    sayfalara yolluyordu: tıklayan yönetici erişemediği bir sayfaya
    gidiyordu. Artık Görüntüleme izni'ne gidiyor.
  * **Hızlı işlem kataloğu** "Ziyaretçiler"i yöneticiye **seçenek olarak
    sunuyordu** (P250). Mobilde bu kısayol 403 alan bir ekran açıyordu.
    Katalogdan çıkarıldı; yalnız güvenlik ve amir.
* Görüntüleme izni sayfası `/api/visitors` ve `/api/kargo` BFF rotalarını
  kullanıyor; rotalar kaldı.

### P251 menü tablosu: "Gelirler yalnız web" düzeltildi

* Mobil Bütçe ekranı gelir kaydını aynı deftere yazıyor
  (`POST /budget/entries` → `finansal_hareket`).
* Satır `yapisal` yapıldı, gerekçesiyle. Mobil "Bilgisayardan yapılanlar"
  listesinden çıkarıldı.
* Kasa/kalem/belge seçimi Aşama 1'de gider ekranıyla birleşir.

### Kullanım verisi (Caddy erişim günlüğü)

* **Ölçüm:** Caddyfile'da `log` yönergesi **yoktu**; erişim günlüğü kapalıydı.
* **Değişiklik** (`infra/Caddyfile`, `(erisim_gunlugu)` parçası, yalnız
  `app.*`):
  * **KVKK:** IP (`remote_ip`, `client_ip`), port, bütün istek ve yanıt
    başlıkları (çerez, Authorization, User-Agent), TLS bilgisi ve URI'nin
    **sorgu kısmı** kaynakta silinir. Kalanlar: metot, konak, yol, durum,
    süre, zaman.
  * **Gürültü:** Next.js bağlantı ön yüklemeleri (`Next-Router-Prefetch`),
    statik dosyalar ve `/api/*` `log_skip` ile hiç yazılmaz. Ön yüklemeler
    sayfa açılmadan gelir ve sayıyı şişirirdi.
  * **Saklama:** `caddy_data` biriminde `/data/erisim/app.log`; 50 MiB'de
    döner, 30 gün tutulur.
* **Doğrulama:**
  * `caddy validate` (bütün değişkenlerle): geçerli.
  * Gerçek Caddy ile işlevsel deneme: çerezli, yetkili ve
    `?kisi=<uuid>` sorgulu istekte günlükte yalnız
    `{"method":"GET","uri":"/kisiler/personel",...}` kaldı. IP, başlık ve
    kimlik yok.
  * Ön yükleme, statik ve `/api` istekleri yazılmadı.
* **Okuma:** `docs/P253-kullanim-olcumu.sh` (salt okuma; prod'da kullanıcı
  koşar).
  * Son N günde (varsayılan 30) GET 200/304 sayfa açılışlarını rota başına
    sayar; kimlik içeren yol parçalarını `[id]` yapar.
  * Örnek veriyle sınandı: eski kayıt ve POST sayılmadı.
* **Sınır:** günlük ilk dağıtımdan **itibaren** birikir. Geriye dönük
  kullanım verisi yok; bir ay sonra anlamlı olur. Aşama 1 sırası bu
  yüzden plandaki tahminle başlar.

### Mobil ortak bileşenler

Hepsi `mobile/lib/src/core/ui/` altında; testi
`test/p253_ortak_bilesenler_test.dart` (8 test).

**`liste_ekrani.dart` — `ListeEkrani<T>`** (plan §2.1):

* Kart listesi, dokununca detay.
* Arama: 350 ms bekler, her tuşa istek atmaz.
* **"Sırala / Süz"** tek pencerede. Seçili süzgeç liste başında **çip**;
  çipin silme düğmesinin erişilebilir adı "Durum süzgecini kaldır".
* **Sonsuz kaydırma:** sunucunun `limit/offset`i korunur; `toplam` gelince
  durur. Aşağı çekip yenileme.
* Boş ve hata durumları; hatada "Tekrar dene".
* Eski isteğin yanıtı yeni listeyi bozmaz (nesil sayacı).
* Sütun gizleme ve sayfa boyu **yok** (§A-5, `yapisal`).

**`coklu_secim.dart` — `CokluSecim`, `TopluEylem`, üst/alt çubuk** (plan §2.5):

* Uzun bas seçim kipini açar. Üstte "N seçili · Tümünü seç", altta işe özel
  eylemler.
* Son seçim kalkınca kip kapanır.
* **Geri tuşu önce seçimi kapatır, ekranı değil.**
* `ListeEkrani` kullanıyor; seçimi kendi yöneten ekranlar (bildirimler) da
  kullanabilir.

**`olustur_paylas.dart` — `olusturVePaylas`** (plan §2.3):

* İlerleme penceresi → baytlar → geçici dizine yazılır → **sistem paylaş
  menüsü** (WhatsApp, e-posta, Drive, Dosyalar).
* Dosya adı temizlenir (dizin ayıracı ve `..` atılır); dosya geçici dizin
  dışına yazılamaz.
* Oluşturma ya da paylaşım düşerse cümleyle söylenir ("Dosya
  oluşturulamadı."), sessiz düşme yok.
* iPad için paylaş menüsünün çıkış noktası verilir; verilmezse iPad'de
  çöker.

**Bağımlılık: `share_plus` 13.3.1** (+ `share_plus_platform_interface`;
`cross_file` ve `mime` zaten vardı). Lisans BSD-3.

* **Boyut ölçümü** (sürüm APK'sı, 1.10.0+20 ile karşılaştırma):
  * APK **+720 bayt**; `classes.dex` sıkıştırmasız +9,3 KB; `libapp.so`
    değişmedi.
  * Bileşen henüz hiçbir ekranda kullanılmadığı için Dart tarafı ağaç
    budamasıyla çıkıyor. Kullanılınca birkaç KB daha beklenir.
* iOS: sistem `UIActivityViewController`ini çağırır, ek varlık yok. iOS
  yapımında `pod install` yeni pod'u alır.
* Ölçüm yapımı 1.10.0+20 paketlerinin üzerine yazdı. Paketler yedekten geri
  kondu; SHA-256'lar kayıttakiyle aynı.

### İstemci tarafı eylemler — `data-eylem` yerine yardımcı çağrısı taraması

Plan §4.5'te, uç üretmeyen web eylemleri (CSV indir gibi) için kaynakta
`data-eylem="..."` işareti önerilmişti.

* **Önce bir düzeltme:** bu bölümün ilk yazımında "örnekle denendi"
  yazmıştım. İşareti koda koyup denemedim; yalnız akıl yürütmüştüm.
  Aşağıdaki karar gerçek bir ölçüme dayanıyor.
* **Ölçüm:** web'deki istemci tarafı dışa aktarımların hepsi iki ortak
  yardımcıdan geçiyor (`lib/csv.ts`: `csvIndir`, `csvMetniIndir`). Beş
  çağrı yeri var:
  * `/reports/tasks`, `/reports/dues`, `/bakim`, devriye takibi: CSV
    dışa aktarım;
  * `/ice-aktarim`: şablon indirme.
* `URL.createObjectURL` kullanan yerler ya **sunucudan gelen** dosya (rapor,
  ekstre, vardiya Excel'i; bunlar zaten uç üretir) ya da görsel önizlemesi
  (eylem değil).
* **Karar:** `data-eylem` işareti **kullanılmadı**. İşaret, eylemin
  varlığını değil, geliştiricinin onu işaretlemeyi **hatırlamasını** ölçer;
  işaretsiz yeni bir düğme kilitten sessizce geçer. Yardımcının **çağrı
  yeri** ise kendiliğinden bulunur. Web kilidi bu iki yardımcının her çağrı
  yerini tarar ve her biri için tabloda `istemci:<rota>` satırı ister.
* **Kalan risk:** biri bir dışa aktarımı yardımcıyı kullanmadan, elle
  `Blob` kurarak yazarsa yakalanmaz. Tarayıcı `new Blob(` görürse de uyarır.
  Bugün bunu yapan tek yer `lib/csv.ts`'nin kendisi.
* Tablo bileşeninin kendi araçları (sütun gizleme, sayfa boyu) karar gereği
  tabloda tek `yapisal` satırdır (§A-5).

### Eylem paritesi tablosu ve üç kilit

**Tablo** (`contracts/eylem-paritesi.tsv`): sözleşmedeki **her** işlem
(660) + 5 istemci tarafı dışa aktarım = **665 satır**.

| Durum | Satır | Anlamı |
|---|---:|---|
| `ayni` | 283 | Web ve mobil aynı ucu çağırıyor |
| `planli:1` | 35 | Aşama 1 |
| `planli:2` | 55 | Aşama 2 (2'si istemci CSV) |
| `planli:3` | 76 | Aşama 3 (3'ü istemci CSV) |
| `yalniz_web` | **0** | Hedef sıfır; gerekçesiz kalan yok |
| `platform` | 43 | Yalnız platform admini (kapsam dışı) |
| `yalniz_mobil` | 83 | Saha, sakin ya da cihaz akışı |
| `yapisal` | 31 | İş iki yüzeyde, uç farklı ya da bilinçli (gerekçeli) |
| `ic` | 59 | Hiçbir yüzey çağırmıyor (Dükkan, webhook, eski uç) |

**Nasıl üretildi** — elle değil, iki kaynak taramasıyla; ardından plan
aşamalarına göre önek kuralları:

* **Web taraması** (`admin-web/tests/eylem-tarama.ts`):
  * 286 BFF rotasının ilettiği metot ve yol.
  * Genel vekiller (`panel/[kaynak]`, `tanimlar/[kaynak]`, eylem rotası)
    beyaz liste modüllerinden açılır.
  * 365 **açık** yolun **hepsi** sözleşmeyle eşleşti; web 492 işleme
    gidebiliyor.
* **Mobil taraması** (`mobile/test/helpers/eylem_tarama.dart`):
  * Kapsananlar: Dio çağrıları, sabit yollar, sarmalayıcılar
    (`_liste('/x')`).
  * Son parçası değişken eylem olan yollar (`/panik/$id/$eylem`) çağrı
    yerlerindeki dizelerle açılır, üç katmana kadar
    (`_eylem(context, ref, 'baslat')` → `api.eylem(id, eylem)` →
    `/tatbikat/{x}/baslat`).
  * Özel adlar dosya içinde aranır (panik ve diyafon ikisi de `_eylem`).
  * 374 işlem, hepsi eşleşti.
* **Ortak eşleme kuralı** (üreteç, web ve mobil kilidi aynı):
  * sabit parça 2 puan;
  * değişken↔parametre 1 puan;
  * değişken↔sabit 0 puan.
  * Kilit, bu kuralı koymadan önce bir tutarsızlık yakaladı:
    `/integrations/${id}` hem `{id}` hem `presets` ile eşleşiyordu.
* Kurala uymayan 23 satır **elle** sınıflandırıldı, gerekçeleri tabloda.
  Örnekler:
  * detay kaydını web ayrıca çekiyor, mobil listedeki kaydı kullanıyor;
  * kamera HLS parçalarını oynatıcı doğrudan istiyor.

**Kilitler** (her biri kırılarak doğrulandı):

| Kilit | Ne ölçer | Kırma denemesi → sonuç |
|---|---|---|
| `backend/tests/test_p253_eylem_paritesi.py` | Sözleşmedeki her işlem tabloda **tam bir kez**; bayat satır yok; `roller` yetki matrisiyle aynı; durum ↔ +/- tutarlı; `ayni` dışında gerekçe | `DELETE /kasalar/{id}` satırı silindi → düştü · `/me/calisma` rolü değiştirildi → düştü · planlı satırın gerekçesi silindi → düştü |
| `admin-web/tests/p253-eylem-paritesi.test.ts` | Web'in her açık çağrısı sözleşmede; web'in yapabildiği her işlem `web=+`; `web=+` satır taramada var; istemci dışa aktarımlar `ISTEMCI` satırlarıyla bire bir; yardımcı dışında `new Blob(` yok | `GET /finans/hareketler` `web=-` yapıldı → düştü · yeni `csvIndir` çağrısı → düştü · olmayan uca giden yeni BFF rotası → düştü |
| `mobile/test/p253_eylem_paritesi_test.dart` | Mobilin her çağrısı sözleşmede ve `mobil=+`; `mobil=+` satır mobilde **gerçekten** çağrılıyor; **aşama sürümü çıkınca `planli:N` kalamaz** (1→1.11.0, 2→1.12.0, 3→1.13.0) | `GET /me` `mobil=-` yapıldı → düştü · sürüm 1.11.0 yapıldı → 35 `planli:1` satırı için düştü |

**Rol sütunu — sınırını yazıyorum.**

* Rol sütunu planda "web `ROTA_ROLLERI` ile mobil menü rolü karşılaştırılır"
  diye geçiyordu. Uygulanan: **backend yetki matrisi** (ucu kim
  çağırabilir).
* Gerekçe: rol tutarsızlığının kaynağı sunucudur. Bir ucun yetkisi değişince
  tablo kırmızı olur ve parite kararı yeniden okunur.
* **Görmediği:** sunucu izin verip mobil menünün o role ekranı **çizmemesi**.
  Bu turdaki iki örnek: yöneticinin araç geçişi, denetçinin mobil yüzeyi.
  * Bunlar menü kilidinin (`menu-paritesi.tsv`) işi.
  * Denetçi Aşama 2'de mobil yüzey kazanınca menü kilidine `denetci`
    kapsamı eklenecek.

**İşlem düzeyinde olmayan fark — sınır:** aynı ucu çağıran iki ekranın aynı
**alanları** gönderip göndermediği ölçülmüyor. Örnek: mobil tahsilatta
tarih ve belge no yok. Bunlar planın §1 tablosunda `KISMEN` olarak duruyor
ve aşamalarda kapatılır.

## §E — "Şimdi çalıştır" saat dilimi

### Ölçüm

* Uygulama saati UTC. Tesis tablosunda `timezone` alanı var (varsayılan
  `Europe/Istanbul`) ama **hiçbir "bugün" hesabı onu okumuyordu**.
* İstek yolunda 17 yerde UTC "bugün" vardı.
  * **Elle tetiklenenler:**
    * maaş "Şimdi çalıştır";
    * gecikme faizi önizle ve işle;
    * aidat planı önizlemesi;
    * hatırlatma önizlemesi.
  * **İstek yolundakiler:**
    * finans özeti (ay başı);
    * tahsilat göstergesi (bu ay);
    * aidat gecikme gösterimi;
    * bakım durumu (bugün / gecikti);
    * maaş kartının ilk dönemi (gece yarısından sonra girilen maaş);
    * personel detayı (bu ay);
    * mesaj şablonundaki `{tarih}`;
    * rapor varsayılan tarihleri.
  * **Defter ve gecikme varsayılanları;** günlük görev ise tek UTC günüyle
    bütün tesisleri koşuyordu.
* **Etki:** İstanbul'da 00:00–03:00 arası elle tetiklenen işler bir önceki
  günü görüyordu. Ayın 1'i gecesi maaş **önceki ayı** hesaplardı.

### Düzeltme

* Yeni `app/tesis_saati.py`:
  * `yerel_bugun(saat_dilimi, simdi)`: saf işlev;
  * `tesis_bugun(db)`: oturumun tesisinden okur (RLS).
* Gecersiz saat dilimi finans işlemini düşürmez; varsayılan bölge kullanılır.
* Yukarıdaki her yer `tesis_bugun(db)` kullanır.
* Günlük görev, gün verilmediyse **her tesis için kendi gününü** hesaplar.
* **Bilinçli istisna (2):** tahsilat tarihinin ve devriye ek tarihinin
  "ileri/geçmiş" doğrulaması UTC'ye **bir gün pay** tanıyor. Tesis günü
  UTC'den en fazla bir gün farklı olabilir; pay bunu zaten karşılıyor.

### Kilit

`tests/test_p253_saat_dilimi.py`:

* **Ay sınırı:** 31 Ekim 22:30 UTC, İstanbul'da 1 Kasım 01:30 eder; maaş
  dönemi Kasım olmalı.
* **Yıl sınırı ve geçersiz saat dilimi.**
* **Kaynak taraması:** istek yolunda UTC "bugün" yasak; yalnız gerekçeli
  istisnalar geçer. Kırılarak doğrulandı: bir yönlendiriciye `date.today()`
  eklenince test düşüyor.

### Aynı hatanın başka yerleri (tarandı)

* **SMS/e-posta günlük kotası:** gün sınırı UTC'ydi ve kodda "bilinen sınır"
  diye yazılıydı. Artık tesisin gün başı (`tesis_gun_basi`): İstanbul'da
  00:00–03:00 arası gönderimler dünün kotasına yazılmıyor.
* Diğer elle tetiklenen uçlar yukarıdaki listede.
