# P228 — Çoklu tesis eşleştirmesi yanlış kişileri birleştiriyordu (VERİ SIZINTISI)

## 0. Bildirilen belirti

Kerem Aşçı (`keremasci34@gmail.com`, yönetici, CityAmbiance69) mobilde
**Ayarlar → Tesis değiştir** listesinde **Oltu Sitesi**'ni "Site Sakini"
olarak görüyordu. Oltu Sitesi'nde hiçbir kaydı yok.

## 1. Ölçüm — hipotez ÇÜRÜTÜLDÜ

İlk hipotez "ada göre eşleştirme" idi. **Yanlış.**

Ölçülen çağrı zinciri:

```
mobile/lib/src/features/tesis/data/tesis_api.dart:31
  → GET /me/tesislerim            (/auth/tesislerim DEĞİL)
  → backend/app/routers/me.py     → _uyelikler(session, user.email)
  → SECURITY DEFINER public.tenant_uyelikleri(p_kimlik)
```

Fonksiyonun gövdesi (dev'de okundu):

```sql
WHERE t.arsivlendi_at IS NULL
  AND (lower(u.email) = lower(btrim(p_kimlik)) OR u.telefon = btrim(p_kimlik))
```

**Ad üzerinden eşleşme hiçbir kod yolunda yoktur** (arandı). Sorun adda
değildi.

## 2. Gerçek kök neden — KISIT ASİMETRİSİ

```
uq_app_user_telefon        UNIQUE (telefon)            -> GLOBAL
uq_app_user_tenant_email   UNIQUE (tenant_id, email)   -> TENANT İÇİ
```

Telefon eşleşmesi kimliği **kanıtlar** (aynı numara iki kişide olamaz).
E-posta eşleşmesi **kanıtlamaz**: aynı adres farklı tesislerde farklı
kişilerde bulunabilir ve şemaya göre bu **meşrudur** — yönetici sakin
eklerken e-posta alanına herhangi bir adres yazabilir, doğrulama
gerekmez.

`tenant_uyelikleri` e-postayı `eposta_dogrulandi` değerine **bakmadan**
eşliyordu; `/me/tesislerim` ve `/me/tesis-degistir` hiçbir ek kanıt
aramıyordu. Sonuç: doğrulanmamış bir e-posta satırı **üyelik** sayılıyor
ve kullanıcı o tesise **gerçekten geçebiliyordu** (geçişten sonra RLS
bağlamı da o tesis olduğu için sakinler, aidatlar, şikâyetler görünür).

Bu, P180'de yazılan kuralın tekrarıdır: **doğrulanmamış e-posta kimlik
sayılmaz.** O kural kayıt/allowlist tarafına konmuş, üyelik listelemesine
konmamıştı.

## 3. Düzeltme — ve NEDEN paylaşılan fonksiyonda değil

Düzeltme `me.py` içinde `_dogrulanmis_uyelikler()` olarak yapıldı:

1. **Telefon** eşleşmesi → kabul (global benzersiz, kanıt).
2. **E-posta** eşleşmesi → **yalnız her iki taraf da doğrulanmışsa**.
3. **Kişinin kendi satırı** → her zaman listede (oturum zaten orada).

`tenant_uyelikleri` **kasten sıkılaştırılmadı**: o fonksiyon **girişte**
de kullanılıyor ve orada **parola** kanıt yerine geçiyor. Fonksiyonu
sıkılaştırmak, doğrulanmamış e-postalı kullanıcıların **girişini
kırardı** — sızıntıyı kapatmak için çalışan kullanıcıları dışarı atmak
kabul edilebilir bir bedel değil. Kanıt aranması gereken yer, hiçbir
kanıtı olmayan uçlardır.

**Liste ve geçiş aynı kuraldan geçiyor.** Yalnız listeyi daraltmak,
ucu doğrudan çağıran bir istemciye kapıyı açık bırakırdı: sızıntı
panelde görünmez ama **sürerdi**.

## 4. Kilitler — ve kırılarak kanıtlandı

`backend/tests/test_p228_tesis_esleme_sizintisi.py` (6 test):

| Test | Ne ölçüyor |
|---|---|
| `DOGRULANMAMIS_EPOSTA_BASKA_TESISI_LISTEYE_SOKMAZ` | sızıntının kendisi |
| `DOGRULANMAMIS_EPOSTA_ILE_TESIS_DEGISTIRILEMEZ` | geçiş ucu (403) |
| `AYNI_AD_FARKLI_KIMLIK_BIRLESMEZ` | ada göre eşleşme yok |
| `TELEFON_ESLESMESI_KABUL_EDILIR` | koruma fazla geniş değil |
| `KENDI_TESISI_HER_ZAMAN_LISTEDE` | seçici boş kalmıyor |
| `DOGRULANMIS_EPOSTA_ESLESMESI_CALISIR` | gerçek çok-tesisli kullanıcı çalışıyor |

**Fixture sızıntıyı zaten taşıyordu**: `world`'de `yonetici_a` ve
`yonetici_b` **aynı e-postayı** ama **farklı parolaları** taşır — yani
iki ayrı kişi, prod'daki durumun aynısı. Testler bu satırları kullanıyor.

Kırma denemeleri:

* Düzeltme geri alındı → 3 test düştü. ✔
* `AYNI_AD` testinin ilk yazımı ada göre değil **e-postaya** takılıyordu
  (sahte güven). B'deki e-posta bağı önce koparılacak şekilde
  düzeltildi; sonra `tenant_uyelikleri`'ne ada göre eşleşme eklendi →
  test düştü. ✔
* Ara bir kırma denemesi (ad sorgusunu `me.py`'ye eklemek) **RLS
  tarafından engellendi** — ikinci savunma katmanı olduğu böylece
  ölçüldü.

`test_tesis_izolasyonu_tarama.py`'ye "farklı kişi, aynı ad" senaryosu
eklendi. Not: o dosyanın tüm taramaları **sorgu** tarafına bakar
(bir uç başka tesisin satırını döndürüyor mu). P228 sorgu tarafında
değil **kimlik** tarafındaydı — sorgular doğruydu, kimin hangi tesise
ait olduğu yanlıştı. Hiçbir RLS testi bunu göremezdi, çünkü geçişten
sonra bağlam **gerçekten** o tesisti.

## 5. Kapsam — ölçemediğim şey

**Sızıntı ne zamandan beri var:** `/me/tesislerim` ilk yazıldığından
beri. Hiçbir sürümde `eposta_dogrulandi` denetimi bulunmuyordu — yani
bu bir regresyon değil, **baştan eksik** bir denetim.

**Prod'da kimler etkilendi — ÖLÇÜLDÜ (2026-09-13, kullanıcı çalıştırdı):**

| e-posta | tesis | durum |
|---|---|---|
| `yonetimtool@gmail.com` | 3 (Ergene Vadisi, Oltu Sitesi, Yönetio Platform) | 1 doğrulanmış, **2 doğrulanmamış** |
| `kafkasozunde@gmail.com` | 2 (CityAmbiance69 security, Oltu Sitesi resident) | 1 doğrulanmış, **1 doğrulanmamış** |

Bu iki hesabın her doğrulanmamış satırı bir sızıntıydı.

## 6. BİLDİRİLEN VAKA AÇIKLANMADI — düzeltme

Yukarıdaki §2'de anlatılan mekanizma **Kerem Aşçı'nın vakasını
açıklamıyor.** Prod taraması onun için tek satır gösteriyor:

```
Kerem AŞCI | keremasci34@gmail.com | dogrulandi=f | +905071531323 | yonetici | CityAmbiance69
```

E-postası başka hiçbir tesiste yok; telefonu global benzersiz. Yani
`tenant_uyelikleri` onun için Oltu Sitesi'ni **hiçbir koşulda**
döndüremezdi. §2'deki kök neden analizi **iki başka hesap için doğru**
ama **bildirilen vaka için kanıtlanmadı** — ilk raporda verilen üç satır
da (farklı e-posta, farklı telefon) bu mekanizmayla eşleşmiyordu ve bunu
o sırada fark etmeliydim.

Açık kalan üç olasılık, sıralı:

1. **Satır sonradan kalktı.** Aynı günlerde prod kurtarma işlemi
   yapıldı (platform admini kalmamıştı); Kerem'in Oltu'daki satırı o
   sırada silinmiş/taşınmış olabilir. `docs/P228-prod-tarama2.sql`
   §5–6 denetim kaydında bunu arar.
2. **İstemci önbelleği.** Mobil "Tesis değiştir" listesi bir kez
   çekilip saklanıyorsa, satır kalktıktan sonra da görünmeye devam
   ederdi.
3. **Üçüncü bir yol.** Ölçtüğüm iki uç dışında bir kaynak. `tesis_uyelik`
   tablosu arandı: modelde var, **hiçbir router onu okumuyor**.

Düzeltmenin kendisi bu belirsizlikten bağımsız olarak doğru ve
gereklidir — ölçülen iki gerçek sızıntıyı kapatıyor. Ama "bildirilen
şikâyetin nedeni buydu" **denemez**.

Tarama sorguları `docs/P228-prod-tarama.sql` ve
`docs/P228-prod-tarama2.sql`.

## 6. Web/mobil parite

**Her iki yüzey de aynı iki ucu kullanıyor** — düzeltme ikisini birden
kapatıyor, yüzeye özel kod gerekmedi:

| Yüzey | Liste | Geçiş |
|---|---|---|
| Mobil | `tesis_api.dart:31` → `GET /me/tesislerim` | `POST /me/tesis-degistir` |
| Web | `KullaniciMenusu.tsx:63` → `/api/me/tesislerim` (BFF) → `GET /me/tesislerim` | `/api/me/tesis-degistir` (BFF) → `POST /me/tesis-degistir` |

BFF katmanı yalnız vekillik yapıyor (`proxyJson`) ve jetonu çereze
yazıyor; üyelik kararına karışmıyor. Dolayısıyla **arka uçta kapatılan
sızıntı web'de de kapalıdır** — P226'daki "orta halka ölçülmedi"
durumundan farkı, burada orta halkanın karar vermemesidir.

`GirisFormu.tsx` → `/auth/tesislerim` **kasten dokunulmadı**: giriş
yolunda kanıt **paroladır**, üyelik listesi yalnız hangi tesise giriş
yapılacağını sorar ve her seçim için parola doğrulaması yapılır.
