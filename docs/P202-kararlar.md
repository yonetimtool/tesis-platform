# P202 — Zorunlu / önerilen güncelleme

**Tarih:** 2026-09-01 · **Kapsam:** backend (göç 0091) · panel · mobil

---

## Tasarım kararları

### K1 — İki seviye, iki ayrı eşik

| Seviye | Davranış | Ne zaman |
|---|---|---|
| **Zorunlu** (`asgari_surum`) | Kapatılamayan ekran, tek düğme "Güncelle" | Kritik güvenlik düzeltmesi, kırıcı API değişikliği |
| **Önerilen** (`onerilen_surum`) | Kapatılabilir uyarı, "Şimdi güncelle" / "Sonra" | Diğer her şey |

İkisi de **boş bırakılabilir; boş = o seviye kapalı.** Göç uygulanır
uygulanmaz iki eşik de boş doğar: bir güncelleme politikasının, kimse
ondan haberdar olmadan yürürlüğe girmesi kabul edilemez.

**Zorunlu, önerileni ezer.** İki eşik de aşılmışsa daha kısıtlayıcı olan
kazanır — yoksa operatör asgariyi yükseltip önerileni güncellemeyi
unuttuğunda zorunlu güncelleme sessizce "önerilen"e düşerdi.

### K2 — Kararı sunucu verir

Uygulama platformunu ve sürümünü bildirir, sunucu kararı döner.

Karar uygulamada olsaydı, "1.2.0'ın altını kilitle" demek için **önce
1.2.0'ı yayınlamak ve kullanıcıların onu almasını beklemek** gerekirdi —
yani tam da ulaşamadığımız kullanıcılar için işe yaramazdı.

**Kontrol ucu public** ve bu zorunlu: kontrol girişten önce çalışır,
çünkü kırıcı bir API değişikliği yapıldıysa eski istemci **giriş bile
yapamayabilir.** Kimlik arkasına koymak, ekranı en çok ihtiyaç duyulan
durumda gösterilemez yapardı. Sızdırdığı tek şey mağazadaki sürüm
numaraları — zaten herkese açık sayılar.

**Mağaza adresi yanıtta gelir.** İstemcide sabitlenseydi, adres
değiştiğinde (paket adı, App Store id) eski istemciler tam "güncelle"
demeye çalışırken kırık bir düğmeye basardı.

### K3 — Politika platform geneli, tenant'a bağlı değil

Mağazadaki paket tektir, tesise göre değişmez. `tenant_id` koymak aynı
gerçeğin tesis sayısı kadar kopyasını üretirdi.

Ekran `panel.*`ta, **platform admininde**: bir tesis yöneticisinin bütün
kullanıcıları kilitleyebilmesi doğru olmazdı.

**İlk yazımda tabloda RLS hiç açmamıştım** ve gerekçem "satırlar zaten
herkese açık sayılar" idi. `test_rls_kapsam.py` bunu düşürdü ve
**haklıydı**: kural "her tablo RLS+FORCE"dur, istisnası da sınıfın
**görünür ve sayılı** kalmasıdır. Sızıntının bugün olmaması, kapıyı açık
bırakmanın gerekçesi değil — bu tabloya bir gün hassas bir alan
eklendiğinde (hedefli dağıtım listesi gibi) korumayı hatırlayacak kimse
olmazdı.

Düzeltilmiş hâli, `tanitim_iletisim` (0033) ve `yonetici_basvuru` (0068)
ile **aynı desen**: RLS açık + FORCE, **politika yok**, erişim yalnız
`surum_politikasi_oku` / `surum_politikasi_yaz` SECURITY DEFINER
fonksiyonlarından. `app_rw` tabloyu doğrudan göremez. Platform tablosu
tavanı 2 → 3'e **bilinçli** yükseltildi ve üç üyenin neden tenant'sız
olduğu kilidin yanına yazıldı.

### K4 — Belirsizlikte karar: ENGELLEME

Zorunlu güncelleme bir güvenlik aracı, bir kendini-vurma tetiği değil.
Şu durumların **hepsi** "güncel" döner:

* eşik boş · eşik geçersiz biçimde · istemcinin sürümü okunamıyor ·
  platform bilinmiyor · **sunucuya ulaşılamıyor** · sunucu tanımadığımız
  bir `durum` döndü (ileri uyumluluk).

Panele yanlışlıkla "surum-3" yazan bir operatör tüm kullanıcıları dışarı
atmamalı. Panelde biçim **ayrıca doğrulanır (422)**: sessizce kabul edip
"geçersiz eşik = yok say" davranışına bırakmak, operatöre "kaydedildi"
deyip politikayı hiç çalıştırmamak olurdu — en kötü tür sessiz kusur.

### K5 — Mesaj 7 dilde ama **zorunlu değil**

Yedi dilin doldurulmasını şart koşmak özelliği kullanılmaz yapardı: acil
bir güvenlik düzeltmesinde operatör çeviri beklemez. Boş bırakılırsa
uygulama **kendi yerelleştirilmiş** metnini gösterir. Dolu ise sunucu
`Accept-Language`e göre seçer, o dil yoksa TR'ye düşer.

### K6 — Erteleme süresi: **24 saat**

İki yanlış uç var:

* **Her açılışta sormak** — kullanıcıyı "kapat" refleksine eğitir. Uyarı
  okunmadan kapatılan bir engele döner ve önerilen seviye anlamını
  yitirir; kötüsü, **zorunlu ekran** çıktığında da aynı refleksle
  karşılanır.
* **Bir hafta susturmak** — önerilen güncellemeler çoğunlukla düzeltme
  taşır; kullanıcıyı bir hafta bilinen bir hatayla bırakmak, hatayı
  düzeltmiş olmanın değerini yok eder.

24 saat ikisinin arasında ve anlaşılır bir söz verir: **günde en fazla
bir kez.** Zorunlu seviye bu süreden muaftır ("Sonra" seçeneği zaten yok).

### K7 — Zorunlu ekran nasıl atlanamaz kılındı

| Atlama yolu | Kapatan şey |
|---|---|
| Geri düğmesi / kaydırarak kapatma | `PopScope(canPop: false)` |
| Geri oku | `AppBar` yok |
| Derin bağlantı, bildirime tıklama, router yönlendirmesi | Kapı **rota değil**, `MaterialApp.builder` — çizilen her ekranın üstünde |
| Arka plana atıp geri gelme | `SurumGozcusu` `resumed`'da yeniden kontrol eder |
| Alttaki ekranın yaşamaya devam etmesi | Ağaç **gizlenmiyor, hiç çizilmiyor** (`Offstage` yeterli olmazdı: alttaki ekranlar ağ isteği atmaya ve odak almaya devam ederdi) |

### K8 — Kontrol açılışta **ve** ön plana gelince

Kullanıcı uygulamayı günlerce açık bırakabilir. Yalnız açılışta bakan bir
kontrol, tam da **en uzun süre güncellenmemiş cihazları** atlardı — yani
hedef kitlesini kaçıran bir kontrol olurdu.

### K9 — Semantik sürüm karşılaştırması

`"1.10.0" < "1.9.0"` metin olarak doğru, sürüm olarak yanlış. Sessiz bir
kusur: 1.9.0 yayındayken kimse fark etmez, 1.10.0 çıkınca **tüm
kullanıcılar "güncel" sayılır** ve özellik tam ihtiyaç duyulduğu anda işe
yaramaz. Karşılaştırma parça parça ve sayısal; `+yapım` eki kırpılır
(mağazada görünen sürüm "1.1.1", "1.1.1+6" değil).

Kural **iki tarafta da** (Python + Dart) uygulanır ve **iki tarafta da
aynı vakalarla test edilir**.

### K10 — Sürüm nereden okunuyor

`package_info_plus` ile **çalışan paketin** sözlüğünden. Koda gömülü bir
sabit `pubspec.yaml` ile ayrışabilirdi; paket sözlüğü ayrışamaz. Paket
zaten geçişli bağımlılıktı, çevrimdışı çözüldü (yeni indirme yok).

---

## Ne ölçtüm

### Backend — canlı uç (dev api)

```
politika: android asgari=1.1.0 onerilen=1.2.0
1.0.9    -> zorunlu   magaza=https://play.google.com/store/...  mesaj=Guvenlik guncellemesi
1.1.0    -> onerilen
1.1.5    -> onerilen
1.2.0    -> guncel    (mesaj/magaza GONDERILMEZ)
1.10.0   -> guncel    ← semver dogru; metin karsilastirmasi "zorunlu" derdi
bozuk    -> guncel
Accept-Language=en  -> "Security update"
iOS (politika bos)  -> guncel
```

Göç **geri alınabilir**: `downgrade 0090` → `upgrade head` ikisi de
çalıştırıldı.

### Testler

| Yer | Sayı | Neyi ölçüyor |
|---|---|---|
| `test_p202_surum_karsilastirma.py` | 28 | Sınır durumları (1.10.0/1.9.0, 1.1.1/1.1.10, eşitlik, geçersiz biçim, yapım eki) |
| `test_p202_surum_politikasi.py` | 16 | Uç davranışı, public erişim, dil seçimi, panel yetkisi, biçim reddi |
| `p202_surum_karsilastirma_test.dart` | 24 | **Aynı vakalar Dart tarafında** |
| `p202_zorunlu_guncelleme_test.dart` | 11 | Ekran akışı, atlanamazlık, ağ hatası, erteleme |
| `p202-surum-politikasi.dom.test.ts` | 5 | Panel: giden gövde, geçersiz biçim gönderilmez, boşaltma |

### Kilit kanıtı — dört bozma, dördü de doğru testten düştü

| Bozma | Düşen test |
|---|---|
| `PopScope canPop: true` | ZORUNLU EKRAN GERİ DÜĞMESİYLE ATLANAMAZ |
| Ağ hatasında kilitle (fail-closed) | SUNUCUYA ULAŞILAMAZKEN UYGULAMA ÇALIŞMAYA DEVAM EDER |
| `resumed` kontrolü kaldırıldı | ARKA PLANA ATIP GERİ GELİNCE EKRAN DURUYOR |
| `compareTo` (metin karşılaştırması) | 5 sınır vakası birden |

Hepsi geri alındı.

### Tam takım beş kilit registresini daha düşürdü — hepsi haklıydı

Bölüm testleri yeşilken tam takım şunları yakaladı:

| Kilit | Ne dedi | Ne yaptım |
|---|---|---|
| `test_rls_kapsam` (2 test) | Tabloda RLS yok; platform sınıfı tavanı aşıyor | RLS+FORCE + SECDEF deseni; tavan bilinçli 3'e |
| `test_hata_i18n` | `platform_gecersiz` ham cümle | `hata_metinleri.py`ye 7 dilde eklendi |
| `test_secdef_kapsam` (PUBLIC EXECUTE) | Postgres yeni fonksiyona **varsayılan PUBLIC EXECUTE** verir | `REVOKE ALL ... FROM PUBLIC` eklendi |
| `test_secdef_kapsam` (envanter) | Yeni SECDEF fonksiyonları envanterde yok | İkisi de gerekçesiyle envantere yazıldı |
| `sabit_metin_denetimi_test.dart` | Depo anahtarı çizim katmanında ham dizge | `data/surum_erteleme.dart`a taşındı — katmanlama da düzeldi |

Beşi de gerçek kusurdu; ikisi (PUBLIC EXECUTE ve RLS) doğrudan güvenlik.

> Not: "ağ hatasında istisnayı dışarı sal" bozması **düşmedi** — çünkü
> hata iki katmanda da yakalanıyor ve varsayılan zaten `guncel`. Yani
> yapı **fail-open**; tek bir katmanın kaldırılması kullanıcıyı
> kilitleyemiyor. Asıl tehlikeli hata (hata durumunda kilitlemek) ise
> yakalandı.

---

## Cihazda doğrulanması gerekenler

Bunlar widget testinde **ölçülemez**; gerçek cihaz/emülatör ister:

1. **Mağazanın gerçekten açılması.** `url_launcher` çağrısı testte
   taklit edilir. iOS'ta App Store uygulamasının, Android'de Play
   uygulamasının açıldığı görülmeli.
2. **Mağaza açılamadığında mesaj.** Play Store'u devre dışı bırakılmış
   bir cihazda (ya da Play'siz bir Android'de) "Mağaza açılamadı" metni
   çıkmalı.
3. **Gerçek sürüm okuması.** `package_info_plus` testte sahte değer
   alıyor; cihazda `pubspec.yaml`daki sürümün gittiği doğrulanmalı
   (sunucu logunda `surum` alanına bakın).
4. **iOS kenar jesti.** `PopScope` testte `handlePopRoute` ile ölçüldü;
   gerçek kaydırma jesti cihazda denenmeli.
5. **Uygulamayı gerçekten arka plana atıp geri getirme.** Testte yaşam
   döngüsü olayı elle tetikleniyor.
6. **Yavaş/kesik ağ.** Testte bağlantı hatası taklit ediliyor; gerçek
   zaman aşımı davranışı (uçak modu, çok yavaş bağlantı) cihazda
   görülmeli — uygulama beklemeden açılmalı.

---

## Dağıtım

1. Göç: `alembic upgrade head` (0091).
2. `api` + `admin-web` yeniden kurulur.
3. **Politika boş doğar — kimse etkilenmez.** Kullanmak için
   `panel.yonetiyor.com` → **Uygulama sürümü**.
4. Mobil tarafın etkin olması için **yeni bir sürüm yayınlanmalı**
   (kontrol kodu uygulamanın içinde). Yani ilk kez 1.1.2 yayınlandıktan
   sonra, 1.1.1 ve altını hedefleyen bir politika işler.

> **Sıralamaya dikkat:** asgari eşiği, **mağazada gerçekten yayında olan**
> bir sürümün üstüne koymayın. Kullanıcı güncelleme ekranını görür ama
> mağazada indirecek yeni sürüm bulamaz.
