# DUKKAN — 04 · API SÖZLEŞMESİ

Ön ek **`/dukkan`**. Hata zarfı Yönetiyor'la **aynı**: `{"error":{"code","message"}}`
(`apps/tanitim-web/lib/backend.ts`'te ölçtüğüm kalıp — istemci tek okuma yolu bilsin).

Kimlik sütunu: `—` jetonsuz · `K` kullanıcı · `İ` işletme sahibi · `M` moderatör.

---

## 1. Kamu uçları (jetonsuz — SEO ve arama buradan beslenir)

| Metot | Yol | Not |
|---|---|---|
| GET | `/dukkan/lokasyon/il` | 81 il |
| GET | `/dukkan/lokasyon/il/{slug}/ilce` | |
| GET | `/dukkan/lokasyon/ilce/{slug}/mahalle` | |
| GET | `/dukkan/kategori` | Ağaç (2 seviye) |
| GET | `/dukkan/isletme` | **Ana arama.** `?mahalle=&kategori=&q=&sirala=&sayfa=` |
| GET | `/dukkan/isletme/{slug}` | Profil + kategoriler + hizmet alanları + saatler |
| GET | `/dukkan/isletme/{slug}/yorum` | Yalnız `durum='yayinda'`; `kaynak` alanı **her zaman** döner |
| GET | `/dukkan/sayfa/{il}/{ilce}/{mahalle}/{kategori}` | SEO sayfası verisi; **eşik altındaysa 404** (`05-seo.md` §3) |
| POST | `/dukkan/sikayet` | **Jetonsuz** — 6563 (`03` §5.2) |

`GET /dukkan/isletme` **yalnız `durum='onayli'` ve `dogrulama_seviyesi>=1`**
döndürür. Bu filtre uç düzeyinde tek bir yerde, çünkü iki ayrı yerde
tekrarlanırsa biri bir gün unutulur ve sahte işletme aramaya sızar (`03` §3).

---

## 2. Kimlik

| Metot | Yol | Kim | Not |
|---|---|---|---|
| POST | `/dukkan/auth/telefon/kod` | — | OTP gönder; hız sınırlı |
| POST | `/dukkan/auth/telefon/dogrula` | — | OTP → Dukkan jetonu |
| POST | `/dukkan/auth/yonetiyor` | Yönetiyor JWT | SSO köprüsü (`02` §3) |
| GET | `/dukkan/ben` | K | Profil |
| PATCH | `/dukkan/ben` | K | |
| DELETE | `/dukkan/ben` | K | Anonimleştirme (`02` §6.5) |

---

## 3. Talep / teklif / iş

| Metot | Yol | Kim | Not |
|---|---|---|---|
| POST | `/dukkan/talep` | K | **`paylas_*` alanları gövdede açıkça**; yoksa `false` |
| GET | `/dukkan/talep` | K | Kendi talepleri |
| GET | `/dukkan/talep/{id}` | K/İ | **Görünürlük role göre değişir → §4** |
| POST | `/dukkan/talep/{id}/iptal` | K | |
| GET | `/dukkan/isletme/{id}/talepler` | İ | Hizmet alanı + kategori eşleşmesi |
| POST | `/dukkan/talep/{id}/teklif` | İ | `UNIQUE(talep_id, isletme_id)` → ikincisi **409** |
| GET | `/dukkan/talep/{id}/teklifler` | K | |
| POST | `/dukkan/teklif/{id}/kabul` | K | **`is` satırı doğar; adres açılır** |
| POST | `/dukkan/is/{id}/tamamlandi` | K/İ | Yorum hakkını açar |

---

## 4. KVKK görünürlük kuralı — sunucuda, testle kilitli

> Tasarımın en kritik tek kuralı. Arayüzde gizlemek **yetmez**: mobil
> ikinci istemci ve o gizlemeyi taşımaz.

`GET /dukkan/talep/{id}` yanıtı **çağırana göre farklıdır**:

**İşletme sahibi çağırıyorsa ve `is` satırı YOKSA** (teklif aşaması):
```json
{ "id":"…", "kategori":"Elektrikçi", "aciklama":"…",
  "mahalle":{"ad":"Çatalmeşe","ilce":"Çekmeköy","il":"İstanbul"},
  "butce_min_kurus":null, "butce_max_kurus":null,
  "ad":null, "telefon":null, "acik_adres":null }
```
`acik_adres` **anahtar olarak vardır ama daima `null`'dır** — istemci
"alan yok mu, izin mi yok?" diye ayrım yapmak zorunda kalmasın.
`ad`/`telefon` yalnız kullanıcı `paylas_*` işaretlediyse dolar.

**Kabul edilen işletme çağırıyorsa** (`is` satırı var): `acik_adres` ve
`telefon` **dolu** döner.

**Başka bir işletme çağırıyorsa:** `403`.

**Kilit testleri (uygulama aşamasında zorunlu, uç birleşmeden yazılır):**
1. Teklif aşamasında `acik_adres is None` — **tüm** yanıt gövdesinde geçmiyor.
2. `paylas_telefon=false` iken telefon hiçbir alanda yok.
3. Teklif kabulünden **sonra** adres açılıyor — yalnız kabul edilen işletmeye.
4. Kabul edilmeyen işletme kabul sonrası da adresi **göremiyor**.
5. Teklif listesinde başka işletmenin teklif metni görünmüyor.

**Mock HTTP katmanında** (P200 dersi): `httpx.MockTransport`. Repo katmanında
taklit, tam da ölçmek istediğim serileştirme adımını atlar — P198 ve P200
aynı dikişten kırılmıştı.

---

## 5. İşletme yönetimi — her uç bir IDOR testi ister

| Metot | Yol | Kim |
|---|---|---|
| POST | `/dukkan/isletme` | K → `onay_bekliyor` |
| GET/PATCH | `/dukkan/isletme/{id}` | İ |
| PUT | `/dukkan/isletme/{id}/kategoriler` | İ |
| PUT | `/dukkan/isletme/{id}/hizmet-alanlari` | İ |
| POST | `/dukkan/isletme/{id}/belge` | İ |
| POST | `/dukkan/isletme/{id}/telefon-dogrula` | İ |
| POST | `/dukkan/isletme/{id}/yorum-daveti` | İ | **Kota kontrolü** (`03` §2.2) |
| POST | `/dukkan/yorum/{id}/cevap` | İ |

> **Kural:** yukarıdaki her uç için, **başka** bir işletmenin sahibiyle
> çağrıldığında **403** bekleyen bir test zorunludur. Testsiz uç birleşmez.

---

## 6. Yorum, moderasyon

| Metot | Yol | Kim |
|---|---|---|
| POST | `/dukkan/is/{id}/yorum` | K | Katman A |
| POST | `/dukkan/yorum-daveti/{kod}/yorum` | — | Katman B, OTP'li |
| POST | `/dukkan/yorum/{id}/bildir` | K/İ | Moderasyona |
| GET | `/dukkan/moderasyon/kuyruk` | M | Tek ekran (`03` §5.4) |
| POST | `/dukkan/moderasyon/isletme/{id}/karar` | M | onayla/reddet/askıya al — **gerekçe zorunlu** |
| POST | `/dukkan/moderasyon/yorum/{id}/karar` | M | |
| POST | `/dukkan/moderasyon/sikayet/{id}/karar` | M | |

Her moderasyon kararı `denetim`e gerekçesiyle yazılır — kararın kendisi kadar
**neden** verildiği de saklanır (itiraz süreci buna dayanıyor).

---

## 7. BFF vekil bütünlüğü — sözleşme kapısı

`admin-web/tests/uc-sozlesme-kapisi.test.ts`'i ölçtüm (M8): bu kapı zaten var
ve **tam da bu sınıf hatayı** yakalamak için yazılmış. Dukkan gün 1'de aynısını
kurar.

Yakaladığı hata, hafızada iki kez kayıtlı (P173, P189):

> `admin-web` BFF `route.ts` bir metodu **export etmezse**, backend ucu
> mükemmel çalışsa bile web çağrısı **405** alır. Testler bunu yakalamaz,
> çünkü testler backend'i ölçer; kırılan **arada** kalan katmandır.

`apps/dukkan-web` için kapı:
1. `/dukkan/*` uçlarını `contracts/openapi.yaml`'dan okur.
2. `apps/dukkan-web/app/api/**/route.ts` altındaki vekilleri tarar.
3. **Metot metot** karşılaştırır: `POST` var, vekilde yalnız `GET` export
   edilmişse → **test kırmızı**.
4. Kamu uçları (§1) muaf değil; SSR onları sunucudan çağırıyor olsa bile
   arayüzden çağrılan her uç vekil ister.

**Sessiz başarısızlık kuralı (bütün yazma uçlarına):** her yazma ucu **ne
yaptığını sayıyla** döndürür — `{"olusturulan": 0}` gibi. Sıfırsa arayüz
"Kaydedildi" **demez**. P217'de ölçtüğümüz kusur birebir buydu: toplu
borçlandırma hiçbir kayıt üretmediği hâlde ekranda "Kaydedildi" yazıyordu ve
finans modülü kullanılamaz hâldeydi — hata veren bir şey yoktu, sadece
**hiçbir şey olmuyordu**.

---

## 8. Yönetiyor tarafındaki uçlar (Dukkan değil)

`app.yonetiyor.com` "Yerel İşletmeler" ve mobil sekme, Dukkan uçlarını
**kullanıcının Dukkan jetonuyla** çağırır. Yönetiyor'a eklenen tek şey
SSO köprüsü (`POST /dukkan/auth/yonetiyor`).

V2 (`00-mimari.md` §4): "Dış Hizmetler listeme ekle" → Yönetiyor'un **kendi**
`POST /external-services` ucu, kullanıcının **kendi** Yönetiyor jetonuyla.
Dukkan `dis_hizmet` tablosuna yazmaz; `dukkan_app` rolü zaten yazamaz.
