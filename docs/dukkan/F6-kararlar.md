# DUKKAN F6 — KARARLAR

Yönetiyor entegrasyonu: bildirimler, mobil "Yerel İşletmeler" menü girişi,
`app.yonetiyor.com` yönetici sayfası.

---

## 1. Ayrı bildirim tablosu — tercih değil zorunluluk

Yönetiyor'un `notification` tablosu `tenant_id` **zorunlu** tutuyor ve RLS
`app.current_tenant_id` üzerinden çalışıyor. Dukkan çok-kiracılı değil; bir
Dukkan kullanıcısının tesisi **olmayabilir**.

Ayrıca `dukkan_app` rolünün `public` şemasında hiçbir yetkisi yok (göç 0113)
— o tabloya **yazamaz bile**.

**Push sağlayıcısı ise paylaşılıyor** (`app.push.get_push_provider`): FCM
kimliği, HTTP katmanı ve hata eşlemesi iki üründe de aynı. Ayrışan şey
**kime** gönderildiği, nasıl gönderildiği değil. Aynı ilke SMS'te de
uygulanmıştı.

---

## 2. Kalıcı satır + anlık push, **yan yana**

Push anlık gönderilir ve **geriye hiçbir şey bırakmaz**: o an telefonu kapalı
olan kullanıcı için olay **yok olur**. Her olay hem `bildirim` tablosuna
yazılıyor hem push ediliyor.

Yönetiyor'da `sakin_bildirimi.py` başlığında aynı karar yazılı ve orada
*"anlık push'un kalıcı ikizi"* diye adlandırılmış.

**Push başarısız olsa bile satır kalıyor** — olay kaybolmuyor.

---

## 3. `gonderildi_at` — P191 tuzağına karşı

P191'de ölçülen kusur: `PUSH_PROVIDER=noop` sessizce *"gönderildi"* gibi
davranıyordu ve bildirimler **hiç gitmiyordu**; kimse fark etmedi.

`gonderildi_at` **yalnızca sağlayıcı kabul ettiğinde** doluyor. NULL olması
*"gitmedi"* demek ve teşhiste **görünüyor**. Bir test dev'de (noop) bu
alanın **hiç dolmadığını** ölçüyor:

> *"{n} bildirim 'gönderildi' işaretli — ama sağlayıcı noop. Sessiz
> başarısızlık: bildirimler gitmiyor ama gitmiş görünüyor."*

**Geçersiz jetonlar budanıyor**, geçici hatalarda jeton **korunuyor** —
`push.py`'deki kalıcı/geçici ayrımı kullanılıyor.

---

## 4. Metin kayda döndürülmüyor

Satır `tip` + `veri` tutuyor; metin **okuma anında, isteğin dilinde**
üretiliyor. 7 dilli bir uygulamada kaydedilmiş metin, kullanıcı dilini
değiştirdiğinde **eski dilde kalırdı**.

Bir test yanıtta `baslik`/`govde`/`mesaj` **bulunmadığını** ölçüyor.

---

## 5. `hedef_yol` sunucuda

Bildirime tıklandığında gidilecek yol **sunucuda** üretiliyor; mobil ve web
**aynı değeri** okuyor.

İki istemcide ayrı ayrı eşleştirmek, birinin bir gün ötekinden ayrışması ve
bildirime tıklayınca **yanlış ekrana** gidilmesi demekti — P217'de push
yönlendirmesi tam bu sınıf bir kusurdu (yönetici tur bildirimine tıklayınca
erişemediği bir sayfaya gidiyordu).

Eksik anahtarda yol `null` oluyor ama **bildirim yine yazılıyor**: yolsuz
bildirim listeye açılır, hiç yazılmayan bildirim **kaybolur**.

---

## 6. Cihaz jetonu devralınıyor

`fcm_token` **UNIQUE**. Aynı jeton ikinci bir kullanıcı tarafından
kaydedilirse **devralınıyor** (`ON CONFLICT DO UPDATE`).

Cihaz el değiştirdiğinde (ortak telefon, ikinci el) eski sahibin
bildirimleri yeni kullanıcıya **düşmemeli**. Bu garanti veritabanında, uygulama
katmanında değil.

---

## 7. Hangi olaylar bildiriliyor

| Olay | Kime | Neden |
|---|---|---|
| `teklif_geldi` | Talep sahibi | Teklifi görmeyen müşteri başka yerden usta bulur; teklif veren işletme boşuna bekler |
| `is_verildi` | İşletme sahibi | Ustanın görmemesi, kabul edilmiş bir işin yapılmaması demek. **Adres de o an açılıyor** |
| `isletme_onaylandi` | İşletme sahibi | Yayına girdiğini fark etmez |
| `isletme_reddedildi` | İşletme sahibi | **Gerekçeyle** — sebebini söylememek, ne düzelteceğini bilmez hâlde bırakmak |
| `isletme_askiya_alindi` | İşletme sahibi | Aynı gerekçe |

---

## 8. Mobil menü girişi — `disHizmet`'ten **ayrı**

`dis_hizmet` = yöneticinin **özel defteri** (tesise bağlı, elle girer, yalnız
o tesis görür — kurumsal hafıza).
Dukkan = **kamu pazar yeri** (işletme kendi kaydolur, yorum ve doğrulama
taşır, herkes görür).

Aynı menü girişinde birleştirmek iki farklı kavramı karıştırırdı ve
yöneticiden kendi defterini almak olurdu (`00-mimari.md` §4).

**İkon da farklı:** `disHizmet` el aleti, `yerelIsletmeler` mağaza. Aynı ikon
iki girişi birbirine karıştırırdı.

**Tüm rollere açık:** arama ve profil uçları kimliksiz. Sakin de, güvenlik de,
yönetici de bölgesindeki ustayı arayabilmeli.

**Menü kilidi girişi yakaladı** — 4 rol listesinde beklenen değerler
güncellendi. Kilit tam da bunun için var: yeni bir modül sessizce menüye
girmesin ya da menüden düşmesin.

---

## 9. `app.yonetiyor.com` — Yönetiyor jetonu **iletilmiyor**

Yönetici sayfası Dukkan'ın **kimliksiz** uçlarını kullanıyor. Yönetiyor
jetonunu oraya iletmek iki sebeple yanlış olurdu:

1. Yönetiyor jetonu Dukkan uçlarında **geçersiz** (`tur: "dukkan"` iddiası
   yok) — 401 alırdı.
2. **Gereksiz:** uç zaten kimliksiz. Jetonu ihtiyaç olmayan bir yere taşımak
   olurdu.

Mobilde aynı ayrım `AuthInterceptor.dukkanJetonu` ile çözülmüştü; burada
gereken daha basit: jetonu **hiç göndermemek**.

**Yönetici Dukkan hesabı açmak zorunda değil** — sadece "bölgemde kim var"
diye bakan yöneticiyi gereksiz bir kayıt akışına sokmak yanlış olurdu.

---

## 10. Dört admin-web kilidi birden yakaladı

Yeni bir korumalı sayfa eklemek dört kaydı birden ilgilendiriyor ve hepsi
**haklı** çıktı:

| Kilit | Ne yakaladı |
|---|---|
| `middleware.test` | `/yerel-isletmeler` matcher'da yok → sayfa **korumasız** kalırdı |
| `i18n.test` | `lib/dukkan-vekil.ts`te **Türkçe sabit metin** — hata mesajını sunucuda sabitlemek, 7 dilli üründe dili sunucuda dondurmak olurdu. Artık `code` dönüyor, istemci kendi dilinde yazıyor |
| `sessiz-fetch.test` | Üç `fetch` yanıt durumunu **denetlemiyordu** — 502 gelen bir yanıtın hata gövdesini "liste" sanıp sessizce boş süzgeç çizerdi |
| `canli-bolge.test` | Hata kutusunda `role="alert"` yok → ekran okuyucu duyurmaz |

Bu dördü hafızada `p193-kurulum-bosluklari` olarak kayıtlı ("YENİ korumalı
sayfada middleware matcher + duraklı BFF rotası unutma") — liste bu turda
**genişledi**.

---

## 11. `storefront` ikonu eklendi

`IconName` tipine yeni bir değer. `hub` kullanamazdım: o zaten
`dis-hizmetler`in ikonu ve iki farklı kavram menüde **yan yana** duruyor.

---

## 12. Açık maddeler

| Madde | Durum |
|---|---|
| **Mobilde bildirim ekranı yok** | Backend hazır (`/dukkan/bildirim`), push kanalı hazır; mobilde bildirim **listesi** ve FCM kaydı bağlanmadı. Yönetiyor'un kendi bildirim ekranı var; Dukkan'ınki ayrı bir yüzey ve F6'da yetişmedi |
| **Mobilde telefon-OTP akışı** | F4'ten devam ediyor: telefonu olmayan Yönetiyor kullanıcısı (%27) web'e yönlendiriliyor |
| **Bildirim tercihleri** | Kullanıcı hangi bildirimi isteyip istemediğini seçemiyor. Yönetiyor'da `bildirim_mobil` alanı var; Dukkan'da yok |
| **`dukkan-web` dağıtılmadı** | Altı fazın tamamı yazıldı ama site **yayına açılmadı** — kullanıcının kararı |

---

## 13. Ölçemediklerim

1. **Gerçek push teslimi.** `PUSH_PROVIDER=noop` olduğu için hiçbir bildirim
   **gerçekten gönderilmedi**. FCM kimliği prod'da var; ama Dukkan
   bildirimlerinin gerçek bir cihaza düştüğünü **ölçmedim**.
2. **Mobil menü girişinin cihazdaki görünümü** — emülatör yok.
3. **Bildirim hacmi.** Aktif bir pazar yerinde teklif bildirimleri hızla
   birikir; "günde kaç bildirim çok" sorusunun cevabını bilmiyorum ve
   toplulaştırma (batching) **yok**. Yönetiyor'da vardiya özeti için batching
   yazılmıştı; Dukkan'da gerekip gerekmediği gerçek trafikte görülür.
