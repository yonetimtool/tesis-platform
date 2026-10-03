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
(660) + 5 istemci tarafı dışa aktarım = **665 satır**. §D dört uç ekledi
(3 `ayni`, 1 `platform`); güncel toplam **669** (`ayni` 286, `platform`
44 — diğerleri aynı).

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

## §D — Şikâyet gizliliği

### Ölçüm (her yüzey)

| Yüzey | Bulgu |
|---|---|
| `GET /unit-complaints` (liste), `PATCH`, `/okundu`, `POST` yanıtı | Şemada `complainant_user_id` ve `complainant_ad` **duruyordu**, her zaman `null`. Değer sızmıyordu ama alanın varlığı bir gün doldurulmasına davetiyeydi. |
| Web harita daire ayrıntısı | `complainant_ad` gelirse **gösteren** dal vardı (`haritaSikayetEden`). Metin "kimlik yalnız yönetime gösterilir" diyordu — **yanlıştı**. |
| `/density`, `/building-map`, `/gorunur-sayi`, `/mine` | Kimlik yok. |
| `/activity` | Anonim; sakin yalnız kendi kayıtlarını görür. |
| Bildirimler | `sikayet_cozuldu` yalnız şikâyet edene; eşik bildirimi yönetime kişi adı içermiyor. |
| Raporlar / dışa aktarım / arama | Daire şikâyeti hiçbir rapora, dışa aktarıma ya da aramaya girmiyor (kaynak taraması). |
| **`GET /audit`** (platform) | **Sızıyordu:** `unit_complaint_file` ve `unit_complaint_withdraw` satırlarının aktörü şikâyet eden; `resource_id` şikâyetin kendisi. Platform yöneticisi gerekçesiz ve denetimsiz eşleyebiliyordu. |
| Mobil | Model alanları okuyordu ama çizmiyordu; güvence metni "komşularınıza gösterilmez" diyordu (yönetimi söylemiyordu). |

### Kararlar

1. **Kimlik hiçbir site rolüne dönmez.**
   * `complainant_*` alanları şemadan, sözleşmeden, web tipinden ve mobil
     modelden **kaldırıldı**. Web'deki gösteren dal silindi.
   * `/audit` bu iki eylemde aktörü `null` verir.
   * Kimlik veritabanında durur (sınırlama ve resmî açma için).
   * Metin: web "Şikâyet edenin kimliği kimseye gösterilmez — yönetim
     dahil", mobil oluşturma ekranı "Kimliğiniz kimseye gösterilmez —
     yönetim dahil" (7 dil).
2. **Eşik farklı kaynak daire sayar.**
   * Yeni sütun `unit_complaint.kaynak_unit_id`: şikâyetçinin hedefin
     bloğundaki aktif dairesi.
   * Sayaç `count(DISTINCT coalesce(kaynak_unit_id, complainant_user_id))`.
     Aynı evden iki kişi tek kaynak sayılır.
   * Eski satırlar göçte dolduruldu.
   * Ayar metni "Kaç farklı daireden şikâyet gelince uyarı gitsin" oldu.
3. **Günlük sınırlar.** Önerilen varsayılanlar:
   * Aynı kişi → aynı daire: 24 saatte 2. Bir gecede iki ayrı olay
     (akşam + gece yarısı) olağan; üçüncüsü bildirim değil baskı.
   * Aynı kişinin toplamı: 24 saatte 5. Sınırı gerçek kullanıcıya değil
     toplu atışa koyar.
   * Mevcut kural (aynı daire + aynı kategori 7 günde 1) aynen duruyor.
   * Yanıt 429 `rate_limited`, kibar metinle ("…yönetim kayıtlarınızı
     aldı. Yarın yeniden bildirebilirsiniz."). Mobil bunu kırmızı hata
     olarak değil, bilgi satırı olarak çizer.
   * Sınırlar şimdilik sabit (`app/sikayet_koruma.py`). Tesis ayarı
     istenirse tek yerden açılır.
4. **Yönetim yalnız örüntüyü görür.**
   * Yeni uç `GET /unit-complaints/kaynak-ozeti`: son 30 günde kaç
     şikâyet, kaç farklı daireden.
   * "Çoğu tek daireden" rozeti: en az 4 şikâyet ve en az %75'i tek
     kaynaktan.
   * Kaynak **etiketi yok**. "Kaynak A" gibi bir etiket iki özet
     arasında kişiyi izlemeye yeterdi.
5. **"Asılsız" işareti.**
   * Uçlar: `POST/DELETE /unit-complaints/{id}/asilsiz`. Gerekçe zorunlu.
   * Şikâyet edene `sikayet_asilsiz` bildirimi gider (uygulama içi +
     push). Yönetim kim olduğunu öğrenmez.
   * Kademe, kişi başına son 90 gün:
     * **Eşik dışı:** en az 2 asılsız **ve** oranı en az %50. Tek bir
       hatalı işaret kimseyi susturmaz. Çok şikâyet edip birkaçı asılsız
       çıkan gerçek mağdur da etkilenmez (oran şartı).
     * **Askıda:** en az 4 asılsız **ve** oranı en az %60. Son işaretten
       14 gün yeni şikâyet açamaz; 429 `sikayet_askida` ve
       `sikayet_sinirlama` bildirimi alır. 14 gün, "bir sonraki hafta
       sonu"nu kapsar ama kişiyi kalıcı dışlamaz.
   * Durum **saklanmaz, her seferinde hesaplanır**: işaret geri alınınca
     ya da pencere geçince kısıtlama kendiliğinden kalkar.
   * Asılsız şikâyet haritayı ve görünür sayıyı boyamaz.
6. **Resmî kimlik açma yalnız platform.**
   * Uç: `POST /platform/sikayet-kimlik`, yalnız `admin`. Gerekçe en az
     20 karakter.
   * Her görüntüleme o tesisin denetimine `sikayet_kimlik_acma` olarak
     yazılır; ikinci bakış ikinci kayıttır.
   * POST kullanıldı: kimlik sorgu dizesinde ya da erişim günlüğünde
     kalmasın.
   * Panel sayfası `/sikayet-kimlik` (platform menüsü). Yöneticiye kayıt
     no gösterilir; resmî talepte o iletilir.
   * Site yöneticisi 403 (rol matrisi + test).

**Göç:** `0168_p253_sikayet_gizlilik`.

**Kilitler** (`backend/tests/test_p253_sikayet_gizlilik.py`):

* Gizlilik: 10 okuma ucu × 7 site rolü, artı yönetim eylemlerinin
  yanıtları. Ne `complainant` anahtarı, ne şikâyet edenin id, e-posta ya
  da adı.
* `/audit` maskesi; şemada kimlik alanı yok.
* Eşik: bir kişinin 5 şikâyeti doldurmaz, 3 farklı daire doldurur; eşik
  dışı kişi sayılmaz.
* Sınırlar ve metinlerin tonu.
* Asılsız: gerekçe, bildirim, yalnız yönetim, askı + geri alınca kalkma.
* Kaynak özeti, platform açma.
* Kırma denemesi: `DISTINCT` kaldırıldı → eşik testi düştü; `/audit`
  maskesi kaldırıldı → denetim testi düştü.
* Mobil: `p253_sikayet_gizlilik_test.dart` (taklit HTTP adaptöründe) ve
  `building_schematic_test` 429 bilgi satırı.

**Web ↔ mobil:**

* Web harita daire ayrıntısı ve mobil yönetim şikâyet kuyruğu ayrıntısı
  aynı üç ucu çağırıyor (eylem tablosunda `ayni`).
* Sakinin kendi listesi kararı ve gerekçeyi gösteriyor (mobil; web'de
  sakin şikâyet yüzeyi yok, şikâyet mobilde açılır).
* Bildirim yönlendirme iki yüzeyde: mobil "Şikâyetlerim", web
  `/taleplerim`.

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

## Aşama 1 — Günlük ve kolay işler (mobil 1.11.0)

### Prod ölçümleri (kullanıcı ölçtü)

* **Mesaj:** gitmediği hâlde "gönderildi" denen yalnız 2 SMS var (Oltu,
  28–29 Ağustos, SMS kanalı kapalıyken, test). Gerçek kayıp yok.
* **Kullanım günlüğü:** dağıtımda Caddy yeniden oluşturulmamıştı; açıldı,
  yazıyor, satırlarda IP ve kullanıcı yok. Aşama 2 önceliği veri birikince
  düzeltilecek.

### Erişim günlüğü düzeltmeleri

* **Sorgu dizesi:** zaten kaynakta siliniyordu; şimdi `multi_regexp` ile
  `?` ve `#` sonrası siliniyor.
  * Kanıt: gerçek Caddy 2.11.4'te `/kisiler?q=Ahmet%20Yilmaz` günlükte
    `/kisiler` olarak yazıldı.
* **Jetonlu yollar maskelendi.** Tarama sonucu, web'de yolda jeton taşıyan
  tek sayfa `/davet/[jeton]`. Diğerleri:
  * şifre sıfırlama: e-postayla gelen kod, yolda jeton yok;
  * OAuth dönüşü: sorgu dizesi kullanıyor, zaten siliniyor;
  * paylaşım bağlantısı: web'de yok.
* **Kurallar** (Caddy'de sırayla):
  1. `/davet/:jeton`;
  2. UUID → `/:id`;
  3. 24 karakterden uzun jeton benzeri parça → `/:jeton`;
  4. sayı → `/:id`.
  * 24 eşiği bilinçli: en uzun sayfa adı (`rezervasyon-yonetimi`) 20
    karakter.
* **Kilit:** `admin-web/tests/p253-erisim-gunlugu.test.ts`. Caddyfile'daki
  kuralları okur ve uygular; şunları ölçer:
  * sorgu silinir;
  * herkese açık her dinamik sayfanın maskesi var;
  * hiçbir gerçek sayfa yolu maskeye takılmaz.
  * Kırma denemesi: eşiği 18'e indirmek ya da davet kuralını silmek testi
    düşürdü.
* **Döndürme:** zaten ayarlıydı. 50 MiB'de döner, en çok 20 dosya, 30 gün
  (`roll_keep_for 720h`); disk payı en çok ~1 GB.
* **Ölçüm betiği:** Caddy'nin maskeleriyle aynı sırayı uygular. Maskeden
  önceki ham satırlar ile sonraki maskeli satırlar aynı rotada toplanır
  (örnek veriyle sınandı).
* **Dağıtım belgesi** (`docs/DAGITIM-SABLONU.md`): Caddyfile ya da `caddy`
  servisi değişince `up -d --force-recreate caddy` gerekiyor. Yalnız
  Caddyfile değiştiyse kesintisiz `caddy reload` yeterli.

### §C finans kuralı — uygulandı

1. **Onay diyaloğu, tutar ve hedefle:**
   * web `hareket-sayfasi` onayla, reddet ve iptal;
   * mobil `core/ui/finans_onay.dart`: finans defteri onayla ve reddet,
     otomasyon ekranındaki maaş onayı (tekil ve toplu).
   * Hedef: daire · kişi · belge no.
2. **Sebep zorunlu** (red ve iptal/ters kayıt):
   * Sunucu `SEBEP_ASGARI = 3`; altında 422 `sebep_zorunlu`, kayıt
     dokunulmadan kalır.
   * Web ortak onay kancasına zorunlu sebep alanı eklendi
     (`sebepleOnayla`).
   * Mobil diyalog da aynı eşikle çalışır.
   * Sebep iptal denetim kaydına da yazılıyor; önceden yazılmıyordu.
3. **Aynı uçlar:** mobil için ayrı uç yok.
4. **Geri al:**
   * **Vardiya:** "haftayı doldur" ve "haftadan kopyala" sonrası geri al.
     Sunucu yeni satır kimliği döndürmediği için mobil önce/sonra farkıyla
     yalnız yeni satırları siler.
   * **Geri alınamayanlar** diyalogda önceden yazılı: ret, toplu çıkarma,
     kopyada "hedefi temizle".
   * **Onay** geri alınamaz; diyalog ancak iptalle (ters kayıt)
     düzeltilebileceğini söyler.
5. **Denetimde yüzey:**
   * `X-Istemci-Yuzey` başlığını web BFF ve mobil Dio gönderir.
   * `IstemciYuzeyi` ASGI katmanı bunu okur; `record_audit` her satıra
     `meta.yuzey` yazar.
   * Başlıksız ya da geçersiz başlıklı istek `bilinmiyor` olur. İstek dışı
     işlerde (Celery) alan yazılmaz.
   * Yetki bu başlığa bağlanmaz.
   * Kilit: `backend/tests/test_p253_finans_kurali.py`. Sebep kontrolü ve
     yüzey yazımı kaldırılınca 11 testin tamamı düştü.

### Mobil — kapatılan işler (35 `planli:1` satırı → `ayni`)

| Alan | Uçlar | Notlar |
|---|---|---|
| Finans | hareketler, kasa bakiyeleri, özet, reddet, hatırlatma geçmişi, otomasyon günlüğü (+ `GET /firmalar`, `planli:2`'den) | Yeni "Finans defteri" (özet + hareketler sekmesi); gider ve tahsilatta tarih, belge no, firma; gelir girişi gider ekranında |
| Vardiya | şablon CRUD, blok düzenle, haftayı doldur, haftadan kopyala, kalıp sil, döngü sonlandır, izin listesi/onay/red/sil | Hafta gezinmesi, toplu seçim, geri al |
| Kişiler, görev, ek | kişi kartı, kişi sil, açılabilir roller, görev ayrıntısı, adım düzenle, ek sil | Arama + aktif/pasif süzgeci; "Aranabilir" anahtarı; ek sil her yerde |
| Günlük küçükler | (var olan uçlar) | Panik kapanış notu, ziyaretçi "içeride", görev durum süzgeci, dış hizmet arama, rezervasyon süzgeçleri, devriye tarih aralığı |
| Dokümanlar | liste, yükle, düzenle, sil, indir | Rol ayrımlı giriş |
| Hatırlatma ve takvim | hatırlatma CRUD, takvim | Yeni "Takvim" menü girişi (`menu-paritesi.tsv`: `yalniz_mobil` — web'de Özet kartı) |
| Sakin | makbuzlar + PDF paylaş | Aidat ekranından |

**Tablo sonrası:** `planli:1` **0**.

| Durum | Satır |
|---|---:|
| `ayni` | 322 |
| `planli:2` | 54 |
| `planli:3` | 76 |
| `yalniz_web` | 0 |

Mobil sürüm **1.11.0+21**. Sürüm kilidi artık `planli:1` satırına izin
vermiyor.

### Kısmi kalanlar (açık)

* **Doküman yükleme:**
  * Mobil yalnız fotoğraf (kamera/galeri) yükleyebiliyor. PDF ve diğer
    dosyalar için `file_picker` bağımlılığı gerekir; onaysız eklenmedi.
  * Form kullanıcıya "PDF için web paneli" diyor.
  * Bağımlılık kararı kullanıcıda.
* **Hareket listesinde serbest arama ve durum süzgeci yok:** sunucu ucu `q`
  ve `durum` almıyor, web'de de yok. Tür ve kasa süzgeci var.
* **Serbest döngü tanımı** (dilim/adım editörü): mobilde yok, tabloda ayrı
  satırı da yok. Önceden de yalnız web'deydi.
* **Rezervasyon süzgeçleri** cihazda uygulanıyor, sunucu parametresiyle
  değil.
* **Borçlandırma ters kaydında §C sebebi:** Aşama 2'de, borçlandırma
  mobile geldiğinde (`planli:2`).

## Aşama 2 — Harita karo kaynağı önerisi (karar 8) — **KARAR BEKLİYOR**

### Ölçüm

* **Web bugün:** Leaflet + OSM'nin genel karoları
  (`tile.openstreetmap.org`). Adres `NEXT_PUBLIC_KARO_URL` ile tek satırda
  değişebiliyor. Adres arama sunucuda (`/konum/ara`, open-meteo geocoding);
  haritaya bağlı değil.
* **Mobil bugün:** harita yok.
* **Mobil paket boyutu** (gerçek derleme, arm64 sürüm APK, taban 29,37 MB):
  * `flutter_map` 8.3.2 + `latlong2` 0.10.1: **+324 KB** (331.588 bayt);
  * `file_picker` 13.1.0 (onaylandı, eklendi): **+23,5 KB**.
* **Hacim tahmini:** harita yalnız yönetici ekranlarında var (tesis konumu
  kurulumda bir kez, devriye haritası ara sıra). 300 tesis × ayda ~20
  harita görünümü × ~15 raster karo ≈ **90.000 karo/ay**. Kendi
  önbelleğimizle bunun belirgin bir kısmı tekrar istekten düşer.

### Seçenekler (fiyatlar 2026-10, sağlayıcı sayfalarından)

| Seçenek | Maliyet | Lisans / kural | Artı | Eksi |
|---|---|---|---|---|
| **A. OSM genel karoları** (bugünkü web) | 0 | Karo politikası: yoğun kullanan bir uygulamayı önceden izin almadan dağıtmak yasak; benzersiz User-Agent zorunlu; uyarısız engellenebilir | Sıfır maliyet, değişiklik yok | Mobil uygulamada dağıtmak politikayla çatışır; engellenme riski. Kullanıcı IP'si OSM'ye gider |
| **B. Stadia Maps Starter** | $20/ay; 1M kredi (1 raster karo = 1 kredi) | Ticari kullanım serbest (ücretsiz planda yasak) | Raster: Leaflet ve `flutter_map` aynı URL şablonuyla; tahmini hacmin ~11 katı pay | Aylık ücret; anahtarın istemcide görünmemesi için vekil gerekir |
| **C. MapTiler Flex** | $30/ay; 25.000 oturum + 500.000 istek | Ticari serbest (ücretsiz planda yasak) | Oturum fiyatlaması | B'den pahalı; raster karo 10–16 istek/görünüm |
| **D. Kendi karo sunucumuz** (Protomaps PMTiles, Türkiye kesiti) | Disk + işletim (dünya ~120 GB; Türkiye kesiti çok daha küçük, **ölçmedim**) | ODbL, OSM atfı zorunlu | Üçüncü taraf yok, IP kimseye gitmez | **Vektör** karo: web'de `protomaps-leaflet`/MapLibre, mobilde `vector_map_tiles` gibi ek ve daha ağır bağımlılık; kurulum ve güncelleme işi |

### Önerim: **B (Stadia Starter) + kendi karo vekilimiz**

* **Vekil:** istemciler karoyu bizden ister (`/karo/{z}/{x}/{y}.png`, API
  ya da Caddy). Sunucu sağlayıcıdan alır ve önbelleğe koyar.
  * API anahtarı sunucuda kalır, uygulamaya gömülmez.
  * Kullanıcının IP'si üçüncü tarafa gitmez (KVKK).
  * Önbellek kredi harcamasını düşürür.
  * İleride sağlayıcı değişirse (D'ye geçiş dahil) **mobil güncelleme
    gerekmez**.
* **Web:** Leaflet aynı kalır; `NEXT_PUBLIC_KARO_URL` vekile döner.
* **Mobil:** `flutter_map` + `latlong2` (+324 KB). Tesis konumu (iğne
  sürükle) ve Aşama 3'teki devriye haritası bunu kullanır.
* **Sıfır maliyet isterseniz:** A + aynı vekil + önbellek. Önbellekli
  düşük hacimde politikanın "yoğun kullanım" eşiğine yaklaşmak
  olası değil, ama izin alınmadan dağıtılan bir uygulama için engellenme
  riski sürer. Vekil sayesinde sonradan B'ye geçiş tek ayar olur.

**Karar gereken:** B mi, A mı (ikisi de vekille), yoksa D mi. Onaya kadar
mobile harita bağımlılığı eklenmez; tesis konumu ekranı bekler (`/konum/ara`
satırı `planli:2` kalır).

**Karar (kullanıcı):** kendi karo dosyamız (D). Uygulandı; ayrıntı
`docs/harita-karo.md`.

## Aşama 2 — Haftalık işler, finans düzeltmeleri, tanımlar, denetçi (mobil 1.12.0)

### Kararlar (kullanıcı)

* **`file_picker`:** onaylandı; eklendi (arm64 APK +23,5 KB, ölçüldü).
  Doküman yükleme PDF alıyor; Aşama 3'teki içe aktarım ve banka ekstresi
  aynı ortak seçiciyi (`core/dosya/dosya_secici.dart`) kullanacak.
* **Hareket araması ve durum süzgeci:** sunucuya eklendi (`q`, `durum`).
  * `q` açıklama, belge no, kişi, daire, firma ve personel adında arar;
    Türkçe harf katlamalı, joker karakterler literal.
  * Web ve mobil aynı parametreleri gönderiyor.
* **Serbest döngü tanımı:** eylem tablosuna yeni satır türü `YETENEK`.
  * Uçlar aynı, eksik olan ekran yeteneğiydi; kilitler kaynakta
    `yetenek:<ad>` işaretini ölçer.
  * Mobilde yapıldı, satır `ayni`.
* **Rezervasyon süzgeçleri:** cihazda kaldı.
  `docs/acik-is-rezervasyon-suzgecleri.md`: sunucu parametreleri zaten
  var, taşımak yalnız mobil işi.
* **Harita:** kendi Türkiye PMTiles dosyamız (yukarıda).

### Kararsız test — kök neden

`test_notifications::test_mark_read_and_isolation` tam takımda düşüyordu.
* **Kök neden:** testin "geçmiş" penceresi 2029 tarihliydi, yani gerçek
  saate göre gelecekte. Saat başı çalışan `materialize_windows` aktif
  planın takvim dışı gelecek `bekliyor` pencerelerini siliyor (doğru ürün
  davranışı). Üretici araya girerse pencere siliniyor, bildirim hiç
  yazılmıyordu.
  * Yeniden üretildi: 0 bildirim. Düzeltmeden sonra: 1.
* **Kapsam:** P248'de yalnız `test_dashboard` düzeltilmişti; aynı kalıp
  `test_notifications`, `test_scans`, `test_scheduler_db` ve
  `test_tur_butunlugu`'nda da vardı. Hepsi gerçek geçmişe bağlandı.
* **Prod karşılığı:** yok; hata testin tarihindeydi.
* **Kilitler:**
  * üretici araya girse de bildirim yazılır (regresyon testi);
  * pencere testlerinde sabit gelecek yıl yasak (kaynak taraması).
  * Kırma denemesi: taban 2029'a döndürülünce ikisi de düştü.

### Bu aşamada bulunan ve düzeltilen gerçek hatalar

* **Prod'da api'ye ulaşmayan ayarlar** (compose `environment` beyaz liste,
  `env_file` yok):
  * `DUKKAN_MOBIL_ACIK`: belgedeki "true yap" tarifi hiçbir şey yapmazdı.
  * `RESEND_WEBHOOK_SIRRI`: Resend webhook'u her istekte 401 dönüyordu,
    e-posta teslim durumları prod'da hiç güncellenmiyordu.
  * `PLAY_STORE_URL`, `APP_STORE_URL`.
  * Kilit: `test_compose_ortam`. `.env.prod.example`'da tarif edilen her
    `Settings` alanı prod api ortamında olmalı.
* **Web'den PDF yükleme 422 alıyordu:** doküman sayfası presign isteğine
  `amac: "belge"` göndermiyordu. Seçici, sunucunun reddettiği Word, Excel
  ve zip türlerini de sunuyordu.
  * Kilit: `p253-belge-yukleme-amaci`.
* **Web "faizi affet" onaysız çalışıyordu:** artık §C onay diyaloğu var.

### §C — bu aşamada

* **Sebep zorunlu:** borçlandırma ters kaydında da. Ortak modül
  `app/sebep.py`; web ve mobil diyalog.
* **Toplu tahakkuk geri al:**
  * Toplu tahakkuk bir `parti_id` döner (göç
    `0169_p253_parti_rapor_hazir`).
  * `POST /borclandirma/parti/{parti_id}/geri-al` partiyi tek istekte
    ters kayıtla kapatır; sebep zorunlu.
  * Ödeme almış satır geri alınmaz, `odenmis` nedeniyle döner.
  * Web: sayfada "Son toplu borçlandırma — Geri al" şeridi. Mobil:
    sihirbazın sonuç ekranında.
* **Geri alma diğer finans eylemlerinde:** iptal, iade, virman, açılış ve
  toplu tahsilat sonrası mobilde "Geri al" var; o da sebep istiyor.
* **Önceden yazılan geri alınamazlık:** faiz affı ve ödeme planı geri
  alınamaz; diyalog bunu önceden yazıyor.

### "Rapor hazır" bildirimi (yeni)

* Kuyruktaki rapor bitince yalnız isteyene kalıcı bildirim ve push
  (`rapor_hazir`) gider.
* Eskiden hiç haber gitmiyordu; yalnız "İşlerim" ekranı açıkken yoklama
  vardı.
* Bildirim, rapor kaydının güncellemesiyle aynı işlemde yazılmıyor.
  P252'deki kilitlenmenin kökü "aynı işlemde ikinci yazma + FK
  denetimi"ydi.
* Web `/raporlar`, mobil rapor merkezi "İşlerim" sekmesi.

### Mobil — kapatılan işler

| Alan | İçerik |
|---|---|
| Borçlandırma | Liste, tekil, toplu tahakkuk sihirbazı (5 adım), ters kayıt, gecikme faizi, daire borç durumu, ödeme kaydı |
| Finans düzeltmeleri | İptal, iade (kısmi), virman, toplu tahsilat, faiz affı, ödeme planı, açılış fişi; hareket arama + durum |
| Raporlar | Katalog, parametre formu, göster, Excel/PDF paylaş, kuyruk + İşlerim + "hazır" bildirimi; borçlu ve görev CSV karşılıkları |
| Tanımlar | Tek genel defter ekranı (7 defter + muhasebe ayarları + görev kategorisi), web `DEFTERLER` ile birebir |
| Tesis ayarları | 16 operasyon ayarı (web tablosuyla aynı anahtarlar), **tesis konumu** (adres arama + kendi karolarımızla harita, iğne) |
| Bütçe hedefleri | Liste, yaz, sil, karşılaştırma |
| Denetçi | Salt okuma yüzeyi: raporlar, şeffaflık, icra, bakım. Menü kilidine `denetci` kapsamı eklendi |
| Serbest döngü | Dilim ve blok düzenleyici (`YETENEK` satırı) |
| Belge yükleme | PDF (`file_picker`) |

### Eylem tablosu sonrası

**671 satır:**

| Durum | Satır |
|---|---:|
| `ayni` | 378 |
| `planli:2` | **0** |
| `planli:3` | 76 |
| `yalniz_web` | 0 |
| `platform` | 44 |
| `yalniz_mobil` | 83 |
| `yapisal` | 31 |
| `ic` | 59 |

Mobil sürüm **1.12.0+22**.

### Kısmi kalanlar (açık)

* **Adres arama ve hava durumu: Open-Meteo'nun ücretsiz API'si ticari
  kullanıma kapalı.** Prod öncesi karar gerekiyor (`docs/harita-karo.md`
  "Adres arama — açık konu").
* **Doküman türleri:** sunucu belge olarak yalnız PDF (+ görsel) kabul
  ediyor. Word ve Excel istenirse sunucu değişikliği gerekir; şimdilik iki
  yüzeyde de seçici yalnız PDF ve görsel sunuyor.
* **Mobil rapor grafiği yok:** sonuç kart listesi olarak çiziliyor.
* **Mobil açılış fişi yalnız kasa bazlı:** kişi bazlı açılış (sunucu ve
  web destekliyor) mobilde yok.
* **Mobil toplu tahsilat** yalnız borçlular ekranındaki seçimden yapılıyor;
  web'deki serbest satır girişi yok.
* **Görev geçmişi CSV'si** mobilde 5000 satırda kesiliyor; artık ekranda "rapor eksik olabilir" uyarısı çıkıyor (web ile aynı).
* **Seçim kutuları** en çok 200 kayıt alıyor (kişi ve daire 500).
* **Web `banka` alan türü** (banka listesinden seçim) mobil tanımlarda düz
  metin.
