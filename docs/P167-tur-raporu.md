# P167 — tur raporu

Brief sekiz ana madde ve ~30 yeni ekran içeriyor. Brief'in kendi uyarısı
("tek oturumda bitmez, aşama sırasına uy, tamamlanmışı bırak, kalanı
dürüstçe raporla") aynen uygulandı.

| Aşama | Kapsam | Durum |
|---|---|---|
| 1 | Menü mimarisi (§1.1–§1.8) | **bitti** |
| 2 | Özet sayfası (dashboard yeniden inşa) | başlanmadı |
| 3 | Web toplu blok/daire hatası | başlanmadı |
| 4 | Finansal İşlemler (8 sayfa) | başlanmadı |
| 5 | Rapor motoru | başlanmadı |
| 6 | Yönetim başlığı (karar defteri, doküman) | başlanmadı |

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
- **Backend tam takım:** ilk koşumda `1703 geçti, 3 düştü`. Üçü de
  aşağıda; ikisi bu turun kusuru, biri **önceden main'de kırıktı**.
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

**3. `test_yonetici::test_yonetici_aidat_raporu_okur_yazamaz` — ÖNCEDEN
KIRIKTI, bu turun değil.** Commit `3a71736f` (bir önceki P167 commit'i)
`POST /dues/assessments`i yöneticiye **kasıtlı olarak** açtı ve
`test_dues.py`, `rol-matrisi.txt`, `auth.md`, `openapi.yaml`ı güncelledi
— ama bu dosyayı atladı. Test, ürünün kasıtlı davranışına karşı kırmızı
duruyordu. Düzeltildi ve adı gerçeği söyleyecek şekilde değişti:
`..._okur_TAHAKKUK_YAZAR_TAHSILAT_YAZAMAZ`. **Tahsilatın 403 kaldığı
satır korundu** — o satır, yetkiyi genişleten commit'in bilinçli
sınırını kilitleyen tek ölçüm.

---

## Test sunucusunda ne göreceksiniz — ekran ekran

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
