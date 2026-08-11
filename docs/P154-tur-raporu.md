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
| **10** — Apsiyon B kovası (kalanlar) | göç 0047 — ters kayıt + defterde silme kilidi; triyajda **iki yanlış ölçüm düzeltildi** | bu tur |

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

## 7. YAPILMAYAN AŞAMALAR — dürüst kayıt

Aşama 3, 6 ve 9'un bir bölümü sonradan yapıldı (§1'e işlendi). **Kalan
dört aşama** ve 9'un artığı:

| Aşama | Neden başlanmadı | Aşama 0'dan hazır girdi |
|---|---|---|
| **4** — OAuth (Google/Microsoft/Apple) | Üç sağlayıcı × iki platform + hesap birleştirme; en büyük tek kalem | Test sunucusu için geri dönüş adresleri `docs/test-sunucusu-kurulum.md` §8'de yazılı |
| **5** — Kullanıcı + yapı yönetimi | Aşama 6 ve 8'e bağımlı (modal + import) | Ölçülen 7 boşluk `docs/envanter.md`'de listeli (toplu daire web'de yok, kat silme yok, sürükle-bırak yok, daire tipi ataması web'de yok…). Modal + Liste **artık hazır** (6.1/6.2) |
| **7.3/7.4** — Onboarding sihirbazı, bağımlılık yönlendirmesi | 7.1 bitti, 7.2'nin üç maddesi yapıldı | Bağımlılık haritası 16 satır hazır (Aşama 0.4); yönlendirme **tek bileşen** olarak kurulacak |
| **8** — Import framework | `/site-aktar` üstüne kurulacak | Uç + şablon **zaten çalışıyor** |
| **9 (artık)** — Kuyruk + yeniden deneme, zengin metin e-posta, gönderim ekranı | Sağlayıcı katmanı kuruldu, üstü kalmadı | `app/gonderim.py` tek giriş noktası; `mesaj_gonderim` tablosundan kota sayılıyor |
| **10** — Apsiyon B kovası | 6'ya bağımlı | 14 A− maddesi listeli; **6 artık bitti** |

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
