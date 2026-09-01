# P193 — Kurulum akışı boşlukları · kararlar ve gerekçeler

Bu tur, `docs/yonetici-kurulum-rehberi.md` sonundaki
**"C) Kurulum sırasında olması gereken ama olmayan şeyler"** listesindeki
14 maddeyi kapatıyor. Her bölümün sonunda **NE ÖLÇTÜM** başlığı var:
yalnız "test yeşil" değil, geliştirme ortamında akışı çalıştırıp ne
gördüğüm yazılı. Ölçemediklerim ayrı listeleniyor.

---

## Bölüm 1 — Excel/toplu aktarımda e-posta (14 eksik · madde 4)

### Sorun
Tek tek kullanıcı eklemede e-posta **zorunlu**, Excel aktarımında
**opsiyoneldi**. Aynı ürünün iki kapısı iki farklı kural uyguluyordu.
Sonuç: 120 kişilik bir dosyayı e-postasız aktaran yönetici, 120 kişilik
bir "hayalet" kadro yaratıyordu — hesaplar açık ama kimse giremiyor,
çünkü SMS varsayılan olarak kapalı, yani davet gidecek tek kanal e-posta.
Hiçbir ekran bunu söylemiyordu.

### Kararlar

**K1.1 — `kisi` türünde e-posta zorunlu alan oldu.**
`ice_aktarim.py` içindeki alan tanımı `zorunlu=True` yapıldı; boş satır
`zorunlu_alan_eksik` ile raporlanıyor. Zorunluluk tek yerde tanımlı
olduğu için hem sunucu doğrulaması hem panelin "Zorunlu sütunlar"
bilgisi hem de şablon aynı listeden besleniyor — ikisi ayrışamaz.

**K1.2 — Varsayılan davranış: "sorunlu satır varsa hiçbir şey yazma".**
İstek gövdesine `sorunlulari_atla` eklendi, **varsayılanı `false`**.
Aktarım artık iki geçişli: önce kuru geçiş, hata varsa `uygulanmadi=true`
ile rapor dönülür ve **tek satır yazılmaz**; kullanıcı kutucuğu bilerek
işaretlerse ikinci geçiş uygulanır.

*Neden SAVEPOINT/rollback değil:* satır uygulanırken davet e-postası
gönderiliyor. Veritabanını geri alabilirim, gönderilmiş e-postayı
alamam. "Yarısı davet aldı, kayıt yok" hali, hiç yazmamaktan daha kötü.
Bu yüzden kuru geçiş ayrı bir tam tur olarak koşuyor.

**K1.3 — Davet gerçekten gitti mi, sayılıyor.**
`davet_gonderildi` / `davet_basarisiz` / `davet_hatalari[]` sonuca
eklendi ve denetim kaydına (audit meta) yazılıyor. "Kaç kişi eklendi"
ile "kaç kişiye ulaşıldı" ayrı sorulardır; eskiden ikincisi hiç
sorulmuyordu. Panelde başarısız davetler satır numarasıyla ve
"bu kişiler giriş yapamaz" uyarısıyla gösteriliyor.

**K1.4 — Panelde önizleme bloklayıcı.**
Sorunlu satır varken **Aktar düğmesi kapalı**; yanında nedeni ve
"Sorunlu satırları atla" kutucuğu var. Çalışmayacak bir düğmeyi basılır
bırakmak kullanıcıya "sistem bozuk" hissi verir.

**K1.5 — Sayılar etiketlendi.** Okunan / Geçerli / Zaten kayıtlı /
Sorunlu ayrı ayrı yazılıyor (7 dilde). "4 satır işlendi" cümlesi
yöneticiye hiçbir şey söylemiyordu.

### NE ÖLÇTÜM

Geliştirme ortamında, `acme-plaza` tesisinde `yonetici@acme.com` ile
giriş yapıp **gerçek uca** (`POST /import/kisi`) 4 satırlık bir dosya
gönderdim: 2 satır sağlam, 1 satır e-postasız, 1 satır bozuk e-postalı.
Gördüğüm:

```
KISI ALANLARI:  ad -> ZORUNLU / telefon -> ZORUNLU / eposta -> ZORUNLU
                daire_no -> opsiyonel / rol_tipi -> opsiyonel

=== 1) ÖNİZLEME (yalniz_dogrula=true) ===
  HTTP 201 · okunan=4  gecerli=2  atlanan=0  sorunlu=2
   SATIR 3 · eposta -> Zorunlu alan boş.
   SATIR 4 · eposta -> Geçerli bir e-posta adresi girin.

=== 2) AKTAR (sorunlulari_atla YOK) ===
  HTTP 201 · uygulanmadi = True · aktarim_id = None
  → HİÇBİR SATIR YAZILMADI (veritabanında kontrol edildi)

=== 3) AKTAR (sorunlulari_atla=true) ===
  HTTP 201 · uygulanmadi = False
  olusan=2  sorunlu=2  davet_gonderildi=0  davet_basarisiz=2
   DAVET SATIR 2 -> Davet e-postası gönderilemedi...
   DAVET SATIR 5 -> Davet e-postası gönderilemedi...
```

Son satır beklenmedik ama **doğru** bir bulgu: geliştirme ortamında
SMTP yok, dolayısıyla davetlerin hiçbiri gitmiyor. Eskiden bu tamamen
görünmezdi — aktarım "2 kişi eklendi" der, kimse giremezdi. Artık
yönetici bunu ekranda görüyor. Prod'da SMTP çalıştığı için orada
`davet_gonderildi=2` beklenir; **bu sayının prod'da doğrulanması
gerekir** (aşağıdaki "ölçemediklerim").

Ekran tarafı: `admin-web/tests/ice-aktarim.dom.test.ts` sayfayı gerçekten
render edip ölçüyor (8 test, hepsi geçiyor) — hem düşen hem geçen durum:
sorunlu satırda Aktar **kapalı** ve "Aktarım YAPILMADI" + satır numarası
görünüyor; kutucuk işaretlenince düğme **açılıyor** ve istek gövdesinde
`sorunlulari_atla: true` gidiyor; davet özeti ve uyarısı basılıyor.

Backend: `backend/tests/test_ice_aktarim.py` **18 test geçti**.

### Ölçemediklerim (prod'da/cihazda doğrulanmalı)
- Gerçek SMTP ile `davet_gonderildi` sayısının dolması ve e-postanın
  gelen kutusuna düşmesi.
- Gerçek bir `.xlsx` dosyasıyla tarayıcıdan yükleme (dosyayı panel
  ayrıştırıyor; testler yapıştırılan metinle ölçüyor — ayrıştırma yolu
  aynı, dosya okuma katmanı değil).

---

## Bölüm 2 — Kurulum sihirbazı (14 eksik · maddeler 11, 12, 13, 14)

### Sorun
Sihirbaz sekiz adımdı ve kurulumun **en kritik iki bağımlılığını** hiç
sormuyordu: e-posta gönderimi (davetlerin gittiği tek kanal) ve kasa
(tahsilatın yazıldığı yer). Ayrıca hiçbir adım "yapmazsan ne olmaz"
demiyordu; yönetici kasayı atlıyor, sonucu ilk tahsilatı girmeye
çalışırken öğreniyordu.

### Kararlar

**K2.1 — Dört yeni adım. Sekiz → on iki.**

| Adım | Neden | Zorunlu mu |
|---|---|---|
| **E-posta gönderimi** (sakinden hemen sonra) | Davetler e-postayla gidiyor; çalışmıyorsa açılan hesapların hiçbirine girilemez ve bu ancak şikâyet gelince anlaşılır. | Evet |
| **Kasa** (aidattan önce) | Tahsilat bir kasaya yazılır. Kasasız tesiste borç yazılabilir, para giremez. | Evet |
| **Rezervasyon alanları** | Tanımsızken modül sessizce boş görünüyor; kullanıcı bozuk sanıyor. | Hayır |
| **Sayaçlar** | Aynı sebep. | Hayır |

Sıra tesadüf değil ve testle kilitli: e-posta **sakinden hemen sonra**
(ilk toplu davet oradan çıkar; önce yüzlerce hesap açıp sonra
"e-postam çalışmıyormuş" demek, davetleri tek tek yeniden göndermek
demektir), kasa **aidattan önce** (önce para kutusu, sonra borç).

*Görev kategorisi* rehberde eksik sayılmıştı (madde 12) ama sihirbazda
**zaten var**: `gorev_alani` adımının sunucudaki ölçüsü `task_category`
sayısıdır. Rehberdeki bu satır yanlıştı; §8'de düzeltiliyor.

**K2.2 — E-posta adımı sayılamaz, ölçülür.**
Öteki adımlar bir tablo satırını sayar; e-posta gönderimi sayılamaz —
tesis kendi SMTP'sini girmemiş olabilir ama **genel (ENV) ayardan**
çalışıyor olabilir. Adımın cevabı ancak sağlayıcı seçimi çalıştırılarak
bulunur, ve ölçüt **Mesajlar ekranındaki rozetle birebir aynı**
(`kanal_saglayicisi("eposta", ayar)` LOG sağlayıcısı mı döndürüyor).
Ayrı bir ölçüt yazmak ("smtp_host dolu mu"), ENV'de çalışan bir SMTP
varken sihirbazı yanlış uyarmak olurdu — P172 §1'de kapatılan kusurun
aynısı.

**K2.3 — "Zorunlu" kararı sunucuda, tek yerde.**
Her adım artık `zorunlu` bayrağıyla dönüyor ve sunucu ayrıca
`eksik_zorunlular[]` + `calisir` özetini veriyor. İstemci bunu kendi
listesinden türetseydi, yeni bir adım eklendiğinde iki liste ayrışırdı.

**K2.4 — İlerleme yüzdesi ile "çalışır mı" AYRI iki sayaç.**
Atlanan adım ilerlemeyi rahatlatır (bilinçli atlayan tesis %100'e
ulaşabilmeli) ama **özeti değiştirmez**: kasası olmayan tesis, adım
atlandı diye tahsilat yapamaz. Bu ayrım hem backend hem panel testinde
kilitli.

**K2.5 — Her adım "ne engelliyor"u yazıyor.**
12 adım için 7 dilde engel metni. Biten adımda çizilmez — olmayan bir
sorunu anlatmak gürültüdür.

**K2.6 — Hatırlatıcıyı geri açma düğmesi sihirbaza taşındı (madde 14).**
Düğme yalnız `/settings`teydi, yani **yalnız admin** görüyordu; "Daha
sonra" diyen bir yöneticiye hatırlatma bir daha çıkmıyordu. Artık
sihirbaz sayfasının özet kartında — kullanıcı hatırlatmayı arıyorsa
sihirbaza bakar, platform ayarlarına değil. `/settings`teki düğme
duruyor (admin'in alışkanlığını bozmanın bir faydası yok).

**K2.7 — Özet alanları istemcide OPSİYONEL.**
Panel ve sunucu ayrı dağıtılıyor; yeni panel bir an eski sunucudan yanıt
alabilir. Alanları zorunlu saymak sayfayı tamamen boş bırakırdı — bu
ölçüldü (`undefined.length` ile çizim çöktü, test yazılırken görüldü).
Özet yoksa yalnız özet çizilmez; adım listesi çalışır.

**Yarım bırakıp devam etme** için kod yazılmadı ve bu bilinçli: durum
zaten saklanmıyor, **sayılıyor** (`routers/kurulum.py`). Yeni oturumda
aynı yerden devam edilir; ölçüldü (aşağıda). Sihirbaza yalnız bunu
söyleyen bir satır eklendi.

### NE ÖLÇTÜM

`acme-plaza` tesisinde, gerçek uca (`GET/PATCH /kurulum`) çağrı yaparak:

```
BASLANGIC: calisir=False eksik=['daire_tipi','eposta'] zorunlu=7 gecilen=10/12
  POST /unit-tipleri  -> 201
TIP EKLENDIKTEN SONRA: calisir=False eksik=['eposta'] gecilen=11/12
  eposta ATLANDI  -> eksik=['eposta'] calisir=False  gecilen=12/12   ← ayrım
  atlama GERI ALINDI -> gecilen=11/12
  YENI OTURUM ayni durumu goruyor: True (11/12)
```

Üç şey bu çıktıda görünüyor: (a) gerçek bir kayıt yaratınca adım kendi
kendine tamamlanıyor, (b) **atlamak ilerlemeyi 12/12 yapıyor ama
`calisir` yine `False`** — istenen ayrım tam olarak bu, (c) yeni bir
oturum aynı ilerlemeyi görüyor, yani "yarım bırakıp devam etme"
çalışıyor.

E-posta adımının ölçütünün Mesajlar ekranıyla aynı olduğunu da ayrıca
doğruladım:

```
GET  /mesaj-ayarlari       -> eposta_hazir=False  kaynak="yok"
POST /mesaj-ayarlari/test  -> {"durum":"yapilandirilmadi","hata":"smtp_yapilandirilmadi"}
```

Sihirbazın `eposta` adımı da `tamam=False` diyor — iki ekran aynı şeyi
söylüyor. (Dev ortamında SMTP yok; §1'deki davet bulgusuyla aynı kök.)

Ekran tarafı: yeni `admin-web/tests/kurulum-ozet.dom.test.ts` sayfayı
render ederek ölçüyor — Kasa ve E-posta adımlarının listede olması,
"Zorunlu adımlar: 5/7" ve engel cümleleri, hepsi tamamken "Tesis çalışır
durumda", **yöneticinin** hatırlatıcıyı geri açması (`localStorage`
kaydının gerçekten silindiği), ve eski sunucu yanıtının sayfayı
kırmaması. 5 test. `test_kurulum.py` 10 test geçti.

### Ölçemediklerim
- Tarayıcıda gerçek tıklama akışı (adım → hedef ekran → geri dön →
  adımın tamamlandığını gör). Ölçüm uç ve render seviyesinde.
- Gerçek SMTP'li bir tesiste `eposta` adımının `tamam=True` olması.
