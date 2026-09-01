# P196 — "Kod gönderildi" diyip hiçbir şey göndermemek

## Şikâyet
Web profil sayfasından e-posta değiştirilince ekran "doğrulama kodu
gönderildi" diyor, **posta kutusuna hiçbir şey gelmiyordu.**

## Kök neden — iki hata üst üste

### 1. Tesisin kendi SMTP ayarı yok sayılıyordu

`/me/eposta/kod-iste` ve `/me/hesap-sil/kod-iste`,
`eposta_kodu_uret_ve_gonder`i **`ayar` vermeden** çağırıyordu. O
parametre verilmezse sağlayıcı **ENV'den** seçilir. Tesis kendi
SMTP'sini `mesaj_yapilandirma`ya girmişse ve ENV boşsa sonuç
`LogEpostaSaglayici` olur: hiçbir şey gönderilmez.

Aynı depodaki öteki akışlar `ayar`ı **geçiyordu** — ölçüm:

| Akış | `ayar` geçiyor mu | Sizin gözleminiz |
|---|---|---|
| Davet (`davet.py`) | ✅ | çalışıyor |
| Giriş kodu (`auth.py`) | ✅ | çalışıyor |
| Parola sıfırlama (`auth.py`) | ✅ | — |
| **Profil e-posta (`me.py`)** | ❌ | **gitmiyor** |
| **Hesap silme kodu (`me.py`)** | ❌ | (henüz fark edilmemiş) |

Tablo, şikâyetle birebir örtüşüyor. Bu, **P172 §1'de kapatılan kusur
sınıfının aynısı**: "sağlayıcıyı ayarsız çağırmak".

### 2. Gönderim sonucu atılıyordu

`gonder()` bir `GonderimSonucu` döndürüyor. Dev'de ölçüldü:

```
GonderimSonucu(durum='yapilandirilmadi', saglayici='log-eposta',
               hata='smtp_yapilandirilmadi')
```

Bu değer **hiçbir yerde okunmuyordu**; uç `{"durum": "gonderildi"}`
yazıyordu. `telefon_kodu.py`deki yorum "SESSİZCE 'gönderildi' DEMEZ"
diyordu — niyet doğruydu, uygulaması çağırana taşınmamıştı.

### Neden `mesaj_gonderim` boştu
Bu akışlar o tabloya **hiç yazmıyordu**; tablo mesajlaşma modülünün
(şablon/toplu gönderim) kaydıydı. Yani tablodaki boşluk "mail gitmedi"
kanıtı **değildi** — ama sizi doğru yere götürdü: kod gönderimlerinin
hiçbir izi yoktu.

## Kararlar

**K1 — Ortak yardımcı `_kod_gonder_ve_dogrula`.** İki uç da tesis
ayarını okuyup `ayar=` ile geçiyor ve sonucu kontrol ediyor. Ayrı ayrı
düzeltmek, üçüncü uç eklendiğinde aynı hatanın tekrarı olurdu.

**K2 — Gönderilemezse 502 + `kod_gonderilemedi` (7 dil).** Kullanıcı
artık "gönderildi" yalanını görmüyor. Hata dönünce istek transaction'ı
geri alınır ve **üretilen kod satırı da gider** — bu doğrudur:
gönderilmemiş bir kodu veritabanında bırakmak, kullanıcının asla
öğrenemeyeceği bir sırrı saklamak olurdu.

**K3 — Sızdırma yüzeyi olan uçlarda hata DÖNÜLMEZ, yalnız loglanır.**
`auth.py`deki giriş-kodu ve parola-sıfırlama uçları bilinmeyen adrese de
aynı yanıtı verir. Orada gönderim hatasını kullanıcıya yansıtmak
"hata = bu adres kayıtlı" demek olurdu. Log merkezî (`telefon_kodu`),
yani o akışlar da artık görünür.

**K4 — Deneme `mesaj_gonderim`e yazılır — AYRI OTURUMDA.**
İlk yazımda çağıranın oturumuna yazdım; **ölçüldü ve yanlıştı**: 502
dönünce transaction geri alınıyor ve teşhis kaydı tam da en gerekli
anda siliniyordu. Artık kendi oturumunda yazılıyor, rollback'ten
etkilenmiyor.

**K5 — Kod gövdeye yazılmaz.** Tablonun sözleşmesi "gönderilen metin
kopyalanır" der ama doğrulama kodu bir sırdır; `kod_hash` olarak
saklanmasının anlamı, düz metnini başka bir tabloya yazmamaktır. Gövdeye
`[dogrulama kodu: <amac>]` yazılır. Test bunu ayrıca kilitliyor
(6 haneli sayı aranıyor).

**K6 — Aynı kalıp taranıp kapatıldı.** `.gonder()` sonucunu atan beş
çağrı bulundu:

| Yer | Kullanıcıya "gönderildi" diyor mu | Karar |
|---|---|---|
| `me.py` profil e-posta | Evet | **düzeltildi** (502) |
| `me.py` hesap silme (e-posta) | Evet | **düzeltildi** (502) |
| `me.py` hesap silme (SMS) | Evet | **düzeltildi** (502) |
| `oauth.py` rol-tamamla OTP | Evet (`otp_gerekli`) | **düzeltildi** (502) |
| `kayit.py` `_eposta_gonder` | Çağırana bağlı | sonuç **döndürülüyor** + log |
| `banka.py` makbuz e-postası | Hayır (yan iş) | değişmedi, bilinçli |
| `tanitim.py` iletişim formu | Hayır (kayıt zaten atıldı) | değişmedi, bilinçli |

## NE ÖLÇTÜM

**Kök nedenin kanıtı** (dev API, gerçek yönetici oturumu):

```
ENV SMTP: ''      TESIS ayari: yok
A) Ucun YAPTIGI cagri (ayar GECILMEDEN) -> LogEpostaSaglayici
B) Tesis ayari GECILEREK               -> LogEpostaSaglayici
C) gonder() DONUS DEGERI (uc bunu HIC OKUMUYOR):
   GonderimSonucu(durum='yapilandirilmadi', saglayici='log-eposta',
                  hata='smtp_yapilandirilmadi')
```

**Düzeltmeden sonra, aynı istek:**

```
POST /me/eposta/kod-iste -> HTTP 502
{"error":{"code":"bad_gateway","message":"Doğrulama kodu gönderilemedi.
 E-posta ayarları çalışmıyor olabilir; lütfen yöneticinize bildirin."}}

mesaj_gonderim:
  01 Sep 13:27 eposta basarisiz | Yönetiyor — E-posta doğrulama kodu
               | hata: smtp_yapilandirilmadi
```

**`ayar` düzeltmesinin çalıştığının kanıtı** — tesise kendi SMTP'si
girildi (127.0.0.1:1025, ENV hâlâ boş) ve istek tekrarlandı:

```
hata: smtp_yapilandirilmadi   ->   hata: STARTTLS extension not supported
```

Hata metninin değişmesi, artık **tesisin kendi sunucusuna gerçekten
bağlanıldığını** gösteriyor; eskiden o ayar hiç okunmuyordu.

**Testler:** `test_p196_gonderim_sessiz_basarisizlik.py` — 6 test.
İlgili suite'lerle birlikte 91 test yeşil.

## Ölçemediklerim

- **Başarı yolunun canlı hâli.** Dev'de STARTTLS konuşan bir SMTP
  sunucusu yok (gönderici koşulsuz `starttls()` çağırıyor); konteynerde
  kurduğum sahte SMTP bu yüzden yetmedi. Başarı sözleşmesi (`gonderildi`
  → satır `gonderildi`, hata yok) **süreç içi** ölçüldü: sağlayıcı
  değiştirilip yardımcı doğrudan çağrıldı.
- **Prod'da hangi yapılandırmanın kullanıldığı.** Tesisin kendi SMTP'si
  mi, ENV mi — bunu dev'den göremem. Aşağıdaki sorgu bunu söyler.

## Prod'da bakılacaklar

```sql
-- Tesis kendi SMTP'sini girmiş mi? (girmişse eski kod ENV'e düşüyordu)
SELECT tenant_id, smtp_host IS NOT NULL AS tesis_smtp_var
  FROM mesaj_yapilandirma;

-- Dağıtımdan sonra: kod gönderimleri artık görünür
SELECT created_at, durum, konu, hata FROM mesaj_gonderim
 WHERE govde LIKE '[dogrulama kodu%' ORDER BY created_at DESC LIMIT 20;
```

Dağıtımdan sonra profil e-postasını bir kez değiştirin: satır
`gonderildi` ise iş tamam; `basarisiz` ise `hata` sütunu **nedenini**
yazıyor olacak — artık sessiz değil.
