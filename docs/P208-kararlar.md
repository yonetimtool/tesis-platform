# P208 — Gürültü uyarı bildirimi + bildirim sesleri

## §1 — GÜRÜLTÜ ŞİKAYETİ: OTOMATİK UYARI

### ÖLÇÜM: mevcut akış ne yapıyordu

P37'den beri var olan akış (`app/gurultu_akisi.py::esik_kontrol`,
şikayet ucundan çağrılıyor — `gurultu_kuyrugu` beat görevi yalnızca
**başarısız webhook'ları yeniden deniyor**, eşiği o hesaplamıyor):

```
açık `gurultu` şikayetleri sayılır  →  sayaç >= tenant.gurultu_esigi (5) ?
   ├─ entegrasyon VARSA  → anons cihazına HMAC imzalı webhook
   └─ entegrasyon YOKSA  → YÖNETİCİYE "lütfen anonsu yapın" push
sonra: o dairenin açık şikayetleri `kapali` yapılır (sayaç sıfırlanır)
```

**Eşik mantığı vardı** (`esik_asildi`, sınır dahil: 4 tetiklemez, 5
tetikler) ama **iki şey eksikti**:

1. **Dairenin sakinine hiçbir şey gitmiyordu** — yani uyarı, uyarılması
   gereken kişiye ulaşmıyordu.
2. **Sayım penceresizdi**: `durum='acik'` olan her şikayet sayılıyordu.
   Bir yıl önce açılmış ve kimsenin kapatmadığı bir şikayet, dün geceki
   kadar ağırlık taşıyordu.

### K1.1 — Eşik penceresi: 30 gün (ayar, 0 = sınırsız)

Bir yıla yayılan 5 şikayet ile bir haftada gelen 5 şikayet aynı şey
değil. **30 gün** seçildi çünkü sakinlerin kullandığı doğal birim bu:
"bu ay sürekli gürültü var". Daha kısa (7 gün) bir pencere, hafta içi
düzenli ama seyrek gürültüyü hiç yakalayamazdı; daha uzun (90 gün) ise
üç ay önceki bir tartışmayı bugünkü davranışa yazardı.

`gurultu_pencere_gun = 0` **eski davranıştır** (sınırsız) — mevcut
tesisler için kaçış kapısı.

### K1.2 — Metin: şikayet edenin izi YOK (en sert kural)

Sakine giden metin **sabit**, hiçbir şablon alanı taşımıyor:

> "Daireniz hakkında gürültü şikâyeti alındı. Lütfen komşularınıza karşı
> dikkatli olun."

Ne kişi, ne daire, ne de **sayı**. Sayı yazmamak bilinçli: "5 şikayet"
demek sakini "kim şikayet etti" aramaya iter — beş kişilik bir koridorda
beş şikayet, herkesi işaret eder. Mesajın işi **davranışı değiştirmek**,
muhasebe yapmak değil.

Ton nötr (P37 kararının devamı): uyarı bir ceza değil hatırlatmadır ve
hakkında haksız şikayet birikmiş bir daireye de aynen gider.

### K1.3 — Kime: KİRACI varsa yalnız kiracıya

Şema bir daireye **rol başına tek** bağ veriyor
(`uq_unitresident_daire_rol`): en fazla bir malik + bir kiracı.

Kural: **kiracı bağı varsa yalnız kiracıya**, yoksa malik(ler)e.
Gürültü daireden çıkar ve onu durdurabilecek kişi **orada oturandır**.
Oturmayan malike "hakkınızda gürültü şikayeti var" demek hem yanlış
kişiyi uyarmak, hem de kiracı hakkındaki şikayeti ev sahibine ihbar
etmektir — sistemin görevi olmayan ve kiracı-malik ilişkisini zedeleyen
bir şey. Yönetici zaten haberdar; gerekirse malikle **kendisi** konuşur.

Aktif bağ: `bitis IS NULL` ya da gelecekte. Taşınmış birine uyarı
göndermek, geçmişteki bir komşuluk için bugün rahatsız etmekti.

### K1.4 — Tekrar engelleme: 7 gün susma

Uyarılan daire `gurultu_susma_gun` (varsayılan **7**) boyunca yeniden
uyarılmaz. Her gece tekrarlanan bir uyarı **kendisi gürültüye dönüşür**
ve okunmaz olur; uyarının işi davranışı değiştirmek ve buna zaman
tanımak. Bir hafta, tam bir hafta sonu döngüsü içerir (gürültü hafta
sonu yoğundur).

Kontrol **sıfırlamadan önce** yapılır ve akış `None` döner: şikayetleri
kapatıp sayacı sıfırlamak, uyarı gönderilmeden daireyi kalıcı olarak
"temiz" göstermek olurdu.

`0` = kapalı (her eşikte yeniden uyarır) — "her eşikte uyarsın" isteyen
tesisin seçeneği kalmalıydı.

**Bu, P37'nin bir davranışını bilinçli olarak değiştiriyor:**
`test_ESIK_SONRASI_yeniden_birikir` "ikinci beş şikayette ikinci uyarı"
bekliyordu; test yeniden adlandırıldı ve yeni kural + kapatma seçeneği
ölçülüyor.

### K1.5 — Yöneticiye ayrı bildirim

| Mod | Yöneticiye giden |
|---|---|
| Manuel (entegrasyon yok) | `gurultu_uyarisi` — "eşiğe ulaşıldı, lütfen anonsu yapın" (P37'den beri var) |
| Webhook (anons cihazı var) | `gurultu_esik_yonetim` — **yeni**: "{daire} için {sayi} şikayet birikti; sakine uyarı gönderildi" |

Webhook modunda yönetici bugüne kadar **hiçbir şey duymuyordu**: anons
cihaza gidiyor, kayıt veritabanında duruyordu. Manuel modda **ikinci**
bildirim gönderilmiyor — aynı olay için iki bildirim, ikisinin de
okunmamasıyla biterdi.

Yönetim satırı in-app'te `user_id=NULL` ile yazılır (yönetim gözü
sahipsiz satırları görür); kişi kişi yazmak aynı olayı yönetici sayısı
kadar çoğaltmak olurdu.

### K1.6 — Daire boşsa

Sakin yoksa `sakin_bildirildi=false` yazılır ve yalnız yönetim
bilgilendirilir. Kayıt yine oluşur: eşiğin aşıldığı bilgisi, dairede
kimse yaşamıyor olsa bile yönetimin defterine girmeli.

### K1.7 — Denetim (kabul kriteri 8)

`audit_log`: işlem, sayaç, eşik, pencere, kanal ve **kaç kişiye
gittiği**. **Kimlik yazılmaz** — denetim kaydı da bir sızıntı yüzeyidir;
"kaç kişi" yeter. Ayrıca `unit_uyari.sakin_bildirildi` bayrağı:
"uyarıldım mı" sorusunun yanıtı "push gönderildi mi" ile aynı şey değil
(daire boş olabilir, ayar kapalı olabilir).

### Ölçüm

`test_p208_gurultu_sakin.py` **11 test**: metinde sızıntı olmaması + 7
dil paritesi, sakine uyarı (push + in-app), kiracı kuralı, boş daire,
ayarın kapatılabilmesi, pencere içi/dışı sayım, pencerenin kapatılması,
susma süresi, süre geçince yeniden uyarı, denetim kaydı.
`test_gurultu_caydirici.py` 18 test (biri yeniden yazıldı + biri
eklendi) yeşil.

**Kilit kanıtı:** üç kusur geri kondu — pencere yok sayıldı, susma
devre dışı bırakıldı, kiracı ayrımı kaldırıldı → tam olarak ilgili üç
test düştü (`PENCERE_DISINDAKI...`, `SUSMA_SURESINDE...`,
`KIRACI_VARSA...`), diğer 8 test geçti. Üçü de geri alındı.

**Ölçemediğim:** gerçek cihazda bildirimin görünmesi; push gönderimi
`dispatch_external` düzeyinde taklit edildi (gövde ve hedef ölçüldü,
FCM'e gerçek istek atılmadı).

---

## §2 — BİLDİRİM SESLERİ: TİPE GÖRE

### Neden ayrı kanal (Android gerçeği)

Android'de sesin sahibi **kanaldır**; "aynı kanaldan farklı ses" diye
bir şey yok. Ayırt edilebilir bir ses istiyorsak **ayrı kanal şart**.
Yan faydası: kullanıcı sistem ayarlarında gürültü uyarısını susturup
vardiya hatırlatmasını açık bırakabilir.

Kanal sayısı **sınırsız büyümemeli**: her kanal, kullanıcının sistem
ayarlarında gördüğü bir satır daha demek. Bu yüzden yalnız gürültü
uyarısına ayrı kanal açıldı.

### Kanal ve ses tablosu

| Bildirim | Kanal | Ses | Öncelik |
|---|---|---|---|
| Gürültü uyarısı (sakine) | `yonetio_gurultu_v1` | **`yonetio_gurultu`** (kendine özgü) | HIGH |
| Gürültü eşiği (yöneticiye) | `yonetio_kritik_v1` | `yonetio_bildirim` | HIGH |
| Kaçan vardiya (`vardiya_baslamadi`) | `yonetio_kritik_v1` | `yonetio_bildirim` | HIGH |
| Vardiya hatırlatma | `yonetio_kritik_v1` | `yonetio_bildirim` | HIGH |
| Şikayet/talep hattı | `yonetio_kritik_v1` | `yonetio_bildirim` | HIGH |
| Diğer (duyuru, kargo, rezervasyon…) | `yonetio_genel_v1` | sistem sesi | NORMAL |
| Ses tercihi KAPALI (her tip) | `yonetio_sessiz_v1` | yok | NORMAL |

**Kaçan vardiya için özel ses açılmadı** — isteğin kararı ("normal alarm
sesi yeterli"). Kritik kanaldan gider: sesli ve `priority=high`.

### SES DOSYASI İHTİYAÇ LİSTESİ — **2 ses, 4 dosya**

**1) Genel kritik ses** — `yonetio_bildirim`
(şikayet, vardiya hatırlatma, kaçan vardiya, gürültü eşiği/yönetim)

**2) Gürültü uyarısı sesi** — `yonetio_gurultu`
(yalnız sakine giden gürültü uyarısı; ötekinden **duyulur biçimde
farklı** olmalı — sakin, bildirimi görmeden ne olduğunu anlamalı)

Her ses için **iki dosya**:

| | Android | iOS |
|---|---|---|
| Yol | `mobile/android/app/src/main/res/raw/<ad>.ogg` | `mobile/ios/Runner/<ad>.caf` |
| Biçim | OGG/Vorbis (MP3/WAV da olur) | CAF (Linear PCM / IMA4); `.aiff`/`.wav` da olur |
| Süre | **1–3 sn** | **30 sn'den KISA olmak zorunda** — uzunsa iOS sesi *sessizce* varsayılana düşürür |
| Boyut | < 100 KB | < 100 KB |
| Ad | küçük harf + rakam + alt çizgi, **uzantısız** koda girer | aynı ad |

Dönüştürme: `afconvert -f caff -d LEI16 giris.wav <ad>.caf`

**Dosyalar geldiğinde değişecek yerler** (dağıtım belgesinde de var):
`push_kanal.py` → `SES_HAZIR = True`; **kanal kimlikleri `_v2`**
(`push_kanal.py` + `MainActivity.kt`); yeni mobil sürüm.

### ANDROID KANAL UYARISI (tekrar)

Var olan bir kanalın sesi **program tarafından değiştirilemez**.
Kullanıcının telefonunda kanal zaten oluşmuştur; `SES_HAZIR=True` yapıp
kimliği aynı bırakırsak **güncelleyen kullanıcıda eski (sessiz) kanal
kalır** ve "sesi ekledik ama çalmıyor" olur. Bu yüzden yeni ses = yeni
kanal kimliği. `docs/P208-dagitim.md` bunu adım adım yazıyor.

### Ölçüm

`test_p207_push_kanal.py`'ye **5 test** eklendi: gürültü uyarısının
kendi kanalından gitmesi, ses kapalıyken yine sessiz kanala düşmesi,
kaçan vardiyanın özel ses **almaması** ama kritik kalması, şikayet ve
vardiyanın P207 kanalından devam etmesi, `SES_HAZIR=True` olduğunda ses
adlarının tipe göre ayrışması.

Kimlik eşitlik kilidi (mobil, `p207_kanal_kimlik_test.dart`) **5 teste**
çıktı: dört kanal kimliği + iki ses adı + gürültü kanalına sesin
gerçekten bağlanmış olması (kimlik aynı olsa bile ses bağlanmamışsa
bildirim kritik kanaldan farksız çalardı; kimlik karşılaştırması bunu
yakalamaz).

**Ölçemediğim:** sesin cihazda gerçekten çalması ve iki sesin
birbirinden ayırt edilebilir olması — dosyalar henüz yok ve emülatör de
yok.
