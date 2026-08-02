# Hesap silme — ne silinir, ne kalır (P112)

> Bu belge **iki soruyu birden** yanıtlar: Apple'ın 5.1.1(v) kuralı ("hesap
> uygulama içinden silinebilmeli") ve KVKK'nın silme hakkı (md. 7 / md. 11).
> İkisi aynı düğmeye bakar ama farklı şeyler sorar; ayrım burada yazılıdır ve
> kodda **tek yerde** yaşar: `backend/app/hesap_silme.py`.

## 1. Kullanıcı ne yapar

**Mobil → Ayarlar → en alt → "Hesabımı sil".** Onay penceresi ne silinip ne
kalacağını **açıkça** yazar, sonra **parolayı yeniden ister**.

Yeniden kimlik doğrulama sarttır: ödünç alınmış ya da kilidi açık bırakılmış
bir telefonda, tek dokunuşla başkasının hesabı silinememeli. `PATCH
/me/password` ile aynı desen.

Uç: `POST /me/hesap-sil` · gövde `{"current_password": "..."}`.

## 2. İKİ MOD — hangisi olacağı hesabın geçmişine bağlıdır

| Mod | Ne zaman | Sonuç |
|---|---|---|
| `deleted: true` (tam silme) | Hesabın **hiçbir geçmişi yok** (yeni açılmış, işlem yapmamış) | `app_user` satırı **tamamen** kalkar |
| `deleted: false` (anonimleştirme) | Hesabın geçmişi **var** (aidat, ödeme, talep, tur…) | Satır kalır, **kimlik alanları temizlenir** |

**İkisi de başarıdır.** `false` "silinemedi" demek değildir; uygulama
kullanıcıya bunu ayrı bir cümleyle söyler — aidat kaydının durduğunu sonradan
öğrenen kullanıcı kandırıldığını düşünürdü.

Hangisi olacağı **tahmin edilmez, denenir**: silme bir SAVEPOINT içinde
denenir, veritabanı `RESTRICT` ile itiraz ederse anonimleştirmeye düşülür.
Tahmin etmek (önce "geçmişi var mı" diye saymak) yeni bir tabloyu listeye
eklemeyi unutunca **sessizce yanlış mod** seçerdi.

## 3. SİLİNEN — kişisel veri

| Alan | Sonrası |
|---|---|
| `ad` | `Silinmiş Kullanıcı` (sabit yer tutucu) |
| `email`, `telefon` | `NULL` |
| `password_hash`, `temp_code_hash` | `NULL` → **giriş imkânsız** |
| `avatar_key` | `NULL` |
| `user_device` (cihaz + push jetonları) | **satırlar silinir** |
| aktif `unit_resident` bağları | kapatılır (`bitis` damgalanır) |
| `is_active` | `false` |

`ad` neden `NULL` değil: kolon NOT NULL'dur ve bu değer **başka sakinlerin**
ekranında (eski talep, karar defteri) görünür; boş bırakmak orada bir boşluk
çizerdi.

**Erişim anında kesilir:** `get_current_user` her istekte `is_active` bakar,
yani elindeki access token o an geçersizleşir. Refresh de `is_active`
kontrolünden geçemez.

## 4. KALAN — yasal saklama yükümlülüğü

| Kayıt | Neden kalır |
|---|---|
| `dues_assessment`, `dues_payment`, `finansal_hareket` | TTK ve vergi mevzuatı **defterlerin saklanmasını emreder** |
| `audit_log` | KVKK'nın kendisi işleme faaliyetinin izlenebilirliğini ister; append-only |
| `hesap_silme_kaydi` | Silmenin **kanıtı** (§5) |
| talep/şikâyet, tur/okutma kayıtları | Tesis operasyonunun kaydı; artık **anonim** kullanıcıya işaret eder |

**Bu bir tercih değil, zorunluluk.** KVKK md. 7 silme hakkı, **başka bir
kanunun öngördüğü saklama yükümlülüğünü ortadan kaldırmaz** (md. 28 ve Kurul
kararları). Alternatif — ödemeyi silmek — kasa bakiyesini geçmişe dönük
değiştirirdi ve **başka sakinlerin** mutabakatını bozardı: bir kişinin silme
hakkı, diğerlerinin doğru hesap görme hakkını yok edemez.

Kalan satırlar artık **kime ait olduğu bilinmeyen** bir kullanıcıya işaret
eder. Yani kayıt duruyor, **kişi** durmuyor.

## 5. Kanıt — `hesap_silme_kaydi` (göç `0029`)

Kişisel verinin kendisi gittiği için "sildik" demenin dayanağı ondan bağımsız
olmak zorunda. `audit_log` yetmez: saklama politikası gereği **purge edilir**
(`retention_audit_months`, varsayılan 24 ay) ve silme talebinde bulunan kişi
bundan **sonra** sorabilir.

Tablo `retention` motoruna **dâhil değildir** ve içinde **kişisel veri
yoktur**: yalnız `tenant_id`, `user_id`, `rol`, `mod`, `kendi_istegi`, zaman.
`app_rw` yalnız `SELECT`/`INSERT` alır — değiştirilebilen bir kanıt kanıt
değildir.

`kendi_istegi` alanı **kullanıcının kendisi mi sildi, yönetim mi çıkardı**
sorusunu ayırır; "kullanıcılar silme hakkını fiilen kullanabiliyor mu"
sorusunun sayıyla yanıtlanmasını sağlar.

## 6. Uç durum — son yönetici

Tesisin **tek** admin/yöneticisi kendini silmek isterse **409** döner ve hata
metni ne yapılacağını söyler: **önce başka bir yöneticiye devret**.

Neden: son yönetici giderse tesis **sahipsiz** kalır — kimse yeni yönetici
atayamaz, sakin ekleyemez, aidat işleyemez; kurtarma ancak platform operatörü
elle müdahale ederse olur.

**Apple kuralına aykırı değildir.** 5.1.1(v) "hesap silinebilmeli" der,
"tesisi kullanılamaz bırak" demez. Kullanıcının önünde açık, tek adımlık ve
uygulama içinde tamamlanabilir bir yol vardır. Engel "yönetici silinemez"
değil, "**sonuncusu** silinemez"dir: ikinci bir yönetici varken silme çalışır
(testle kilitli).

## 7. Yönetim tarafı aynı çekirdeği kullanır

`DELETE /residents/{id}` (yönetici bir sakini çıkarır) **aynı** fonksiyonu
çağırır. İki ayrı uygulama yazmak, KVKK ayrımını iki yerde tutmak ve birinde
düzeltilip diğerinde unutulan bir alanın **silinmiş sanılan kişisel veri**
bırakması demekti.

Denetim kaydında ayrılırlar: `account_self_delete` (kullanıcı) ·
`resident_delete` / `resident_erasure` (yönetim).

## 8. Panel (admin-web) neden bu düğmeyi taşımıyor

Panel App Store'a gönderilmiyor; 5.1.1(v) **uygulamayı** bağlar. Panelde
oturum açan admin, mobil uygulamadan da giriş yapıp hesabını silebilir —
yani hakkın kullanımı engellenmiş değil. Panele ayrı bir silme akışı
eklemek, aynı kuralın üçüncü bir kopyası olurdu.

## 9. Testler

* `backend/tests/test_hesap_silme.py` — iki mod, defterin **kendisinden**
  doğrulama (kasa/talep kaydı duruyor mu), yeniden kimlik doğrulama, son
  yönetici engeli, kanıt satırının **tek** olması, yönetim silmesinin
  `kendi_istegi=false` yazması.
* `mobile/test/hesap_silme_test.dart` — giriş noktası görünüyor mu, onay
  metni **iki tarafı da** yazıyor mu, parolasız silme isteği gitmiyor,
  `deleted=false` **başarı** olarak gösteriliyor, 409 metni aynen çiziliyor
  ve pencere kapanmıyor.
