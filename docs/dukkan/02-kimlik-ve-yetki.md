# DUKKAN — 02 · KİMLİK VE YETKİ

---

## 1. Üç kullanıcı tipi

| Tip | Nasıl girer | Dukkan kaydı |
|---|---|---|
| **Yönetiyor kullanıcısı** | Mevcut Yönetiyor jetonuyla (mobil/panel) | `dukkan_kullanici` + `dukkan_yonetiyor_bag` |
| **Bağımsız kullanıcı** | `dukkan.yonetiyor.com`'da telefon + OTP | Yalnız `dukkan_kullanici` |
| **İşletme sahibi** | Aynı şekilde girer, sonra işletme kaydı açar | + `isletme` (durum `onay_bekliyor`) |

Üçü de **aynı** `dukkan_kullanici` tablosunda. Ayrı tablolara bölmek, "aynı kişi
hem hizmet alıyor hem veriyor" gibi son derece olağan bir durumu iki hesaba
bölerdi.

---

## 2. Kimlik çapası: telefon (ölçüme dayanıyor)

`01-veri-modeli.md` §1'de ölçtüğüm gibi: Yönetiyor'da **telefon global
benzersiz**, **e-posta yalnız tesis içinde** benzersiz. Dolayısıyla iki
sistemi eşleştirebilecek tek alan telefon.

Somut sonuç: aynı e-postayla iki farklı tesiste kayıtlı iki **farklı** insan
olabilir (ortak ofis e-postası, aile hesabı). E-posta ile eşleştirseydim
bu ikisi Dukkan'da **tek hesapta birleşirdi** — birinin talepleri diğerine
görünürdü. Bu, sessiz ve ciddi bir veri sızıntısı sınıfı.

**Kural:** Dukkan'da `telefon_dogrulandi_at IS NULL` olan hiçbir kullanıcı
talep açamaz, teklif veremez, yorum yazamaz. Doğrulanmamış telefon, kimlik değil.

---

## 3. SSO — Yönetiyor kullanıcısı Dukkan'a nasıl girer

Ölçtüğüm gerçek (M2): Yönetiyor JWT'si `sub` + **`tenant_id`** + `role` taşıyor.
`tenant_id` zorunlu. Bağımsız Dukkan kullanıcısının tesisi yok → **Yönetiyor
jetonu Dukkan'da doğrudan kullanılamaz.** İki jeton dünyası var; köprü gerekiyor.

```
POST /dukkan/auth/yonetiyor
  Authorization: Bearer <YÖNETİYOR JWT>
  →  { dukkan_token, kullanici }
```

Akış:
1. Yönetiyor JWT'si **aynı süreçte** doğrulanır (imza + `exp`). Ağ atlaması yok,
   sır paylaşımı yok — `00-mimari.md` K1'in somut karşılığı.
2. `sub` + `tenant_id` ile köprüden (`kopru.py`, en fazla 3 fonksiyon) kişinin
   **doğrulanmış telefonu** ve **adı** alınır.
3. Telefon `dukkan_kullanici`'de aranır:
   - Varsa → o kullanıcı. Bağ yoksa `dukkan_yonetiyor_bag` eklenir.
   - Yoksa → yeni `dukkan_kullanici`, `telefon_dogrulandi_at = now()`.
4. **Dukkan'ın kendi jetonu** üretilir: `sub` = `dukkan_kullanici.id`,
   `tenant_id` **YOK**, `dukkan_rol`.

> **3. adımdaki devralma önemli:** Yönetiyor telefonu zaten SMS ile doğrulamış.
> Kullanıcıyı bir kez daha OTP'ye sokmak, hiçbir güvenlik kazancı olmadan
> SSO'nun bütün anlamını yok ederdi.

**Telefonu boş olan Yönetiyor kullanıcısı** (`app_user.telefon` nullable —
ölçtüm): SSO **tamamlanamaz**. Kullanıcıya Dukkan'da bir kez telefon+OTP
sorulur, sonra bağ kurulur. **ÖLÇÜLDÜ (Ö1) — ve sonuç bu yolu ana yol yapıyor: 3104 kullanıcının
837'sinde telefon YOK (%27).** Yani her dört Yönetiyor kullanıcısından biri
SSO'ya girdiğinde telefonu sorulacak. Bu, "nadir bir kenar durum" değil;
akışın **normal bir dalı**. Sonucu: telefon sorma adımı bir hata ekranı gibi
değil, kayıt akışının doğal bir parçası gibi tasarlanmalı.

**Bağımsızken sonradan Yönetiyor'a bağlanma:** telefon aynıysa aynı satırda
buluşurlar (`UNIQUE(telefon)`), geçmiş talepler korunur. Kendiliğinden çalışır —
kimlik telefona çapalı olduğu için.

---

## 4. Roller

Dukkan'ın rolü **Yönetiyor rolünden bağımsızdır**. Yönetiyor'da `yonetici`
olmak Dukkan'da hiçbir ayrıcalık vermez; bir site yöneticisi de Dukkan'da
sıradan bir hizmet alandır.

| Rol | Nereden gelir | Ne yapar |
|---|---|---|
| `misafir` | Jetonsuz | Arama, profil, yorum **okur** |
| `kullanici` | Doğrulanmış telefon | Talep açar, teklif görür, iş verir, yorum yazar |
| `isletme_sahibi` | `isletme.sahip_kullanici_id` | Kendi işletmesi + gelen talepler + teklif |
| `moderator` | Elle atanır | Onay kuyruğu, şikâyet, askı |

`isletme_sahibi` bir **jeton iddiası değil, bir sorgu sonucudur**.
Jetona gömülseydi: sahiplik değiştiğinde jeton eskimiş kalırdı ve askıya
alınmış bir işletme sahibi jetonu dolana kadar yetkisini kullanmaya devam ederdi.

---

## 5. Yetki sınırı: sahiplik (IDOR)

`00-mimari.md` K4: RLS yok, **açık kontrol + zorunlu test** var.

Tek yardımcı:
```
isletme_sahipligi_dogrula(kullanici_id, isletme_id) -> isletme | 403
```
İşletmeye ait **her** uç bundan geçer. İkinci bir yol açılmaz; açılırsa
kontrolün atlandığı yer orası olur.

**Kural (sözleşme kapısına bağlanacak):** `/dukkan/isletme/{id}/...` biçiminde
her uç için, **başka bir işletmenin sahibiyle çağrılınca 403** bekleyen bir
test zorunlu. Testi olmayan uç birleştirilmez.

Bunu bir süreç kuralı değil **makine kuralı** yapmamın sebebi ölçülmüş:
`uc-sozlesme-kapisi.test.ts` (M8) tam da "insan hatırlar" varsayımının
tutmadığı yerde işe yarıyor.

---

## 6. KVKK — sakinin verisi

> **Bu bölüm, prompt'unda "KRİTİK" dediğin kısım. Tasarımın tamamı buna göre
> kuruldu, sonradan eklenmiş bir kontrol listesi değil.**

### 6.1 Otomatik paylaşım YOK

Yönetiyor bir sakinin adını, telefonunu, **daire numarasını** ve açık adresini
biliyor. Dukkan'ın bunlara erişimi **fiziksel olarak** kapalı:
`dukkan_app` rolünün `public` şemasında yetkisi yok (`00-mimari.md` K2).

Yani "unutmayalım, sakin verisini işletmeye göndermeyelim" diye bir kural
yok — **gönderemez.** Kısıt koda değil veritabanına gömülü.

### 6.2 Kullanıcı ne paylaştığını görür ve seçer

Talep formunda üç açık onay, **üçü de kapalı başlar**
(`paylas_ad`, `paylas_telefon`, `paylas_adres` — `DEFAULT false`):

```
  Bu talebi gönderdiğinde işletmeler şunları görecek:
    ✓ Mahalle: Çatalmeşe (her zaman görünür — teklif verebilmeleri için)
    ✓ İhtiyacın açıklaması
    ☐ Adın
    ☐ Telefon numaran
    ☐ Açık adresin      → "İşi verdiğin ustaya iş kabulünden sonra açılır"
```

Varsayılanın `false` olması bir tercih değil, **güvenli yön seçimi**:
kullanıcı formu dikkatsiz doldurduğunda olan şey "veri paylaşılmadı" olmalı,
"veri paylaşıldı" değil.

### 6.3 İki aşamalı görünürlük

| Aşama | İşletmenin gördüğü |
|---|---|
| **Teklif** (`talep.durum='acik'`) | Kategori, açıklama, **yalnız mahalle**, bütçe. Ad/telefon/adres yalnız kullanıcı işaretlediyse |
| **İş kabul** (`is` satırı oluştu) | + açık adres, + telefon — **yalnız kabul edilen işletmeye** |

Kural sunucuda: `is` satırı yoksa `acik_adres` **hiçbir yanıtta yer almaz**.
Arayüzde gizlemek yetmez — ikinci istemci (mobil) geldiğinde o gizleme delinir.
`04-api-sozlesmesi.md` §4'te uç bazında, testle kilitli.

### 6.4 Daire numarası

Daire numarası Dukkan'da **ayrı bir alan değil**; varsa `acik_adres` serbest
metninin içinde, kullanıcının kendi yazdığı kadarıyla. Yönetiyor'un
`unit.no` bilgisi Dukkan'a **hiç gelmiyor** (§6.1).

### 6.5 Aydınlatma ve silme

- Kayıt anında Dukkan'ın **kendi** aydınlatma metni (`kvkk_onay_at`).
  Yönetiyor'un tenant `kvkk_metin`'i başka bir veri sorumlusuna ait; devralınmaz.
- Silme: `dukkan_kullanici.durum='silindi'`, kişisel alanlar anonimleştirilir.
  **Yorumlar anonim olarak kalır** — silinirse bir kullanıcı hesabını silerek
  olumsuz yorumunu geri alabilir ve bu, yorum sisteminin tamamını sömürülebilir
  kılar. Yönetiyor'un `kvkk-audit-retention` kalıbıyla aynı mantık.
- `denetim` kaydı korunur (hukuki ispat).

**EMİN DEĞİLİM:** Yönetiyor'da hesabını silen bir kullanıcının Dukkan hesabına
ne olacağı bir **ürün kararı** ve sana ait. Teknik olarak Dukkan hesabı
bağımsız yaşayabilir (telefon çapalı); ama kullanıcı "hesabımı sildim"
derken ikisini birden kastediyor olabilir. Sormadan karar vermiyorum.
