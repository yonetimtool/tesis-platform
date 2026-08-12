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
| **3** — Rol seçimli kayıt | 2 uç + web `/kayit` + mobil ekran (4 rol) | `2025f50`, `0987fc5` |
| **9 (kod, kısmen)** — Ortak gönderim | `app/gonderim.py` — kanal seçimi tek yerde | `1bdecf9` |
| — | Test sunucusu seed'i (tamamen uydurma veri) | `e9ec4fd` |
| **6.1 + 6.2** — Ortak `Modal` + `Liste` | `/tanimlar` bu ikisine geçirildi | `5eb1817` |
| **6.3** — Global arama | `/arama` ucu + üst bar; yetki routerdan okunuyor | `7ff8d2e` |
| **6.4** — Not ve ek sistemi | göç 0043 + `/ekler` + ortak `Ekler` bileşeni | `e57a944` |
| **7.1** — Menü mimarisi (web) | brief taksonomisi + `/icra` ekranı + daire tipleri | `e45eff7` |
| **7.1** — Menü mimarisi (mobil) | çekmece bölümlendi, katlanabilir, tercih kalıcı | `1f856a0` |
| **7.2 (6/7 madde)** — UI temizliği | parola göster/gizle · daire tipleri · alt menü rol bazlı · FAB yazısız · gizli aksiyonlar · görev kategorisi | `a513d82` |
| **7.2 (7/7)** — "Site sayfası" kaldırıldı | anket ayrıldı → portal silindi; **tablolar duruyor** | `7654572` |
| **7.3** — Onboarding sihirbazı | göç 0044 + `/kurulum` ucu + panel sayfası + ayarlar bağlantısı | `a7b8ad7` |
| **7.4** — Bağımlılık yönlendirmesi | `BagimlilikUyarisi` + `DonusCubugu` + 9 satırlık kayıt; 4 ekrana bağlandı | `8d18f56` |
| **8** — Import framework | göç 0045 + `/ice-aktarim` çatısı (4 tür) + geri alma + panel sayfası; `/site-aktar` kaldırıldı | bu tur |
| **9** — Bildirim/şablon altyapısı **TAM** | göç 0046 + mesaj kuyruğu + yeniden deneme; politika `yeniden_deneme.py`de paylaşıldı | bu tur |
| **10** — Apsiyon B kovası (kalanlar) | göç 0047 — ters kayıt + defterde silme kilidi; triyajda **iki yanlış ölçüm düzeltildi** | `e4f5a1d` |
| **4** — OAuth (Google/Microsoft/Apple) | Üç sağlayıcı × mobil+web · SMS'li eşleşme · hesap birleştirme · yöntem ekle/kaldır · konsol kılavuzu | bu tur |
| **5** — Kullanıcı ve yapı yönetimi | **12 maddenin 12'si**: kullanıcı silme · başlangıç katı · toplu nitelik/tip · sürükle-bırak (+klavye) · kat silme · blok toplu silme · toplu daire oluşturma · aralık seçimi · Excel→çatı · daire başına tek hesap | bu tur |

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

### 4.7 `kayit_dogrulama` RLS altına alındı — çözücü tasarlanıp uygulandı
Tablo **kimlik öncesi** okunuyor: satırı görmek için tenant bağlamı
gerekiyor, tenant'ı öğrenmek için de satırı görmek. Döngü, `tenant_id_by_slug`
ile aynı desende — **yalnız tenant kimliği döndüren** bir `SECURITY DEFINER`
fonksiyonla kırıldı. Ayrıntı: §6.7.

---

### 4.8 Menü satır bütçesi korundu — kilit gevşetilmedi (Aşama 7.1)

Brief FİNANS bölümünde yedi satır istiyor. Altısını `finans` grubuna
koyunca **ölçüldü:** bölüm 5 satırdan 11'e çıktı ve finans açıkken menü
17 satır oldu. Kerem'in ölçülebilir şartı "900px'te kaydırmasız ~10
satır"dı ve kilit 12'de duruyor.

Kilidi 17'ye yükseltmek ölçüyü işin peşinden sürümek olurdu. Bunun
yerine altı satır kendi **katlı** bölümüne alındı ("Finans hareketleri"),
mevcut "Daha fazla" desenini kullanarak: hepsi erişilebilir, günlük bütçe
11'de kaldı.

### 4.9 WhatsApp menü satırı BİLEREK eklenmedi (Aşama 7.1)

Brief'in İLETİŞİM listesinde WhatsApp var. Ama `mesaj_kanal` enum'u bugün
yalnız `sms, eposta` taşıyor — tıklanabilir ama şablonu **kaydedilemeyen**
bir satır, envanterde kusur olarak yazdığım "ölü bağlantı" sınıfının ta
kendisi olurdu. Aşama 9'un kalan işi (enum + şablon onay alanları,
`docs/whatsapp-arastirma.md`) bittiğinde tek satırla açılır.

### 4.10 Menü öğesinin kimliği artık (rota + sorgu) (Aşama 7.1)

Sorgu `href`e **gömülmedi**: `rotaYuzeyi`/`rotaRoldeGorunur` tam eşleşme
yapar, `"/finans?tip=gelir"` yazsaydık arama boşa düşer ve öğe hiçbir
rolde görünmezdi — sessizce. Tekillik kilidi `href`ten `href+sorgu`ya
taşındı; `key` ve aktiflik bu değerden okunuyor.

### 4.11 Alt menünün 4. yuvası saha rollerinde İŞE YARAMIYORDU (Aşama 7.2)

Ölçüldü: beş yuvanın biri güvenlik ve tesis görevlisi için yalnızca
"raporlar yakında" bildirimi gösteriyordu. Gerekçe doğruydu (rapor ucu
RBAC'ta yöneticiye kapalı) ama sonuç, **navigasyonun beşte birinin boşa
gitmesiydi.** Brief'in istediği "Görevlerim" zaten onların günlük ekranı
ve ucu onlara açık.

Sakinde ise yuva `/transparency`e gidiyor ama **"Raporlar" yazıyordu** —
tıklanan ad ile açılan ekran farklıydı.

### 4.12 Gizli aksiyonlar: ikon büyütülmedi, MENÜYE giriş açıldı (Aşama 7.2)

Brief çözümü bana bıraktı. Ölçüm: Devriye Takibi'nin sağ üstündeki iki
etiketsiz ikon **iki ayrı EKRANI** açıyordu ve o ekranların başka hiçbir
girişi yoktu — yönlendiricide bile kayıtlı değillerdi.

İkonu büyütmek ya da yanına yazı koymak dar bir bara üçüncü bir çözüm
sıkıştırmak olurdu. Bunun yerine kodun kendi kurduğu desen izlendi
(P139.3/P143: "ekran vardı, modül girişi yoktu"): iki ekrana da rota +
**etiketli menü girişi** açıldı, böylece çekmeceden ve ana ekran
ızgarasından bulunuyorlar. App-bar ikonları bağlam içi kısayol olarak
kaldı.

### 4.13 FAB'ın yazısı kaldırıldı ama ADI kaldı (Aşama 7.2)

Brief "sadece '+' kalsın" diyor. Çıplak bir "+" ekran okuyucuya yalnızca
"düğme" der; ad `Semantics`e taşındı. Görsel sadeleşmenin bedeli
erişilebilirlik **olmadı** ve bunu ölçen ayrı bir test yazıldı.

**Bir gerileme yakalandı:** `Column`u kaldırınca daire esnek kısıtları
benimseyip 56 yerine **160 piksel** çizildi; `merkez FAB 56px` testi
yakaladı, `Center` ile kısıtlandı.

### 4.14 Portal kaldırıldı — ama önce anket ayrıldı (Aşama 7.2)

Brief: "'Site sayfası' kaldırılacak … ölü kod kalmasın."

**Ölçüm önce yapıldı ve silmeyi durdurdu:** `/portal` sayfası **anket
yönetiminin tek yüzeyiydi** ve backend'de `portal.py` hem portal hem anket
uçlarını taşıyordu. Mobil anket ekranı bilerek salt-okumadır
("oluşturma/kapatma yönetim işidir ve panele"). Portalı olduğu gibi
silmek, uçtan uca çalışan bir özelliği götürürdü.

Sıra: **(1)** anket kendi router'ına (`routers/anketler.py`) ve kendi
panel sayfasına (`/anketler`) taşındı — **uçların yolu ve davranışı
değişmedi**, yani mobil istemci etkilenmedi; **(2)** portal kaldırıldı:
`/public/{slug}`, `/public/{slug}/iletisim`, `/portal*` uçları, panel
sayfası, public `/site/[slug]` sayfası, menü girişi, rota kayıtları,
middleware eşleşmesi, BFF beyaz listesi, 9 Pydantic şeması ve `portal*`
çeviri anahtarları.

Rol matrisinden **tam olarak sekiz satır** düştü; başka hiçbir değişiklik
yok.

**TABLOLAR DURUYOR — Kerem'in açık kararıyla.** `tenant_portal`,
`portal_galeri`, `iletisim_mesaji`: `DROP TABLE` geri alınamaz bir veri
kaybıdır. Modeller de duruyor ve bu bir "ölü kod" değil **tablonun
tanımıdır**: `goc-uyum` kapısı şemayı modelle karşılaştırır, tablo
dururken modeli silmek kapıyı kırardı. Gerekçe `models.py`de
`TenantPortal`ın altına yazıldı.

**Kaybolmayan testler:** portal testleri silindi ama anket testleri
`test_anket.py`ye taşındı. Yalnız *public portal üzerinden* anket okuyan
tek test düştü — ölçtüğü yüzey artık yok. `test_tenant_izolasyonu`
portalsız yeniden yazıldı; anket izolasyonu ölçülmeye devam ediyor.

### 4.15 Kurulum sihirbazı: tamamlanma SAYILIR, saklanmaz (Aşama 7.3)

Brief sekiz adımlık bir sihirbaz ve "tamamlananların **kalıcı**
işaretlenmesi" istiyor. Buna rağmen hiçbir adım için "tamamlandı" bayrağı
tutulmadı.

**Neden:** her adımın çıktısı zaten veritabanında (blok satırı, daire,
daire tipi, sakin, personel, görev kategorisi, NFC noktası, aidat
tahakkuku). Bayrak tutmak aynı gerçeğin ikinci bir kaynağını üretirdi ve
ayrışırdı — yönetici tek bloğunu silince bayrak "tamamlandı" demeye devam
ederdi. Tamamlanma her istekte veriden sayılıyor ve bunu ölçen bir test
var (`test_ADIM_verisi_SILININCE_geri_acilir`).

**Atlama ise veriden türetilemez** ve saklanıyor: "bu sitede NFC yok" ile
"henüz eklemedim" verisel olarak **aynıdır** (ikisi de sıfır satır), ama
kullanıcı için değil. Bu tek bilgi `tenant.kurulum_atlanan`da duruyor
(göç 0044) — cihazda değil **tesiste**, çünkü bir tesiste iki yönetici
olabilir ve biri "NFC yok" dediyse öteki de bunu görmeli.

**İlerleme atlananı sayar.** Saymasaydık, bilinçli atlayan bir tesis
%100'e asla ulaşamaz ve gösterge kalıcı bir sitem hâline gelirdi.

**Sihirbaz kendi formlarını çizmez** — sekiz adımın sekizinin de çalışan
bir ekranı zaten var; içine ikinci bir "blok ekle" formu koymak aynı
doğrulamayı iki yerde tutmak olurdu. Adımlar **kilitli değil**: kilitlemek
brief'in "yarım bırakıp devam edebilme" şartıyla çelişirdi.

### 4.16 Bağımlılık yönlendirmesi: geri dönüş ADRESTE taşınır (Aşama 7.4)

Brief üç şey istiyor: uyarı cümlesi + ilgili alana yönlendirme + **işlem
bitince geri dönüş**, hepsi TEK bileşende.

**`history.back()` kullanılmadı.** Kullanıcı hedef ekranda birkaç adım
gezinir (defter sekmesi değiştirir, modal açar, kaydeder); `back()` onu
işini bitirdiği yere değil bir önceki karesine gönderirdi. Dönüş adresi
`?donus=` ile taşınıyor ve bu gezinmelerden etkilenmiyor.

**Dönüş şeridi korumalı düzende, tek yerde.** Bileşen dokuz farklı hedefe
yollayabiliyor; her hedefe bir "geri dön" düğmesi koymak aynı davranışı
dokuz kez yazmak olurdu.

**Açık yönlendirme kapatıldı.** `?donus=https://baska-site` yazan biri
panelden dışarı yönlendiren bir düğme üretebilirdi. Yalnız uygulama içi
yollar kabul ediliyor — `//host` ve `/\host` de reddediliyor, çünkü ikisi
de tarayıcıda mutlak adrestir. Üçü de test edildi.

**`eksik` kararı çağırandadır.** Ekranların çoğu bağlı olduğu listeyi
zaten çekiyor; bileşen kendi sorgusunu atsaydı aynı veriyi ikinci kez
indirirdi. Yalnız `/units`te blok listesi uyarı için ayrıca çekiliyor.

**Bağlanan dört ekran:** görevler (kategori), finans (kasa), mesajlar
(şablon), daireler (blok). Kalan kayıtlar bileşene hazır — her biri tek
satır. `/dues`e uyarı **konulmadı**: envanterdeki 422 `/borclandirma`
ucuna ait, `/api/dues/assessments`e değil; yanlış yerde uyarı göstermek
uyarısızlıktan kötüdür.

### 4.17 İçe aktarım: kısmi başarı tanımı ve bedeli (Aşama 8)

Brief açıkça istedi: "Kısmi başarı davranışını tanımla ve gerekçelendir."

**TANIM:** geçerli satırlar yazılır, hatalı satırlar yazılmaz ve satır
numarası + **alan adıyla** raporlanır. Koşum bir işlemdir.

**GEREKÇE:** 300 satırlık bir dosyada 4 hatalı satır yüzünden 296 doğru
satırı reddetmek, kullanıcıyı dosyayı Excel'de elle ayıklamaya zorlardı —
ve o ayıklama, hata raporunu okuyup 4 satırı düzeltmekten çok daha
hatalı bir iştir.

**TAKASI DÜRÜSTÇE:** bu, "yarım aktarım" durumunu mümkün kılar. Bedeli iki
şeyle ödendi — **önizleme** hiçbir şey yazmadan aynı raporu verir ve
**geri alma** koşumun tamamını kaldırır. Kullanıcı yarım kalmış bir
sonuca mahkûm değildir.

### 4.18 Geri alma için hedef tablolara sütun EKLENMEDİ (Aşama 8)

Alternatif, içe aktarılan her tabloya bir `aktarim_id` sütunu eklemekti.
Reddedildi: altı tabloya göç demekti, her yeni tür yeni bir göç
gerektirirdi, o sütunlar aktarılmamış satırlarda sonsuza kadar boş
dururdu — ve en önemlisi `finansal_hareket` gibi **defter** tablolarına
"bunu bir dosya yazdı" bilgisini gömerdi. Defterin işi para hareketini
anlatmaktır, nereden geldiğini değil.

Bunun yerine bir **iz tablosu** (`ice_aktarim_kayit`) bu bilgiyi dışarıda
tutuyor; hedef tablolar hiç değişmedi.

**Geri alma HEP YA DA HİÇ.** Ters sırada silinir (önce çocuk, sonra
ebeveyn). Bir satır silinemiyorsa tüm geri alma düşer. Kısmi geri alma
yapılmaz: yarım geri alınmış bir aktarım, kullanıcının "sildim" sandığı
ama bir kısmı duran bir veri bırakırdı. Koşum kaydı **silinmez**, durumu
`geri_alindi` olur — silmek denetim izinin anlatması gereken şeyi yok
etmek olurdu.

### 4.19 `/site-aktar` kaldırıldı — davranış farkı dürüstçe (Aşama 8)

Brief'in çakışma notu "hepsi tek framework üzerinden" diyordu; ikinci bir
içe aktarım ucu tutmak önizleme + hata raporu + işlem sınırı mantığını
iki yerde sürdürmek olurdu.

**Davranış farkı:** eski uç TEK SATIRDA blok+daire+kişi yaratıyordu; çatı
bunları ayrı türlere bölüyor (brief'in kapsam listesi de "daireler/
bloklar" ve "kişiler/sakinler" diye ayırıyor). `kisi` türü `daire_no`
alanıyla var olan daireye bağlanır — aynı sonuç **iki geçişte** elde
edilir ve ikinci geçiş, ilkini geri almadan yinelenebilir.

Ölçülen garantiler kaybolmadı: eski dosyadaki dört test
`test_ice_aktarim.py`ye taşındı, üstüne geri alma ve iki tür daha eklendi.

### 4.20 Yeniden deneme politikası KOPYALANMADI, paylaşıldı (Aşama 9)

Katlanan geri çekilme (1/5/25 dk) P37'de caydırıcı webhook kuyruğu için
zaten yazılıydı. Mesaj kuyruğu tam olarak aynı şeye ihtiyaç duyuyordu:
"kaçıncı deneme, ne zaman tekrar, ne zaman vazgeç".

Kopyalasaydım iki politika olurdu — biri düzeltilir, öteki unutulurdu ve
"neden SMS 3 kez ama webhook 5 kez deneniyor" sorusunun cevabı hiçbir
yerde yazılı olmazdı. `yeniden_deneme.py`ye taşındı; `gurultu.py` çağrı
yerleri değişmesin diye iki ince sarmalayıcı tutuyor. **Max deneme sayısı
çağrıya bırakıldı** — ortak olan zamanlama eğrisi, sayı değil.

### 4.21 Başarısız gönderim artık SON SÖZ DEĞİL (Aşama 9)

Ölçüldü: gönderim istek içinde senkron yapılıyordu ve sağlayıcı bir kez
başarısız olunca kayıt `basarisiz` yazılıp bırakılıyordu. Yani
sağlayıcının beş saniyelik bir kesintisi, üç yüz kişilik bir duyurunun
**kalıcı olarak** eksik gitmesi demekti.

Yeniden denemeyi isteğin içine koymak da çözüm değildi: yöneticinin
tarayıcısını sağlayıcının geri çekilme süresi boyunca bekletirdi.

**Ayrı kuyruk tablosu açılmadı.** `mesaj_gonderim` zaten alıcıyı, gövdeyi,
durumu (`kuyrukta` enum'da mevcuttu) ve hatayı tutuyordu; eksik olan tek
şey zamanlamaydı (iki sütun). Ayrı tablo, aynı satırı iki yerde tutmak ve
"geçmiş" ile "kuyruk" arasında hangisinin doğru olduğu sorusunu üretmek
olurdu.

**Kalıcı hata ayırt edilemiyor — dürüstçe:** "numara geçersiz" ile
"sağlayıcı düştü" bizim için aynı görünüyor (`GonderimSonucu` bir hata
metni taşıyor, sınıf değil). Bu yüzden deneme sayısı düşük tutuldu (3).
Sağlayıcı hata taksonomisi eklendiğinde doğru yer orasıdır.

**Kota deneme değil MESAJ sayar:** yeniden deneme yeni satır açmaz, var
olanı günceller. Aksi hâlde düşük bir sağlayıcı, günlük kotayı kendi
arızasıyla tüketirdi.

### 4.22 Kendi testim yanlış varsayımla yazılmıştı (Aşama 9)

Kuyruğun tükenme yolunu ölçen test "sağlayıcı test ortamında başarısız
olur" varsayıyordu. **Ölçtüm: sağlayıcı başarılı dönüyor** — satır ilk
denemede kapanıyor ve tükenme yolu hiç koşmuyordu. Test düşen bir sahte
sağlayıcıyla yeniden yazıldı; kuyruğun kararı artık sağlayıcı
yapılandırmasından bağımsız ölçülüyor.

### 4.23 Aşama 10: kendi triyajımda iki yanlış ölçüm buldum

B kovasında hiçbir kodlama aşamasının sahiplenmediği üç madde vardı.
Ölçtüm — **ikisi zaten yapılmıştı:**

| Triyajda yazan | Ölçüm |
|---|---|
| "Çoklu satır finansal işlem — **tek satır**, 2 g" | **Zaten var:** `POST /finans/hareketler` çok satırlı (`idempotency_key` + `idem_satir`) |
| "Finansal denetim kaydı — finans **bağlanmamış**" | **Bağlanmış:** 9 yazma ucunun 8'inde `audit_user`; 9.'su (`banka-eslestir`) hiçbir şey yazmıyor — öneri üreticisi, denetlenecek mutasyon yok |

Triyaj belgesi düzeltildi. Gerçek iş tek maddeydi: **ters kayıt + defterde
silme kilidi**.

### 4.24 DELETE veritabanında kapatıldı, uygulamada değil (Aşama 10)

Bugün hiçbir uç `finansal_hareket` silmiyor; yarın biri yazarsa kimse
fark etmez. Yetkiyi geri almak kuralı **kanıtlanabilir** kılar —
`audit_log`un append-only yapıldığı yolun aynısı.

**Blanket GRANT her `migrate` sonrası koşuyor** ve DELETE'i geri veriyor;
bu yüzden REVOKE hem göçte hem `setup_app_role.py`de. Yalnız göçte yapmak
kilidi ilk koşumdan sonra **sessizce açardı.**

**Bağın yönü yol haritasının önerisinin tersine kondu:** iptal satırı
iptal ettiğini gösterir. Sebep, tabloda zaten aynı işi yapan
`iade_edilen_id`nin bu yönde olması — iki benzer bağı iki farklı yönde
tutmak, her okuyanın durup bakması demekti.

### 4.25 AŞAMALAR ARASI ÇAKIŞMA — 8 ile 10 (Aşama 10)

DELETE'i kilitlemek **Aşama 8'in geri almasını kırıyordu**:
`acilis_bakiye` içe aktarımı defter satırı yaratıyor ve geri alma onları
siliyordu.

Kilidi gevşetmedim. Geri alma artık defter satırları için **ters kayıt**
yazıyor: kullanıcı açısından sonuç aynı (bakiye eski hâline döner) ama
defter ne olduğunu anlatmaya devam ediyor. Bunu ölçen bir test var.

### 4.26 Kendi göçüm FK indeksini iki kez kaçırdı (Aşama 8/10)

`test_indeks_kapsam` `ice_aktarim_kayit(tenant_id)` FK'sının indekssiz
olduğunu yakaladı. Düzeltirken tek indeksi `tenant_id` ile başlattım — bu
kez **`aktarim_id` açıkta kaldı** ve aynı test onu yakaladı. Tabloda iki
FK var; ikisi de kendi öncü kolonuyla indekslendi.

Göç 0045 **yerinde düzeltildi**: commit'lenmemiş ve hiçbir yere
gitmemişti; ikinci bir düzeltme göçü eklemek, hiç yaşamamış bir kusuru
tarihe yazmak olurdu.

### 4.27 Aralık ifadesi ("3,5,7-12") SUNUCUDA çözülmüyor (Aşama 5)

Brief "aralık desteğini de değerlendir" dedi. Değerlendirme sonucu:
destek **var** ama ayrıştırma **arayüzde**.

Sebep: ifade kullanıcının **ekranda gördüğü** listeye göre anlam kazanır.
Blok süzgeci açıkken "7-12" o bloğun daireleridir. Sunucuda çözmek,
istemcinin gördüğü küme ile sunucunun anladığı kümenin **ayrışması**
demekti — ve yanlış daireye toplu işlem uygulamak geri alması zor bir
hatadır. Sunucuya kesinleşmiş kimlikler gider.

**Eşleşmeyen parçalar sessizce düşmez:** "12 daire seçtim" deyip 9'unu
işlemek en kötü sonuçtur; kullanıcıya hangi parçanın bulunamadığı
söylenir. 9 test.

### 4.28 "Zemin" ayrı bir değer değil, 0'dır (Aşama 5)

Brief başlangıç katı için "-2, -1, 0, **zemin**, 1..." diyor. `zemin`
metin olarak saklanmadı: bir kat numarası sıralanamaz hâle gelirdi ve
"zemin" ile "0" iki ayrı değer olarak dururken sıralama iki kurala
bağlanırdı. Etiket arayüzde çözülür.

Eskiden katlar **her zaman 1'den** başlıyordu; bodrumlu bir binada kat
numaraları bir kaydırmayla yazılıyordu — yani veri, binanın kendisini
anlatmıyordu.

### 4.29 Kullanıcı silme: sert, ama kendi hesabına kapalı (Aşama 5)

`is_active` zaten var; ikinci bir yumuşak silme düğmesi kullanıcıyı
yanıltırdı (Aşama 1'deki yönetici silmeyle aynı gerekçe). Aynı
`_yonetim_kapisi`ndan geçer — kapıyı tekrar yazmak, birinin güncellenip
ötekinin unutulması demekti.

**Kendi hesabı kontrolü kapıdan ÖNCE:** sırası ters olsaydı kendi kaydını
silmeye çalışan yönetici "bu hesap türünü düzenleme yetkiniz yok"
mesajını alırdı — doğru ama yanıltıcı.

### 4.30 Toplu güncelleme için `UnitBulkResult` yeniden KULLANILMADI

İlk denemede kullandım ve **500 aldım**: `olusturulan` ve `bitis_no`
alanları bir güncellemede anlamsız ve doldurmak için uydurma değer yazmak
gerekirdi. Ayrı bir `TopluIslemSonuc` tipi yazıldı.

### 4.31 Sürükle-bırak TEK YOL DEĞİL — klavye eşdeğeri var (Aşama 5)

Fare sürüklemesi klavyeyle **erişilemez** ve brief'in kendi şartı "klavye
navigasyonu" diyor. Tek yol olsaydı klavye/ekran okuyucu kullanıcısı
yerleşimi hiç değiştiremezdi.

`Alt + ok` aynı işi yapar: sol/sağ kat içinde, yukarı/aşağı kat
değiştirir. `Alt` seçildi çünkü çıplak ok tuşları sayfayı kaydırır ve
odaklanmış bir kutuda kaydırmayı yutmak, klavye kullanıcısını sayfada
hapsederdi. 4 test — biri "Alt'sız ok yerleşimi değiştirmez" diye ölçüyor.

**Etkilenen katın tamamı yeniden numaralanır** (1..n). İki daireyi takas
etmek boşluk ya da çift `sira` bırakabilirdi — veri zaten boşluklu
gelebiliyor (`sira` NULL olabilir).

**Katsız satırda sürükleme kapalı:** kat bilinmeden sıralama anlamsız ve
uç `kat`ı zorunlu istiyor.

### 4.32 Başlangıç katı varsayılanını 0 yaptım — kilit yakaladı (Aşama 5)

Brief "başlangıç katı **seçilebilsin**" diyor. Ben varsayılanı 0 (zemin)
yaptım; `test_units_bulk` düştü. Haklıydı: alanı hiç göndermeyen **her
çağıranı** (mobil toplu oluşturma dahil) sessizce etkilerdi — bugüne
kadar 1'den başlayan binalar bir anda zeminden başlardı.

Varsayılan **1'de bırakıldı**; seçilebilirlik eklendi. Bu, brief'in
istediğinin tam karşılığı ve bir davranış kayması değil.

### 4.33 Kilitli kural 4 hiçbir yerde zorlanmıyordu (Aşama 5)

"Bir daire için en fazla 1 hesap" ne uçta ne veritabanında vardı. Artık
`assign_resident` ve içe aktarımın `kisi` türü **ortak bir yardımcıdan**
geçiyor — iki yere yazmak, birinde unutulması demekti.

"Aktif" ölçülür (`bitis IS NULL`), "hiç" değil: geçmiş sakinler
sayılsaydı bir daire **el değiştiremezdi**.

**Excel'de aynı daireye iki satır: İLKİ KAZANIR**, ikincisi satır hatası
olarak raporlanır. Üzerine yazmak ilk satırı kullanıcıya hiç söylemeden
atmak olurdu; ikisini de bağlamak kuralı çiğnerdi.

**Veritabanı kısıtı EKLENDİ — rol başına** (göç 0049): bir dairede en
fazla bir malik ve bir kiracı. Kuralın harfi (`unit_id`) ölçüldü ve
elendi (1 kırık + 104 hata). Ayrıntı: §4.47–§4.52.

### 4.34 Sosyal hesap ESLESME ANAHTARI DEGIL — Aşama 4'ün tamamı bunun üzerine kurulu

Brief bunu KRİTİK diye işaretliyor ve haklı: sağlayıcı telefon vermiyor,
bizim eşleşme modelimiz ise tesis ID + telefon. Şemada bu, **hiçbir yerde
kullanıcı yaratılmaması** demek — `oauth_kimlik` satırı her zaman ZATEN
VAR OLAN bir `app_user`a bağlanır.

Tersi tasarım (sağlayıcı e-postasından kullanıcı türetmek) üç şeyi
birden kırardı: tesis eşleşmesi kaybolurdu, Apple private relay adresleri
kalıcı kimlik değildir, ve kilitli kural 4 ("bir daire için en fazla 1
hesap") delinirdi.

### 4.35 İlk bağlamada SMS ZORUNLU — ve bu yeni bir kapı açmıyor

Sağlayıcı "bu Google hesabının sahibisin" der; **"bu telefonun
sahibisin" DEMEZ**. SMS olmasaydı, birinin tesis kodunu ve telefon
numarasını bilen herhangi biri kendi Google hesabını o kişinin hesabına
bağlayıp içeri girerdi. Tesis kodu **kamuya açık**, telefon numarası ise
sır değil — ikisi birlikte bir kimlik kanıtı **değildir**.

Bu, ürüne yeni bir zayıflık **eklemiyor**: SMS bu üründe zaten tek başına
oturum açıyor (`/auth/giris/kod-dogrula`, P149). Yani SMS ile korunan bir
bağlama, en zayıf mevcut kapıdan daha zayıf değil.

**Parolası olan hesap da bağlayabilir.** `kayit` akışındaki
`password_set=false` şartı buraya konmadı; konsaydı "parolan var, o hâlde
Google'ı hiç kullanamazsın" demiş olurduk.

### 4.36 Sağlayıcı jetonları SAKLANMIYOR — bilinçli

`oauth_kimlik` tablosunda `access_token`/`refresh_token` **yok**. Kimliğe
yalnız giriş anında ihtiyaç var; sonrasını kendi JWT çiftimiz yürütüyor
ve hiçbir sağlayıcı API'si çağrılmıyor. Saklamak, sızması hâlinde
kullanıcının **Google hesabına** erişim veren, hiçbir işi olmayan bir
sorumluluk olurdu (KVKK "veri en az").

Bunu bir test kilitliyor: `test_SAGLAYICI_JETONU_SAKLANMIYOR` tabloda
öyle bir sütunun **olmadığını** ölçüyor.

### 4.37 `aud` kontrolü bu aşamanın tek en önemli satırı

Geçerli imzalı, geçerli `iss`li ama **başka bir istemciye kesilmiş** bir
Google jetonu kabul edilseydi, o uygulamaya girebilen herkes bizde de
girerdi ("karışık vekil"). Bu yüzden `aud` listesi **boş bırakılamaz**:
boşsa sağlayıcı yapılandırılmamış sayılır ve uç 503 döner — sessizce
kabul etmez.

Doğrulama **gerçek kripto ile** test ediliyor: testte bir RSA çifti
üretilip ondan bir JWKS kuruluyor ve modülün önbelleğine enjekte
ediliyor. Sahtelenen tek şey sağlayıcının anahtar listesi; imza/`iss`/
`aud`/`exp`/`nonce` kontrollerinin **asıl kodu** koşuyor.
`kimlik_dogrula`yı mock'lamak, aşamanın en riskli kodunu hiç ölçmemek
olurdu.

### 4.38 Yol şekli `/baslat/{saglayici}` — ölçülerek değişti

İlk yazımda `/{saglayici}/basla` idi. `POST /auth/oauth/baglan/basla`
isteği o kalıba düştü (`saglayici="baglan"`), gövde **başka bir şemayla**
doğrulandı ve 422 verdi — testler yakaladı.

FastAPI yolları tanım sırasına göre eşleştirdiği için "literal rotaları
önce yaz" ile de çözülebilirdi, ama o çözüm **disipline** bağlı:
sıralamayı bozan biri sessiz bir 422 üretirdi. Değişken segmenti sona
almak aynı hatayı **yapısal olarak** imkânsız kılıyor.

### 4.39 Mobil yerel SDK KULLANMIYOR — tarayıcı akışı

Üç sebep: (1) Apple "Sign in with Apple" geri dönüş adresinde https
ister, özel şema kabul etmez; (2) böylece her sağlayıcıda kaydedilecek
**tek bir adres** kalıyor — mobil için ayrı istemci/anahtar gerekmiyor;
(3) doğrulama tek yerde (arka uç) kalıyor — yerel SDK jetonu
`aud`/`iss` kontrolünün ikinci bir kopyası demekti.

Akış: sağlayıcı → arka ucun https callback'i → `com.app.yonetiyor://oauth`
özel şeması. Sağlayıcı özel şemayı **hiç görmüyor**.

### 4.40 Geri dönüş adresi İSTEKTEN ALINMIYOR

Callback'ten sonra tarayıcının gideceği adres ayarlardan gelir. İstekten
almak klasik açık-yönlendirme açığı olurdu. Aynı sebeple sağlayıcıya
bildirilen `redirect_uri` her zaman bizim callback ucumuz.

**Boş bırakılırsa `baslat` 503 döner** — hata kullanıcı siteden
AYRILMADAN görünür. Aksi hâlde yanlış yapılandırma sessiz kalır:
kullanıcı Google'a gider, döner ve 404 bulur.

### 4.41 Jeton URL'de taşınmıyor

Callback sonucu Redis'e **tek kullanımlık** bir kimlikle yazar ve
tarayıcıyı `?oauth=<id>` ile geri gönderir. Erişim jetonunu adres
çubuğuna koymak, onu tarayıcı geçmişine, `Referer` başlığına ve sunucu
günlüklerine yazmak olurdu.

### 4.42 Yüzey kapısı TEK YERE alındı

Bir token çifti elde eden her yolun rolü yüzeye sokup sokmayacağını
sorması gerekiyor. Bu, `login/route.ts`te satır içiydi ve sosyal giriş
üçüncü bir yol getiriyordu. Kopyalamak, sosyal girişi kapının
**etrafından dolaşan** bir yol yapardı: `panel.*` için reddedilen bir
rol, Google düğmesiyle içeri girebilirdi. `lib/oturum-kapisi.ts` bunu tek
yerde tutuyor.

### 4.43 Test bir tasarım kusurumu yakaladı (mobil)

Denetleyicide "oturum açıldı mı, yoksa kullanıcı vazgeçti mi" ayrımını
`restoreSession()` çağırarak — yani **güvenli depoya sorarak** — yapmayı
denedim. Mobil test hemen düştü: sahte depoyla bile gerçek eklentiye
inmeye çalıştı.

Haklıydı ve düzeltme davranışı da iyileştirdi: `akis()` artık sonucu
**doğrudan** döndürüyor, `null` yalnız vazgeçme demek. Cevabı ilgisiz bir
yan etkiden okumak yanlıştı.

### 4.44 Son giriş yöntemi kaldırılamaz

Kullanıcının elinde parola, başka bir sosyal kimlik ya da telefon
kalmalı; yoksa kendi hesabına bir daha giremez ve kurtarma yolu yalnız
yöneticiden geçer. Kural **sunucuda** yaşıyor: istemci "silinebilir mi"
hesabı yapmıyor, deniyor ve 409 metnini gösteriyor. İki yerde yaşasaydı
istemcideki kopya sunucununkinden sapabilirdi.

### 4.45 KEREM'İN YAPACAĞI İŞ: `docs/oauth-kurulum.md`

Üç konsolun (Google Cloud, Azure, Apple Developer) adım adım listesi,
ortam değişkenleri ve doğrulama komutları orada. Kod tarafı bitti;
yapılandırma tamamlanana kadar sosyal giriş **kapalı** ve bu bilinçli —
yapılandırılmamış sağlayıcı hiçbir yerde düğme olarak görünmüyor,
telefon/parola girişi hiç etkilenmiyor (brief'in şartı: "tıkanırsa Aşama
3 tek başına çalışsın", `test_ASAMA_3_SOSYAL_GIRIS_OLMADAN_CALISIR`).

### 4.46 `test_dashboard` yarış koşulu — bulundu ve DÜZELTİLDİ

Tam takımda `test_ayni_planin_alti_alarmi_TEK_GRUBA_dusuyor` 6 alarm
beklerken **18** gördü.

**Mekanizma:** test plana altı pencere ekleyip
`detect_missed(now=2030-01-01)` çağırıyor. Beat'in
`generate_patrol_windows` görevi ise aynı plan için **12 pencere** daha
üretiyor (bugün + yarın × 6); `NOW_AFTER` çok ileri bir tarih olduğu için
onlar da "kaçırılmış" sayılıyor. 6 + 12 = 18.

**Kusur testin varsayımındaydı:** `sayi == 6` demek, "bu planın tek
pencere kaynağı benim" demekti. Testin **asıl iddiası** zaten sayı
değildi — "altı alarm ALTI GRUP değil TEK grup olur".

**Düzeltme, iddiayı sayıdan kimliğe taşıdı:**
1. bu plan için **tek** grup var (gruplama iddiası),
2. testin eklediği altı pencerenin **hepsi** o gruptaki olaylarda,
3. `sayi == len(olaylar)` (iç tutarlılık).

**Ve test artık bağımsızlığını KANITLIYOR:** yarışın kazara oluşmasını
beklemek yerine üreticinin ekleyeceği 12 pencere **bilerek** ekleniyor.
Yarış penceresi küçük olduğu için "geçti" demek yeterli değildi — eski
hâli bu enjeksiyonla **her** koşumda düşerdi.

**Doğrulama beat AÇIKKEN yapıldı.** Önceki iki tur beat durdurularak
yeşile alınmıştı; artık gerek yok.

> Bu bir gevşetme değil: kaldırılan tek şey yanlış olan varsayımdı.
> Gruplama iddiası, kapsama iddiası ve iç tutarlılık — üçü de eskisinden
> daha sıkı ölçülüyor.

### 4.56 Gizli bağımlılık: bir test DEMO TESİSİNİN varlığına bağlıymış

Doğrulama için dev veritabanında bir `demo` tesisi açtım (`demo_mod=true`)
ve işim bitince **sildim** — o betiğin kendi başlığı "dev'de ASLA
açılmamalı" diyor. Silince `test_var_olan_telefon_ikinci_kez_kaydolamaz`
düştü.

Sebep testin tek satırındaydı:

```python
"telefon": world["resident_a"].get("telefon") or "+905000000101",
```

İki kusur üst üste:

1. Fixture'daki anahtar **`phone`**, `telefon` değil. Yani `.get()` **her
   zaman** `None` dönüyor; test hiçbir zaman fixture'ın numarasını
   kullanmıyordu — `or` sağdaki sabite düşüyordu.
2. O sabit `+905000000101` **demo tesisinin** yöneticisine ait. Yani test,
   dev veritabanında `demo_tenant.py`'nin bir kez koşturulmuş olmasına —
   ve `demo_mod=true`nun dev'de **açık kalmış** olmasına — bağlıydı.

`or` ilk kusuru gizliyordu: test yıllardır yeşildi ve ölçtüğünü sandığı
şeyi ölçmüyordu. Artık numara `world["resident_a"]["phone"]`den geliyor —
var olduğu **kesin** ve başka hiçbir şeye bağlı değil.

**Bu turda ikinci kez aynı ders:** dev veritabanındaki artık veri
zararsız kirlilik değil; testlerin neyi ölçtüğünü değiştiriyor (ilki
§4.54, 112 birikmiş tesis).

### 4.55 Denetçi hesabı depoya girdi — ve bir tuzak kapatıldı

Kilitli kural 2 `+905777777777 denetci`'yi **adıyla** sayıyordu ama hesap
hiçbir betikte yoktu; canlıda elle açılmıştı. Yani her yeni ortam o
kuralı karşılamıyordu ve eksik ancak birinin giriş yapamamasıyla
anlaşılırdı. Artık `demo_tenant.py`'nin `HESAPLAR` listesinde.

**Görev penceresi bilerek boş.** `gorev_penceresi_disinda` ikisi de NULL
ise "pencere yok" sayar ve girişi her zaman kabul eder. Tarihli bir
pencere, demo hesabını **önceden belirli bir günde sessizce** çalışmaz
hâle getirirdi — ve bunu fark eden ilk kişi App Store denetçisi olurdu.
Kilitli kural 2 "demo hesaplar çalışmaya **devam** edecek" diyor;
süresiz görev bunun tek garantili biçimi.

**Eklerken bir tuzak çıktı ve ölçülerek kapatıldı.** Betiğin upsert'ü
`(tenant_id, lower(email))` üzerindeydi; oysa `telefon` **global**
benzersiz. Numara başka bir e-postayla kayıtlıysa INSERT e-posta
çakışmasına değil `uq_app_user_telefon`'a çarpar. Bu kurgusal değildi:
elle açma SQL'i `denetci@test.yonetiyor.com` kullanıyordu, yani betiğin
ilk koşumu tam o duvara çarpardı. **Ölçtüm** — aynı numarayı yeni bir
e-postayla eklemeyi denedim: `duplicate key value violates unique
constraint "uq_app_user_telefon"`.

`_hesap_yaz` artık **önce telefona** bakıyor:
- aynı tesiste bulunursa **sahiplenir** (kanonik ad/e-posta/parolaya
  getirir) — ölçüldü, çakışmadı,
- **başka bir tesiste** ise dokunmaz ve hangi tesis olduğunu söyleyip
  durur — başka bir tesisin kullanıcısının rolünü ve parolasını sessizce
  değiştirmek kilitli kural 1'i çiğnerdi; ölçüldü, doğru mesajla durdu.

Kural altı hesabın **hepsine** uygulandı, yalnız denetçiye değil: risk
aynı ve iki ayrı yol yazmak brief'in "aynı işi iki kez yapma" kuralına
aykırıydı.

**Uçtan uca doğrulandı:** `login-phone` 200 · `/me` 200 ·
`POST /blocks` **403** (salt okuma kapısı çalışıyor) · ikinci koşumda
hesap sayısı 6'da sabit.

**Dev seed'e de bir denetçi eklendi** (`+905321112208`,
`denetci@acme.com`) — ayrı bir gerekçeyle: dev'de bu rolün hesabı hiç
yoktu ve yüzeyi yerelde tıklamanın tek yolu `demo_tenant.py` koşturmaktı.
O betik ise tesise `demo_mod = true` yazar ve kendi başlığı "dev'de ASLA
açılmamalı" der (tur kaydının kanıt değerini askıya alan bir bayrak).
Yani doğru olanı yapmak için yanlış olanı yapmak gerekiyordu.

**App Store notlarına EKLENMEDİ ve bu bilinçli:** denetçinin **mobil
yüzeyi yoktur** (kilitli kural 5) — mobilde yalnız web paneline
yönlendiren ekranı görür. Denetçiye o hesabı vermek, ona boş görünen bir
ekran açtırıp uygulamayı bozuk göstermek olurdu. Oradaki bayat "dördü de
aynı" ifadesi de sayısızlaştırıldı.

### 4.54 Yarışı kovalarken ikinci bir kusur çıktı: test çöpü ÜRÜN DAVRANIŞINI değiştirdi

Pano düzeltmesinden sonraki tam takımda **başka** bir test düştü:
`test_AYNI_taban_cakisirsa_sira_eki_alir`. Zincir şöyle çıktı ve
ilginç kısmı ortadaki halka:

1. `test_sakin_kaydi` ve `test_tesis_kodu_ve_coklu_yonetici` tesisleri
   `c-<8 hex>` slug'ıyla açıyor. `conftest`in artık temizliği **önek**
   listesiyle çalışıyor ve `c-` o listede **yok** — yani bu satırlar her
   tam koşumda birikiyordu. **112 artık tesis** sayıldı.
2. `tenant_kayit_kodu_ata` (göç 0041) çakışmada **90 iki haneli**
   adaydan rastgele seçer; 20 denemede bulamazsa 6 haneli hex yedeğe
   düşer ("sonlanma garantisi").
3. 112 birikinti o 90 slotu **tüketti**. Artık her yeni `OLTU-260715`
   kaydı hex ek alıyor: `OLTU-260715-fde3b9`.
4. Test yalnız `-\d+` biçimini kabul ediyordu → kalıcı kırmızı.

**Yani test çöpü zararsız kirlilik değildi; ürünün hangi kod yolunu
seçtiğini değiştirdi.** `conftest`in kendi yorumu bu sınıfı zaten
kaydetmişti (100 birikmiş "kurulum-bekliyor-" tesisi); aynı tuzağın
ikinci örneği.

**İki taraf da düzeltildi:**

- **Temizlik**: `FIXTURE_SLUG_DESENLERI` eklendi (`^c-[0-9a-f]{8}$`).
  Önek listesine `"c-"` yazmak **kolaydı ama tehlikeli**: "C Blok
  Sitesi" gibi gerçek bir tesisin slug'ı da `c-blok-sitesi` olur ve
  temizlik onu silerdi. Ölçüm: veritabanında bu desene uyan 112 kaydın
  **hepsi** fixture, başka `c-` tesisi **yok**. 112'si silindi;
  birikmenin durduğu iki ardışık koşumla doğrulandı (sabit 2).
- **Test**: artık **iki meşru ek biçimini de** kabul ediyor —
  `-<10..99>` (normal yol, kilitli kural 3'ün "rastgele sayı"sı) ve
  `-<6 hex>` (yedek yol). Yedek yol ürünün belgelenmiş davranışı; testin
  onu reddetmesi yanlıştı.

**Tetikleyicide kusur YOK.** 90 slot + hex kaçış yolu bilinçli bir
tasarım ve kilitli kural 3'ü karşılıyor. Kusur, ona 112 çöp satırla
gelinmesindeydi.

### 4.47 Daire başına tek hesap: **A seçeneği uygulandı** (göç 0049)

Kural **rol başına** işliyor: bir dairede en fazla bir **malik** ve bir
**kiracı**. Kerem A'yı onayladı.

**Nasıl buraya gelindi — üç varyant ölçüldü:**

| Kısıt | Sonuç |
|---|---|
| `(unit_id)` — kuralın harfi | **1 kırık + 104 hata** |
| **`(unit_id, rol_tipi)`** ← uygulanan | yeşil |
| `(unit_id, rol_tipi)` + NULL kovası | **37 hata** |

Harfin kırdığı test tesadüf değildi:
`test_hedefleme_KIRACI_VAR_YOK_IKISI_BIRDEN`. `borclandirma.hedef_sec`
(P28) bir dairede malik ve kiracı birlikte bulunabilsin diye yazılmış —
`kiraci_oncelikli` = "kiracı varsa ona, yoksa malike" — ve tek sakinli
bir dairede o kuralın seçeceği bir şey kalmaz. İçe aktarımın `rol_tipi`
sütunu (Aşama 8) da aynı varsayımı taşıyor.

### 4.48 Eski indeks DURUYOR — farklı bir şeyi koruyor

`uq_unitresident_aktif` = `(unit_id, user_id)`: **aynı kişi** aynı
daireye iki kez bağlanamaz. Yeni indeks bunu **kapsamaz** — aynı kişi bir
kez malik, bir kez kiracı olarak çatışmadan geçerdi.

İlk denemede eski indeksi düşürmüştüm ve seed'in
`ON CONFLICT (unit_id, user_id)` yazımı kırıldı: `ON CONFLICT`
**eşleşen** bir indeks arar, "semantik olarak kapsayan" değil. İndeksi
bırakmak o sorunu da ortadan kaldırdı — seed'e dokunmak gerekmedi.

### 4.49 NULL `rol_tipi` boşluğu — veritabanında kapatılamadı, uçta kapatıldı

PostgreSQL benzersiz indekslerde NULL'ları çatıştırmaz: rolsüz iki aktif
sakin indeksten **geçer**. Kapatmanın iki yolu da denendi ve elendi:

- `(unit_id, COALESCE(rol_tipi::text,'-'))` → *"functions in index
  expression must be marked IMMUTABLE"* (enum→text cast STABLE'dır).
- Ek kısmi indeks `WHERE bitis IS NULL AND rol_tipi IS NULL` → oluşuyor
  ama **37 test hatası**; ziyaretçi fixture'ları bir daireye rolsüz çoklu
  sakin bağlıyor.

Bu yüzden boşluk `units.daire_rolu_dolu_mu`da kapatıldı: **NULL'u da bir
değer sayar** ve ikinci rolsüz sakini reddeder. Yani uçtan geçen hiçbir
yazma boşluğu kullanamaz; doğrudan SQL yazan bir yol kullanabilir ve bu
**kabul edilen sınırdır** — alternatifi çalışan 37 testi bozmaktı. Bir
test ikisini de ölçüyor: uç 409 verir, doğrudan SQL geçer.

### 4.50 KENDİ KUSURUM DÜZELTİLDİ: `daire_dolu_mu` fazla katıydı

Aşama 5'te yazdığım kontrol `rol_tipi`ne **bakmadan** her ikinci sakini
reddediyordu — yani malik+kiracı `a237863`'ten beri uçtan
kurulamıyordu ve bunu Aşama 5 raporunda yazmamıştım. Testler görmedi
çünkü o 104 fixture sakinleri **doğrudan SQL** ile bağlıyor.

`daire_rolu_dolu_mu(db, unit_id, rol_tipi)` bunu düzeltiyor; iki
çağıran (`assign_resident` ve içe aktarım) ortak yardımcıyı
kullanmaya devam ediyor.

### 4.51 Seed: bağ koparılmadı, ROL DÜZELTİLDİ

A-12'de iki **malik** vardı (seed'in kasıtlı "aynı dairede çoklu sakin"
kurgusu). İlk denememde eşin bağını **kapatmıştım**; A seçeneğiyle buna
gerek kalmadı — ikinci sakinin rolü `kiraci` oldu (`Acme Sakin Es` →
`Acme Kiraci`).

Bu daha iyi: senaryo korunuyor, kural sağlanıyor **ve** seed artık
`hedef_sec`in `kiraci_oncelikli` yolunu gerçek veriyle sergiliyor. Ön
kontrol betiğine de not düşüldü — bazen doğru düzeltme kapatmak değil
rolü düzeltmektir.

### 4.52 Ön koşul sessizce değil, anlaşılır şekilde patlar

Ham `CREATE UNIQUE INDEX` hatası operatöre **hangi dairenin** sorunlu
olduğunu söylemez. Göç önce kontrol ediyor ve ihlalde
`daire (rol)` listesiyle duruyor.

`infra/scripts/daire_tek_hesap_onkontrol.py` aynı sorguyu salt okunur
koşar; ayrıca rolsüz çoklu sakinleri **ayrı bir bilgi bölümünde**
gösterir (göç onlar yüzünden durmaz ama uygulama katmanı yeni atamaları
reddeder). **Owner bağlantısı ister:** `app_rw` ile RLS yüzünden hiçbir
satır göremez ve "temiz" derdi — mümkün olan en tehlikeli yanlış cevap.

Üretim görülemiyor (yalnız 80/443), bu yüzden yayından önce **orada**
koşulmalı.

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
| `backend-pytest` | **0 failed, 1492 passed** ✔ (taban: 11 failed / 1462 passed) |
| Hedefli koşum (yetki + secdef + göç kimlikleri + çoklu yönetici) | **22/22** |
| `goc-uyum` / `goc-tersinir` | **ikisi de bulgu: 0** ✔ |
| `mobil-*` | **dokunulmadı** (mobil dosyası değişmedi) |

**Net:** taban 11 hatanın **hepsi** kapatıldı, **yeni hata üretilmedi**,
+30 test eklendi. **Backend takımı tamamen yeşil (1492/1492).** Göç
kapılarının ikisi de sıfır. Geriye yalnız `depo-alan-adi` kapısı kaldı ve
o, canlı Caddy yapılandırmasına dokunmayı gerektiriyor (kilitli kural 6).

### 6.3 KALAN KIRMIZI — tek kapı, canlıya dokunmayı gerektiriyor

| Test | Sebep | Neden bu turda kapatılmadı |
|---|---|---|
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

### 6.7 `test_rls_kapsam` — **KAPANDI** (göç 0042)

Bu, turun kalan son kod kusuruydu ve "politikayı ekle geç" ile
kapatılamıyordu: `kayit_dogrulama` **kimlik öncesi** okunuyor, yani
politikanın bakacağı `app.current_tenant_id` daha set edilememiş oluyor.
Naif bir politika sakin kaydını ve parolasız girişi **sessizce sıfır
satıra** düşürürdü — hiçbir yerde hata çıkmadan, kullanıcı yalnızca
"kod geçersiz" görürdü.

**Üç `SECURITY DEFINER` fonksiyon**, hiçbiri satır döndürmüyor:

| Fonksiyon | Döndürdüğü | Neden var |
|---|---|---|
| `kayit_dogrulama_tenant_coz(telefon, amac)` | `uuid` | Kimlik öncesi bağlamı kurar. Kod/ad/daire **çıkmaz** |
| `kayit_dogrulama_acik_temizle(telefon, amac)` | silinen sayı | "Bekleyen kodu ez" — `durum='telefon_bekliyor'` |
| `kayit_dogrulama_telefon_sifirla(telefon)` | silinen sayı | "Kayda baştan başla" — süzgeçsiz |

**Neden temizlik fonksiyona taşındı:** `uq_kayit_acik_basvuru` **kısmi ve
GLOBAL** bir benzersizlik indeksi — bir telefon tüm platformda tek açık
başvuru taşıyabilir. Kişi A sitesinde kayda başlayıp B'de başlarsa, RLS'e
tabi bir `DELETE` A'nın satırını **göremez** ve `INSERT` benzersizlik
ihlaliyle **500** verir. Yani "ezme" tanımı gereği tenant-üstü bir
işlemdir ve politikayla ifade **edilemez**.

**Neden iki ayrı temizlik fonksiyonu:** kodda iki farklı semantik vardı ve
ikisi de korundu. `kod_uret_ve_gonder` (amaç + `telefon_bekliyor`) ile
`auth.kayit_basla`ın satır içi `DELETE`'i (**süzgeçsiz** — kişi onay
bekleyen başvurusunu iptal edip baştan başlayabilsin diye) aynı şey
değil. Tek fonksiyona `p_amac IS NULL ⇒ hepsi` dalı koymak, çağıranın
hangi kuralın işlediğini ancak gövdeyi okuyarak anlaması demekti.

**Test önce yazıldı ve gerçek bir kusuru yakaladı.**
`test_kayit_dogrulama_rls.py::test_A_sitesinde_baslayip_B_sitesinde_kaydolabilir`
**500 verdi** — çünkü `auth.kayit_basla` `kod_uret_ve_gonder`'i
**çağırmıyor**, kendi satır içi kopyasını taşıyor ve ilk düzeltme o yolu
ıskalamıştı. Kusur ekranda değil, testte bulundu.

**Bağlam ezilmiyor, doğrulanıyor:** `/me/*` uçları `get_tenant_db` ile
gelir ve bağlamı kuruludur. Orada bağlamı ezmek, bir kullanıcının başka
bir tesisin satırına ulaşmasına açılan kapı olurdu — çözücü uyuşmazlıkta
`None` döner ve çağıran "geçersiz kod" der, ayrımı sızdırmadan.

**Yan bulgu:** `auth.kayit_dogrula`da `amac` süzgeci **yoktu**.
`uq_kayit_acik_basvuru` `(telefon, amac)` üzerinde olduğu için aynı
telefon farklı amaçlarla birden fazla açık satır taşıyabilir ve
`scalar_one_or_none()` `MultipleResultsFound` ile **500** verirdi. Süzgeç
eklendi; ayrıca bir **giriş** kodunun kayıt doğrulamasını tamamlaması da
engellenmiş oldu.

---

## 7. AŞAMA DURUMU — hepsi bitti, açık kalanlar aşağıda

**A, 0, 1, 2, 3, 4, 5, 6.1–6.4, 7.1–7.4, 8, 9, 10, 11 — TAMAM.**
Brief'te 6.5 diye bir madde YOK (Aşama 0'da ölçüldü; 6 dört alt maddeden
oluşuyor). Her aşamanın çıktısı ve commit'i §1'deki tabloda.

> Bu bölüm daha önce "yapılmayan aşamalar" listesiydi (5 · 7.3/7.4 · 8 ·
> 9-artık · 10). Hepsi sonradan yapıldı; liste bayat kaldığı için
> değiştirildi — duran bir "yapılmadı" listesi, biteni bitmemiş
> gösterirdi.

### Aşama bitti ama ÇALIŞMASI Kerem'e bağlı olanlar

| Aşama | Kod durumu | Eksik olan |
|---|---|---|
| **4** — OAuth | Bitti, testli | Üç konsolun yapılandırması (`docs/oauth-kurulum.md`). Yapılmadan sosyal giriş **kapalı** — bu bilinçli, hiçbir yerde düğme görünmez. |
| **9** — SMS/WhatsApp/e-posta | Altyapı bitti (kuyruk + yeniden deneme + kota) | Netgsm başlık onayı; WhatsApp için **model A/B kararı** |
| **A** — Test sunucusu | Kılavuz bitti | Sunucu + DNS |

### Bu turda bulunan kusurların hepsi kapandı

- **`daire_dolu_mu` fazla katıydı** (§4.50) → A seçeneğiyle kapandı.
- **`test_dashboard` yarış koşulu** (§4.46) → düzeltildi; test artık
  bağımsızlığını her koşumda kanıtlıyor ve tam takım **beat açıkken**
  yeşil.

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
5. ~~**Karar: `+905777777777` denetçi**~~ — **KARAR VERİLDİ ve YAPILDI:**
   hesap `scripts/demo_tenant.py`'ye eklendi (§4.55).
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

---

# 10. DÜZELTME TURU — kayıt ve giriş şartnamesine göre ölçüm

> Kerem tam şartnameyi yeniden yazdı ve "mevcut uygulamayı buna göre ölç,
> sonra düzelt" dedi. Bu bölüm **önce ölçümü**, sonra kapatılan dört
> maddeyi yazar.

## 10.1 Ölçüm — 25 maddenin 21'i zaten doğruydu

| Madde | Durum |
|---|---|
| §1 Site oluşturma (6 madde: panel · ID biçimi · rastgele ek · telefon+ad ile yönetici · çoklu yönetici · sonradan ekle/sil) | **6/6 vardı** (göç 0037/0041) |
| §2.1 İlk açılışta rol listesi | **EKSİK** → 10.2 |
| §2.2–2.3 Mobil 4 rol / web 2 rol | vardı |
| §3.1 Sıra: tesis ID → telefon | vardı |
| §3.2 Kimlik doğrulama yöntemi **seçimi** | **EKSİK** → 10.3 |
| §3.3–3.6 Role göre daire kuralı | vardı |
| §3.7–3.9 Eşleşme kuralı · kimin tanımladığı · sosyal kayıtta tesis+telefon | vardı |
| §4 Sonraki girişler (parola · sosyal · tek hesap iki yöntem) | vardı (göç 0048) |
| §5.1 Web Excel toplu yükleme | vardı (göç 0045) |
| §5.2 Mobil tekli ekleme "yalnız telefon" | **YANLIŞ** → 10.4 |
| §5.3–5.4 Telefon güncelleme · silme · saha/denetçi hesabını yönetici açar | vardı |
| §6.1 Daire başına hesap sınırı | göç 0049 → 10.5 |
| §6.2 Denetçinin mobil yüzeyi yok | vardı |

## 10.2 §2.1 — ilk açılış artık rol listesine düşüyor

Uygulama **her** açılışta giriş ekranıyla başlıyordu; rol listesine ancak
giriş ekranındaki bağlantıyla ulaşılıyordu. Yani kaydolmaya gelen
kullanıcı önce "giriş yap" demek zorundaydı.

Artık `ui.rol_secimi_gosterildi` bayrağı yok iken açılış `/kayit`a düşer.
**Bayrak liste GÖRÜLÜNCE yazılır**, kaydolma tamamlanınca değil: brief
listeyi "ilk açılışın ekranı" sayıyor, kaydolmanın ödülü değil.

**Varsayılan `true` ve bu bilinçli.** "İlk açılış" iddiası ancak depo
GERÇEKTEN okunup anahtar bulunamayınca yapılabilir (`acilisTercihleriniOku`).
Elle kurulan her `AcilisTercihleri` — depo hatasındaki fallback ve dil/tema
tohumlayan testler dahil — "gösterildi" sayılır. Varsayılan `false` olsaydı
okunamayan bir depo, hesabı olan kullanıcıyı **her açılışta** kayıt
ekranına düşürürdü.

**Ölçülen kusur:** işaretleme önce `Future(...)` ile ertelenmişti; o bir
ZAMANLAYICI kurar ve ağaç çalışmadan atılırsa `flutter_test` "A Timer is
still pending" ile düşer — `acilis_dil_titremesi_test` böyle kırıldı.
`addPostFrameCallback` ağaçla birlikte düşer.

## 10.3 §3.2 — kimlik doğrulama yöntemi artık bir ADIM

Akış kimlik adımından **doğrudan paroladan** devam ediyordu. Sosyal
hesapla kaydolmak yalnızca **giriş** ekranından mümkündü; yani brief'in
"(a) parola (b) Google (c) Microsoft (d) Apple" seçimi hiç sorulmuyordu.

Mobil `rol → kimlik → YÖNTEM → kod`, web `rol → kimlik → YÖNTEM → kod →
parola` oldu.

**SMS neden hâlâ var:** brief onu saymıyor ama sağlayıcı "bu telefonun
sahibisin" DEMEZ. İki yolda da telefon sahipliğini kanıtlayan şey SMS'tir;
yöntem seçimi onun **yerine** değil, **önüne** kondu.

**SMS artık yöntemden SONRA gönderiliyor.** Önce kimlik adımında
gönderiliyordu: "Google" seçen kullanıcıya önce bir `amac=kayit` SMS'i
gider, ardından sosyal yol kendi kodunu gönderirdi — **iki kod, tek
telefon**.

**Web'de tesis ID + telefon TAŞINIYOR.** Web'de sağlayıcıya tam
yönlendirme var; dönüşte `/giris/oauth` yeni bir React ağacıdır ve
bellekteki hiçbir şey yaşamaz. İki alan `sessionStorage`a bırakılır
(niyet ile **aynı** mekanizma — iki ayrı saklama yeri, birinin
temizlenip ötekinin kalması demekti) ve dönüş sayfası aynı şeyi bir daha
sormaz.

**Bilinen asimetri (kapatılmadı, yazıya döküldü):** sosyal dalda sakinin
**daire eşleşmesi** doğrulanmıyor — `/oauth/baglan/basla` daire almıyor.
Kapatmak, aynı ucu kullanan "açık oturuma yöntem ekle" akışını da daire
sormaya zorlardı. Daire bir **güvenlik sınırı değil** (sınır telefon
sahipliği + SMS'tir); doğrulanması kişinin kendi dairesini bildiğinin ek
teyididir.

## 10.4 §5.2 — mobil tekli ekleme: telefon + daire no

Form **Ad + telefon + daire no + parola** istiyordu. Kerem "telefon +
daire no kalsın" dedi (sakinin hangi daireye bağlanacağı başka türlü
bilinmiyor ve §3'ün daire eşleşmesi buna dayanıyor).

* **Ad kalktı** — yönetici numarayı bilir, adı çoğu zaman bilmez.
* **Parola kalktı** — brief'te sakinin parolasını yönetici belirlemiyor;
  kullanıcı kendi kayıt akışında seçiyor. Yöneticinin parola koyması, o
  akışın "hesabı SAHİPLENME" adımını baştan tüketirdi.

**`app_user.ad` NULLABLE YAPILMADI.** Sütun NOT NULL, **87 yerde**
okunuyor ve **20+ yanıt şemasında** `ad: str` olarak zorunlu. Global
nullable yapmak, brief'in dokunmadığı her ekranı (personel, yönetici,
denetçi listeleri) ilgilendiren bir değişiklik olurdu. Bunun yerine uç,
ad verilmediğinde **daireden türetilen** geçici bir ad yazar
(`"A-12 sakini"`): listede anlamlı görünür, geçici olduğu okunur ve kişi
kaydolunca profilinden düzeltir.

## 10.5 §6.1 — kural ROL BAŞINA, ve NULL boşluğu kapatıldı

Kerem netleştirdi: **"her daire tek malik tek kiracı"** — yani göç
0049'un davranışı doğru, sıkılaştırma yok. Kuralın harfi (role bakmadan
tek sakin) `borclandirma.hedef_sec`in `kiraci_oncelikli` kuralını seçecek
bir şey bırakmazdı.

**Ama bu turda gerçek bir boşluk bulundu:** kontrol
`units.assign_resident` ve içe aktarımda vardı, sakin açmanın **asıl
kapısı** olan `POST /residents`te **YOKTU**. Veritabanı indeksi
`(unit_id, rol_tipi)` ikinci bir MALİKİ yakalar; ama PostgreSQL benzersiz
indekslerde NULL'ları çatıştırmaz — **rol tipi verilmeden açılan sakinler
aynı daireye sınırsız eklenebiliyordu**. Mobil form artık rol tipi
sormadığı için (10.4) o dal **varsayılan yol** hâline geliyordu.

`POST /residents` artık `daire_rolu_dolu_mu` çağırıyor (NULL'u da bir
değer sayan ortak yardımcı) ve ikinci rolsüz sakini 409 ile reddediyor.

## 10.6 Yan bulgu — denetim notları testi bayattı

`denetim_notlari_test` tohumlamada **5** demo hesabı bekliyordu; `f864415`
altıncısını (denetçi) eklemişti. Belge doğruydu ve denetçinin giriş
tablosunda **neden** olmadığını zaten yazıyordu; bayat olan **testti**.

Test artık niyeti tam olarak kodluyor: altı hesap tohumlanır, beşi giriş
tablosundadır, altıncısı tabloda **olmamalıdır** ama notta **anılmalıdır**.
Belgeye eksik olan `denetci@demo.yonetio.site` eklendi.

## 10.7 Testler

| Nerede | Ne ölçülüyor |
|---|---|
| `test_rol_secimli_kayit.py` | **Beş rolün her biri** için uçtan uca: rol → tesis ID → telefon → kod → parola → **giriş** (parametrik) |
| `test_rol_secimli_kayit.py` | Denetçi UCU açık — kapalı olan LİSTE; sınır yazıya döküldü |
| `test_sakin_ekleme_telefon_daire.py` | Ad'sız ekleme · ad daireden türer · verilen ad ezilmez · ikinci malik 409 · malik+kiracı birlikte · **rolsüz ikinci sakin 409** |
| `kayit_rol_secimi_test.dart` | Yöntem adımı dört seçenek · sağlayıcı yoksa yalnız parola · sosyal yolda kayıt ucu **çağrılmaz** · tesis+telefon ikinci kez sorulmaz |
| `uygulama_acilis_giris_test.dart` | İlk açılış rol listesi · ikinci açılış giriş · bayrak depoya yazılır |
| `kayit-rolleri.test.ts` | Adım sırası brief'inki · dört seçenek · SMS yöntemden sonra · tesis+telefon taşınır |
| `denetim_notlari_test.dart` | Altı hesap · denetçi tabloda yok ama notta açıklanmış |
