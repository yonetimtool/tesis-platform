# P245 — ÖZET SAYFASI: REFERANSA UYDURMA

Referans: **`docs/tasarim-referans/ui5.png`**.

**Bir düzeltme:** brief `ui4.png` diyordu; ui4 **20 ekranın mozaiği**.
Tarif edilen özet düzeni (karşılama bandı + 4 KPI + büyük maket + sağ
sütun + alt sıra) **ui5**. Yanlış görselle çalışmak haftalarca yanlış
yöne gitmek olurdu, bu yüzden önce doğrulandı.

---

## 1. YÖNTEM: SONUCU GÖRMEK

Kök neden kabul edildi: **jsdom yerleşim hesaplamaz.** Genişlik, oran ve
boşluk ölçülemez; testler yeşilken sayfa referansa benzemeyebilir.

**YENİ `admin-web/scripts/ekran-goruntusu.mjs`** — gerçek Chromium,
1440×900, gerçek veri, gerçek oturum.

Hat kurulurken üç engel ölçüldü ve çözüldü:

| engel | ölçüm | çözüm |
|---|---|---|
| `localhost` = platform yüzeyi | yönetici girişi **403** ("panel yalnız platform yöneticisi") | `app.localhost:3000` — `konakYuzeyi()` ilk DNS etiketine bakar |
| İlk-giriş turu ekranı kaplıyordu | modal tıklamayla kapanmıyordu | işaret **sunucuda** (`POST /me/tur-goruldu`) |
| Kurulum hatırlatıcısı | hidrasyon bitmeden tıklama modalı geri getiriyordu | `localStorage` işareti **sayfa yüklenmeden** yazılıyor |

**Ve bir yöntem hatası kendi ölçümüm yakaladı:** ilk sürüm sabit
`waitForTimeout` kullanıyordu; görüntü iki kez **yarım** çıktı
(iskeletler, boş maket, "Henüz duyuru yok"). Sabit süre, derleme + SWR +
WebGL'in ne kadar süreceğini **tahmin etmektir**. Bekleme **içerik
koşuluna** bağlandı.

### 1.1 Hat ilk çalıştığında BİR HATA BULDU

Konsolda **hidrasyon uyuşmazlığı**: sunucu `"September 2026"`, istemci
`"Eylül 2026"`. React **tüm belgeyi** değiştiriyordu.

Sebep: `Intl.DateTimeFormat(undefined, …)` — sunucu kullanıcının dilini
bilmiyor. Dört kullanım `dil` parametresine geçti. **Hiçbir test bunu
görmüyordu**; ekran görüntüsü hattının ilk çıktısı buydu.

---

## 2. ÖLÇÜLEN FARKLAR ve KAPATILANLAR

| # | ui5 | ölçüm (önce) | şimdi |
|---|---|---|---|
| 1 | Bina görselli karşılama bandı + sağda ifade | düz gradyan, sağ taraf boş | nötr bina silueti + ifade |
| 2 | 4 KPI: büyük sayı, ikon, alt açıklama | 5 kısayol kartı, **sayı yok** | 4 kart, **gerçek veriyle** |
| 3 | Maket solda, ~%65, 3D/Harita geçişi, arama | sağda ~%38, geçiş yok | 2/1 satır, geçiş + arama |
| 4 | Sağda Hızlı İşlemler + Duyurular | **yok** | var |
| 5 | Alt sıra: tahsilat halkası + talepler + son işlemler | **yok** | üç eşit sütun |
| 6 | Tam genişlik | dev takvim sayfayı ele geçiriyordu | takvim aşağı indi |

### 2.1 Düzen motoru referansın oranlarını bilmiyordu

Motor yalnız `tam` ve `yarim` biliyordu — yani maket **ancak yarım
genişlikte** çizilebiliyordu. "Maket sağda küçük bir kutu" şikâyetinin
doğrudan sebebi buydu.

Eklenen: `genis` + `dar` → **2/1**, `uc` ×3 → **üç eşit**.

**Oran kayda yazılmaz**, bölümün kendi tanımından türer: aynı bilgiyi
iki yerde tutmak, biri değişince ötekini bayatlatmaktı. Kullanıcı satırı
elle kursa bile maket yine büyük çizilir.

### 2.2 KPI: gerçek veri, uydurma trend yok

| kart | kaynak |
|---|---|
| Toplam daire | `building-map` (sayfada zaten çekiliyor) |
| Tahsilat oranı | `/finans/tahsilat-gostergesi` — tahsil/tahakkuk + `degisim_puan` |
| Açık talepler | `/unit-complaints/gorunur-sayi` + `?oncelik=yuksek` |
| Toplam borç | `/finans/yaslandirma?ozet=true` — tutar + borçlu daire sayısı |

**Yeni sunucu ucu açılmadı**: beşi de backend'de vardı ve başka
ekranlarda kullanılıyordu. P244'ün "yeni uç yok" kilidi bu gerekçeyle
güncellendi — iddia hâlâ *"pano sunucuya yeni uç eklettirmez"*.

**Trend yalnız verisi olanda.** Sözleşme yalnız tahsilat için
`degisim_puan` veriyor; talep ve borç için önceki-ay karşılaştırması
**hiçbir uçta yok**. Ok çizmek uydurmak olurdu.

**YAPILAMAYAN — açıkça:** referansın "Toplam Daire %87 dolu / %13 boş"
alt satırı **çizilemedi**. Doluluk bilgisi hiçbir uçta yok (`Unit`
şemasında sakin/doluluk alanı bulunmuyor) ve daire başına
`/units/{id}/residents` çağırmak bir KPI için N istek demekti. Yerine
gerçek olan yazıldı: "3 blokta". **Bu bir backend toplaması ister.**

### 2.3 Devriye sayaçları kaybolmadı — rol uyumlu oldu

Şerit eskiden "geciken okutma" ve "bugünkü tur"u gösteriyordu.
Referansın dört başlığı mali; mali yetkisi **olmayan** rolde o iki kart
zaten çizilmiyor ve şerit yarıya düşerdi.

Çözüm: yönetim referansın dördünü görür, **yetkisiz rol aynı yerde
kendi dört sayısını**. Hiçbir bilgi silinmedi.

### 2.4 Maket: iki görünüm zaten vardı, birleştirildi

3B sahne panoda, plan haritası `/schematic`te. Referans ikisini **aynı
kartta** yan yana koyuyor. Yeni görünüm yazılmadı; var olan ikisi tek
kartta birleşti ve **seçim ortak durumda** — sekme değişince seçili
daire korunur.

**Lejant referansın altısı değil, bizim ikimiz.** Referans
Dolu/Boş/Borçlu/Kiracı/Malik/Tadilat diyor; bizim maketimiz bu sayfada
yalnız **iki** durum üretiyor (şikâyeti var / yok). Altı durumlu bir
lejant, hiçbir zaman çizilmeyecek dört renk ilan ederdi.

**Etkileşim korundu** (P244 karar 6): geometri, kamera, tıklama, seçim
tek satır değişmedi.

### 2.5 Son işlemler yalnız platform adminine

Ölçüldü: `GET /audit` `require_role("admin")` ile korunuyor, yöneticiye
**403**. Denetim kaydı bir KVKK yüzeyidir; yöneticiye açmak bir arayüz
turunun vereceği karar değil. Yetkisiz rolde bölüm **hiç çizilmez** —
boş bir kart bırakmak, olmayan bir şeyin yerini ayırmaktı.

### 2.6 Kendi hatam: aynı metin iki anlamda

Hızlı işlem düğmesini "Aidat tahsilatı" diye adlandırdım — KPI kartının
etiketiyle **aynı dize**. Test "birden çok eleman" diyerek yakaladı.
P239'da kaydedilen dersin aynısı; düğme "Tahsilat gir" oldu.

---

## 3. EKRAN GÖRÜNTÜLERİ — `docs/P245/`

| dosya | ne |
|---|---|
| `ozet-yonetici-acik-standart.png` | ana referans karşılaştırması |
| `ozet-yonetici-koyu-standart.png` | koyu tema |
| `ozet-yonetici-acik-buyuk.png` | Büyük görünüm modu |
| `ozet-denetci-acik-standart.png` | denetçi (salt okuma) |
| `ozet-admin-acik-standart.png` | platform admini (`panel.*`) |

**ÖLÇÜLEN SINIR — istenen üç rolden ikisi alınamadı:** `security` ve
`resident` hesapları web girişinde **403** alıyor — *"Bu hesap türü
Yönetiyor mobil uygulamasında çalışır"* (P129 kararı). O iki rolün
**web özet sayfası yoktur**. Yerine web'de panoyu gören diğer iki rol
alındı: **denetçi** ve **admin**.

---

## 4. Bu turda YAPILMAYAN — açıkça

* **Karşılama bandında gerçek fotoğraf yok.** `Tenant` şemasında
  logo/kapak alanı bulunmuyor; fotoğraf çizilemezdi. Nötr bina silueti
  çizildi (ağ isteği yok, temayla kaymaz). Gerçek fotoğraf **sözleşme +
  backend** işi.
* **Daire doluluk oranı** (yukarıda).
* **Yan panel tek bölüm**: Hızlı İşlemler ve Duyurular birlikte
  gizlenir/taşınır, ayrı ayrı değil. Motor satır başına bir bölüm/sütun
  çizdiği için ikisini ayırmak onları yan yana koymak demekti.
* **Yalnız Özet sayfası.** Diğer altı grup bu turda açılmadı.

## 5. Doğrulama

`npm run dogrula` (tsc + next lint + vitest + **next build**) →
**çıkış kodu 0** · **2121 test yeşil** · **YENİ** `p245-ozet-duzeni`
(7 iddia); iki kırma denendi, ikisi de yakalandı.

---

# P245 §2 — GÜVENLİK GRUBU (ui3)

Referans: **`ui3.png`** — dokuz güvenlik ekranı.

## 6. Ölçülen ortak desen

ui3'teki dokuz ekranın **hepsinde** aynı iskelet var: başlık + bir
cümlelik açıklama → **KPI şeridi** → filtre çubuğu → yoğun tablo.

Playwright ile yedi ekranı topluca görüntüledim. Ölçüm:

| ekran | başlık | KPI | filtre |
|---|---|---|---|
| `/arac-gecisleri` | ✔ | ✔ | ✔ (P244 §6a) |
| `/kameralar`, `/olaylar` | ✔ | ✔ | ✘ |
| `/patrol-plans`, `/checkpoints`, `/panik`, `/akilli-ev`, `/vardiya-plani`, `/kamera-kayitlari` | ✘ | ✘ | ✘ |

Yani altı ekran **üçünden hiçbirine** sahip değildi — `/patrol-plans`
çıplak bir başlık ve tek satırlık bir tablodan ibaretti.

Bu turda **dördü** kapatıldı: `/patrol-plans`, `/checkpoints`,
`/panik`, `/akilli-ev`.

## 7. UYDURULMAYAN SAYILAR — açıkça

Referansın KPI'ları her zaman bizde karşılığı olan sayılar değil:

* **Devriye Planları** — ui3 *"%92 Tamamlanma"* ve *"2 Aksama"* diyor.
  İkisi de plan listesinde **yok**, tur geçmişinde. Yerine bu listenin
  gerçekten yanıtladığı dört soru kondu (aktif plan, toplam plan,
  kontrol noktası, vardiya).
* **Acil Durum Çağrıları** — ui3 *"4 dk Ort. Müdahale"* ve *"%96
  Zamanında"* diyor. İkisi de çağrı başına **müdahale başlangıcı**
  damgası ister; kayıtta `created_at` ve `kapandi_at` var, **aradaki
  adım yok**. Sunucu onu vermeden hesaplanan bir "4 dk" ölçülmemiş bir
  sayıdır.
* **NFC Noktaları** — ui3 "Aktif / Pasif / **Bakımda**" diyor; bizde
  durum alanı iki değerli (`aktif`). Üç durumlu bir şerit, hiçbir zaman
  dolmayacak bir kart ilan ederdi. Üçüncü kart yerine **bugün okutulan**
  kondu — bu ekranın asıl sorusu "noktalar çalışıyor mu".

## 8. Hat iki GERÇEK KUSUR daha buldu

### 8.1 Giriş formu parolayı ADRES ÇUBUĞUNA yazıyordu

Ekran görüntüsü betiği formu **hidrasyon tamamlanmadan** gönderdi ve
tarayıcı **native** gönderim yaptı. `<form>`un varsayılanı GET olduğu
için kimlik ve **parola** adres çubuğuna düştü:

```
/login?username=...&password=...
```

Oradan tarayıcı geçmişine, `Referer` başlığına ve sunucu erişim
günlüklerine gider.

`onSubmit` bunu normalde engeller — **ama yalnız JS hazırsa**.
Hidrasyon gecikmesi, JS hatası ya da yavaş ağ formu bir anlığına
korumasız bırakıyordu. `method="post"` eklendi: o pencerede de gönderim
gövdeye gider. Sunucuda bu yolu karşılayan bir POST işlevi **yok** (405)
ve olması da gerekmiyor — istenen şey başarılı bir gönderim değil,
**sızmayan bir başarısızlık**.

### 8.2 `npm run build` çalışan dev sunucusunu bozuyor

Yarım saat "giriş çalışmıyor" diye aradım. Kök neden: `next.config`
`output: "standalone"` ve `npm run dogrula` içindeki `next build`,
çalışan `next dev`in `.next` dizinini **eziyor**. Statik parçalar 404
dönüyor, React hiç yüklenmiyor, sayfa sunucu çizimi olarak "çalışıyor"
görünüyor ama **hiçbir şey tıklanmıyor**.

**Kural:** ekran görüntüsü alırken `npm run dogrula` koşulmaz; zincir
en sona bırakılır ve sonrasında dev sunucusu yeniden başlatılır.

## 9. Betikteki iki yöntem hatası (ikisi de ölçümle bulundu)

* **Ard arda giriş**: her rota için yeniden giriş yapılıyordu; sekiz
  ardışık denemede hepsi zaman aşımına düştü. Tek oturum, çok rota.
* **"İçerik var" yetmedi**: `innerText.length > 200` koşulu sayfa
  başlığı çizilir çizilmez doğru oluyordu ve tablo hâlâ iskeletken
  görüntü alınıyordu (`/patrol-plans` yarım çıktı). Koşul artık
  **içerik var VE iskelet yok**.

## 10. Bu turda YAPILMAYAN — açıkça

* `/vardiya-plani` (1353 satır) ve `/kamera-kayitlari` (270) —
  başlık/KPI/filtre üçlüsü **eklenmedi**.
* Altı ekranın hiçbirine **filtre çubuğu** eklenmedi; bu tur KPI
  şeridine ve başlığa odaklandı.
* `ui3`ün "Bildirimler" ekranı (`/notifications`) ölçülmedi.
* Diğer beş grup (tesis, finans, operasyon, iletişim, tanımlar) bu turda
  açılmadı.

## 11. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2121 test yeşil**.
Ekran görüntüleri: `docs/P245/` altında güvenlik grubundan yedi ekran.

---

# P245 §3 — GÜVENLİK GRUBU TAMAMLANDI

## 12. Kalan iki ekran

* **`/kamera-kayitlari`** — başlık + açıklama + iki kartlık şerit.
  **Sayılar kamera listesinden**, kayıt sayısından değil: bu ekranın ucu
  bir **aralık** sorar ve kayıt listesi **döndürmez**; "kaç kayıt var"
  sorusunu yanıtlayan bir uç **yok**. Ayrıca NVR kaydı sitede kalır
  (P213) — bulutta bir kayıt sayacı zaten olamaz.
  **Mevcut sorgu kutusu `FiltreCubugu`'na çevrilmedi:** o kutu bir liste
  süzgeci değil, kaydı getirmek için **zorunlu** alanlar; "temizle" ve
  "aktif süzgeç sayısı" orada anlamsız olurdu.
* **`/vardiya-plani`** — yalnız başlık paylaşılan bileşene taşındı.
  P240 §5a'nın kararı korundu ve güçlendi: asıl eylem başlık satırında,
  tek birincil düğme. Kontrol kümesine (görünüm seçici, filtreler,
  tazele, araçlar) **dokunulmadı** — P240/P241/P207'de ölçülmüş bir
  düzen. **KPI şeridi eklenmedi:** referansta da (ui3) bu ekranda şerit
  **yok**; eklemek referansı aşmak olurdu.

## 13. Filtre çubukları — ve sayaç tuzağı

Dört ekrana süzgeç geldi: `/olaylar` (durum), `/patrol-plans` (aktiflik),
`/checkpoints` (aktiflik), `/panik` (durum). **Hepsi sunucuda** —
istemcide süzmek yalnız görünen sayfayı arar.

**Her birinde aynı tuzak vardı ve dördünde de kapatıldı:** şerit
sayıları aynı listeden besleniyordu; süzgeç eklenince *"Kapatılmış"*
seçildiğinde **"Açık olay: 0"** yazacaktı — yani ekran, açık olay
**olmadığını** söyleyecekti. Sayaçlar artık **ayrı, süzgeçsiz** bir
istekten (P244 §8c'de bakım ekranında ölçülüp kilitlenen dersin aynısı).

`/kameralar` ve `/kamera-kayitlari`ya süzgeç **eklenmedi**: ui3'te o
ekranlardaki kontroller (ızgara yoğunluğu, harita, tam ekran, aralık)
**görünüm** kontrolleri, liste süzgeci değil.

## 14. BEŞİNCİ KEZ: `/api/violations` `durum`u düşürüyordu

Arka uç `durum`u destekliyor; vekil yalnız `limit`/`offset` taşıyordu.
Yani ekrana bir durum süzgeci eklendiği anda **sessizce çalışmayacaktı**.

Aynı kusur sınıfının **beşinci** örneği (P173, P189, P213 + P244 §6, §8a,
§8c). Kilitlendi; kırma denendi, yakalandı.

## 15. Hat ÜÇ KUSUR DAHA buldu

### 15.1 `<tr>` içinde `<tr>` — sekiz dosyada hidrasyon çöküyordu

`TabloBasligi` `<tr>`i **kendi** çiziyor. On beş çağrı yerinin
**dokuzu** içeriği ayrıca bir `<Tr>` ile sarıyordu → `<tr><tr>`,
**geçersiz HTML**. Tarayıcı iç `<tr>`i dışarı taşıyor, sunucu
çiziminden **farklı** bir ağaç oluşuyor ve React hidrasyonu **düşüyor**:
*"Hydration failed because the initial UI does not match what was
rendered on the server."* Sonuçta sayfanın tamamı istemcide yeniden
çiziliyordu.

**Hiçbir test görmedi:** `tsc` JSX'in HTML geçerliliğini denetlemez,
jsdom iç içe `<tr>`i sessizce kabul eder ve görünüm neredeyse aynı
kalır. Gerçek tarayıcıda, ekran görüntüsü alınırken konsolda çıktı.

Bileşenin sözleşmesi yazıldı, dokuz çağrı yeri düzeltildi, **yeni
`p245-tablo-basligi-tek-tr`** kilidi eklendi (kırma yakalandı).

### 15.2 `w-full` kazanıyordu, `w-auto` kaybediyordu

Filtre çubuğundaki durum seçimi şeridin **tamamını** kaplıyordu.
`Secim`in taban sınıfı `w-full` ve çağıranın verdiği `w-auto`
kazanmıyor: iki sınıfın **özgüllüğü aynı**, hangisinin kazandığını
`className` sırası değil **üretilen CSS'teki sıra** belirler. Kural
açıkça yazıldı: çağıran bir genişlik sınıfı verdiyse taban `w-full`
**eklenmez**.

### 15.3 `/panik`: yüklenirken boş tablo, boş durumda "alert" yazısı

Koşul yalnız "boş durum"u ayırıyordu; `isLoading` doğruyken else dalına
düşerek **başlıksız, satırsız bir tablo** çiziyordu. İskelet eklendi.

Ayrıca `ikon="alert"` — `BosDurum.ikon` bir `ReactNode` bekler; dize
verilince **aynen çizilir** ve ekranda "alert" yazıyordu. jsdom'da da
öyleydi ama **hiçbir iddia onu sorgulamıyordu**.

## 16. Bilinçli güncellenen iddia

`guvenlik-ekranlari` testi "kaynak seçtirilmez" kuralını *"sayfada hiç
`combobox` yok"* diye ölçüyordu — kuralın kendisi değil bir **vekil**.
Sayfaya durum süzgeci gelince düştü. Sorgu **diyaloğa** kapsamlandı;
iddia değişmedi.

## 17. Bu turda YAPILMAYAN — açıkça

* `/kameralar`a başlık/şerit **vardı**, süzgeç eklenmedi (yukarıda).
* `ui3`ün "Bildirimler" ekranı (`/notifications`) hâlâ ölçülmedi.
* Diğer beş grup açılmadı.

## 18. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2126 test yeşil**.

---

# P245 §4 — TESİS GRUBU (ui2)

Referans: **`ui2.png`** — tesis operasyonu + finans; 23 ekran, hepsinde
aynı iskelet (KPI şeridi → filtre → yoğun tablo).

## 19. Ölçüm: tesis grubu büyük ölçüde hazırdı

P244'te dokunulan ekranlar (`/units`, `/assets`, `/bakim`, `/schematic`,
`/tasks`, `/ziyaretciler`) zaten başlık + şerit taşıyordu. Gerçek
boşluklar:

| ekran | eksik |
|---|---|
| `/rezervasyon-yonetimi` | başlık, açıklama, şerit — **üçü de yok** |
| `/yerel-isletmeler` | başlık yok |
| `/units` | filtre çubuğu yok (ui2 "Daireler"de blok + durum + arama) |

## 20. `/units`: serbest metin süzgeci → seçim

Blok süzgeci elle yazılan bir metin alanıydı. Var olmayan bir blok adı
yazmak **boş liste** üretiyordu ve kullanıcı bunu *"daire yok"* diye
okuyordu. Seçenekler artık `/api/blocks`ten — o liste **zaten
çekiliyordu** (bağımlılık uyarısı için).

Aktiflik süzgeci de eklendi (arka uç `?aktif=` destekliyordu).
**Şerit sayıları etkilenmez:** özet `/units/arsa-payi-ozeti`ten gelir ve
o uç süzgeç **almaz** — "A blok" seçilince toplam daire sayısı değişmez.

## 21. `/rezervasyon-yonetimi`: sayaçlar iki sekmeden de bağımsız

Her iki sekme kendi listesini çekiyor ve **ikisi de süzgeçli**. Şerit
onlardan beslenseydi, sekme ya da tarih değişince sayılar da değişirdi —
*"bugün 3 rezervasyon"* yerine *"seçili süzgeçte 3"*. Ayrı sorgular
(`?tarih=`, `?gecmis=false`, `limit=1` → `meta.total`).

## 22. Hat ÜÇ KUSUR DAHA buldu

### 22.1 Yeşil zemin üzerine yeşil metin — kontrast 1.53

`/rezervasyon-yonetimi`nin elle kurulmuş "Aktif" rozeti:
zemin `--yz-success-edge` (#159946), metin `--yz-success-ink` (#107736).
**Ölçüldü: 1.53** (eşik 4.5). Etiket okunmuyordu.

Tarama üç yerde daha aynı sınıfı aradı ve bir tane daha buldu:
`pano/widget-seridi` beyaz metni `--yz-danger-edge` (#ef4444) üzerinde
**3.76** ile çiziyordu — küçük metin, eşik 4.5. `--yz-danger-fill`
(#dc2626) tam bu iş için var: **4.83**.

**Kural P244 aşama 1'de yazılmıştı ama hiçbir yerde zorlanmıyordu:**
`-edge` **grafik** eşiğidir (3.0), metin değil. **YENİ**
`p245-dolgu-uzerinde-metin` kilidi; iki kırma yakalandı.

`/panik`in kırmızı tam ekran alarmı **kontrol edildi ve temiz**: kırmızı
yalnız arka örtü, metin `--yz-surface-1` kartın üzerinde.

### 22.2 Çıplak özel özellik sözdizimi — renk hiç uygulanmıyordu

`/yerel-isletmeler` köşeli parantez içinde `color:` öneki **olmadan**
değişken adı yazıyordu. Tailwind bu biçimde değerin bir **renk**
olduğunu çıkaramaz: kenar için **genişlik** üretmeye çalışır ve renk hiç
uygulanmaz.

`p244-token-var-mi` kilidi token'ın **tanımlı** olduğunu ölçüyordu,
**sözdizimini** değil — bu ikisi ondan kaçmıştı. Kilit aynı turda
genişletildi.

### 22.3 Betikteki üçüncü yöntem hatası

`/units` görüntüsünde 27 kayıtlı listenin yalnız **iki satırı** doluydu,
gerisi boş şerit. Sebep veri değil: `VeriTablosu` satırları **kademeli**
beliriyor ve görüntü o kademe bitmeden alınıyordu.

Tarayıcı **azaltılmış harekete** alındı (`reducedMotion: "reduce"`) —
uydurma bir durum değil, deponun **zaten saygı duyduğu** desteklenen bir
hâl (`hareketVar`). Ayrıca `animations: "disabled"`.

## 23. Bu turda YAPILMAYAN — açıkça

* `/building-editor` (1327 satır) — yalnız başlık var, şerit/filtre
  eklenmedi.
* `/bakim`, `/schematic`, `/assets`, `/tasks`, `/ziyaretciler` — filtre
  çubuğu **eklenmedi** (başlık + şerit zaten vardı).
* `ui2`nin **finans** yarısı (Aidat, Finans, Borçlandırmalar,
  Tahsilatlar, Giderler, Gelirler, Virman, İade, Açılış, Banka,
  Otomasyon, Fazla Mesai, Borçlular, Bütçe, İcra, Sayaç, Raporlar) bu
  turda açılmadı — ayrı bir grup.

## 24. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2130 test yeşil**.
Ekran görüntüleri: `docs/P245/` altında tesis grubundan altı ekran.

---

# P245 §5 — FİNANS GRUBU (ui2)

## 25. Ölçüm: on yedi ekranın on üçünde başlık bile yok

| ekran | başlık | KPI | filtre |
|---|---|---|---|
| `/dues` | ✔ | ✔ | ✔ (P244 §7b) |
| `/finans/tahsilatlar`, `/giderler`, `/gelirler` | ✔ | ✔ | — (ortak `HareketSayfasi` kabuğu, P244 §7a) |
| `/finans` | ✘ | yerel kart | ✔ |
| `/finans/borclandirmalar`, `/banka`, `/virman`, `/iade`, `/acilis`, `/mesai`, `/borclular`, `/sayac-okuma`, `/raporlar` | ✘ | ✘ | ✘ |

Bu turda **dördü** kapatıldı: `/finans`, `/finans/borclular`,
`/finans/mesai`, `/sayac-okuma`.

## 26. `/finans`: ikinci bir kart tanımı vardı

Sayfa **kendi** `OzetKart` bileşenini taşıyordu — etiket + sayı, ikon
yok, durum rengi yok. Aynı ekranda referans (ui2 "Finans") ikonlu ve
anlam taşıyan kartlar gösteriyor. İkinci bir kart tanımı, boşluk ve
tipografinin iki yerde ayrışması demekti — P244 boyunca kapatılan tam o
sınıf. **Değerler değişmedi**: aynı uç, aynı alanlar.

## 27. `/finans/borclular`: şerit kova seçiminden bağımsız

Sayfadaki kova seçimi listeyi daraltır, **şeridi değil**. Aksi hâlde
"90+" seçildiğinde *"Toplam borçlu: 3"* yazardı — oysa toplam borçlu
değişmez.

**Ortalama türetildi ama uydurulmadı:** daire sayısı sıfırken bölme
yapılmaz, "—" yazılır.

## 28. `/finans/mesai`: ücreti tanımsız kişi tutara girmez

`fazla_mesai_kurus` null gelir; toplama katmak **olmayan bir parayı
saymak** olurdu. Kaç kişinin ücretinin tanımsız olduğu alt bilgide
ayrıca yazıyor.

Bu ekranda şerit **seçilen ayın** özeti: dönem değişince sayıların da
değişmesi **doğru** davranıştır (bir "genel toplam" değil).

## 29. `/sayac-okuma`: ŞERİT EKLENMEDİ — ve bu bir atlama değil

Referansta (ui2) üstte "128 Toplam / 6 Okunmadı / 122 Tamamlandı" ve bir
**liste** var. Bizdeki ekran liste değil, adım adım **giriş sihirbazı**:
dönem seç → bölüm seç → değerleri gir → onayla. Sihirbazın üstüne "kaç
sayaç var" şeridi koymak, kullanıcının **şu anki adımıyla ilgisi
olmayan** bir sayı göstermek olurdu; ilerleme zaten adım şeridinde.

Yalnız başlık + açıklama eklendi.

## 30. Bu turda YAPILMAYAN — açıkça

* `/finans/borclandirmalar` (762), `/finans/banka` (629),
  `/finans/otomasyon` (692), `/finans/virman` (150), `/finans/iade`
  (177), `/finans/acilis` (181) — **dokunulmadı**.
* `/raporlar` — P244 §7b'de ölçülmüştü: zaten kategorili kart ızgarası,
  referansın deseni. Dokunulmadı.
* Bu grupta **hiçbir yeni filtre çubuğu** eklenmedi.

## 31. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2130 test yeşil**.
Ekran görüntüleri: `docs/P245/` altında finans grubundan dört ekran.

---

# P245 §6 — FİNANSIN KALANI

## 32. Şerit YAZILMIŞTI ama HİÇ KULLANILMIYORDU

`FinansOzetSeridi`de **`borclandirma` varyantı P244 §7a'da tanımlanmış**
ama `/finans/borclandirmalar`a **bağlanmamıştı**: öteki altı finans
ekranı ortak `HareketSayfasi` kabuğunu kullanıyor ve şerit onun `ozet`
yuvasından geliyor; bu sayfa kendi düzenini taşıdığı için yuvası yoktu.

Yani **kod vardı, ekranda yoktu**. Başlık + açıklama eklendi ve şerit
bağlandı.

## 33. Virman / iade / açılış: üç sayı yerine bir doğru sayı

Referansta (ui2) üçünün de üstünde sayı serisi var; örneğin ödeme
iadesinde *"12 Bekleyen / 8 Onaylanan / 3 Reddedilen"*.

**Bizde o durumlar yok:** üçü de **tek deftere** (P192) yazılan hareket
tipleri ve iade için bir **onay akışı tanımlı değil**. Üç sayı uydurmak
yerine üçünün de gerçekten yanıtladığı soru gösterildi — **kasa
toplamı**:

* **virman** — para kasalar arasında taşınır, toplam **değişmemeli**
* **açılış** — açılış fişleri toplamı **doğrudan kurar**
* **iade** — iade kasadan **çıkar**

Yani kasa toplamı bu üç ekranda da işlemin **sonucudur**. Yeni
`tur: "kasa"` varyantı.

## 34. `/finans/banka`: şerit EKLENMEDİ — ve bu bir atlama değil

Referansta bu ekranın üstünde **sayı şeridi yok**; **banka marka
kartları** listesi var (hesap adı, son senkron, durum). O liste bir
**hesap listesi** ekranı ister; bizim ekranımız bugün bir **yükleme
akışı + eşleştirme tablosu** (P244 §7b'de ölçülüp açık madde
yazılmıştı). Uydurma bir şerit koymak, referansın sorduğu soruyu
yanıtlamadan **yanıtlamış gibi yapmaktı**. Yalnız başlık taşındı.

## 35. Ortak şerit ikonsuzdu

`FinansOzetSeridi` kartları ikonsuz çiziliyordu; `/finans`, `/dues` ve
güvenlik ekranlarının şeritleri ikonluydu. **Aynı bileşen ailesi iki
farklı görünümdeydi** ve referansta her kartın solunda ikon var. Tek
dosyada düzeltildi — **altı finans ekranı** birden.

## 36. Finans grubu — durum

| ekran | başlık | şerit |
|---|---|---|
| `/dues`, `/finans`, `/finans/borclular`, `/finans/mesai` | ✔ | ✔ |
| `/finans/tahsilatlar`, `/giderler`, `/gelirler` | ✔ | ✔ |
| `/finans/borclandirmalar` | ✔ | ✔ **(bu tur)** |
| `/finans/virman`, `/iade`, `/acilis` | ✔ | ✔ **(bu tur, tek kart)** |
| `/finans/banka`, `/sayac-okuma` | ✔ | **bilerek yok** (gerekçe yukarıda) |
| `/finans/otomasyon` | ✔ (P244 §7b) | bilerek yok |
| `/raporlar` | zaten referansın deseni (P244 §7b) | — |

**Grubun tamamında başlık var.**

## 37. Bu turda YAPILMAYAN — açıkça

* Finans grubunda **hiçbir yeni filtre çubuğu** eklenmedi. `/finans`ta
  tip süzgeci P244 §9c'de çubuğa taşınmıştı; ötekilerde süzgeç yok.
* `/finans/banka`nın **marka kartı listesi** yapılmadı (ayrı düzen
  kararı, P244 §7b'den beri açık).
* `/finans/otomasyon`da **yerinde aç/kapat** hâlâ yok (yazma ucu yok,
  P244 §7b).

## 38. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2130 test yeşil**.
Ekran görüntüleri: `docs/P245/` altında finanstan dokuz ekran.

---

# P245 §7 — OPERASYON GRUBU

## 39. Ölçüm: grup zaten büyük ölçüde hazırdı

`/bakim`, `/tasks`, `/assets`, `/schematic`, `/complaints`, `/kargolar`,
`/ziyaretciler`, `/gorevlerim`, `/taleplerim`, `/dis-hizmetler` —
**hepsinde başlık var** (P244 §8a–§8c). Gerçek boşluklar:

| ekran | eksik |
|---|---|
| `/ziyaretciler` | filtre yok — **ve BFF dört süzgeci düşürüyordu** |
| `/bakim` | süzgeç kartın içinde, şerit değil |
| `/schematic` | filtre yok |

## 40. ALTINCI KEZ: `/api/visitors` dört süzgeci birden düşürüyordu

Arka uç `icerde`, `unit_id`, `baslangic`, `bitis` destekliyor
(`list_visitors`); vekil yalnız `limit`/`offset` taşıyordu. Yani ekran
**"içerideki ziyaretçiler"** diye süzemiyordu — kapıdaki görevlinin en
sık sorduğu soru.

Aynı kusur sınıfının **altıncı** örneği: P173, P189, P213 + P244 §6
(araç geçişleri), §8a (kargo), §8c (görevler), P245 §3 (olaylar).
Kilitlendi; kırma yakalandı.

## 41. Şerit tuzağı — yedinci kez aynı ders

`/ziyaretciler`in şeridi görünen listeden sayıyordu ve bu **o gün
doğruydu**: süzgeç yoktu. Süzgeç gelince aynı kod, *"Çıkmış"*
seçildiğinde **"İçerideki: 0"** yazacaktı — yani ekran, içeride kimse
**olmadığını** söyleyecekti. Sayaçlar ayrı, süzgeçsiz bir isteğe
bağlandı.

`/bakim`da bu tuzak **yoktu**: sayaçlar P244 §8c'de zaten ayrı
sorgulara bağlanmıştı. Süzgeç kartın içinden şeride çıkarken hiçbir şey
bozulmadı — o turda ödenen bedel bu turda işe yaradı.

## 42. `/bakim`: süzgeç karttan şeride

Seçim kartın üst satırındaydı ve her ekranda başka bir yerde duran bir
kontrol kümesi üretiyordu; referansta süzgeçler tablonun **üstünde**
kendi şeritlerinde. "Ekipman ekle" düğmesi de şeridin `eylemler`
yuvasına geçti.

## 43. Bu turda YAPILMAYAN — açıkça

* `/schematic`e filtre eklenmedi (blok/yoğunluk süzgeci için uçta
  parametre yok; haritanın kendisi zaten tüm binayı tek yanıtta veriyor).
* `/taleplerim` ve `/gorevlerim`e şerit eklenmedi — P244 §8b'de
  ölçülmüştü: ikisi de kart dili ve sakin/saha tarafının **kısa**
  listeleri; şerit orada boş bir sayı satırı olurdu.
* `/tasks`, `/assets`, `/complaints`, `/kargolar`, `/dis-hizmetler`
  zaten üçlüyü taşıyor; dokunulmadı.

## 44. Doğrulama

`npm run dogrula` → **çıkış kodu 0** · **2134 test yeşil**.
