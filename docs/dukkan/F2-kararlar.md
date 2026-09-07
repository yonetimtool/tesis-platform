# DUKKAN F2 — KARARLAR

Arz tarafı: kimlik, işletme kaydı, moderasyon. Her kararın **gerekçesi** yazılı.

---

## 1. Kimlik telefona çapalandı, e-postaya değil

**Ölçüm:** `\d app_user` → `uq_app_user_telefon` telefonu **global** benzersiz
yapıyor; `uq_app_user_tenant_email` e-postayı **yalnız tesis içinde**.

**Sonuç:** e-posta bir *kişiyi* tekilleştiremez. Ortak bir ofis/aile e-postası
iki farklı tesiste iki **farklı insana** ait olabilir. E-postaya çapalasaydım
o iki insan Dukkan'da **tek hesapta birleşirdi** ve birinin talepleri ötekine
görünürdü — sessiz ve ciddi bir sızıntı.

**Ek fayda:** telefon bir **maliyet kapısı**. Her hesap bir SIM demek. Çok
hesaplılık (T8) sahte yorumun ve sahte işletmenin çarpanı; ücretsiz e-posta
o çarpanı sınırsız yapardı.

**Telefon normalizasyonu bunun şartı.** `0555…`, `555…`, `+90555…` normalize
edilmezse aynı kişi **üç hesap** olur ve `UNIQUE(telefon)` işini yapamaz.
Tanınmayan biçim sessizce kabul edilmiyor, **422** dönüyor: kimlik çapasına
çöp veri girmemeli.

---

## 2. Dukkan kendi jetonunu üretiyor

Yönetiyor JWT'si `tenant_id`'yi **zorunlu** taşıyor (ölçüldü:
`create_access_token`). Bağımsız bir Dukkan kullanıcısının tesisi yok →
Yönetiyor jetonu burada kullanılamaz.

Dukkan jetonu `tur: "dukkan"` iddiası taşır ve doğrulamada **aranır**. Aynı
JWT sırrı kullanıldığı için bu ayrım olmasaydı bir Yönetiyor erişim jetonu
Dukkan uçlarında **geçerli sayılırdı**. Ters yön de kapalı: Dukkan jetonunda
`type: "access"` yok, `decode_token(expected_type="access")` reddediyor.

**Her iki yön de testle kilitli** (`test_dukkan_arz_akisi.py`).

**Jeton ömrü 30 gün** — Yönetiyor'unkinden uzun. Gerekçe: pazar yeri seyrek
kullanılır (yılda birkaç kez usta aranır); her ziyarette OTP istemek kullanıcıyı
akışın başında kaybetmek olur. Yönetiyor ise günlük bir çalışma aracı ve orada
kısa ömür doğru.

---

## 3. Köprü RLS'i atlamıyor, ona TABİ — ölçerek bulundu

İlk yazımda `/dukkan/auth/yonetiyor` **500** veriyordu:

```
invalid input syntax for type uuid: ""
```

`app_user` ve `tenant` FORCE RLS altında; politika
`current_setting('app.current_tenant_id')::uuid` okuyor ve değer kurulmadığında
boş dizge cast'i patlıyor. Hata mesajı yanıltıcıydı — parametre listesinde
UUID'ler **doğru görünüyordu**. Ancak akışı sürerek bulundu.

**Düzeltme bir güvenlik kazancı, sadece hata giderme değil:** köprü artık
`set_tenant(session, tenant_id)` çağırıyor, yani **yalnızca kendisine verilen
tesisin** satırlarını görebiliyor. Owner bağlantısıyla ya da RLS'i atlayarak
okusaydı, jetondaki `tenant_id` ile oynayan biri **başka bir tesisin
kullanıcısını** okuyabilirdi.

Kilit AST ile: her köprü fonksiyonu `set_tenant` çağırmalı. Birinin ileride
"sorgu zaten `tenant_id` ile filtreliyor, gereksiz" diye silmesini engelliyor —
filtre **uygulama** katmanındadır ve bir gün unutulur; RLS **veritabanındadır**.

---

## 4. Köprü oturumu da köprüden geliyor

`auth_uclar.py` önce `app.db`'yi doğrudan ithal ediyordu ve sınır testi bunu
yakaladı. **Kilidi gevşetmek yanlış cevaptı:** kural "Dukkan Yönetiyor'a yalnız
köprüden bakar" ve bir **oturum** da tam olarak Yönetiyor'a bakmanın yolu.

Doğru cevap kapıyı genişletmek değil, **kapının arkasına almaktı**: oturumu da
`kopru.py` sağlıyor (`yonetiyor_oturumu`). Böylece Dukkan tarafında Yönetiyor'a
açılan **tek dosya** yine o dosya kalıyor.

---

## 5. İşletme `taslak` başlar, `onay_bekliyor` değil

Profili eksikken kuyruğa düşen başvuru moderatörün zamanını harcar ve
reddedilir; kullanıcı da neden reddedildiğini anlamaz. Başvuru **açık bir
eylemle** yapılır (`/basvur`).

**Ön koşullar başvuru ucunda ve eksikler TEK SEFERDE, ADIYLA dönüyor:**
`basvuru_eksik:kategori,hizmet_alani,telefon_dogrulama`. Tek tek dönseydi
kullanıcı formu üç kez gönderip üç farklı hata görürdü.

Panelde ayrıca bir **hazırlık listesi** var: eksikleri yalnız başvuru anında
söylemek kullanıcıyı dene-yanıl döngüsüne sokardı.

---

## 6. Doğrulama seviyesi: telefon ≠ kimlik

| Sv | Ad | Şart | Aramada |
|---|---|---|---|
| 0 | Kayıtlı | — | **çıkmaz** |
| 1 | Telefon doğrulandı | OTP | çıkar |
| 2 | Belge doğrulandı | vergi levhası + **insan** | ✔ rozet |
| 3 | (V2) Kurumsal | e-imza/MERSİS | — |

**Seviye 0 aramada çıkmıyor** çünkü kayıt ücretsiz ve anında; görünür kılmak
sahte işletmeyi (T3) **davet etmek** olurdu.

**Seviye 1 ile 2 ayrı çünkü telefon doğrulaması kimlik kanıtı DEĞİL** —
yalnızca numaranın kontrolünü kanıtlar; ön ödemeli hat 50 liraya alınır.
"Bu numara gerçek" ile "bu işletme gerçek" aynı şey değil; ikisini tek rozette
birleştirmek kullanıcıya yalan söylemek olurdu.

**Telefon değişirse doğrulama düşer.** Aksi halde bir işletme doğrulanmış
numarayla seviye 1 alıp sonra numarayı değiştirerek rozeti **doğrulanmamış**
bir numaraya taşırdı — ve kullanıcı o numarayı arardı.

**Onayda telefon doğrulanmamışsa 409.** Onaylı ama seviye 0 bir işletme
"onaylandı" görünüp **hiçbir yerde çıkmazdı**: sessiz ve teşhisi zor bir kusur.

---

## 7. `denetim` append-only, `moderator` ayrı tablo

**`denetim`:** bir moderasyon kararı sonradan "hiç verilmemiş" hâle
getirilemez. İtiraz süreci buna dayanıyor. `UPDATE`/`DELETE` yetkisi hem göçte
hem `setup_dukkan_role.py`'de geri alınıyor — **ikisi birden gerekli**, çünkü
betik her koşumda blanket GRANT veriyor ve yalnız göçte yapmak kilidi ilk
`migrate` koşumunda sessizce açardı. (Aynı ders `setup_app_role.py`'de
`audit_log` için zaten yazılıydı.)

**`moderator` ayrı tablo, bayrak değil:** bayrak olsaydı bir `UPDATE` hatası
sıradan bir kullanıcıyı moderatör yapabilirdi. Ayrı tabloya satır eklemek
**kasıtlı** bir eylemdir. Atama ucu da **yok** — bir uçtan moderatör
yapılabilseydi o uç ürünün en tehlikeli yüzeyi olurdu.

---

## 8. Sessiz başarısızlık yok — üç yerde

| Yer | Ne yapıyor |
|---|---|
| `PATCH /isletme/{id}` | **Güncellenen alan sayısını** döndürür; sıfırsa arayüz "Kaydedildi" demez. Boş gövde **422** |
| `PUT .../kategoriler` | Bulunamayan slug **sessizce yutulmaz** (422). Yutulsaydı işletme kategorisini seçtiğini sanıp hiç talep almaz, sebebini asla öğrenemezdi |
| `POST /auth/telefon/kod` | SMS sağlayıcısı bağlı değilse `"gonderim": "saglayici_bagli_degil"`. `"gonderildi": true` deyip hiçbir şey göndermemek kullanıcıyı olmayan bir SMS'i beklerken bırakırdı |

---

## 9. Web'den başvuru tamamlanamıyordu — akışı sürerken bulundu

Kamu mahalle ucu yalnızca `slug` döndürüyordu; hizmet alanı ucu ise mahalle
**kimliği** istiyor (mahalle slug'ı yalnız ilçe içinde benzersiz).

Sonuç: mahalle listesi **görünüyor ama seçilemiyordu**. İşletme hizmet alanı
seçemiyor, hizmet alanı olmadan da başvuru yapamıyordu. Backend kusursuz
görünürken akış **sessizce tıkanıyordu** — birim testler geçiyor, ürün
çalışmıyor.

Düzeltme: mahalle ucu artık `id` de döndürüyor. **İki testle** kilitlendi:
uç `id` döndürmeli **ve** o `id` hizmet alanı ucunda doğrudan kullanılabilmeli
(iki ucu **birlikte** ölçen test — ayrı ayrı geçip birlikte kırılan sınıf tam
olarak buydu).

---

## 10. IDOR: iki katmanlı ve testsiz uç eklenemez

Dukkan çok-kiracılı değil, RLS yok; sınır `isletme.sahip_kullanici_id` ve tek
bir yardımcıdan (`_sahiplik_dogrula`) geçiyor.

1. **Davranış:** her özel uç, başka bir işletmenin sahibiyle çağrılınca **403**.
2. **Ters yönlü kanıt:** sahibin **kendi** işletmesine erişebildiği de ölçülüyor
   — yoksa herkese 403 dönen bozuk bir uç "güvenli" görünürdü.
3. **Tarama:** yeni bir `/isletme/{id}/...` ucu eklenip listeye yazılmazsa test
   düşer. "İnsan hatırlar" varsayımı bu depoda P173/P189'da iki kez tutmadı.

**404 ile 403 ayrı:** var olmayan bir kimliğe 403 demek, "bu kimlik var ama
senin değil" bilgisini sızdırırdı.

---

## 11. Açık maddeler

| Madde | Durum |
|---|---|
| **SMS sağlayıcısı** | **BAĞLI DEĞİL.** Kod üretiliyor ve hash'leniyor ama gönderilmiyor; yanıt bunu açıkça söylüyor. Prod'da akış bu yüzden tamamlanamaz. Sağlayıcı seçimi **senin kararın** — Yönetiyor'da SMS ürün genelinde kapalı, devralınacak entegrasyon yok |
| **Jeton `localStorage`da** | XSS'e açık. httpOnly çerez daha güvenli olurdu; bu turda kurulmadı. Panel yüzeyi dar ve para yok. **Ödeme geldiğinde (V2) yeniden değerlendirilmeli** |
| **Belge yükleme UI** | Backend hazır (presign + inceleme izi), panel ekranı yok |
| **Moderasyon paneli UI** | Backend hazır, ekran yok — kuyruk şimdilik API'den |
| **Vergi no doğrulaması** | Yalnız **biçim** kontrolü (10/11 hane). Gerçek doğrulama V1'de insan incelemesi |
