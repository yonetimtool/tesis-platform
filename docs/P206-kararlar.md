# P206 — Yönetici finans yetkisi + mobil parite

## §1 — YÖNETİCİ FİNANS YETKİSİ

### Ölçüm: hangi uçlar yöneticiye kapalıydı

Rol matrisi (`backend/tests/yetki/rol-matrisi.txt`, uçların tamamı ×
yedi rol) tarandı. Finans altında yöneticiye **kapalı (403)** olan
uçlar — **on altı**:

| Uç | Ne yapar | Kısıt bilinçli miydi? |
|---|---|---|
| `POST /finans/tahsilat` | Tekil tahsilat | Bilinçli (P167) — **gerekçe geçersiz** |
| `POST /finans/tahsilat/toplu` | Gün sonu toplu tahsilat | Aynı |
| `POST /finans/hareketler` | Gider/gelir kaydı | Aynı |
| `POST /finans/hareketler/{id}/onayla` | Gider onayı | Aynı |
| `POST /finans/hareketler/{id}/reddet` | Gider reddi | Aynı |
| `POST /finans/hareketler/{id}/iptal` | Hareket iptali | Aynı |
| `POST /finans/virman` | Kasa/banka arası aktarım | Aynı |
| `POST /finans/iade` | İade (ters kayıt) | Aynı |
| `POST /finans/acilis` | Açılış fişi | Aynı |
| `POST /finans/banka-eslestir` | Ekstre eşleştirme onayı | Aynı |
| `POST /dues/payments` | Aidat tahsilatı | Bilinçli (P167) — **gerekçe geçersiz** |
| `POST /borclandirma/toplu/onizleme` | Toplu tahakkuk önizleme | Gerekçesizdi |
| `POST /borclandirma/toplu` | Toplu tahakkuk | Gerekçesizdi |
| `POST /borclandirma/sayac` | Sayaç borçlandırma | Gerekçesizdi |
| `POST /borclandirma/ice-aktarim` | Borç içe aktarma | Gerekçesizdi |
| `PATCH /borclandirma/gecikme-ayari` | Gecikme faizi ayarı | Gerekçesizdi |

Kullanıcının verdiği somut örnek (`POST /borclandirma/toplu/onizleme`
yöneticiye 403) ölçümle doğrulandı — ve yalnız o değil, on altı uç.

Yöneticiye **zaten açık** olanlar (değişmedi): kasa yönetimi
(`/kasalar`), banka ekstresi içe aktarma ve eşleştirme (`/banka/*`),
bütçe (`/budget/*`), otomasyon (`/otomasyon-gunlugu`, düzenli giderler),
gecikme faizi işleme/önizleme, muhasebe tanımları ve ayarları,
raporlar (`/raporlar/*`, `/reports/*`), borçlulara hatırlatma/ödeme
planı/faiz affı, icra dosyaları, içe aktarım (`/ice-aktarim/*`).

### K1.1 — On altı ucun hepsi yöneticiye açıldı

Eski gerekçe (P167, `dues.py` içinde yazılıydı):

> "Tahakkuk bir BORÇ YAZMAKTIR ve yanlışsa düzeltilebilir; tahsilat ise
> PARA ALINDI beyanıdır ve muhasebe kaydını kapatır."

Ayrım mantıklı ama **yanlış yere çizilmişti**: parayı kapıda elden alan
kişi **yöneticidir**, platform admini değil. Platform admininin o
tahsilatı girebilmesi için önce yöneticiden duyması gerekiyordu — yani
kaydın doğruluğu zaten yöneticiye dayanıyordu. Yetkiyi ondan almak,
kaydı **geciktirmekten** başka bir şey yapmıyordu; modül, onu kullanacak
kişi için fiilen yoktu.

**Gider onayında kendi kaydını onaylama** sorusu: engellenmedi. Tek
yöneticili sitelerde (çoğunluk) engellemek, gider onayını **imkânsız**
kılardı. Bedeli açıkça yazıyorum: küçük sitede dört göz ilkesi
işlemiyor. Karşılığı denetim kaydıdır — kaydı kimin oluşturduğu ve
kimin onayladığı `audit_log`'ta ayrı ayrı duruyor ve denetçi ikisini de
okuyor. İki yöneticili sitede ayrım doğal olarak oluşuyor.

### K1.2 — Platform admini ile yönetici farkı

**Platformda kalan** (yöneticiye kapalı, bilinçli):

| Alan | Uçlar | Gerekçe |
|---|---|---|
| Tesis yaşam döngüsü | `/tenants*` (oluştur, sil, yönetici ata, kota) | Abonelik ve müşteri ilişkisi platformun; tesisin kendini silmesi/çoğaltması ürün sınırı |
| Sürüm politikası | `/surum-politikasi*` | Zorunlu güncelleme tüm tesisleri etkiler (P202) |
| Platform gözlemi | `/admin/overview`, `/audit` (platform kapsamı), `/devices` | Çapraz tesis görünümü |
| Destek kuyruğu | `/support/all`, `PATCH /support/{id}` | Platform ekibinin işi |
| Tanıtım sitesi | `/tanitim-iletisim*` | Tesise ait değil |

Kural cümlesi: **tesisin parası, kadrosu ve kayıtları yöneticinindir;
tesisin var olup olmaması, ne kadar kota aldığı ve hangi sürümü
çalıştırdığı platformundur.**

### K1.3 — Denetçi ve sakin değişmedi

Denetçi **salt okuma**: on altı ucun hepsinde 403 alır
(`test_DENETCI_finans_YAZMA_uclarinda_403_ALIR`). Mali gözetim okumakla
yapılır; yazma yetkisi gözetimin bağımsızlığını bozardı. Sakin finans
uçlarının hiçbirine giremez (ayrı test).

### K1.4 — Yetki genişledi, KAPSAM genişlemedi

Yönetici yalnız **kendi** tesisinde yazar. Üç yerden birden kapalı:
`get_tenant_db` oturumu token'daki tenant'a RLS ile bağlar; başka
tesisin kasa/daire kimliği 422 `invalid_reference` alır; kayıt
`tenant_id=user.tenant_id` ile yazılır (istekten gelmez). Test:
`test_YONETICI_BASKA_TESISIN_kasasina_YAZAMAZ`.

### Ölçüm — kilit kanıtı

`test_p206_yonetici_finans.py` 4 test. `_YAZMA`yı `require_role("admin")`
yapınca iki test düştü (`403 == 422`), geri alındı. Rol matrisi
yeniden üretildi: **16 satır** `RED` → `IZIN` (yalnız yönetici sütunu).
Ayrıca eski beklentiyi kilitleyen üç test güncellendi
(`test_finans.py::test_rbac`, `test_dues.py::test_yonetici_tahakkuk_
tenant_izolasyonu`, `test_borclandirma_uc.py::test_rbac_yazma_ADMIN` →
`..._YONETIM`) — hepsi **kusuru** kilitliyordu.

---

## §2 — TAHSİLATTA BORÇLU LİSTESİ

### Kök neden — ÖLÇÜLDÜ, yetkiyle İLGİSİ YOK

```
GET /users?limit=500  -> 422 {"field":"query.limit","message":"Input should be less than or equal to 200"}
GET /users?limit=200  -> 200 (7 kayıt)
```

İstemci (`useKisiler`) `limit=500` istiyor, uç 200 tavanında **422**
dönüyor, SWR hatası `data?.items ?? []` ile **sessizce** boş listeye
dönüşüyordu. Kullanıcı "kimseyi seçemiyorum" diyordu; ekran hiçbir şey
söylemiyordu. §1 ile ilgisi yok — yönetici zaten `/users` okuyabiliyor.

### K2.1 — Üç ayrı düzeltme

1. **Tavan uyumu:** `/users` limiti 200 → **1000** (`/units` P187'de aynı
   sebeple aynı şeyi yapmıştı: istemci ve tavan uyuşmuyordu).
2. **Sessizlik bitti:** `useKisiler` artık `{kisiler, hata}` dönüyor ve
   ekran hatayı yazıyor. Bir listenin boş görünmesiyle alınamamış olması
   kullanıcı için aynı şey değil.
3. **Liste artık BORÇLULAR:** tahsilat penceresinde sorulan soru "kime
   borcu var"dır. Kaynak `/finans/yaslandirma` — borçlular ekranının
   kaynağıyla **aynı** (P192 tek kaynak kuralı; ikinci bir uç yazmak
   aynı sayının iki yerde ayrışması demekti). Satırda **ad · daire ·
   kalan tutar** yazar.

### K2.2 — Peşin ödeme AÇIK bir seçim

P192'de "borç öncesi peşin ödeme alacakta bekler" senaryosu var, yani
borcu olmayandan tahsilat mümkün olmalı. İki listeyi birleştirmek yerine
**açık bir kutu** kondu ("Borcu olmayan birinden tahsilat"). Birleştirmek,
borçlu ararken yüzlerce borçsuz adı da listelemek olurdu; gizlemek ise
meşru bir işlemi imkânsız kılardı.

Borçlu yoksa ekran bunu **yazar** ve peşin ödeme kutusuna yönlendirir —
boş bir seçim kutusu bırakılmaz (kabul kriteri 6).

### K2.3 — Borçlu seçilince daire otomatik dolar

Borç daireye bağlıdır. Daireyi ayrıca elle seçtirmek, yanlış daireye
makbuz kesme riskini bedavaya ekliyordu. Arama hem adda hem daire
numarasında çalışır.

### Ölçüm

`p206-tahsilat-borclu.dom.test.ts` 6 test (borçlu listesi + tutar,
kişisiz daire atlanır, borçlu yok mesajı, uç hatası görünür, arama,
peşin ödeme, seçimde dairenin gövdeye gitmesi). Kilit kanıtı: borçlu
listesi boş dönecek şekilde bozuldu → 3 test düştü, geri alındı.

---

## §3 — IBAN VE BANKA ALANI

### Ölçüm: ne vardı

```
schemas.py:  _IBAN_PATTERN = r"^TR[0-9]{24}$"     (Pydantic)
DB CHECK:    ck_kasa_iban  iban ~ '^TR[0-9]{24}$'
web:         { ad: "iban", tip: "metin" }          (serbest metin, gruplama yok)
             { ad: "banka_adi", tip: "metin" }     (elle yazılıyor)
```

Bu denetim **iki uçta birden yanlıştı**:

* **Çok dar:** yurt dışındaki bir tesis kendi IBAN'ını giremiyordu; DB
  hatası "değer kısıt ihlali" diyordu, yani kullanıcı nedenini bile
  anlayamıyordu.
* **Çok gevşek:** "TR" + 24 rakamın **herhangi biri** geçerli sayılıyordu.
  Tek hanesi yanlış yazılmış bir IBAN kaydediliyor, para yanlış hesaba
  gidiyor ve bu ancak ödeme kaybolunca fark ediliyordu. (Ölçüldü:
  `TR330006100519786457841327` eski regex'ten **geçiyor**, mod 97'den
  geçmiyor.)

### K3.1 — Ülke sınırı YOK; doğruluk MOD 97 ile

Uzunluk **ülkeye göre** denetlenir (tablo: TR=26, DE=22, GB=22, …).
Tabloda olmayan ülke için yalnız genel ISO sınırı (15–34) uygulanır —
listede olmayan bir ülkeyi reddetmek, doğru IBAN'ı olan kullanıcıyı
kilitlemek olurdu. Doğruluk **ISO 13616 mod 97** sağlama toplamıyla
denetlenir; regex'in yapamadığı tam olarak buydu.

Katmanlar:

| Katman | Ne denetler | Neden orada |
|---|---|---|
| DB CHECK (göç 0097) | Yapı: `^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$` | "Bu alan bir IBAN'dır"ın veritabanında söylenebilecek en doğru hâli. Mod 97'yi CHECK içinde yazmak mümkün ama okunmaz bir ifade olur ve kural iki dilde iki kez bakım isterdi |
| Pydantic (`app/iban.py`) | Ülke uzunluğu + mod 97, **kanonik** hâle çevirir | Son söz sunucunundur; istemci her zaman bizim istemcimiz değil |
| Web (`lib/iban.ts`) | Aynısı + yazarken gruplama | Kullanıcıyı 422 beklemeden uyarır |

Kural iki dilde yazılı; ayrışmaya karşı **aynı örnek kümesi** iki tarafta
da koşuyor (`test_p206_iban.py` / `p206-iban.test.ts`).

### K3.2 — Depoda boşluksuz, ekranda dörderli

Aynı IBAN'ın `TR33 0006…` ve `TR330006…` diye iki kayıt üretmesi, IBAN'ı
eşleme anahtarı olarak kullanan **banka ekstresi eşleştirmesini** (P191)
bozardı. Kanonik biçim depoda; okunabilirlik çizim katmanının işi.
Yazarken alan dörderli gruplar ve azami uzunluğu **sert** sınırlar
(sınırsız yazdırıp sonra reddetmek kullanıcıyı boşuna uğraştırırdı).

### K3.3 — Banka adı: liste + otomatik doldurma + serbest giriş

TR IBAN'ı: `TR` + 2 kontrol + **5 hane banka kodu** + 1 rezerv + 16 hane
hesap. EFT kodları 4 hanedir ve alana soldan sıfırla doldurulur
(`0062` → `00062`) — bu yüzden **son dört hane** alınır. (İlk yazımda ilk
dördü alıyordum; Garanti "0006" diye okunup listede bulunamıyordu, örnek
IBAN'la görüldü ve düzeltildi.)

IBAN girilince banka adı **otomatik dolar** (boşsa; üzerine yazmak
serbest). TR dışında banka **uydurulmaz** — kodun yeri ülkeye göre
değişir ve tahmin, yanlış banka adı yazdırırdı.

**Liste kapalı değil.** `datalist` ile hem seçim hem serbest giriş var.
Kapalı bir açılır liste, katılım bankalarını, yeni lisans alanları ve
yabancı şubeleri dışarıda bırakır; gerçek bir hesabı **kaydedilemez**
yapardı. Banka adları çeviri taramasından muaf tutuldu (gerekçe
`tests/i18n.test.ts` içinde): banka adı bir cümle değil, **kurumun tescilli
adıdır** ve mutabakatta ekrandaki adla bankanın adı aynı olmalı.

### Ölçüm

Backend `test_p206_iban.py` 16 test, web `p206-iban.test.ts` 8 +
`p206-iban-alani.dom.test.ts` 5 test. Kilit kanıtı: mod 97 denetimi
kaldırıldı → 3 test düştü (biri açıkça "eski regex bunu geçiriyordu"
diyen test), geri alındı. Göç 0097 downgrade→upgrade ile doğrulandı.

**Ölçemediğim:** banka kodu listesinin güncelliği — kodlar TCMB/BKM
yayınından elle alındı; yeni lisans alan bir bankanın kodu listede
olmaz (serbest giriş bu yüzden korundu).
