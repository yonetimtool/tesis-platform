# WHATSAPP ARAŞTIRMASI — senaryomuzu ne kısıtlıyor? (AŞAMA 9)

> Brief: *"WhatsApp için ARAŞTIR VE RAPORLA: Business API şablon onayı,
> 24 saatlik pencere kuralı ve doğrulanmış işletme şartı senaryomuzu nasıl
> kısıtlıyor?"*
>
> Kaynaklar belgenin sonunda. Sağlayıcı **henüz seçilmedi** (brief'in kendi
> notu); bu belge sağlayıcıdan bağımsız olan **Meta platform kurallarını**
> ölçüyor.

---

## 1. SENARYOMUZ — ne göndermek istiyoruz?

Aşama 9'un alıcı segmentleri: *tüm site · blok · borçlular · rol bazlı*.
Yani gönderdiğimiz şeylerin **tamamı işletme-başlatmalı** (business-initiated):

| Mesaj | Kim başlatıyor | Tür |
|---|---|---|
| Aidat hatırlatma / son ödeme | **biz** | işletme-başlatmalı |
| Borç bildirimi | **biz** | işletme-başlatmalı |
| Duyuru / toplantı çağrısı | **biz** | işletme-başlatmalı |
| Arıza-talep durum değişikliği | **biz** | işletme-başlatmalı |
| Geçici giriş kodu (Aşama 3) | **biz** | işletme-başlatmalı |
| Sakinin sorusuna cevap | **sakin** | pencere içi |

**Bu, kısıtın merkezidir:** listenin altı maddesinden beşi sakin bize
yazmadan gönderilir.

---

## 2. ÜÇ KURAL VE HER BİRİNİN BİZE MALİYETİ

### 2.1 24 saatlik müşteri hizmetleri penceresi

**Kural:** Pencere, kullanıcıdan gelen **son mesajdan** itibaren 24 saat
sürer. Bu süre içinde serbest metin gönderebilirsiniz. Pencere dışında
**yalnız önceden onaylanmış şablon** gönderilebilir.

**Bize etkisi — SERT.** Sakinlerimizin çoğu bize **hiç** WhatsApp yazmaz.
Dolayısıyla bizim için pencere pratikte **hep kapalıdır** ve
**her aidat hatırlatması bir şablon mesajıdır.**

**Tasarım sonucu:** Aşama 9'un "serbest metin gönderim" ekranı WhatsApp
kanalı için **serbest olamaz**. Kanal seçimi WhatsApp olduğunda arayüz
şablon seçtirmeli; serbest metin alanı yalnız SMS/e-posta/push için açık
kalmalı. Bunu çalışma anında keşfetmek, "gönderildi" diyip Meta'dan
`131047` hata kodu almak demekti.

### 2.2 Şablon onayı

**Kural:** Her şablon inceleme sürecinden geçer (birkaç dakika ile 24 saat
arası). Şablonlar kategorilere ayrılır: **Utility** (sipariş/işlem
bildirimi), **Marketing** (kampanya/duyuru), Authentication (kod).

**Bize etkisi — ORTA ama sinsi.**

* Aidat hatırlatma **Utility**'dir (işleme dayalı bildirim) → onay olasılığı
  yüksek, ücret düşük.
* **"Site toplantısı yarın 19:00"** gibi genel duyurular **Marketing**
  sayılma riski taşır → hem daha pahalı hem reddedilme olasılığı yüksek.
* Geçici giriş kodu **Authentication** kategorisindedir.

**Tasarım sonucu — bu, veri modelini etkiliyor.** Aşama 9'un
`mesaj_sablonu` tablosuna WhatsApp için **iki alan daha** gerekir:

```
mesaj_sablonu
  + wa_kategori   enum(utility|marketing|authentication)   -- Meta kategorisi
  + wa_durum      enum(taslak|onay_bekliyor|onaylandi|reddedildi)
  + wa_sablon_adi text   -- Meta'daki adı (bizim `ad`dan FARKLI olabilir)
```

**Neden ayrı `wa_durum`:** bizde "aktif" olan bir şablon Meta'da
**reddedilmiş** olabilir. Tek bir `aktif` bayrağı bu iki gerçeği
birleştirir ve yöneticiye "gönderilecek" dediğimiz şablon sessizce
gönderilmez.

**Değişkenler farklı:** bizim `{daire}`, `{tutar}`, `{son_odeme}`
yer tutucularımız Meta'da **konumsal** (`{{1}}`, `{{2}}`) olarak yazılır.
Eşleme tablosu gerekir; kanal eklentisi bunu çevirmeli.

### 2.3 Doğrulanmış işletme (Meta Business Verification)

**Kural:** WhatsApp Business API için doğrulanmış bir Meta Business
Manager, bir WhatsApp Business hesabı ve **kullanılmamış** bir telefon
numarası gerekir. Doğrulama **30 güne kadar** sürebilir ve tüzel kişilik
belgesi (vergi levhası/ticaret sicil), adres ve telefon eşleşmesi ister.
Doğrulama, günlük 1.000+ konuşma limitini ve 20 numaraya kadar kayıt
hakkını açar.

**Bize etkisi — EN SERT KISIT ve zamanlama sorunu.**

1. **Takvim:** 30 güne kadar sürebilir. Play kapalı testi sürerken bu
   başlatılmalı, yoksa WhatsApp özelliği hazır olduğunda hesap hazır
   olmaz.
2. **Kullanılmamış numara:** WhatsApp Business API'ye kaydedilen numara
   normal WhatsApp/WhatsApp Business uygulamasında **kullanılamaz**.
   Yönetio'nun mevcut bir iletişim numarası varsa **onu kullanmayın** —
   kayıt, o numaranın normal WhatsApp'ını kapatır.
3. **Kim doğrulanıyor?** Bu, tasarımın en kritik sorusudur — aşağıda.

---

## 3. EN KRİTİK BULGU — "hangi işletme?" sorusu

Meta doğrulaması **tüzel kişiliğe** bağlıdır. Bizim ürünümüz çok kiracılı
(multi-tenant): yüzlerce **site yönetimi** var ve mesaj **onların adına**
gidiyor.

İki model mümkün ve **seçim ürün kararıdır**:

| | **A — Tek numara: Yönetio** | **B — Tesis başına numara** |
|---|---|---|
| Doğrulanan tüzel kişi | Yönetio | her site yönetimi ayrı |
| Sakinin gördüğü gönderen | "Yönetio" | "Oltu Sitesi Yönetimi" |
| Kurulum | **bir kez** | tesis başına 30 güne kadar + belge |
| Numara | 1 (doğrulama sonrası 20'ye kadar) | tesis başına kullanılmamış numara |
| Şablon onayı | **merkezî** — bir kez onaylanır, herkes kullanır | tesis başına ayrı onay |
| Maliyet | Yönetio'nun faturası | tesisin faturası |
| Ölçeklenme | ✔ | ✘ pratikte imkânsız (yeni site = 30 gün bekleme) |

**Öneri: A.** Gerekçe: B modelinde yeni bir site sisteme girdiğinde
WhatsApp'ı **30 gün kullanamaz** ve her tesisten belge toplamak gerekir —
kurulum sihirbazını (Aşama 7.3) haftalarca bekletir. A modelinde şablon
`{tesis_adi}` değişkeni taşır ve gönderen tek marka olur.

**A'nın kabul edilmesi gereken bedeli:** sakin mesajı "Yönetio"dan alır,
site yönetiminden değil. Bu bir **marka kararıdır ve Kerem'e aittir.**
SMS tarafında da aynı durum var: Netgsm'de onaylı gönderici başlığı tek
ve o da Yönetio'nun.

---

## 4. SONUÇ — WhatsApp bugün SMS'in yerini ALAMAZ

| Kriter | SMS (Netgsm) | WhatsApp |
|---|---|---|
| İşletme-başlatmalı mesaj | serbest | **yalnız onaylı şablon** |
| Kuruluma kadar geçen süre | bağlı, **çalışıyor** | 30 güne kadar doğrulama |
| Yeni mesaj türü eklemek | metni yaz, gönder | şablon yaz → onay bekle |
| Sakinin uygulama kurma zorunluluğu | yok | **WhatsApp gerekir** |
| Birim maliyet | yüksek | düşük |

**Karar önerisi:** WhatsApp **ikinci kanal** olarak, SMS'in **yerine
değil yanına** planlansın. Aşama 9'un ortak gönderim arayüzü (kanal:
`sms | whatsapp | email | push`) bunu zaten mümkün kılıyor; eklenti
takılabilir olduğu için WhatsApp doğrulama beklerken diğer kanallar
çalışır.

---

## 5. AŞAMA 9'A SOMUT GİRDİLER

Bunlar sağlayıcı seçilmeden **şimdi** yapılabilir:

1. `mesaj_sablonu`ya `wa_kategori`, `wa_durum`, `wa_sablon_adi` alanları
   (§2.2) — WhatsApp yokken NULL kalır, zarar vermez.
2. Gönderim arayüzünde **kanal WhatsApp ise serbest metin KAPALI** (§2.1).
3. Yer tutucu eşlemesi: `{daire}` → `{{1}}` çevirici, kanal eklentisinde.
4. Gönderim kaydına (`mesaj_gonderim`) sağlayıcı hata kodu alanı —
   `131047` (pencere kapalı) gibi kodlar teşhis için gerekli.

## 6. KEREM'İN KARAR VERMESİ GEREKENLER

1. **Model A mı B mi** (§3) — öneri A.
2. **Meta Business doğrulaması ne zaman başlatılsın?** 30 güne kadar
   sürüyor; WhatsApp bu turda planlanıyorsa **şimdi** başlamalı.
3. **Kullanılmamış numara** ayrılacak mı? Mevcut iletişim numarası
   kullanılırsa o numaranın normal WhatsApp'ı kapanır.
4. **Sağlayıcı:** doğrudan Meta Cloud API mi, aracı (Twilio/360dialog/
   yerel BSP) mı? Aracı, doğrulamayı kolaylaştırır ama mesaj başına ek
   ücret alır.

---

## Kaynaklar

- [WhatsApp Cloud API Get Started — Meta for Developers](https://developers.facebook.com/documentation/business-messaging/whatsapp/get-started)
- [Key Concepts and Terms for the WhatsApp Business Platform — Twilio](https://www.twilio.com/docs/whatsapp/key-concepts)
- [WhatsApp Message Templates — respond.io](https://respond.io/help/whatsapp/whatsapp-message-templates)
- [Meta Business Verification — respond.io](https://respond.io/help/whatsapp/meta-business-verification)
- [WhatsApp API Prerequisites: Phone, Documents, and Verification — Wati](https://www.wati.io/en/blog/whatsapp-api-prerequisites/)
- [About Meta Verified for Business on WhatsApp — WhatsApp Help Center](https://faq.whatsapp.com/3872729742954601)
- [WhatsApp API Message Templates: Complete Guide 2026 — Gurusup](https://gurusup.com/blog/whatsapp-api-message-templates)

> **Dürüstlük notu:** Meta'nın kuralları sık değişir ve yukarıdaki
> ücret/limit ayrıntıları ikincil kaynaklardan derlendi. Uygulamaya
> geçmeden önce Meta'nın kendi belgesinden **tarih damgalı** olarak
> doğrulanmalıdır. Türkiye'ye özgü ek bir şart bulunamadı.
