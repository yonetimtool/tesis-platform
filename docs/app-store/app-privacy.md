# App Privacy anketi — cevap tablosu (P115)

> App Store Connect → App Privacy bölümüne **bu tablo** girilir. Tablo,
> `mobile/ios/Runner/PrivacyInfo.xcprivacy` ile **birebir aynı** olmak
> zorundadır: bildirimde "toplanıyor" deyip ankette "toplanmıyor" demek
> (ya da tersi) denetimde tutarsızlık olarak okunur ve ret sebebidir.
> Değişiklik yaparken **ikisini birlikte** güncelleyin; `mobile/test/
> ios_yapilandirma_test.dart` bildirimin bozulmasını yakalar.

## Genel cevaplar

| Soru | Cevap | Neden |
|---|---|---|
| Veri topluyor musunuz? | **Evet** | Hesap tabanlı bir yönetim uygulaması; ad/telefon olmadan çalışamaz. |
| Kullanıcıyı **izliyor** musunuz? (Tracking) | **HAYIR** | Reklam kimliği (IDFA) okunmuyor, cihazlar arası eşleştirme yok, veri veri simsarlarına satılmıyor. `NSPrivacyTracking = false`. |
| Üçüncü taraf reklam/analitik SDK'sı | **YOK** | Uygulamada reklam SDK'sı, analitik SDK'sı ve çerez tabanlı izleme bulunmuyor. |

## Toplanan veri tipleri

Tümü **kullanıcıya bağlı** (hesapla ilişkili) ve tümünün amacı
**App Functionality**. Hiçbiri izleme (tracking) için kullanılmıyor.

| App Store veri tipi | Toplanıyor | Bağlı | İzleme | Nerede kullanılıyor |
|---|---|---|---|---|
| Name | Evet | Evet | Hayır | Hesap kimliği; talep/duyuru yazarı olarak görünür. |
| Phone Number | Evet | Evet | Hayır | **Giriş anahtarı** (sakin telefonla girer). |
| Email Address | Evet | Evet | Hayır | Opsiyonel; yönetim hesaplarında giriş anahtarı. |
| Photos or Videos | Evet | Evet | Hayır | Yalnız kullanıcı seçtiğinde: görev/talep/etkinlik/kargo fotoğrafı. |
| Precise Location | Evet | Evet | Hayır | **Yalnız saha personeli**, tur okutması ve acil bildirim anında. Arka planda **toplanmaz**. |
| User ID | Evet | Evet | Hayır | Tesis içi hesap kimliği. |
| Payment Info | Evet | Evet | Hayır | Aidat **tahakkuku ve tahsilat kaydı**. **Kart verisi toplanmıyor** (kartla ödeme şu an etkin değil). |
| Other User Content | Evet | Evet | Hayır | Talep/şikâyet metinleri, duyurular. |

## Toplanmayanlar (açıkça)

| Veri tipi | Durum |
|---|---|
| Contacts (rehber) | **Hayır** — rehbere erişilmiyor. |
| Health & Fitness | Hayır |
| Financial Info (kart/banka) | **Hayır** — kartla ödeme etkin değil; etkinleşince veri doğrudan iyzico'ya gider ve bizde tutulmaz. |
| Browsing History / Search History | Hayır |
| Identifiers → Advertising Data (IDFA) | **Hayır** |
| Diagnostics / Crash Data | Hayır — üçüncü taraf çökme raporlayıcı yok. |
| Sensitive Info | Hayır |

## Gerekçe zorunlu API'ler (Required Reason APIs)

`PrivacyInfo.xcprivacy` içindeki beyanla aynıdır.

| Kategori | Gerekçe | Nereden geliyor |
|---|---|---|
| UserDefaults | `CA92.1` | `flutter_secure_storage` / `shared_preferences` — yalnız uygulamanın kendi verisi. |
| File Timestamp | `C617.1` | `path_provider` / `image_picker` — kullanıcıya görünür dosya işlemleri. |
| Disk Space | `E174.1` | Fotoğraf yazarken yer kontrolü. |
| System Boot Time | `35F9.1` | Çevrimdışı kuyrukta geçen süreyi ölçmek. |

## Bildirim ve ödeme — bugünkü durum

* **Push bildirim (Firebase/FCM):** şu an **etkin değil** (P12, kimlik yok).
  Etkinleştiğinde cihaz jetonu Google'a gider; anket "Identifiers → Device
  ID" satırıyla güncellenmelidir.
* **Kartla ödeme (iyzico):** şu an **etkin değil** (P13, sandbox anahtarı
  yok). Etkinleştiğinde kart verisi **bize gelmez**; yine de "Financial
  Info" satırı gözden geçirilmelidir.

İkisi de açılınca **bu tablo, `PrivacyInfo.xcprivacy` ve
`/gizlilik` sayfası birlikte** güncellenir.
