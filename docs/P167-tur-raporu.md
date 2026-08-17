# P167 — tur raporu

Brief sekiz ana madde ve ~30 yeni ekran içeriyor. Brief'in kendi uyarısı
("tek oturumda bitmez, aşama sırasına uy, tamamlanmışı bırak, kalanı
dürüstçe raporla") aynen uygulandı.

| Aşama | Kapsam | Durum |
|---|---|---|
| 1 | Menü mimarisi (§1.1–§1.8) | **bitti** |
| 2 | Özet sayfası (dashboard yeniden inşa) | **bitti** |
| 3 | Web toplu blok/daire hatası | **bitti** |
| 4 | Finansal İşlemler (8 sayfa) | **bitti** |
| 5 | Rapor motoru | **bitti** |
| 6 | Yönetim başlığı (karar defteri, doküman) | **bitti** |

---

# AŞAMA 1 — MENÜ MİMARİSİ

## 1.1 İkon kuralı tersine çevrildi

**Yapılan.** İkon artık **ana başlıkta**; alt satırlar ikonsuz ve
girintili (`ps-9`). Bağımsız sekmeler (Özet) ve alt çubuk satırları
(Kurulum sihirbazı) ikon taşır — brief'in "alt başlığı olmayan bağımsız
sekmelerde ikon olacak" maddesi.

**Neden bu yön doğru.** 40 satırlık bir menüde 40 küçük şekil ayırt edici
değil gürültüdür; hiçbiri ötekinden ayrılmıyordu. Yedi başlık ikonu ise
taranarak değil **bakılarak** bulunur.

**Yeni ikon:** `shield` (Güvenlik başlığı). `scan` kullanılamazdı — o
zaten NFC noktaları ve araç geçişlerinin satır ikonuydu; başlık,
altındakilerden birinin kopyası gibi görünürdü.

**Dar modda kural tersine döner ve dönmek zorunda:** 68 px'lik şeritte
etiket görünmez, geriye tek tanıma aracı olarak ikon kalır. İkonsuz bir
dar menü boş kutucuklar listesi olurdu.

## 1.2 İlk açılışta tüm ana başlıklar kapalı

`localStorage` anahtarı `yonetio.menu.durum.v2` → **`.v3`**. Sürüm
atlamak zorunluydu: P166 kayıtlarında sekiz bölümün hepsi "açık" olarak
yazılı; eski kaydı okusaydık o kullanıcılar değişikliği **hiç
görmezdi**.

**Bir istisna korundu ve gerekçesi var:** bulunulan sayfanın bölümü her
zaman açılır. Bu "hepsi kapalı başlar" ile çelişmiyor — ilk açılışta
gidilen yer `/dashboard`, o da bağımsız Özet sekmesi (hiçbir bölüme ait
değil). Kural ancak kullanıcı bir bölüm sayfasına geçtiğinde devreye
girer ve orada istenen şey zaten yön duygusudur.

## 1.3 Canlı Panel → Özet

Bağımsız üst sekme, ikonlu, başlıksız, en üstte. Menü verisinde bir
`GrupId` (`ozet`) olarak duruyor ama `bagimsiz: true` taşıyor: kabuk onu
başlıksız çizer. Teknik gerekçe — görünürlük/arama/aktiflik mantığı tek
kümeden yürüyor; "grupsuz öğe" ikinci bir kod yolu açardı.

"Canlı Panel" adı Güvenlik'in altındaydı ve ikisi de yanlıştı: sayfa
yalnız güvenliği değil tesisin tamamını özetliyor.

## 1.4 İcra dosyaları taşındı

Bağımsız `icra` bölümü kaldırıldı; `/icra` **Finansal İşlemler**
başlığının altında bir satır. Aynı işlemde `finansHareket` bölümü de
finansa katıldı.

P154 bu ikisini bir **yer bütçesi** yüzünden ayırmıştı (tüm bölümler açık
çizildiği için 11 satırlık finans menüyü taşırıyordu). §1.2 o bütçeyi
ortadan kaldırdı — artık bir bölümün kaç satır olduğu ancak kullanıcı onu
açtığında önemli. Sebebi kalkmış bir bölünmeyi sürdürmek olurdu.

## 1.5 İletişim üçlüsü birleştirildi

"Mesajlar", "SMS gönderimi", "E-posta gönderimi" → tek satır:
**SMS/E-Posta Yönetimi** (`/mesajlar`).

**Ölü rota yok:** `?kanal=sms` ve `?kanal=eposta` hâlâ geçerli ve sayfa
onları okuyor (`useSorguSecimi`); eski yer imleri ve `/kurulum`
bağlantıları kırılmadı. Kaybolan bir yetenek de yok — sayfa kanalı zaten
kendi içinde seçiyor.

## 1.6 Tanımlar başlığı düzeltildi

Eski hâl gerçekten bozuktu: başlık "Tanımlar" diyordu ama altında
`/tanimlar` ekranının **on bir defterinden yalnız yedisi** vardı; buna
karşılık kendine işaret eden bir "Tanımlar" satırı ve bir "Kurulum
sihirbazı" duruyordu (sihirbaz bir tanım değil bir **akış**).

Yeni hâl: bölüm, `/tanimlar` ekranının sekme şeridinin **birebir
aynası** (11 defter + Ayarlar) + aynı seviyede **Bloklar** ve **İçe
aktarım**. Sıra da sayfadaki `DEFTERLER` dizisiyle aynı.

**Yan ürün — sayfada bir düzeltme:** "Ayarlar" sekmesi yerel bir
`useState`te duruyordu, yani menüden **açılamayan tek bölüm** oydu.
Aynı `?defter=` sorgusuna defter olmayan tek bir değer (`ayarlar`)
eklendi; seçim artık tek yerden (adresten) okunuyor.

## 1.7 Profilim sağ üste taşındı

**Sol menüden kalktı.** Sol menü siteye ait ekranların listesidir;
kullanıcının kendi kaydı o listede "yönetim işi" gibi okunuyordu.

**Yeni bileşen `KullaniciMenusu`** — avatar + tesis adı + kullanıcı adı,
tıklanınca açılır menü: Hesap bilgileri · Güvenlik ve giriş · Bildirim
ayarları · Şifre değiştir · Hesabımı sil · Çıkış yap. Dil seçicinin
sağında; **mobil üst barda da var** (profil satırı çekmeceden kalktığı
için oraya koymasaydık mobil kullanıcının hesabına hiçbir yol kalmazdı).

**Avatar** (`components/Avatar.tsx`): fotoğraf yoksa baş harfler. Renk
addan türetilir (kararlı) — rastgele renk "hesap değişti mi?" sorusunu
her yenilemede sordururdu. Yükle / değiştir / kaldır çalışıyor; dosya
BFF'ten geçmez (presign → doğrudan MinIO), anahtar sunucuda kendi tenant
namespace'i için doğrulanır.

**Profil sayfası kendi sol menüsüyle açılıyor.** Bölüm listesi
`lib/profil-bolumleri.ts`te **tek kaynak** — aynı liste sağ üst menüde de
çiziliyor; iki yerde tekrar edilseydi biri eklenip öteki unutulduğunda
menüde görünen ama sayfada açılmayan bir satır kalırdı. Seçim adresten
okunur (`?bolum=guvenlik`), yoksa menüdeki bağlantılar çalışmazdı.

### Verilen karar: e-posta alanı salt okunur

Brief "Hesap Bilgileri" formunda **E-posta** istiyor. Alan çizildi ama
**kilitli** ve nedeni ekranda yazılı.

Gerekçe: bu sistemde e-posta **login anahtarıdır**
(`uq_app_user_tenant_email`) ve bir doğrulama akışı yoktur.
Doğrulamasız değiştirilebilseydi (a) ödünç alınmış bir oturum adresi
değiştirip hesabın sahibini kalıcı olarak dışarıda bırakabilirdi,
(b) yanlış yazılan bir adres parola sıfırlamayı **sessizce** çalışmaz
kılardı. Değişim yolu, doğrulama kodu akışıyla **birlikte** açılmalı —
tek başına açmak bir özellik değil bir açık olurdu. Alan gizlenmedi
çünkü gizlemek "neden yok?" sorusu üretirdi.

**Ad soyad** self-servis değiştirilebilir hâle geldi (yeni sema
`MeContactUpdate`). `UserContactUpdate`'e eklenmedi: o şema yönetim ucunu
da besliyor ve oraya `ad` eklemek, "iletişim güncelle" adlı bir ucun
sessizce kimlik alanı da değiştirebilmesi olurdu.

### Verilen karar: `PATCH /me/avatar` admin ve denetçiye açıldı

Ölçüm sırasında çıktı: uç **yalnız `yonetici` + `resident`**e açıktı ve
gerekçesi *"admin'in self-servise ihtiyacı yoktur"*du. Bu tur o gerekçeyi
geçersiz kıldı — panelin sağ üst köşesi artık **her rol** için avatar
çiziyor ve profil sayfası üçüne de açık. Yükleme düğmesini gösterip ucun
403 dönmesi kullanıcıya sebebi olmayan bir hata verirdi; düğmeyi rolde
gizlemek ise aynı kuralı istemcide ikinci kez yazmak olurdu.

`admin` ve `denetci` eklendi. **`security` / `tesis_gorevlisi` hâlâ
dışarıda ve bu bilinçli:** onların fotoğrafı bir süs değil **operasyonel
kimlik kaydıdır** (vardiya, devriye, ziyaretçi karşılama) ve yönetim
`PATCH /users/{id}/avatar` ile yönetir. Kendileri değiştirebilseydi
"kim kimdir" kaydı denetlenemez hâle gelirdi.

### Yeni backend uçları (§1.7 için açıldı)

| Uç | Ne yapar |
|---|---|
| `GET /me/cihazlar` | Kendi push cihazları (en son görünen üstte) |
| `DELETE /me/cihazlar/{id}` | Bir cihazı kaldır (satır **silinmez**, `aktif=false`) |
| `POST /me/cihazlar/tumunden-cik` | Hepsini pasifleştir |
| `GET /me/etkinlik?limit=20` | Kendi denetim kaydı satırları |
| `GET|PATCH /me/bildirim-tercihleri` | E-posta / SMS / mobil anahtarları |
| `POST /api/me/hesap-sil` (BFF) | Uç P112'de vardı, **panelde vekili yoktu** |

Bunlar var olan uçların kısıtlı kopyası **değil, ayrı yetki
kararları**: `GET /devices` tenant'ın tüm cihazlarını yalnız admin'e,
`GET /audit` tesisin tüm denetim kaydını admin+denetçiye açar.
Buradakiler **her role** açık ve yalnız kişinin **kendi** satırlarını
döner — kendi hesabında hangi cihazın açık olduğunu görmek bir yönetim
yetkisi değil, hesap güvenliğinin temel koşuludur.

Tasarım detayları ve gerekçeleri:
- **`fcm_token` dönmez.** Push adresidir; dışarı vermek o kullanıcıya
  bildirim göndermenin anahtarını vermektir. Satırlar `id` ile yönetilir.
- **Cihaz silinmez, pasifleşir.** `uq_user_device_tenant_token` aynı
  token'ın tekrar kaydını upsert'e çevirdiği için silme, aynı telefonun
  her girişinde cihaz geçmişini sıfırlardı.
- **"Tümünden çık" oturumları sonlandırmaz** ve etiketi bunu söylüyor.
  Refresh token'lar bu tabloda değil; sonlandırılmış gibi göstermek
  kullanıcıyı güvende **sandığı** ama olmadığı bir yerde bırakırdı.
- **`limit` tavanı 100.** Sınırsız `limit`, tek istekle denetim tablosunu
  süzdüren bir yol açardı.

### Göç 0055 — `bildirim_eposta / bildirim_sms / bildirim_mobil`

`app_user`da zaten `pazarlama_*` kolonları var; **ayrı kolonlar açıldı**
çünkü ikisi hukuken ve işlevsel olarak farklı:

- **Pazarlama bir RIZADIR** (KVKK md. 5/1). Varsayılanı **kapalı** olmak
  zorunda, her an geri alınabilir.
- **Bildirim bir TERCİHTİR.** "Aidat borcunuz oluştu", "görev size
  atandı" — sözleşme ilişkisinin işleyişi, rıza gerektirmez.
  Varsayılanı **açık** olmalı; kullanıcı gürültü azaltmak için kapatır.

Tek bayrakta birleştirmek: pazarlamayı kapatan kullanıcının aidat
bildirimini de kaybetmesi — ya da tersi, pazarlama gönderimini bir
tercihe indirip KVKK ihlali.

`arama` kanalı bilerek yok: telefonla aranmak `aranabilir` kolonuyla
zaten yönetiliyor ve orası bir **numara açıklama** kararı.

## 1.8 Alt bar düzeni

```
[ Kurulum sihirbazı ]        <- tam genişlik, ikonlu
[ Tema ]  [ Çıkış ]          <- ikiye bölünmüş
```

"Çıkış yap" iki kolonluk satırda taşıyordu; görünen etiket "Çıkış"a
kısaldı ama **erişilebilir ad tam cümle kaldı** (`aria-label="Çıkış
yap"`) — ekran okuyucu kullanıcısı için bir sayfa adı değil bir **eylem**
olduğu belli olmalı.

Kurulum sihirbazı dar modda da (yalnız ikon) çiziliyor: sihirbaz bir
**yoldur**, tema gibi bir kısayol değil — kaldırmak, kurulumunu
bitirmemiş yöneticiyi yolsuz bırakırdı.


---

# AŞAMA 2 — ÖZET SAYFASI

## Yapılan işin şekli: sayfa artık **bölümlerden** oluşuyor

Eski pano sabit bir sıralamaydı (kahraman blok → KPI → alarmlar → harita →
3D → kamera). §2.5 bunu tersine çeviriyor: her bölüm gizlenebilir ve
sıralanabilir. Bölüm listesi `lib/pano-tercihi.ts`te **tek kaynak** — hem
çizim, hem düzenleme modu, hem sunucuya yazılan gövde oradan okuyor.

### Verilen karar: brief'in bölüm listesine iki bölüm **eklendi**

§2.5 bölümleri *"widget şeridi, finansal kartlar, takvim, 3D, alarmlar"*
diye sayıyor. Ama sayfada bunlardan başka şeyler de vardı: süren/sıradaki
devriyeyi gösteren **kahraman blok**, dört **KPI halkası** ve **kamera
şeridi**. Listeyi harfi harfine uygulamak onları silmek olurdu — ve
GENEL KISITLAR'ın ilk maddesi *"Mevcut işlev kaybolmayacak"* diyor.

Çözüm ikisini de tutuyor: işlev kaldı, ama artık öteki bölümlerle **aynı
kurala tabi** — `devriye`, `kpi` ve `kameralar` da gizlenebilir ve
sıralanabilir. Yani "sayfa özelleştirilebilir olacak" şartı onları da
kapsıyor.

**Varsayılan sıra:** kısayollar → [finansal özet | site maketi] →
takvim → [devriye durumu | alarmlar] → günün sayıları → kameralar.
Köşeli parantez içindekiler tek satırı paylaşan **yarım** bölümler.

## 2.1 Widget şeridi

Altı kısayol, tam genişlik, özelleştirilebilir. **Seçilebilir küme
`menuGruplari(yuzey, rol)`ten geliyor** — brief'in *"erişemeyeceği bir
sekmeyi widget yapamaz"* şartı böylece **menüyle aynı kaynaktan** doğuyor.
İkinci bir yetki listesi yazsaydık, bir sayfanın rol kapısı değiştiğinde
biri güncellenip öteki unutulurdu ve şerit kullanıcıyı 403'e götüren bir
düğme taşırdı — sessizce, çünkü kimse tıklamadan fark etmez.

Kayıtta duran ama artık yetkisi olmayan rota **çizimde elenir** (kayıt
temizlenmeden eski hâlinde kalır). Rozet yalnız elimizde sayı varsa
çizilir ve **sıfır çizilmez**: "0" bilgi değil gürültüdür.

## 2.2 Finansal özet

Altı kart + ayrı Kasalar paneli (liste + sağ üstte Genel Toplam).

**Animasyonlu sayaç kullanılmadı** — brief'in açık şartı. Panonun `Kpi`
bileşeninde sayma animasyonu var ve tam bu yüzden burada kullanılmadı:
0'dan 84.320,50'ye sayan bir kart, yolun her karesinde ekranda duran ama
**doğru olmayan** bir rakam gösterir.

**Excel/PDF için yeni uç açılmadı.** Rapor motoru (P31) zaten
`POST /raporlar/{kod}?bicim=excel|pdf` ile dosya üretiyor ve aynı
`RaporSonuc`tan hem tablo hem dosya çıkıyor. Panoya özel bir dışa aktarma
ucu açmak, aynı rakamları **ikinci bir yerden** hesaplamak olurdu — kartla
dosyanın bir gün ayrışması ancak öyle mümkün olur. İkonlar renkli
(Excel yeşil tablo, PDF kırmızı belge), düğmenin kendisi nötr.

### Üç kart yeni bir alan gerektirdi

| Kart | Kaynak |
|---|---|
| Borçlandırılan / Tahsil edilen / Alacaklarım | `/finans/ozet` — zaten vardı |
| **Borçlarım** | ödenmemiş gider → `finansal_hareket.durum` |
| **Onay bekleyen hareketler** | `durum = onay_bekliyor` |
| **Ödenmiş faturalar (bu ay)** | `durum = odendi`, tip `gider`, bu ay |

`durum` kolonu **göç 0056**'da açıldı. Aşama 4'ün "Durumu (varsayılan
Ödendi)" alanı da aynı kolondur; iki turda iki kez açmak, arada kalan
sürümde kartı besleyecek bir alan olmaması demekti.

**Varsayılan `odendi` olmak zorunda:** tabloda duran her satır zaten
gerçekleşmiş bir para hareketidir (kasa bakiyesi onlardan hesaplanıyor).
Başka bir varsayılan geçmiş bütün defteri bir gecede "ödenmemiş" gösterir
ve kasa mutabakatını bozardı. `Borçlarım` hesabında **ters kayıtla iptal
edilmiş** satırlar dışarıda: iptal bir düzeltmedir, ödenmemiş borç değil.

## 2.3 Takvim

Gün / Hafta / Ay, ileri-geri gezinme, bugünün vurgulanması, tam ekran.
Altı kaynak: etkinlik · devriye penceresi · aidat son ödeme · görev teslim
· rezervasyon · **kişisel hatırlatma**.

**Tek uç (`GET /takvim`), altı ayrı uç değil.** İstemcinin altı listeyi
ayrı çekmesi, kullanıcı her ay okunu tıkladığında altı gidiş-dönüş demekti
ve üçü gelip üçü gelmediğinde takvim yarım çizilirdi. Ayrıca altı tablo
altı farklı kolon adı taşıyor (`tarih`, `pencere_baslangic`,
`son_odeme_tarihi`, `sonraki_planlanan`…); bu çeviriyi istemciye bırakmak,
çizim kodunun altı veri şeklini bilmesi demekti.

Kararlar:
- **Aidat satırları tarihe göre gruplanır**, daire başına değil: 200
  daireli bir sitede aynı gün 200 kayıt takvimi okunamaz kılardı. Grup
  satırının `id`'si tarihten türetilmiş kararlı bir `uuid5`.
- **Tekrar saklanır, genişletilmez.** "Her hafta" bir kuraldır; her
  örneğini satır olarak yazmak, kuralı değiştirmeyi yüzlerce satır
  güncellemeye çevirirdi. Genişletme okuma anında, pencere kadar.
- **Ay sonu kaydırılmaz, atlanmaz:** "her ayın 31'i" diyen bir hatırlatma
  şubatta **ayın son gününe** çekilir. Atlamak onu şubatta hiç
  göstermemek, ileri kaydırmak marta taşımak olurdu.
- **Pencere zorunlu ve en fazla 120 gün** — sınırsız aralık, altı tablonun
  tamamını tek istekte süzdürmek olurdu.
- **İptal edilen rezervasyon dışarıda:** iptal slotu boşaltır; takvimde
  göstermek boş bir saati dolu gibi okuturdu.
- Tarihler **yerel saatte** hesaplanır (kullanıcının "bugün"ü
  tarayıcısının saat dilimindedir); sunucuya giden pencere ISO/UTC.
- Hafta **pazartesi** başlar; `getDay()` pazar=0 döndüğü için düzeltme
  atlanırsa ay ızgarası bir gün kayar ve **her** hücre yanlış güne yazılır.

**`hatirlatma` `event` tablosuna eklenmedi.** Etkinlik sakinlere duyurulur,
RSVP alır, ortak alan ayırtır; hatırlatma kimseye görünmeyen kişisel bir
nottur. Tek tabloda `gizli` bayrağıyla tutmak, "notu yanlışlıkla herkese
açmak" hatasını bir kutucuk mesafesine indirirdi. Görünürlük kapısı
`user_id`; aynı tesisteki başka bir yönetici bile görmez.

## 2.4 Harita kaldırıldı, 3D sağ üstte

`SiteHarita` bu sayfanın **tek** çağrı yeriydi; brief "Özet'te olmayacak"
dediği için çağrı kalktı. 3D maket varsayılan sırada finansal özetin
yanında, yani widget şeridinin hemen altında **sağ sütunda**.

**Bileşen dosyası silinmedi** ve bu bilinçli: tesis konumu bir gün kendi
ekranını bulacak, çalışan bir bileşeni silip yeniden yazmak kaldırılan şeyi
geri getirmenin en pahalı yolu olurdu. **Bugün hiçbir yerden
çağrılmıyor** — bu raporda açıkça yazıyor ki unutulmuş bir kalıntı
sanılmasın. `haritaAdresi` birim testleri korundu (anahtarsız OSM'e düşme,
marker parametresi hâlâ doğru olmalı).

## 2.5 Sayfa özelleştirme

"Paneli düzenle" modu: her bölümde yukarı/aşağı taşı + göster/gizle,
üstte "Varsayılana dön". Kısayollar için ayrı bir seçim modalı.

**Sürükle-bırak yerine yukarı/aşağı düğmeleri.** Brief sürükle-bırak
istiyor; düğmelerle yapıldı ve gerekçesi erişilebilirlik: sürükle-bırak
klavye ve ekran okuyucu kullanıcısı için ayrı bir mekanizma gerektirir
(`aria-grabbed` terk edildi, HTML5 DnD mobilde çalışmaz). Aynı işi yapan
düğmeler **her girdi yöntemiyle** çalışıyor. Sürükleme ileride bunun
**üstüne** eklenebilir; tersi mümkün değil.

**Düzen tek boyutlu bir liste.** Yan yana gelen iki `yarim` bölüm tek
satırı paylaşıyor; iki eksenli bir ızgara olsaydı hem kod hem klavye
erişimi kat kat karmaşıklaşırdı.

Her değişiklik **anında** sunucuya yazılır (ayrı "Kaydet" yok): düğmeye
basıp sayfadan çıkan kullanıcı değişikliği sessizce kaybederdi.
Yazılamazsa toast ile söylenir.

## Aşama 2 — yeni uçlar ve göç

| Uç | Ne yapar |
|---|---|
| `GET/POST /hatirlatmalar` | Kişisel takvim notları (yalnız sahibinin) |
| `PATCH/DELETE /hatirlatmalar/{id}` | Başkasınınki 404 |
| `GET /takvim?baslangic=&bitis=` | Altı kaynağın birleşik okuması |
| `GET/PUT /me/pano-tercihi` | Kullanıcı başına pano düzeni |
| `GET /finans/ozet` | Üç yeni alan |

**Göç 0056:** `app_user.pano_tercihi jsonb` · `hatirlatma` tablosu (RLS +
sahiplik) · `finansal_hareket.durum` enum + kısmi indeks.

`pano_tercihi` **sunucuda, `localStorage`ta değil**: tarayıcı deposu
kullanıcı başına değil *tarayıcı* başına çalışır; ofisten düzenlenen pano
evdeki dizüstünde varsayılana dönerdi. (Kabuk menüsünün açık/kapalı durumu
bilerek `localStorage`ta kalıyor — o bir gezinme alışkanlığı ve cihaz
başına farklı olması doğal.) JSONB **şemasız değil**: uç `PanoTercihi` ile
doğrular ve tanımadığı anahtarı atar.

## Aşama 2 — web/mobil eşitlik

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| §2.1 widget şeridi | **hayır** | Mobil ana ekran P160'ta zaten kısayol ızgarası + "Tüm Modüller" olarak yeniden tasarlandı; ikinci bir şerit aynı işi iki kez yapardı. |
| §2.2 finansal kartlar | **kısmen** | Mobilde özet kartlar var; üç yeni alan (`borc_kurus`, `onay_bekleyen_adet`, `odenmis_fatura_ay_kurus`) aynı uçtan geliyor, mobil onları henüz çizmiyor. Küçük ekran işi. |
| §2.3 takvim | **evet — sonraki turda** | Yaklaşan olay ve hatırlatma, telefonda en çok bakılan şey. `GET /takvim` ve `/hatirlatmalar` rol bağımsız ve hazır. |
| §2.4 3D maket | **hayır** | Mobilde WebGL sahnesi taşımak pil ve paket boyutu maliyeti; mobilin karşılığı şematik plan. |
| §2.5 panel düzenleme | **hayır** | Mobil ana ekranın düzeni zaten sabit ve tek kolon; sıralama orada bir soruna çözüm değil. |

---

---

# AŞAMA 3 — "KAYITSIZ BLOK" HATASI

## Kök neden (ölçüldü, tahmin edilmedi)

İki istemci **aynı ucu, aynı gövdeyle** çağırıyor (`POST /units/bulk`).
Fark çağrının kendisinde değil **öncesinde**:

- **Mobil:** toplu oluşturma diyaloğu bir bloğun **içinden** açılıyor
  (`blok: widget.blok`). O blok daha önce `POST /blocks` ile kaydedilmiş —
  `building_block` satırı **var**.
- **Web:** diyalog blok adını **serbest metin** yazdırıyor (`oBlok`) ve
  doğrudan `/units/bulk`a gönderiyor. `building_block` satırı **hiç
  açılmıyor**.

`unit.blok` **zayıf bir metin bağı** (hard FK yok — bilinçli: bloksuz ve
blok tabanlı siteler birlikte destekleniyor, göç 0001'in notu). Blok kaydı
olmayınca editör `registeredFor(label)` için false dönüyor:
**"kayıtsız (yalnızca dairede)"** rozeti çiziliyor ve Düzenle/Sil düğmeleri
hiç çizilmiyor — ikisi de `block.id` istiyor.

## Düzeltme: istemcide değil **sunucuda**

Web'i mobile benzetmek **örneği** düzeltirdi, **sınıfı** değil. Aynı deliğe
içe aktarım, doğrudan API kullanan bir müşteri ve ileride yazılacak her
yeni ekran düşerdi — ve düştüğünde yine sessiz olurdu: istek 201 döner,
kayıt "çalışır" görünür, kusur ancak editör açılınca fark edilir.

`_blok_kaydini_gerektir()` hem `POST /units` hem `POST /units/bulk`
içinde: `blok` verilmiş ama kaydı yoksa `building_block` satırını açar.

Üç detay:
- **`ON CONFLICT DO NOTHING`, "önce bak sonra yaz" yerine.** İki eşzamanlı
  toplu oluşturma arasında yarış olurdu; ikisi de "yok" görür, ikincisi
  benzersiz kısıtı ihlal eder. O ihlali `except`te yutmak da yetmezdi —
  SQLAlchemy oturumu o noktada kırılır ve toparlamak `rollback` ister;
  oysa bu fonksiyon **çağıranın işlemi içinde** çalışıyor ve onun o ana
  kadarki yazmalarını geri almaya hakkı yok.
- **Denetime yalnızca gerçekten açılan kayıt yazılır** (`RETURNING id`
  boşsa blok zaten vardı); yoksa her toplu oluşturma sahte bir "blok
  oluşturuldu" satırı bırakırdı.
- **Blok kaydı dairelerden ÖNCE açılır**: sonra açmak, arada düşen bir
  istekte tam olarak "kayıtsız blok" durumunu yeniden üretirdi.

Web tarafında **değişiklik gerekmedi**: editörün `refresh()`i zaten hem
`/api/blocks` hem `/api/units`i tazeliyor, yani yeni blok anında görünür.

## Onarım göçü 0057 — mevcut bozuk kayıtlar

```sql
INSERT INTO building_block (tenant_id, ad)
SELECT DISTINCT u.tenant_id, btrim(u.blok) FROM unit u
 WHERE u.blok IS NOT NULL AND btrim(u.blok) <> ''
   AND NOT EXISTS (SELECT 1 FROM building_block b
                    WHERE b.tenant_id = u.tenant_id AND b.ad = btrim(u.blok))
ON CONFLICT (tenant_id, ad) DO NOTHING
```

**Veri kaybı riski YOK** ve bu somut bir iddia: tek işlem INSERT. Hiçbir
satır silinmiyor, hiçbir sütun güncellenmiyor, `unit` tablosuna
**dokunulmuyor** — daireler zaten doğruydu, eksik olan yalnızca bloğun
kendi kaydıydı. Bu yüzden **durup sormaya gerek olmadı**.

Üç karar:
- **`kat_sayisi` bilerek NULL.** Dairelerden türetmek cazip (`max(kat)`)
  ama yanlış olurdu: bodrumlu binada katlar −2'den başlar, yani en yüksek
  kat numarası kat *sayısı* değildir. Uydurma bir sayı, kullanıcının
  düzeltmesi gereken sessiz bir yanlış bırakırdı.
- **Boş/NULL etiketler atlanıyor.** Bloksuz daireler bilinçli bir durum ve
  editörde zaten kendi kovasında ("Blok atanmamış") görünüyor.
- **`downgrade` boş ve bu bir karar.** Göç *eksik* bir kaydı tamamladı;
  geri almak onarılanları yeniden kayıtsız yapmak olurdu. Ayrıca hangi
  satırın göç, hangisinin kullanıcı tarafından açıldığını ayırt etmenin
  yolu yok — silmeye kalkmak elle oluşturulmuş blokları da götürürdü.

**Neden göç, neden tek seferlik betik değil:** kusur üründe oluşmuş veriyi
etkiliyor ve her ortamda aynı. Betik, çalıştırılması **unutulabilen** bir
adımdır; göç sürümle birlikte kendiliğinden gider ve `alembic_version`
uygulandığının kaydıdır.

## Aşama 3 — web/mobil eşitlik

Düzeltme **sunucuda** olduğu için her iki yüzey de aynı anda düzeldi.
Mobil zaten doğru çalışıyordu; artık mobilde de bloğun içinden değil
serbest metinle oluşturulsa bile kayıt tutarlı olur.

---

# AŞAMA 4 — FİNANSAL İŞLEMLER

## Önce zorunlu ilke: merkezi belge numaralandırma

Brief: *"Belge numaralandırma MERKEZİ olsun, her modül kendi numarasını
üretmesin."* Sekiz sayfanın hepsi buna dayandığı için ilk iş buydu.

**Bugünkü durum neydi:** `finansal_hareket.belge_no` **serbest metindi**.
Aynı numara iki belgede olabiliyordu, boş bırakılabiliyordu, her modül
kendi biçimini uyduruyordu.

**Göç 0058** — `belge_sayaci (tenant_id, tip, yil, son_no)` +
`finansal_hareket (tenant_id, belge_no)` üzerinde kısmi benzersizlik
indeksi. **`app/belge_no.py`** tek üretim yeri; biçim `TAH-2026-000123`.

Üç karar:

- **Postgres `SEQUENCE` kullanılamazdı.** (a) Tenant başına ayrı sayması
  gerek — global dizi A tesisinin fiş numarasını B'nin işlem hacmine
  bağlardı; tenant başına sequence açmak ise her yeni tesiste DDL demek.
  (b) Yılbaşında sıfırlanması gerek (TR'de fiş serileri yıllık) ve
  `SEQUENCE`i elle sıfırlamak unutulabilir bir bakım işi. (c) **`SEQUENCE`
  işlem dışıdır** — geri alınan bir işlemde tüketilen numara kaybolur ve
  muhasebe serisinde **boşluk** kalır; denetimde açıklanması gereken bir
  şeydir.
- **Kilit yok:** artırma tek `INSERT ... ON CONFLICT DO UPDATE ...
  RETURNING`. "Önce SELECT sonra UPDATE" iki eşzamanlı fişe aynı numarayı
  verebilirdi ve bu ancak aylar sonra bir mutabakatta fark edilirdi.
- **Altı hane sıfırla doldurulur:** metin sıralaması sayı sıralamasıyla
  aynı olsun diye. `TAH-2026-9` ile `TAH-2026-10` alfabetik sırada ters
  düşerdi ve ekstreler yanlış sırada çıkardı.

**Özel durumlar:**
- **Virmanın iki satırı belgesiz.** İkisi tek işlemdir; ayrı numara
  ekstrede iki bağımsız fiş gibi gösterirdi, aynı numara benzersizlik
  kısıtıyla çatışırdı. Eşleştirme `virman_grup_id` üzerinden.
- **Toplu tahsilatta her satır kendi numarasını alır** — N ayrı makbuzdur;
  fiş başına tek numara, sakinin kendi makbuzunu bulmasını imkânsız
  kılardı.
- **İptal kendi serisini kullanır** (`IPT-`); iptal edilen belgeyle aynı
  numarayı taşısaydı "hangisi geçerli" sorusu numaradan cevaplanamazdı.
- **Geçmiş tarihli fiş o yılın serisine düşer** (`tarih` verilirse onun
  yılı) — yoksa 2026 defterine 2027 numaralı bir belge düşerdi.

## Sekiz sayfa — ortak kabuk, ince sayfalar

`components/finans/hareket-sayfasi.tsx` (liste + araç çubuğu + dışa
aktarma + iptal) ve `satir-tablosu.tsx` (satır tabanlı giriş) ortak;
sayfalar yalnızca kendi tipini, sütunlarını ve formunu veriyor.

| § | Sayfa | Rota |
|---|---|---|
| 4.1 | Borçlandırmalar (+ toplu, önizlemeli) | `/finans/borclandirmalar` |
| 4.2 | Tahsilatlar (+ toplu satır tablosu) | `/finans/tahsilatlar` |
| 4.3 | Giderler | `/finans/giderler` |
| 4.4 | Gelirler | `/finans/gelirler` |
| 4.5 | Hesaplar arası virman | `/finans/virman` |
| 4.6 | Ödeme iadesi | `/finans/iade` |
| 4.7 | Açılış fişleri | `/finans/acilis` |
| 4.8 | İcra dosyaları (oluşturma genişletildi) | `/icra` |

`/finans` **kaldı**: bütün hareketlerin tek defteri hâlâ anlamlı ve eski
yer imleri kırılmadı. Menüdeki `?tip=` süzgeçleri gerçek sayfalara döndü.

**Denetçi bu sekizini görmüyor.** Hepsi "+ Yeni" düğmesi taşıyan yazma
ekranı; ona basamayacağı düğmelerle dolu bir sayfa göstermek olurdu.
Denetçinin mali okuma yolu (`/raporlar`, `/icra`) açık kaldı — ve bu
testle **dengelendi**: "denetçi görmez" tek başına ölçülseydi, ona hiçbir
mali ekran vermemek de geçerdi.

**"Sil" düğmesi hiçbir sayfada yok.** Brief'in ilkesi: *"Finansal kayıtlar
SİLİNMEZ; iptal/ters kayıt mekanizması kullanılır."* Uç zaten öyle (göç
0047 DELETE yetkisini geri aldı). Çizilen şey "İptal et" ve onay metni ne
olacağını söylüyor: kayıt kalır, deftere ters bir satır eklenir. Ters
kaydın kendisinde düğme çizilmiyor — uç 422 döner, yapamayacağı bir eylemi
göstermek olurdu.

## Brief'ten bilinçli dört sapma

**1. İade modalı "hangi tahsilat" soruyor** (Kişi + Bağımsız Bölüm + Kasa
yerine). Uç `hareket_id` alıyor ve kişiyi/daireyi/kasayı **orijinal
hareketten türetiyor**. Doğrusu bu: iade "birine para vermek" değil
"alınmış bir parayı geri vermek"tir. Elle kasa seçtirmek, iadeyi orijinal
tahsilattan bağımsız bir hareket yapar; "hangi tahsilat iade edildi"
sorusu ancak açıklama metnine bakılarak cevaplanabilir ve yanlış kasadan
iade iki kasayı birden bozardı. Brief'in istediği alanlar **ekranda
görünüyor** — yalnızca hangisinin yazılabilir, hangisinin türetilmiş
olduğu değişti.

**2. Borçlandırmada "Kişi" yerine "Bağımsız Bölüm".** Tahakkuk daireye
yazılır (`unit_id`), hedef kişi daireden türer. İkisini ayrı sordurmak,
daireyle çelişen bir kişi seçimine kapı açardı. **"Dönem" alanı da
sorulmuyor** — uç `YYYY-MM` istiyor ama brief'in modalinde yok; girilen
tarihin ayından türetiliyor (bir Mart tahakkuku Mart dönemine yazılır).

**3. Virman/Açılışta "Hesap Tipi" = kasa.** Sistemde ayrı bir "hesap tipi"
varlığı yok; uydurmak, kullanıcıya doldurulamayan bir alan göstermek
olurdu.

**4. Tahsilat yöntemi tek seçenekli ve pasif.** Brief "varsayılan
Otomatik" diyor; uç bugün bir `yontem` alanı **taşımıyor**. Seçenek
uydurup sunucuya göndermemek sessiz bir yalan olurdu — alan görünür ama
kilitli, eksik burada yazılı. Uç genişletildiğinde tek satırla açılır.

## Aşama 4 — bilinçli eksikler

- **Borçlandırmada "İptal et" yok.** Uç `DELETE /dues/assessments/{id}`
  taşımıyor, yani bugün bir tahakkuku düzeltme yolu **yok**. Olmayan bir
  yolu düğme olarak çizmek, kullanıcıyı çalışmayacak bir eyleme davet
  etmek olurdu.
- **"Düzenle" hiçbir finans sayfasında yok.** Uç `PATCH
  /finans/hareketler/{id}` taşımıyor ve taşımamalı: bir muhasebe kaydını
  yerinde değiştirmek, geçmiş raporları geriye dönük değiştirirdi.
  Düzeltme yolu iptal + yeniden giriş.
- **Makbuz kutusu** işaretlenince makbuz dökümü raporunu açıyor; ayrı bir
  "makbuz" varlığı uydurulmadı — `makbuz_dokumu` raporu zaten o çıktı.

## Aşama 4 — web/mobil eşitlik

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| Merkezi belge no | **otomatik eşit** | Sunucuda; mobilin yazdığı her hareket de aynı seriden numara alıyor. Mobil tarafta kod değişikliği gerekmedi. |
| 4.1–4.7 finans ekranları | **hayır** | Bunlar masa başı muhasebe işleri: çok satırlı giriş, Excel/PDF çıktısı, dönem seçimi. Telefonda satır tablosu doldurmak, aracı yanlış işe koşmaktır. Mobilin mali ihtiyacı (aidatım, borç görüntüleme) zaten karşılanıyor. |
| 4.8 icra | **hayır** | Hukuki dosya takibi de masa başı işi. |
| `finansal_hareket.durum` | **kısmi fark** | Alan mobil listelerde çizilmiyor. Küçük ekran işi; uç hazır. |
---

# AŞAMA 5 — Rapor motoru

## Görev bölümü: sunucu "hangi alanlar", istemci "nasıl çizilir"

Brief "ortak bir RaporModalı yaz; her rapor kendi alan tanımını versin"
diyor. Kritik soru şu: **alan tanımı nerede durur?**

Katalog artık her rapor için `alanlar: string[]` döndürüyor — o raporun
gerçekten anlamlandırdığı `RaporParametre` alanları. İstemci o adları
`lib/rapor-alanlari.ts` sözlüğünden çözüp çiziyor.

Alternatifi — listeyi istemcide tutmak — ölçülebilir bir kusur sınıfı
açardı: bir rapora yeni süzgeç eklendiğinde iki yer ayrışır, modal alanı
çizer, kullanıcı doldurur, sunucu yok sayar. **Ekranda hata çıkmaz,
log'a satır düşmez**; kusur ancak çıktı yanlış geldiğinde fark edilir.
`tests/rapor-alanlari.test.ts` backend kaynağını okuyup her alan adının
istemci karşılığı olduğunu doğruluyor.

Tersi de doğru: "nasıl çizilir" sunucuda dursaydı, backend bir form
kütüphanesi tarif etmeye başlar ve arayüz değiştiğinde sözleşme
değişmek zorunda kalırdı.

### Bu, eski sayfadaki gerçek bir kusuru kapatıyor

Eski sayfa **sabit dört alan** çiziyordu (başlangıç, bitiş, blok, ad
sütunu). Yani kasa ekstresi **kasa seçmeden**, firma ekstresi **firma
seçmeden** çalışıyordu: rapor üretiliyordu ama **sorulan soru
sorulmuyordu**. Bu bir eksiklik değil, yanlış cevaptı.

## Üç yeni rapor

| Rapor | Kaynak | Karar |
|---|---|---|
| **Notlar** | `varlik_eki` (`tur='not'`) | Ayrı bir "not" varlığı **açılmadı** — notlar zaten orada duruyor. Yeni tablo, aynı veriyi iki yerde tutmak olurdu. |
| **Firma Ekstresi** | `finansal_hareket` + firma | Kasa ekstresiyle aynı şekil, farklı eksen: biri paranın **nerede durduğunu**, öteki **kiminle çalışıldığını** anlatır. |
| **Hesap Ekstresi** | borç + tahsilat, tek zaman çizgisi | **Yürüyen bakiye** taşır. Borç ve tahsilatı iki ayrı tabloda göstermek, kullanıcıyı bakiyeyi kafadan hesaplamaya bırakırdı — ekstrenin varlık sebebi tam olarak o sorudur. |

**Yön işareti tutara gömülü:** ekstrede "çıkış" yazıp tutarı artı
göstermek, sütunun toplamını gözle almayı imkânsız kılardı. Gider
negatif, tahsilat pozitif.

**Brief'in listesinde olmayan iki rapor korundu** (Tahsilat Performansı,
Denetim Raporu) — genel kısıt "mevcut işlev kaybolmayacak" diyor.
Dökümler kategorisine kondular.

## Kuyruk — göç 0059 + Celery

Brief: *"büyük raporlar kuyruğa girsin ve hazır olunca indirilebilsin
(senkron üretim tarayıcıyı kilitler)"*.

Ölçülebilir sorun: `borc_alacak` ve `detayli_borc` **tüm defteri tarar**.
500 daireli bir sitede bu, her dairenin bütün tahakkuk/tahsilat geçmişini
okuyup gecikme tazminatını tek tek hesaplamak demek. İstek yolunda
yapıldığında tarayıcı yanıt gelene kadar bekler, ters vekil zaman aşımı
sınırına takılabilir ve **zaman aşımında iş yarım kalır** — kullanıcı
neyin olduğunu bilmez, yeniden dener, sunucu aynı işi bir kez daha yapar.

### Dört karar, dört gerekçe

1. **Ayrı uç, "bazen kuyruğa alan tek uç" değil.** Senkron uç bir
   **dosya**, kuyruk ucu bir **iş kimliği** döner (202). Aynı ucun bazen
   dosya bazen JSON döndürmesi, ayrımı unutan bir istemcinin JSON'u dosya
   diye indirmesine yol açardı.
2. **Hangi raporun ağır olduğunu sunucu söyler** (`agir` bayrağı). Ölçü
   istemcide olsaydı, yeni bir ağır rapor eklendiğinde arayüz onu senkron
   çağırmaya devam ederdi — ve bunu kimse fark etmezdi.
3. **Üretim mantığı `_uret` ile aynı fonksiyondan geçiyor.** Kuyruk ayrı
   bir hesaplama yolu değil, aynı hesaplamanın başka bir zamanlaması.
   İkinci bir üretici yazsaydık, senkron ve kuyruk çıktıları bir gün
   ayrışırdı.
4. **"Göster" ağır raporda da senkron.** Kullanıcı ekranda görmek
   istiyorsa zaten beklemeye razıdır; tabloyu kuyruğa almak, görmek
   istediği şeyi indirilecek bir dosyaya çevirmek olurdu.

### Veritabanı kısıtı: "hazır ama dosyasız" iş olamaz

`CONSTRAINT ck_rapor_isi_hazir CHECK (durum <> 'hazir' OR dosya_key IS
NOT NULL)`. Bu hâl, arayüzde tıklanan ve hiçbir şey indirmeyen bir bağlantı
demektir — kullanıcının sebebini anlayamayacağı bir sessizlik. Kısıt
uygulamada değil **veritabanında**, çünkü işi yazan iki yol var (uç ve
worker) ve ikisinde de aynı kuralı hatırlamak gerekirdi.

**Dosya MinIO'da, veritabanında değil:** bir Excel megabaytlarca olabilir
ve `bytea` sütunu her yedeği, her replikasyonu ve her `SELECT *`i şişirir.
Tabloda yalnızca anahtar durur; indirme kısa ömürlü presigned URL ile.

**Görünürlük kapısı `user_id`:** rapor çıktısı kişi adları ve site finansı
taşır; aynı tesisteki başka bir yöneticinin başkasının istediği dosyayı
görmesi için bir sebep yok — ve bu sızıntı sessizdir. Başkasının işi için
**404** döner, 403 değil: 403 "senin değil" demek olurdu ve o işin **var
olduğunu** doğrulardı.

**Hata yutulmaz, kaydedilir:** görev çökerse Celery yeniden dener ve
kullanıcı sonsuza kadar "üretiliyor" görür. Durum `hata`ya çekilip kısa
bir kimlik satıra yazılıyor; yığın izi log'a ait ve arayüze sızmamalı.

## Denetçi kararı — `contracts/auth.md` güncellendi

`POST /raporlar/{kod}/kuyruk` **gerçekten bir satır yazar**, yani
"denetçi hiçbir mutasyon ucunda yer almaz" ilkesinin karşısına çıkıyor.
Karar: **açık**, ve gerekçesi yazılı istisna listesine eklendi.

Yazdığı şey **kullanıcının kendi isteğinin kaydıdır**: tesis verisinde
hiçbir şey değişmez, kayıt yalnızca "kim ne istedi, hazır mı" sorusunu
yanıtlar ve yalnızca sahibi görür. Kapatmak, denetçiyi büyük raporların
PDF/Excel çıktısından tamamen mahrum bırakırdı — yani denetim görevinin
ana aracından.

## Brief'ten bilinçli sapma: "beş ayrı alan"

Brief Detaylı Borç için *"Borçlandırma Türü 1* … Türü 5"* diyor. Bu bir
**modal yerleşimidir**; veri bir **listedir**. API `gelir_gider_tanim_idler:
list[UUID] (max 5)` alıyor, modal çoklu seçim çiziyor. Beş ayrı alan adı
açsaydık, altıncısı istendiğinde **sözleşme** değişmek zorunda kalırdı.

## Değiştirilen bir metin: "Excel indir" → "Excel"

Modal düğmesi ağır raporda **indirmiyor, kuyruğa alıyor**. Eski etiket
artık tutmayan bir söz veriyordu; brief'in düğme listesi de zaten
`[İptal] [Göster] [PDF] [Excel]`.

## Değiştirilen bir erişilebilirlik ölçümü

Kart eskiden `aria-pressed` taşıyordu (P160), çünkü seçim **sayfa içinde**
kalıyordu. Artık kart bir **diyalog** açıyor ve `aria-pressed` ekran
okuyucuya "açık/kapalı bir anahtar" diye yanlış bilgi verirdi. Yerine
`aria-haspopup="dialog"` kondu ve test daha güçlü bir şey ölçüyor:
**diyaloğun erişilebilir adı raporun adıdır**, yani ekran okuyucu hangi
raporu yapılandırdığını kartın durumundan değil açılan pencerenin
kendisinden duyar.

## Aşama 5 — yeni uçlar ve göç

| Uç | Rol | Not |
|---|---|---|
| `POST /raporlar/{kod}/kuyruk?bicim=excel\|pdf` | admin, yönetici, denetçi | 202 + `RaporIs`. `bicim=tablo` **422**. |
| `GET /raporlar/isler` | admin, yönetici, denetçi | Yalnız kendi işleri, yeniden eskiye. |
| `GET /raporlar/isler/{id}/indir` | admin, yönetici, denetçi | Presigned URL. Hazır değilse **409**, başkasınınsa **404**. |

**Göç 0059** — `rapor_isi` + `rapor_is_durum` enum + RLS + `ck_rapor_isi_hazir`
+ `ix_rapor_isi_sahip`. `created_at` indeksli: temizlik tarihe göre tarar.
Bu göç **temizlik işi kurmaz** — retention zaten gecelik çalışıyor
(`app/retention.py`) ve kural oraya eklenmelidir; burada yalnızca indeks
hazır bırakıldı.

## Aşama 5 — web/mobil eşitlik

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| Kategorili kart ızgarası | **hayır** | On beş raporluk bir yapılandırma ızgarası masa başı işi. Mobilin rapor ihtiyacı (aidatım, borcum) kendi ekranlarında karşılanıyor. |
| Ortak RaporModalı | **hayır** | Yukarıdakinin parçası. |
| Kuyruk + iş listesi | **kısmi fark, uç hazır** | Uçlar role göre açık; mobil bir gün rapor isterse aynı kuyruğu kullanır. Bugün mobilde rapor üretim ekranı yok, o yüzden ekran yazılmadı. |
| Üç yeni rapor | **otomatik eşit** | Sunucuda; herhangi bir istemci aynı çıktıyı alır. |

---

# AŞAMA 6 — Yönetim başlığı

## 6.1 "Yönetişim" kaldırıldı — ve dörde bölündü

Brief: *"Yönetişim alt başlığı tamamen kaldırılsın."*

Ama o başlığın arkasında **dört ayrı iş** duruyordu: karar defteri,
doküman arşivi, KVKK aydınlatma metni ve gürültü uyarıları. Brief bunlardan
yalnızca ikisini adıyla anıyor (§6.2, §6.3).

Kalan ikisini de sessizce yok etmek genel kısıtla çelişirdi ("mevcut işlev
kaybolmayacak") — ve kayıp **sessiz** olurdu: uçlar durur, veri durur, ama
panelde ulaşılacak hiçbir yol kalmaz. Bu yüzden dördü de kendi menü
satırına çıktı ve `tests/yonetim-bolunmesi.test.ts` bunu kilitliyor.

Zaten "Yönetişim" bir **iş değil bir soyutlamaydı**: kullanıcı menüde
"yönetişim" aramaz, "karar defteri" arar. Tek satırın arkasına dört iş
gizlemek, dördünü de bulunamaz kılıyordu.

**KVKK metni ile `/kvkk` ayrı satırlar:** biri tesisin **yayınladığı**
aydınlatma metni, öteki kullanıcının **kendi** pazarlama tercihi. Aynı
satıra koymak ikisini karıştırmak olurdu.

Bölerken **yetki değişmedi** (dördü de admin+yönetici) — bölme sırasında
yanlışlıkla genişletmek, KVKK metni yayınlama yetkisini başka bir role
açmak olurdu. Test bunu da ölçüyor.

## 6.2 Karar Defteri

Liste + "+ Karar Ekle" modalı (Konu*, No, Tarih, Karar Metni, Başkan,
**birden fazla Üye satırı**).

**Form sayfadan modala taşındı.** Eskiden liste ile form aynı sayfadaydı;
uzun bir karar metni yazarken liste ekrandan kayıyor ve "hangi numaradan
devam ediyorum" sorusu göz denetimine kalıyordu.

**Üyeler artık ad + görev.** Eski hâl tek bir çok-satırlı kutuydu ve
üyenin görevini taşıyamıyordu — oysa sunucu modeli `{ad, gorev}` bekliyor.

### Karar numarası artık zorunlu değil — ve merkezî seriden geliyor

Brief'in alan listesinde yıldız yalnız "Konu"da. Numara boş bırakılırsa
sunucu üretiyor: `KRR-2026-000001`.

**Ayrı bir sayaç yazılmadı.** Aşama 4'ün zorunlu ilkesi *"belge
numaralandırma merkezî olsun, her modül kendi numarasını üretmesin"*.
Karar defteri de bir belge serisidir; kendi sayacını açsaydı yıl dönümü
sıfırlaması ve işlem-geri-alma davranışı iki ayrı yerde yaşar ve biri
günün birinde ötekinden ayrışırdı.

Kullanıcının yazdığı numara **korunuyor**: elinde gerçek bir karar
numarası olan kişi engellenmemeli.

## 6.3 Doküman Yönetimi

Liste + "+ Dosya Yükle" + Excel ikonu; seçim sütunu, Eklenme Tarihi,
Doküman Adı, satır işlemleri, sunucu taraflı sayfalama; sürükle-bırak
yükleme, boyut/tür sınırı ve ilerleme göstergesi.

### Üç gerçek eksik kapandı — üçü de sessizdi

1. **İndirme yoktu.** Dosya yüklenebiliyor ve listelenebiliyordu ama
   **indirilemiyordu** — arşivin tek amacı olan şey yapılamıyordu. Yeni
   uç `GET /dokumanlar/{id}/indir` kısa ömürlü bir bağlantı döner. Obje
   anahtarı değil URL: anahtar istemciye verilseydi hem depo yapısı
   dışarı sızar hem de iznin **süresi** kaybolurdu.
2. **Silme depoda çöp bırakıyordu.** Kayıt siliniyor, MinIO objesi
   kalıyordu. Gerekçe *"yanlışlıkla silinen bir yönetim planı geri
   alınabilsin"*di — ama kayıt gittiği için dosyaya yalnızca **depoya
   elle bağlanan** biri ulaşabiliyordu. Yani pratikte geri alınamıyor,
   buna karşılık obje sonsuza kadar duruyordu.
3. **Yükleme akışı yoktu.** Sayfa yalnızca listeliyordu; dosyanın başka
   bir ekrandan gelmiş olması gerekiyordu.

### Retention: brief'in isteği bilinçli olarak *dar* yorumlandı

Brief *"dosyalar retention politikasına dahil edilsin"* diyor. Bunu
"yönetim dokümanlarını N ay sonra sil" diye okumak **yanlış** olurdu ve
söylemekte fayda var: yönetim planı, bütçe, bilanço ve genel kurul
tutanağı **kişisel veri değil, tesisin kendi arşividir**. KVKK'nın saklama
sınırlaması kişisel veri içindir; site arşivini yaşla silmek, mevzuatın
istemediği ve **geri alınamaz** bir kayıp yaratırdı.

Gerçek eksik başka yerdeydi ve ölçülebilirdi: silinen kaydın **artığı**.
Göç 0060 `silindi_at` ekliyor:

* Silme artık **yumuşak**: kayıt listeden kalkar, obje ve satır bir süre
  daha durur — "yanlışlıkla sildim" penceresi **artık gerçekten var**.
* Gecelik retention süresi dolanların **önce MinIO objesini sonra
  satırını** siler — kargo/talep fotoğrafıyla aynı desen: depo
  erişilemezse satır o gece silinmez, yani obje asla kayıtsız kalmaz.
* Ay değil **gün** (varsayılan 30): bu bir saklama sınırı değil, bir geri
  dönüş penceresi.

Yani dokümanlar retention politikasına **girdi** — ama giren şey arşivin
kendisi değil, silinmiş olanın artığı.

### Excel: ikinci bir yazıcı yazılmadı

Brief bu ekranda bir Excel dışa-aktarım ikonu istiyor. Rapor motorunun
Excel/PDF hattı zaten var; sütun biçimlendirmesi ve site başlığı orada.
Ayrı bir yazıcı, para/tarih biçimlerinin iki yerde yaşaması ve birinde
düzeltilen bir hatanın ötekinde kalması olurdu.

Bunun yerine kataloğa `dokuman_listesi` raporu eklendi (Dökümler). Yan
fayda: liste artık Raporlar ekranından da alınabiliyor. **Silinmişler her
iki çıktıda da yok** — ekranda görünmeyen bir satırın Excel'de görünmesi,
iki çıktının aynı soruya farklı cevap vermesi olurdu.

**Boyut sütunu "sayı" tipinde**, metin değil: `"1,2 MB"` yazsaydık hücre
Excel'de toplanamazdı.

## Aşama 5/6 — kilitlerde iki değişiklik

### `MUTASYON_OLMAYAN_POSTLAR` → `DENETCI_ISTISNALARI`

`POST /raporlar/{kod}/kuyruk` denetçiye açık ve **gerçekten bir satır
yazıyor** (`rapor_isi`). Yapısal test bunu haklı olarak yakaladı: denetçiye
açık GET-dışı her uç, gerekçesi yazılı bir istisna listesinde olmak zorunda.

Eklerken listenin adının **yalan söylediğini** gördüm: içindeki
`PATCH /me/avatar` de bir satırı gerçekten değiştiriyor. Yanlış adlı bir
kilit, bir gün *"ama bu mutasyon değil ki"* denerek genişletilirdi. Ad
`DENETCI_ISTISNALARI` oldu ve gerçek ölçü yazıldı: **"tesisin defterine
yazmıyor."** Denetçinin salt-okurluğu tesisin kayıtları içindir; kişinin
kendi hesabına ait işlem ve kendi isteğinin kaydı o kapsamın dışındadır.
`contracts/auth.md` de güncellendi.

### Rol matrisi kilidi

Üç yeni uç (`/raporlar/{kod}/kuyruk`, `/raporlar/isler`,
`/raporlar/isler/{id}/indir`) ve `GET /dokumanlar/{id}/indir` eklendi;
kilit yeniden üretilip satır satır doğrulandı.

## Ölçüm hatası — dürüstçe

Aşama 5'in 29 dakikalık takım koşumu **3 kırmızı** verdi. Biri gerçekti
(yukarıdaki denetçi istisnası); **ikisi benim ölçüm hatamdı**.

`infra/docker-compose.yml` api servisine `../contracts:/contracts:ro`
**canlı mount** ediyor, ama `backend/` kodunu imaja **gömüyor**. Koşum
sürerken Aşama 6'nın openapi girdilerini yazınca sözleşme yenisini,
çalışan uygulama eskisini gördü: `GET /dokumanlar/{id}/indir` uygulamada
yoktu, 404 döndü ve test bunu *"korumasız uç, her role IZIN"* diye
raporladı — yani sahte bir güvenlik açığı gibi göründü.

Uçta gerçekte `require_role("admin","yonetici")` vardı; imaj yeniden
kurulduğunda matris `IZIN IZIN RED RED RED RED RED` verdi. Ders: takım
koşarken `contracts/` altını düzenleme.

## Aşama 6 — yeni uçlar ve göç

| Uç / değişiklik | Not |
|---|---|
| `GET /dokumanlar/{id}/indir` | **yeni.** Kısa ömürlü presigned URL. Silinmişte 404. |
| `DELETE /dokumanlar/{id}` | **davranış değişti:** yumuşak silme. İkinci silme 404. |
| `GET /dokumanlar` | Silinmişler listede ve `meta.total`da **yok**. |
| `POST /karar-defteri` | `karar_no` artık **opsiyonel**; boşsa `KRR-…` merkezî seriden. |
| `POST /raporlar/dokuman_listesi` | **yeni rapor** (Dökümler kategorisi). |
| **Göç 0060** | `tenant_dokuman.silindi_at` + iki kısmi indeks (canlı liste / süpürme). |
| `app/retention.py` | Silinmiş dokümanların gecelik süpürmesi (önce depo, sonra satır). |

## Aşama 6 — web/mobil eşitlik

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| Karar defteri | **hayır** | Yönetim kurulu kararı yazmak masa başı işi; uzun metin girişi telefonda aracı yanlış işe koşmaktır. Sakinin karar defterini **okuma** ihtiyacı ayrı bir istektir ve brief'te yok. |
| Doküman yönetimi | **hayır (yükleme), açık soru (okuma)** | Yükleme masa başı işi. Sakinin yönetim planına telefondan bakmak istemesi makul bir ihtiyaç ama brief bunu istemiyor ve uç bugün admin+yönetici'ye kapalı — açmak bir **yetki kararıdır**, sessizce alınmamalı. |
| KVKK metni yayınlama | **hayır** | Hukuki metin yayınlama; sürüm mantığı ve geri alınamazlığı masaüstünde kalmalı. |
| Gürültü uyarıları | **kısmi fark, uç hazır** | Uç açık; mobilde ekran yok. Anons "yapıldı" işaretlemesi saha işi olabilir — mobil bir gün isterse aynı uç kullanılır. |
| Merkezî karar numarası | **otomatik eşit** | Sunucuda. |
| Yumuşak silme + süpürme | **otomatik eşit** | Sunucuda. |

---

## Değişen dosyalar (Aşama 5)

**Sözleşme + göç**
- `contracts/openapi.yaml` — 3 yeni yol (`/raporlar/{kod}/kuyruk`,
  `/raporlar/isler`, `/raporlar/isler/{id}/indir`), `RaporIs` şeması,
  genişletilmiş `RaporKatalogOgesi`/`RaporKatalog`, ~19 yeni
  `RaporParametre` alanı
- `contracts/db/migrations/versions/0059_rapor_isi.py` — `rapor_isi` +
  `rapor_is_durum` enum + RLS + `ck_rapor_isi_hazir` + `ix_rapor_isi_sahip`
- `contracts/auth.md` — denetçi istisna listesi (kuyruk ucu, gerekçesiyle)

**Backend**
- `app/routers/rapor_motoru.py` — `KatalogKaydi` (kategori/alanlar/ağır),
  15 raporluk katalog, 3 yeni rapor dalı, `_param()`, 3 kuyruk ucu
- `app/rapor_kuyruk.py` *(yeni)* — `isi_uret()`; owner ile tenant çözümü,
  sonra `tenant_session`; `_uret` ile **aynı** üretim
- `app/tasks.py` — `rapor.uret` Celery görevi (`max_retries=2`)
- `app/models.py` — `RaporIsi` + `RAPOR_IS_DURUM`
- `app/schemas.py` — `RaporIsOut`, genişletilmiş katalog/parametre
- `app/raporlar.py` — `RaporParam`e karşılık gelen yeni alanlar
- `app/storage.py` — `sunucudan_yukle()`
- `app/hata_metinleri.py` — `rapor_isi_bulunamadi`, `rapor_isi_hazir_degil`
  (7 dil)

**Web**
- `app/(protected)/raporlar/page.tsx` — kategorili kart ızgarası + iş listesi
- `components/rapor/rapor-modali.tsx` *(yeni)* — ortak modal, 4 düğme
- `lib/rapor-alanlari.ts` *(yeni)* — alan sözlüğü (nasıl çizilir)
- `app/api/panel/rapor/{[kod]/kuyruk,isler,isler/[is_id]/indir}/route.ts`
  *(yeni)*
- 7 dilde ~50 anahtar; `raporExcel`/`raporPdf` metinleri düzeltildi

**Test**
- `tests/rapor-alanlari.test.ts`, `tests/rapor-motoru.dom.test.ts` *(yeni)*
- `backend/tests/test_rapor_kuyruk.py` *(yeni)*
- `tests/rapor.dom.test.ts`, `tests/yz-tasima-rapor-icra.dom.test.ts` —
  yeni sayfa şekline göre güncellendi (`aria-pressed` ölçümü daha güçlü
  bir ölçümle değişti)
- `tests/i18n.test.ts` — "Excel" ürün adı istisnası

## Değişen dosyalar (Aşama 6)

**Sözleşme + göç**
- `contracts/openapi.yaml` — `GET /dokumanlar/{id}/indir` *(yeni)*,
  `DELETE /dokumanlar/{id}` yumuşak silmeye göre yeniden yazıldı,
  `KararDefteriCreate.karar_no` artık opsiyonel
- `contracts/db/migrations/versions/0060_dokuman_saklama.py` —
  `silindi_at` + iki kısmi indeks
- `contracts/auth.md` — `DENETCI_ISTISNALARI` ad değişikliği ve gerçek ölçü

**Backend**
- `app/routers/yonetisim.py` — yumuşak silme, indirme ucu, listede
  `silindi_at IS NULL`, karar numarası merkezî seriden
- `app/belge_no.py` — `karar` → `KRR` ön eki
- `app/models.py` — `TenantDokuman.silindi_at`
- `app/schemas.py` — `KararDefteriCreate.karar_no` opsiyonel
- `app/retention.py` — silinmiş dokümanların gecelik süpürmesi
- `app/config.py` — `retention_dokuman_grace_days` (30)
- `app/routers/rapor_motoru.py` — `dokuman_listesi` raporu
- `app/hata_metinleri.py` — `dokuman_bulunamadi` (7 dil)

**Web**
- `app/(protected)/karar-defteri/page.tsx` *(yeni)*
- `app/(protected)/dokumanlar/page.tsx` *(yeni)*
- `app/(protected)/kvkk-metinler/page.tsx` *(yeni)*
- `app/(protected)/gurultu-uyarilari/page.tsx` *(yeni)*
- `app/(protected)/yonetisim/page.tsx` **silindi**
- `app/api/panel/dokumanlar/{route.ts,[id]/route.ts,[id]/indir/route.ts}`
  *(yeni)* — üçü birden gerekli: düz segment dinamiği yener, aksi hâlde
  liste ve silme sessizce 404 verirdi
- `lib/menu.ts` (+`doc` ikonu), `lib/yuzey.ts`, `middleware.ts`,
  `components/AppShell.tsx`
- 7 dilde ~50 anahtar

**Test**
- `tests/yonetim-bolunmesi.test.ts` *(yeni)* — bölünme + yetkinin
  genişlemediği
- `backend/tests/test_dokuman_karar.py` *(yeni)*
- `backend/tests/test_retention.py` — doküman süpürme testi (iki yönlü)
- `backend/tests/test_denetci_salt_okuma.py` — sabit yeniden adlandırıldı
- `tests/rol-menusu.test.ts`, `tests/yz-asama10-tarama.dom.test.ts` —
  dört yeni rota

## Değişen dosyalar (Aşama 1)

**Sözleşme + göç**
- `contracts/openapi.yaml` — 5 yeni yol, 4 yeni şema, `MeProfileOut.avatar_url`
- `contracts/db/migrations/versions/0055_bildirim_tercihleri.py`

**Backend**
- `app/models.py` — 3 kolon
- `app/schemas.py` — `BildirimTercihleri`, `BildirimTercihUpdate`,
  `CihazOut`, `HesapEtkinligiOut`, `MeContactUpdate`, `MeProfileOut.avatar_url`
- `app/routers/me.py` — 6 yeni uç + `_profile_out`
- `app/audit.py` — `DEVICE_REMOVE`, `NOTIFICATION_PREFS_UPDATE`
- `tests/test_me_hesap_ayarlari.py` (yeni), `tests/test_denetci_salt_okuma.py`

**Web**
- `lib/menu.ts` — grup yeniden düzeni, `GRUP_IKONU`, `bagimsiz`,
  `KURULUM_OGESI`, `kurulumGorunur`
- `components/AppShell.tsx` — ikon kuralı, kapalı varsayılan, alt çubuk,
  kullanıcı menüsü bağlantısı
- `components/KullaniciMenusu.tsx` (yeni), `components/Avatar.tsx` (yeni)
- `lib/profil-bolumleri.ts` (yeni)
- `app/(protected)/profil/page.tsx` — beş bölümlü yeniden yazım
- `app/(protected)/tanimlar/page.tsx` — Ayarlar sekmesi adrese taşındı
- `app/api/me/{cihazlar,cihazlar/[id],cihazlar/tumunden-cik,etkinlik,bildirim-tercihleri,avatar,hesap-sil}/route.ts`
- `lib/i18n/sozluk/*.ts` — 7 dil: 5 anahtar silindi, 40 anahtar eklendi,
  `kabukGrupFinans` → "Finansal İşlemler"
- Testler: `menu-gruplari`, `menu-katlama.dom`, `kabuk-katlanma.dom`,
  `kabuk-rol-menusu.dom`, `duzen-rol.dom`, `profil.dom`, `sayfa-aramasi`,
  `modal-tasima`

---

## Web / mobil eşitlik değerlendirmesi (Aşama 1)

Tam tablo `docs/web-mobil-esitlik.md` sonuna eklendi. Özet:

- **§1.1–§1.6 ve §1.8 (menü ağacı, alt bar): mobilde gerekmiyor.** Mobilde
  sol menü yok; gezinme alt sekme + "Tüm Modüller" (P160). Karşılığı
  olmayan bir yapı için "fark" da oluşmuyor.
- **§1.7 avatar ve hesap silme: eşitlik bu turda WEB tarafında kapandı.**
  İkisi de mobilde zaten vardı (P3, P112); eksik olan panel'di.
- **Üç açık fark bırakıldı ve üçü de aynı ekrana düşüyor — mobil profil:**
  ad soyad düzenleme, güvenilen cihazlar listesi, bildirim ayarları.
  Uçların hepsi açıldı ve rol bağımsız; kalan iş yalnız ekran işi.
  **Bildirim ayarları öncelikli:** mobil bildirim anahtarını web'den
  kapatmak dolaylı bir yol; kullanıcı bildirimi aldığı cihazda kapatmak
  ister.

---

## Test çıktısı (Aşama 1)

- **Web:** `125 dosya / 1195 test — hepsi yeşil.` `tsc --noEmit` temiz,
  `next lint` temiz, `next build` geçti.
- **Backend tam takım (Aşama 4 sonunda, nihai): `1741 geçti, 0 düştü`.**
- Aşama 1 ilk koşumunda `1703 geçti, 3 düştü`; Aşama 2 sonunda
  `1720 geçti, 2 düştü`. Beşinin de nedeni ve düzeltmesi aşağıda —
  dördü bu turun kusuru, biri **önceden main'de kırıktı**.
- **Yetki matrisi kilidi güncellendi** (`backend/tests/yetki/rol-matrisi.txt`).

### Düşen üç test ve nedenleri

**1. `test_hata_i18n::test_kaynakta_ham_cumle_kalmadi` — bu turun kusuru.**
`DELETE /me/cihazlar/{id}` 404'ünde `cihaz_bulunamadi` kimliğini
kullanıyordum ama katalogda karşılığı yoktu; tarama haklı olarak
"katalogsuz hata metni" dedi. Yedi dile eklendi. Metin bilinçli olarak
*"bu cihaz senin değil"* demiyor: öyle demek, o id'nin **var olduğunu**
doğrulamak olurdu.

**2. `test_sayfalama_siralamasi::test_kararsiz_sayfalama_ARTMIYOR` — bu
turun kusuru ve gerçek bir hata yakaladı.** `GET /me/etkinlik` yalnız
`ts DESC` ile sıralıyordu. Denetim satırları toplu yazıldığında `ts`
milisaniyesine kadar aynı olabiliyor (`audit_user` aynı işlemde birden
fazla satır yazar); `limit` ile birleşince bir satır **her iki sayfada
da** ya da hiçbirinde görünebilirdi. `id` kırıcı eklendi. Aynı düzeltme
`/me/cihazlar`a da uygulandı (o sayfalamıyor ama liste her tazelemede yer
değiştirirdi).

**3. `test_users_avatar::test_me_avatar_rbac_...` (Aşama 2 koşumunda) —
bu turun kusuru.** `test_avatar.py`nin kardeşi; **aynı kuralı ikinci bir
dosyada** ölçüyordu ve Aşama 1'de gözümden kaçmıştı. Adı gerçeği
söyleyecek şekilde değişti; saha personelinin hâlâ 403 aldığı satır
korundu — genişletilen yetkinin bilinçli sınırını kilitleyen ölçüm o.

**4. `test_yetki_kapsam::test_rol_matrisi_kilidi` (Aşama 2 ve 4
koşumlarında) — beklenen.** Yeni uçlar matrisi değiştirdi; kilit her
seferinde güncellendi ve diff gözle doğrulandı.

**5. `test_yonetici::test_yonetici_aidat_raporu_okur_yazamaz` — ÖNCEDEN
KIRIKTI, bu turun değil.** Commit `3a71736f` (bir önceki P167 commit'i)
`POST /dues/assessments`i yöneticiye **kasıtlı olarak** açtı ve
`test_dues.py`, `rol-matrisi.txt`, `auth.md`, `openapi.yaml`ı güncelledi
— ama bu dosyayı atladı. Test, ürünün kasıtlı davranışına karşı kırmızı
duruyordu. Düzeltildi ve adı gerçeği söyleyecek şekilde değişti:
`..._okur_TAHAKKUK_YAZAR_TAHSILAT_YAZAMAZ`. **Tahsilatın 403 kaldığı
satır korundu** — o satır, yetkiyi genişleten commit'in bilinçli
sınırını kilitleyen tek ölçüm.

---

## Test çıktısı (Aşama 5 ve 6)

- **Web:** `131 dosya / 1269 test — hepsi yeşil.` `tsc --noEmit` temiz,
  `next build` geçti.
- **Backend tam takım: `1774 geçti, 0 düştü`** (1 atlandı — `world`
  fixture'ında daireye bağlı sakin yok; bu turdan bağımsız, önceden
  var olan bir atlama). Süre 29 dk 10 sn.
- **Yetki matrisi kilidi** dört yeni uç için yenilendi ve diff satır satır
  doğrulandı:
  `GET /dokumanlar/{id}/indir` → admin+yönetici;
  `POST /raporlar/{kod}/kuyruk`, `GET /raporlar/isler`,
  `GET /raporlar/isler/{id}/indir` → admin+yönetici+denetçi.

### Yol boyunca düşen testler ve nedenleri

**1. `test_denetci_salt_okuma::test_denetci_hicbir_mutasyon_ucunda_YOK` —
gerçek ve haklı.** `POST /raporlar/{kod}/kuyruk` denetçiye açık ve
gerçekten bir satır yazıyor. Yapısal kural bunu gerekçeli bir istisna
listesinde görmek istiyor. Eklerken listenin **adının yalan söylediği**
görüldü (ayrıntı yukarıda) ve ad `DENETCI_ISTISNALARI` oldu.

**2–3. `test_yetki_kapsam` iki testi — ölçüm hatası, kod hatası değil.**
Ayrıntı "Ölçüm hatası — dürüstçe" başlığında: koşum sürerken
`contracts/openapi.yaml` düzenlendi, sözleşme yenisini uygulama eskisini
gördü. İmaj yeniden kurulunca ikisi de yeşile döndü.

**4. `tests/middleware.test.ts` — bu turun kusuru ve gerçek bir açık
yakaladı.** Dört yeni rota `middleware.ts` matcher'ına eklenmemişti;
matcher kapsamayınca o rotalar **auth kapısını atlardı**. Test iki yönlü
olduğu için hem eksik girişi hem de kaldırılan `/yonetisim` girişini
gösterdi.

**5. `tests/erisilebilir-etiket.test.ts` — bu turun kusuru.** Doküman
yükleme ekranındaki gizli `<input type="file">` adsızdı. `hidden` olması
görünmezliği sağlar ama girdi hâlâ erişilebilirlik ağacında; ekran
okuyucu adsız bir dosya denetimi okurdu. `aria-label` eklendi.

**6. `tests/sabit-metin.test.ts` ve `tests/i18n.test.ts` — depo
kuralları.** Üçlüde dizge yazılmıştı (rozet kimliği, girdi tipi, sözlük
anahtarı — hiçbiri kullanıcı metni değil, sabite çıkarıldı) ve "Excel"
yedi dilde aynı olduğu için TR kopyası sanıldı; ürün adı olarak istisna
listesine eklendi (kardeşi "PDF" zaten kısaltma olduğu için geçiyordu).

---

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 1)

1. **Giriş sonrası ilk ekran.** Sol menü artık kısa: en üstte ikonlu
   **Özet** satırı, altında **kapalı** altı ana başlık (Güvenlik · Tesis ·
   Finansal İşlemler · İletişim · Tanımlar · Yönetim), her biri ikonlu.
   En altta tam genişlikte **Kurulum sihirbazı**, onun altında yan yana
   **Tema** ve **Çıkış**.
2. **Bir başlığa tıklayın.** Açılır; alt satırlar **ikonsuz ve girintili**.
   Sekmeyi kapatıp geri gelin — açık bıraktığınız başlık açık kalır.
3. **Finansal İşlemler'i açın.** Aidat, Finansal hareketler, Tahsilatlar,
   Gelirler, Giderler, Virman, İade, Açılış fişleri, **İcra dosyaları**,
   Sayaç okuma, Raporlar. İcra artık ayrı bir üst sekme değil.
4. **İletişim'i açın.** "Mesajlar / SMS gönderimi / E-posta gönderimi"
   üçlüsü yerine tek satır: **SMS/E-Posta Yönetimi**.
5. **Tanımlar'ı açın.** Bloklar · İçe aktarım · Kasalar · Gelir-gider
   grupları · Gelir-gider kalemleri · Firmalar · Görev kategorileri ·
   Personel · Araçlar · Sayaçlar · Bölüm sayaçları · Daire tipleri ·
   Daire grupları · Ayarlar. Her biri sayfayı **doğru sekmede** açar.
6. **Sağ üst köşe.** Dil seçicinin sağında avatar + tesis adı + kullanıcı
   adı. Fotoğrafınız yoksa baş harfleriniz dairesel zeminde. Tıklayın:
   altı satırlık menü; "Hesabımı sil" kırmızı.
7. **Hesap bilgileri.** Sol iç menülü profil sayfası. Fotoğraf yükleyin —
   anında kaydedilir ve sağ üstteki avatar değişir. E-posta alanı
   **kilitli** ve nedeni altında yazıyor. Ad soyad artık düzenlenebilir.
8. **Güvenlik ve giriş.** Giriş yöntemleri + **güvenilen cihazlar**
   (platform, son etkinlik, "Kaldır", "Tüm cihazlardan çık") + **son 20
   hesap etkinliği** ("Detayları gör" ile açılır).
9. **Bildirim ayarları.** Üç anahtar; çevirince anında kaydedilir.
   Altındaki cümle bunların pazarlama izinleri **olmadığını** söylüyor.
10. **Şifre değiştir.** Üç alanda da göz ikonu.
11. **Menüyü daraltın (logo yanındaki ok).** 68 px'lik şeritte ikonlar
    kalır; Kurulum sihirbazı ikonu da orada durur.

---

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 2: Özet)

1. **Özet sekmesi.** En üstte **altı kısayol widget'ı**. "Paneli düzenle"ye
   basın: widget'lar sürüklenebilir hâle gelir, göz ikonuyla bölüm
   gizlenir, "Varsayılana dön" her şeyi geri alır. Çıkın ve **başka bir
   tarayıcıdan aynı kullanıcıyla girin** — düzeniniz orada (tercih
   kullanıcı başına sunucuda).
2. **Finansal özet.** Altı kart: Borçlandırılan · Tahsil Edilen ·
   Borçlarım · Alacaklarım · **Onay Bekleyen Hareketler** · Ödenmiş
   Faturalar. Rakamlar **doğrudan** yazılıyor — sayaç animasyonu yok
   (brief'in açık isteği).
3. **Kasalar paneli** ayrı bir kart; altında **Genel Toplam** ve sağ üstte
   iki ikon: yeşil tablo (Excel), kırmızı belge (PDF). Tıklayın, dosya
   iner.
4. **Takvim.** Gün / Hafta / Ay düğmeleri, ok tuşlarıyla gezinme, bugün
   vurgulu, sağ üstte tam ekran. İçini besleyen altı kaynak: yaklaşan
   etkinlikler, devriye planları, aidat son ödeme günleri, görev
   termini, rezervasyonlar ve **sizin eklediğiniz hatırlatmalar**.
5. **Hatırlatma ekleyin.** Başlık, tarih-saat, açıklama, renk/kategori ve
   tekrar (yok / günlük / haftalık / aylık). "Her ayın 31'i" seçip Şubat'a
   gidin: hatırlatma **ayın son gününe** düşer — kaybolmaz, Mart'a da
   kaymaz.
6. **Bir olaya tıklayın.** Detay penceresi açılır; "Kayda git" sizi ilgili
   ekrana götürür.
7. **Sağ üstte 3D site maketi.** Harita bu sayfadan **tamamen kaldırıldı**.

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 3: toplu blok hatası)

1. **Tanımlar → Bloklar.** Mevcut blok sayısını not edin.
2. **Daireler → Toplu daire ekle.** Blok adına daha önce **hiç
   kullanılmamış** bir ad yazın (örn. "F Blok"), 1–10 daire oluşturun.
3. **Bloklar'a dönün.** "F Blok" artık **listede** — düzenlenebilir ve
   silinebilir. Eskiden bu kayıt "kayıtsız (yalnızca dairede)" olarak
   görünüyor ve hiçbir şey yapılamıyordu.
4. **Onarım göçünün sonucu:** göç 0057 uygulandığı için **eskiden kalan**
   kayıtsız bloklar da listede. Göç yalnızca `INSERT` yapar, hiçbir
   daireye dokunmaz — veri kaybı riski yoktur, bu yüzden sorulmadan
   yazıldı.

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 4: Finansal İşlemler)

1. **Finansal İşlemler'i açın.** Sekiz ayrı sayfa: Borçlandırmalar ·
   Tahsilatlar · Giderlerim · Gelirlerim · Virman · Ödeme İadesi ·
   Açılış Fişleri · İcra Dosyaları.
2. **Her sayfada aynı iskelet:** DataTable liste · "+ Yeni" · satır
   menüsünde işlemler · sağ üstte Excel ve PDF ikonları.
3. **Bir gider girin.** Belge No'yu **boş bırakın** — kayıttan sonra
   listede `GID-2026-000001` gibi bir numara göreceksiniz. Bir tahsilat
   girin: `TAH-…`. Seriler **tip ve yıl başına ayrı**, merkezî sayaçtan
   geliyor; hiçbir modül kendi numarasını üretmiyor.
4. **Elle numara yazın.** Yazdığınız değer korunur — sayaç sizi ezmez.
   Aynı numarayı ikinci kez yazmayı deneyin: veritabanı reddeder.
5. **Silme yok.** Hiçbir finans satırında "Sil" yok; düzeltme yolu iptal
   veya ters kayıt. Bu bilerek: muhasebe kaydını yerinde değiştirmek
   geçmiş raporları geriye dönük değiştirirdi.
6. **İcra Dosyaları.** "+ Yeni" ile dosya açın; kişi seçtiğinizde sağda
   **açık evrakları** listelenir. Durum seçimi dosyanın aşamasını taşır.

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 5: Rapor motoru)

1. **Raporlar'ı açın.** Artık düz bir liste değil: **üç bölüm** —
   Listeler · Ekstreler · Dökümler — her biri ikonlu kartlardan oluşan bir
   ızgara. Kart adları ve bölümleri **sunucudan** geliyor.
2. **"Kasa Ekstresi" kartına tıklayın.** Yapılandırma modalı açılır ve
   içinde **Kasa** seçimi var. Eskiden bu alan yoktu; ekstre kasa
   sorulmadan üretiliyordu.
3. **"Site Sakinleri Listesi"ne tıklayın.** Alanlar **tamamen farklı**
   (Listeleme tipi · Blok · Ad sütunu · İmza alanı). Her rapor kendi alan
   listesini sunucudan alıyor.
4. **Dört düğme:** `[İptal] [PDF] [Excel] [Göster]`. "Göster" tabloyu
   ekranda çizer, toplam satırıyla birlikte.
5. **"Borç/Alacak" kartını açın.** Modalın üstünde bir uyarı: bu rapor tüm
   defteri tarar, PDF/Excel isteği **kuyruğa alınır**. Excel'e basın —
   dosya inmez, "Rapor kuyruğa alındı" bildirimi gelir.
6. **Sayfanın altında "Rapor İşlerim" tablosu belirir.** Durum önce
   *Sırada*, sonra *Üretiliyor*, sonra *Hazır* olur — liste kendi kendine
   tazelenir, yenilemenize gerek yok. Hazır olunca **İndir** düğmesi
   çıkar; hazır olmadan o düğme **hiç çizilmez**.
7. **Üç yeni rapor deneyin:** *Notlar* (kayıtlara düşülen notlar),
   *Firma Ekstresi* (gider negatif, tahsilat pozitif), *Hesap Ekstresi*
   (borç ve tahsilat tek zaman çizgisinde, **yürüyen bakiye** sütunuyla).
8. **Denetçi hesabıyla girin.** Rapor motoru ve kuyruk açık — denetim
   görevinin ana aracı. Saha rolleri (güvenlik, görevli, sakin) 403 alır.
9. **Başka bir yöneticiyle girin.** "Rapor İşlerim" listesi **boş**:
   herkes yalnızca kendi işlerini görür ve yalnızca kendi dosyasını
   indirebilir.

## Test sunucusunda ne göreceksiniz — ekran ekran (Aşama 6: Yönetim)

1. **Sol menüde Yönetim'i açın.** "Yönetişim" satırı **yok**. Yerine dört
   ayrı satır: **Karar Defteri · Doküman Yönetimi · KVKK Metinleri ·
   Gürültü Uyarıları** (Kullanıcılar, Şeffaflık, Denetim kaydı, Yetki ve
   KVKK tercihlerim yerinde duruyor).
2. **Karar Defteri.** Liste + sağ üstte "Karar Ekle". Modalı açın:
   Konu\*, Karar No, Tarih, Başkan, Karar Metni\* ve **Üye satırları**
   (her satırda ad + görev; "Üye Satırı Ekle" ile çoğaltılır, son satır
   silinemez).
3. **Numarayı boş bırakıp kaydedin.** Listede `KRR-2026-000001` görünür.
   Bir tane daha ekleyin: `…000002`. Alanın altındaki ipucu bunu zaten
   söylüyor. Kendi numaranızı yazarsanız **o korunur**.
4. **Satırdaki "PDF"ye tıklayın.** Karar metni sayfası açılır — karar bir
   *yazıdır*, tabloya sıkıştırılmadı.
5. **Doküman Yönetimi.** Sağ üstte yeşil **Excel** ikonu ve "Dosya Yükle".
   Tablo: seçim kutusu · Eklenme Tarihi · Doküman Adı · Yükleyen · Boyut ·
   işlemler. 25'ten fazla kayıt varsa altta **Önceki / Sonraki**.
6. **"Dosya Yükle"ye basın.** Kesikli çerçeveli alana dosya **sürükleyin**
   (ya da tıklayıp seçin — klavyeyle de açılır). Doküman adı dosya
   adından ön-dolar ama düzenlenebilir. Yükleme sırasında **ilerleme
   çubuğu** ve yüzde görünür.
7. **25 MB'tan büyük bir dosya deneyin.** Yükleme **başlamadan** uyarı
   alırsınız — sınır, dakikalarınızı harcadıktan sonra değil önce
   kontrol edilir.
8. **"İndir"e basın.** Dosya yeni sekmede açılır. Bu düğme **yeniydi**:
   daha önce yüklenen bir doküman panelden hiçbir şekilde alınamıyordu.
9. **Bir dokümanı silin.** Onay metni size dosyanın *bir süre saklanıp
   sonra kalıcı silineceğini* söyler. Kayıt listeden kalkar; aynı
   bağlantıya gitmeyi denerseniz bulunamaz. Arka planda obje bir süre
   daha durur ve gecelik iş süresi dolanları temizler.
10. **Birden çok satır seçin.** Üstte "Seçilenleri sil (n)" şeridi çıkar.
11. **Raporlar → Dökümler → "Doküman Listesi".** Aynı liste; Excel'de
    boyut sütunu **sayı** olduğu için toplam alınabiliyor. Silinmiş
    dokümanlar burada da **yok**.
12. **KVKK Metinleri.** Yayınlanmış sürümler listesi + yeni sürüm formu.
    Aynı gövdeyi ikinci kez yayınlamayı denerseniz reddedilir —
    yayınlanmış metnin gövdesi **değiştirilemez**, her yayın yeni bir
    sürümdür.
13. **Gürültü Uyarıları.** Eşiği aşan şikâyetler; "Anons bekliyor"
    olanlarda **"Yapıldı"** düğmesi var, ötekilerde yok.
14. **Saha rolleriyle girin** (güvenlik / görevli / sakin). Dört satırın
    hiçbiri menüde yok ve adres çubuğuna yazsanız da açılmıyor.

