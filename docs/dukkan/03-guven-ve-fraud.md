# DUKKAN — 03 · GÜVEN VE DOLANDIRICILIK

> Prompt'unda **"EN KRİTİK BÖLÜM"** dediğin yer. Tek satırla geçilecek bir
> konu olmadığı için burada uzun.
>
> Bölümün tezi şu: **bir pazar yerini öldüren şey kötü yazılım değil, kötü
> güvendir.** Yorumlarına inanılmayan bir platform, teknik olarak kusursuz
> olsa bile boştur. Buradaki kararların çoğu teknik değil **operasyonel** —
> ve bunu bir eksiklik olarak değil, doğru cevap olarak yazıyorum.

---

## 1. Tehdit haritası

| # | Tehdit | Kim yapar | Zarar |
|---|---|---|---|
| T1 | Sahte olumlu yorum | İşletme (kendi/tanıdık/satın alınmış) | Yorumlar anlamsızlaşır → platform ölür |
| T2 | Sahte olumsuz yorum | Rakip | Dürüst işletme haksız cezalanır → esnaf platformu terk eder |
| T3 | Sahte işletme | Dolandırıcı | Kullanıcı kapısına dolandırıcı gelir → **ciddi güvenlik ve hukuk riski** |
| T4 | Kimlik gaspı | Var olan bir esnafın adıyla kayıt | Marka zararı + T3 |
| T5 | Kapora dolandırıcılığı | Sahte/gerçek işletme | Maddi zarar; platform "aracı" görülür |
| T6 | Talep hasadı | Sahte işletme | Sakinlerin telefon/adresi toplanır → **KVKK ihlali** |
| T7 | Yorum şantajı | Kullanıcı | "Ödeme yapmazsan 1 yıldız" |
| T8 | Çoklu hesap | Herkes | T1/T2'nin çarpanı |

**T6'nın altını çiziyorum:** kimse sahte işletme kurup dolandırıcılık yapmak
zorunda değil — sadece **talepleri okuyarak** bir sitedeki sakinlerin
telefonlarını ve adreslerini toplayabilir. `02-kimlik-ve-yetki.md` §6.3'teki
iki aşamalı görünürlük, yalnızca bir KVKK inceliği değil, **T6'ya karşı asıl
savunma**. Teklif aşamasında yalnız mahalle görünmesinin sebebi bu.

---

## 2. Yorum güveni — önerdiğim model

### 2.1 Asıl gerilim

İdeal kural: **"yalnız platform üzerinden tamamlanmış işe yorum yazılır."**
Sahte yorumu neredeyse tümüyle keser.

Gerçek hayat: kullanıcı numarayı görür, **telefonla arar**, iş biter.
Platform bunu hiç görmez. Bu bir kaçak değil, **beklenen davranış** —
ustayla iş sözlü yapılır.

İdeal kuralı uygularsam: yorumların %90'ı doğmaz, işletmelerin çoğu "0 yorum"
görünür, kullanıcı hiçbir işletmeye güvenemez ve **platform daha doğmadan
işlevsiz** olur. Katı olan kural, burada güvenli olan kural değil.

### 2.2 Önerim: **iki katman, açıkça etiketli**

> Yorumları filtrelemek yerine **ayırıyorum**. Kullanıcı hangi yorumun neye
> dayandığını **görüyor** ve kararı kendi veriyor.

**Katman A — "Platform üzerinden alınan hizmet"** (`yorum.kaynak='platform'`)
- Yalnız `is` satırı olan ve `durum='tamamlandi'` olan işe.
- `UNIQUE(is_id)` → bir işe bir yorum. Zorlaması veritabanında.
- Yayına **doğrudan** girer. Rozet taşır. Sıralamada **tam ağırlık**.

**Katman B — "Davetli değerlendirme"** (`yorum.kaynak='davet'`)
- İşletme, işi yaptığı müşterinin numarasına platformdan **davet** gönderir
  (`yorum_davet`). Müşteri **OTP ile** doğrulanır, sonra yorum yazar.
- Rozet **taşımaz**, "İşletmenin daveti üzerine" diye etiketlenir.
- Sıralamada **düşük ağırlık**.
- **Davet kotası — T1'e karşı asıl kilit:** bir işletmenin aylık davet hakkı,
  o ayki **platform etkinliğiyle** orantılı (verilen teklif sayısı, tamamlanan
  iş sayısı). Hiç teklif vermemiş bir işletme davet gönderemez.

  *Neden kota:* kotasız davet, "bana 50 yorum yaz" demenin platform onaylı
  yolu olurdu. Kota, sahte yorum üretmenin maliyetini **gerçek iş yapmaya**
  bağlar. Bunu tamamen engelleyemem; **pahalı** hale getirebilirim.

- Bir işletme + bir telefon: **90 günde bir** davet yorumu
  (`UNIQUE(isletme_id, yazan_id, kaynak)` + zaman kuralı).

### 2.2b Onayladığın üç ek şart

**(a) Rozet farkı GÖRÜNÜR olsun, ince yazıyla değil.**
Doğrulanmış yorum, listede **kendi rozetiyle ve kendi satırında** durur;
davetli yorum ayrı bir başlık altında toplanır. Aynı listeye karıştırıp
sonuna küçük bir etiket iliştirmek, farkı *teknik olarak* göstermek ama
*fiilen* gizlemek olurdu. Profil özetinde iki sayı **ayrı ayrı** yazılır.

**(b) Ağırlık farkı puan hesabında nasıl yansıyor — açık formül.**
`isletme.siralama_puani` hesabında yorum bileşeni şudur:

```
yorum_bileseni = (A_ortalama × A_sayisi × 1.0  +  B_ortalama × B_sayisi × 0.3)
                 / (A_sayisi × 1.0 + B_sayisi × 0.3)

güven_çarpanı  = min(1, (A_sayisi + 0.3 × B_sayisi) / 5)
```

- **A = doğrulanmış** (platform üzerinden iş), **B = davetli**.
- **0,3 katsayısı:** bir davetli yorum, doğrulanmış bir yorumun **üçte biri**
  kadar ağırlık taşır. Sıfır yapmak Katman B'yi anlamsız kılardı (o zaman
  hiç toplamayalım); bire eşitlemek ise davet kotasını tek savunma hattı
  bırakırdı.
- **`güven_çarpanı`** ayrı duruyor ve şunu çözüyor: tek bir 5 yıldızlı
  yorumu olan işletme, 40 yorumlu 4,6 ortalamalı işletmenin üstüne çıkmamalı.
  Az sayıda yorum, ortalamayı yükseltmez — **güveni** düşürür.
- Katsayılar **başlangıç değeri**, ölçülmüş sabit değil; ilk üç ayda
  gerçek veriyle ayarlanacak ve yapılandırmadan okunacak.

**(c) Kota aşımı ve şüpheli örüntü moderatöre BİLDİRİLİR.**
Sessizce reddetmek, kötüye kullanımı *görünmez* yapar — engellenen deneme de
bir sinyaldir. Moderasyon kuyruğuna düşenler:

| Olay | Neden sinyal |
|---|---|
| Davet kotası aşıldı | İşletme platform etkinliğinden fazla yorum topluyor |
| Aynı cihaz/IP'den aynı işletmeye 2+ yorum | T1/T8 örüntüsü |
| Yeni hesap → tek işletmeye tek olumsuz yorum → sessizlik | T2 (rakip saldırısı) |
| Yorumcu telefonu = işletme telefonu | T1, kesin ret + kayıt |
| Kısa sürede ≥N ödeme şikâyeti | T5, otomatik askı + inceleme |

**İşletme profilinde ikisi ayrı gösterilir:**
```
  ★ 4,7   ·  23 değerlendirme
     ✔ 8 platform üzerinden alınan hizmet
       15 davetli değerlendirme
```
Kullanıcı "8 doğrulanmış" ile "0 doğrulanmış, 40 davetli" arasındaki farkı
kendi okur. Bu, kararı gizlemek yerine **görünür** kılar.

### 2.3 Somut sorularının cevapları

**"İş platform dışında telefonla tamamlandıysa?"** → Katman B. Kotalı ve
etiketli. Yok saymak yorum sistemini boş bırakırdı.

**"Aynı kişi tekrar tekrar yorum yazabilir mi?"** → Hayır.
Katman A'da `UNIQUE(is_id)`; iki ayrı iş = iki ayrı yorum (meşru — usta iki
kez gelmiş olabilir). Katman B'de 90 gün.

**"İşletme kendine yorum yazabilir mi?"** → Şu kontrollerle engellenir:
1. `yorum.yazan_id == isletme.sahip_kullanici_id` → **kesin ret**.
2. Yorumcunun telefonu == işletme telefonu/WhatsApp'ı → **kesin ret**.
3. Katman A zaten `is` satırı ister; kendine iş veremez (1. kural).
4. Aynı cihaz/IP'den aynı işletmeye çoklu yorum → **moderasyon kuyruğu**
   (ret değil; ortak ev/işyeri IP'si meşru olabilir).

Tanıdığına yazdırmayı **teknik olarak engelleyemem.** Kotalı davet
(§2.2) bunu sınırlar; 4. kural örüntüyü yakalar. Dürüst cevap: bu
tümüyle çözülmüş bir problem değil, **maliyeti yükseltilmiş** bir problem.

**"Rakip kötü yorum yazarsa?"** → En zoru, çünkü meşru olumsuz yorumu
susturmadan çözmek gerekiyor. Dört kural:
1. **Katman A olumsuz yorumu doğrudan yayınlanır.** Gerçek bir iş var;
   susturmak yorum sistemini yalancı yapar.
2. **`is` kaydı olmayan olumsuz yorum (≤2 yıldız) `beklemede` başlar** →
   moderasyon. Yayın gecikir, kaybolmaz.
3. **İşletmenin herkese açık cevap hakkı** (`yorum_cevap`). Çoğu durumda
   en iyi savunma budur: okuyucu iki tarafı görür.
4. İşletme yorumu **silemez**; **işaretleyebilir** → moderasyon. Silebilseydi
   sistemin tamamı anlamsız olurdu.

Ayrıca örüntü izlenir: yeni açılmış, tek işletmeye tek olumsuz yorum yazıp
susan hesaplar (T2 + T8) — otomatik ret değil, **kuyruğa alma** sinyali.

---

## 3. Sahte işletme (T3/T4) — doğrulama basamakları

`isletme.dogrulama_seviyesi`, kademeli ve **görünür**:

| Sv | Ad | Şart | Kullanıcı ne görür |
|---|---|---|---|
| 0 | Kayıtlı | E-posta | Rozet yok — **arama sonuçlarında çıkmaz** |
| 1 | **Telefon doğrulanmış** | İşletme numarasına OTP | "Telefon doğrulandı" |
| 2 | **Belge doğrulanmış** | Vergi levhası/sicil + **insan** incelemesi | ✔ "Doğrulanmış işletme" |
| 3 | (V2) Kurumsal | e-İmza / MERSİS | — |

**Seviye 0 aramada çıkmaz** — kaydın kendisi ücretsiz ve anında olduğu için,
onu görünür kılmak T3'ü davet etmek olurdu.

**Vergi numarası doğrulaması — araştırdım, dürüst durum:**
GİB'in "vergi kimlik numarasından mükellefiyet sorgulama" hizmeti var, ancak
**tek geliştiricinin kullanabileceği, ücretsiz ve resmî bir toplu API bulduğuma
emin değilim.** Bulunmuş gibi tasarlamak, uygulamada çöken bir adım yaratırdı.

**V1 kararı:** vergi no **beyan** alınır (format + kontrol hanesi doğrulanır),
**belge fotoğrafı** istenir, **insan** onaylar. Otomasyon yok.

**İnceleme izi kalır (senin şartın).** `isletme_belge` satırı şunları tutar:
`tip` (vergi_levhasi / ustalik_belgesi / sicil), `dosya_yolu` (MinIO),
`durum` (bekliyor / onaylandi / reddedildi), **`inceleyen`** (hangi moderatör),
`incelendi_at`, `not`. Admin panelinde işletme kartında **"Vergi levhası:
yüklendi / incelendi / yok"** açıkça görünür.

Gerekçe: bir işletme sonradan sorun çıkardığında "biz bunu onaylarken neye
baktık?" sorusunun cevabı olmalı. İz yoksa cevap "hatırlamıyorum"dur ve
hem hukuki hem operasyonel olarak savunulamaz.

Bu bilinçli: günde 5-10 başvuruda insan incelemesi günde birkaç dakika, ve
bir insanın gözü sahte belgeyi bugün herhangi bir otomasyondan iyi yakalar.
Hacim büyüyünce otomasyon aranır — **önce hacim, sonra otomasyon.**

**"Telefon doğrulaması yeterli mi?"** → **Hayır.** Telefon yalnız numaranın
kontrolünü kanıtlar, **kimliği değil**; ön ödemeli hat 50 liraya alınır.
Bu yüzden Seviye 1 ile Seviye 2 ayrı: "telefon doğrulandı" kullanıcıya
"bu numara gerçek" der, "bu işletme gerçek" **demez**. İkisini tek rozette
birleştirmek kullanıcıya yalan söylemek olurdu.

**Kimlik gaspı (T4):** başkasının işletme adıyla kayıt. Ad benzerliği +
aynı bölge → **kuyruğa**. Gerçek sahibin itirazı için `sikayet` yolu (§5) ve
**işletme sahipliği devri** süreci gerekiyor. **EMİN DEĞİLİM:** bu sürecin
hukuki tarafını (kim hangi belgeyle sahiplik iddia edebilir) tasarlayacak
yetkinlikte değilim; hukuki görüş gerekiyor.

---

## 4. Kapora dolandırıcılığı (T5)

Platform üzerinden ödeme **yok ve olmayacak** (`00-mimari.md` §8.1) —
bu artık bir V1 ertelemesi değil, **kalıcı** bir tasarım kararı ve
testle kilitli (`test_dukkan_para_akisi_yok.py`). Para tamamen platform
dışında. Bu, ödeme riskini almadığımız anlamına geliyor ama
**algısal sorumluluğu** ortadan kaldırmıyor: kullanıcı ustayı *burada*
buldu, dolandırıldığında *buraya* kızacak.

Yapılabilecekler, hepsi ucuz:
- İş kabul ekranında **kalıcı uyarı**: *"Ödemeyi iş bitmeden yapma. Dukkan
  ödemelere aracılık etmez, kapora talebi bir uyarı işaretidir."*
- Şikâyet tipi olarak **"kapora/ödeme"** ayrı izlenir (§5) — tekrarlayan
  işletme örüntüsü görünür olsun diye.
- Bir işletme hakkında kısa sürede ≥N ödeme şikâyeti → **otomatik askı**,
  inceleme sonrası karar. Otomatik askı burada haklı: bekleyen her gün yeni
  mağdur demek ve askı **geri alınabilir** bir işlem.

---

## 5. Şikâyet mekanizması ve platform sorumluluğu (6563)

### 5.1 Hukuki durum — burada dürüst olmam gerekiyor

6563 sayılı Elektronik Ticaretin Düzenlenmesi Hakkında Kanun ve onu 2022'de
esaslı biçimde değiştiren 7416 sayılı Kanun, **elektronik ticaret hizmet
sağlayıcı (ETHS)** ve **elektronik ticaret aracı hizmet sağlayıcı (ETAHS)**
kavramlarını ve ETBİS kayıt yükümlülüğünü düzenliyor.

**EMİN DEĞİLİM — ve bu, belgedeki en önemli belirsizlik:**

1. **Dukkan V1'in ETAHS sayılıp sayılmayacağından emin değilim.** V1'de
   platform üzerinden **sipariş ve ödeme yok**; yapılan şey ilan/eşleştirme.
   **F8 notu:** gelir modeli reklama döndü. Sipariş/ödeme hâlâ yok, ama
   platform artık işletmelerden **reklam bedeli** alıyor. Bunun 6563
   değerlendirmesini değiştirip değiştirmediği avukata soruldu
   (`07-hukuki-sorular.md` S1, S17).
   Bu, mevzuatın "aracı hizmet sağlayıcı" tanımına girebilir de girmeyebilir de.
   Ayrım **önemsiz değil**: ETAHS yükümlülükleri (ETBİS kaydı, hizmet
   sağlayıcı bilgilerinin doğrulanması, ciro eşiklerine bağlı ek yükümlülükler)
   ciddi bir uyum yükü.
2. **ETBİS kayıt yükümlülüğünün bu ürün için doğup doğmadığından emin değilim.**
3. Kayıt saklama sürelerini ve ceza tutarlarını **bilerek yazmıyorum** —
   yanlış hatırlanmış bir süre, hiç yazmamaktan kötüdür.

> **Önerim: yayına çıkmadan önce e-ticaret mevzuatı bilen bir avukatla bir
> saatlik görüşme.** Bu, teknik tasarımın çözemeyeceği bir belirsizlik ve
> tahminle kapatılırsa geriye dönük düzeltmesi pahalı.
>
> **Soru listesi hazır: [`07-hukuki-sorular.md`](07-hukuki-sorular.md)** —
> 16 soru, öncelik sırasında, her birinin altında "bu neden önemli" ve
> "cevaba göre hangi tasarım kararı değişir". Cevap üretilmedi, yalnız soru.

Buna rağmen, **hangi kategoriye girerse girsin doğru olan** şeyler var ve
tasarım onları bugünden içeriyor:

### 5.2 Her hâlükârda yapılacaklar

- **İşletme kimlik bilgileri saklanır** (`isletme`, `isletme_belge`) — bir
  ihtilafta karşı tarafın kim olduğu bilinsin.
- **Herkese açık şikâyet yolu** (`sikayet`) — giriş yapmadan da erişilebilir.
- **Bildir-kaldır**: şikâyet → inceleme → gerekiyorsa içerik kaldırma/askı,
  her adım `denetim`e yazılır.
- **İşletmenin bilgileri profilde görünür** (unvan, bölge, doğrulama seviyesi).
- Kararlar **gerekçeli** ve **itiraz edilebilir**.

### 5.3 Askıya alma ölçütleri — yazılı olsun ki keyfî olmasın

| Durum | İşlem |
|---|---|
| Belge sahteliği tespiti | **Kalıcı kapatma** |
| Kimlik gaspı (T4) doğrulandı | Kalıcı kapatma |
| Kısa sürede ≥N ödeme şikâyeti | **Otomatik askı** + inceleme |
| Sahte yorum örüntüsü | 1: uyarı → 2: yorum davet hakkı iptali → 3: askı |
| Talep hasadı şüphesi (T6) | Askı + KVKK incelemesi |
| Tekrarlayan hizmet şikâyeti | Uyarı → teklif kısıtı → askı |
| Yorum şantajı (T7, kullanıcı) | Yorum kaldırma → kullanıcı askısı |

**Kademelilik bilinçli:** ilk hatada kapatmak, dürüst ama acemi esnafı
kaybettirir. Kademe atlanan tek yer sahtelik — orada niyet zaten kanıtlı.

### 5.4 Operasyonel süreç (teknik çözümün olmadığı yer)

Bunlar yazılımla çözülmez, **yazılı süreçle** çözülür:

- **Moderasyon kuyruğu**: yeni işletme başvuruları + bekleyen yorumlar +
  şikâyetler. **Günde bir kez**, tek ekrandan.
- **Hedef süreler:** işletme onayı 2 iş günü, şikâyet ilk yanıt 2 iş günü,
  acil (T3/T5/T6) **aynı gün**.
- **İtiraz:** her olumsuz karar için bir kez itiraz hakkı, farklı bir gözle.
- **Kayıt:** her moderasyon kararı `denetim`e gerekçesiyle yazılır.

**Bu bir kişilik bir iş ve o kişi sensin.** Tasarımın hacim varsayımı bu:
günde ~10 başvuru, ~20 yorum, ~2 şikâyet **tek kişinin günde 20-30 dakikası**.
Bunun üstüne çıkıldığında ürün değil **ekip** sorunu doğar ve o noktada
otomasyon/moderatör kararı yeniden verilir. Bunu şimdiden yazıyorum ki
büyüme bir sürpriz olarak gelmesin.

---

## 6. Çok hesaplılık (T8)

- **Doğrulanmış telefon** = ana kilit. Her hesap bir SIM demek: ücretsiz değil.
- Yorum/talep/teklif için telefon doğrulaması **zorunlu**.
- Talep açmada hız sınırı; aynı IP'den kısa sürede çok kayıt → kuyruk.
- Sanal numara sağlayıcılarını engellemek **oynanacak bir kedi-fare oyunu**;
  V1'de girmeyi önermiyorum, ama şüpheli hesapların örüntüsü zaten §2.3'teki
  moderasyon sinyaline düşüyor.

---

## 7. Kabul: neyi çözmüyorum

Dürüst olmak, bu bölümün işe yaraması için şart:

1. **Sahte yorumu bitiremem.** Maliyetini yükseltir, örüntüsünü görünür kılar,
   kullanıcıya hangi yorumun neye dayandığını gösteririm. Bitirdiğini iddia
   eden bir tasarım yanlış olurdu.
2. **Sahte işletmeyi otomatik ayıklayamam** — V1'de insan inceler (§3).
3. **Platform dışı dolandırıcılığı engelleyemem** — uyarır, izler, kısıtlarım.
4. **Hukuki durum belirsiz** (§5.1) ve bunu yazılımla kapatamam.
5. **Ölçemediğim şey:** hiçbiri gerçek trafikle sınanmadı. Kotalar (davet
   sayısı, şikâyet eşiği N) **başlangıç tahminleri** — ilk üç ay ölçülüp
   ayarlanmak üzere konuyor, sabit doğrular olarak değil.

Sources:
- [6563 sayılı Kanun — mevzuat.gov.tr](https://www.mevzuat.gov.tr/mevzuatmetin/1.5.6563.pdf)
- [7416 sayılı Kanun'la yapılan temel değişiklikler](https://legesegitim.com/elektronik-ticaretin-duzenlenmesi-hakkinda-kanunda-7416-sayili-kanunla-yapilan-temel-degisiklikler-yavuz-akbulak-spk-basuzmani/)
