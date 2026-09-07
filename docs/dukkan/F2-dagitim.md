# DUKKAN F2 — DAĞITIM NOTU

> **Prod'a sen alacaksın.** F2 = **arz tarafı**: kimlik (telefon OTP + Yönetiyor
> SSO), işletme kaydı, hizmet alanı seçimi, belge yükleme ve moderasyon kuyruğu.
>
> `dukkan.yonetiyor.com` bu turda da **yayına açılmıyor** — talep tarafı (F4)
> gelmeden gösterilecek bir ürün yok. F2'nin çıktısı, işletme toplamaya
> başlayabilmek.

---

## 1. Yeni ortam değişkeni — **prod'da bilinçli olarak YOK**

F1'de eklenen `DUKKAN_DB_USER` / `DUKKAN_DB_PASSWORD` dışında **yeni zorunlu
değişken yok**.

Bir tane var ama **prod'a KOYMA**:

```
DUKKAN_OTP_YANITTA=true     # YALNIZ DEV. Prod compose'unda YOK.
```

Bu ayar açıkken telefon doğrulama kodu **HTTP yanıtında** döner. Dev'de akışı
SMS sağlayıcısı olmadan sürebilmek için var.

**Varsayılanı `false` ve bu bilinçli bir güvenli-yön seçimi.** Kodu
"ortam production değilse aç" biçiminde bir koşula bağlamadım: ortam değişkeni
prod'da eksik ya da yanlış gelirse kod **sessizce herkese açılır** ve telefon
doğrulamasının tamamı anlamsızlaşırdı. Açıkça açılmadıkça kapalı.

> **Bunu dağıtımdan sonra doğrula** — §3.4.

---

## 2. Uygulama sırası

```bash
git pull

# KISMİ BUILD YAPMA (P213 dersi: 0107 zinciri komple düşürmüştü).
docker compose -f docker-compose.prod.yml build migrate api admin-web worker

# Göç 0115 + rol kurulumu
docker compose -f docker-compose.prod.yml up migrate

# `restart` YETMEZ: env tazelemez (P215'te ölçüldü).
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

Göç **0115_dukkan_kimlik_ve_isletme** 10 tablo ekler:
`dukkan_kullanici`, `dukkan_yonetiyor_bag`, `telefon_dogrulama`, `isletme`,
`isletme_kategori`, `isletme_hizmet_alani`, `isletme_belge`,
`isletme_calisma_saati`, `moderator`, `denetim`.

**Yönetiyor tablolarına DDL yok.** Hepsi `dukkan` şemasında.

---

## 3. Doğrulama

### 3.1 Göç ve append-only kilidi

`migrate` çıktısında **iki satır** görünmeli:

```
[setup_dukkan_role] denetim append-only (UPDATE/DELETE revoked).
[setup_dukkan_role] 'dukkan_app' hazır: 'dukkan' şemasında DML, 'public' şemasında SIFIR yetki (doğrulandı)
```

İlk satır F2'de eklendi ve **önemli**: `setup_dukkan_role.py` her koşumda
tüm tablolara blanket GRANT veriyor; `denetim` üzerindeki REVOKE yalnız
göçte yapılsaydı, ilk `migrate` koşumu append-only kilidini **sessizce
açardı**. Aynı ders `setup_app_role.py`'de `audit_log` için zaten yazılıydı.

Betik kendi işini doğruluyor: kalan bir UPDATE/DELETE yetkisi bulursa
**hata verip çıkar** (exit 1).

### 3.2 Denetim gerçekten append-only mi — elle teyit

```bash
D="postgresql://dukkan_app:$DUKKAN_DB_PASSWORD@localhost:5432/$POSTGRES_DB"

# BEKLENEN: INSERT 0 1
docker compose -f docker-compose.prod.yml exec db psql "$D" \
  -c "INSERT INTO dukkan.denetim (eylem) VALUES ('dagitim_kontrol');"

# BEKLENEN: permission denied for table denetim
docker compose -f docker-compose.prod.yml exec db psql "$D" \
  -c "UPDATE dukkan.denetim SET eylem='x' WHERE eylem='dagitim_kontrol';"

# BEKLENEN: permission denied for table denetim
docker compose -f docker-compose.prod.yml exec db psql "$D" \
  -c "DELETE FROM dukkan.denetim WHERE eylem='dagitim_kontrol';"
```

Yazabiliyor ama değiştiremiyor/silemiyor olmalı. Bir moderasyon kararı
sonradan "hiç verilmemiş" hâle getirilememeli — itiraz süreci buna dayanıyor.

### 3.3 F1 sınırı hâlâ duruyor mu

Göç yeni tablolar ve yeni GRANT'ler ekledi; sınırın bozulmadığını teyit et:

```bash
# BEKLENEN: 0
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM information_schema.table_privileges
   WHERE grantee='dukkan_app' AND table_schema='public';"
```

### 3.4 OTP kodu prod'da SIZMIYOR — **atlama**

```bash
curl -s -X POST https://api.yonetiyor.com/dukkan/auth/telefon/kod \
  -H 'content-type: application/json' \
  -d '{"telefon":"+905551112233"}'
```

Yanıtta **`dev_kod` OLMAMALI**. Beklenen gövde:

```json
{"gonderildi": true, "gecerlilik_dk": 10, "gonderim": "saglayici_bagli_degil"}
```

`dev_kod` görürsen **dur ve bildir**: `DUKKAN_OTP_YANITTA` prod'a sızmış
demektir ve telefon doğrulaması işlevsizdir.

### 3.5 İki jeton dünyası ayrı mı

```bash
# Yönetiyor jetonuyla Dukkan ucu -> BEKLENEN 401
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer <YÖNETİYOR_JETONU>" \
  https://api.yonetiyor.com/dukkan/auth/ben
```

Dukkan jetonu `tur: "dukkan"` iddiası taşır; Yönetiyor jetonu taşımaz. Aynı
JWT sırrı kullanıldığı için bu ayrım olmasaydı Yönetiyor jetonu Dukkan
uçlarında **geçerli sayılırdı**.

---

## 4. SMS sağlayıcısı BAĞLI DEĞİL — bilerek

Telefon doğrulama kodu üretiliyor ve saklanıyor (hash'lenmiş), ama
**gönderilmiyor**. Yanıt bunu **açıkça söylüyor**:
`"gonderim": "saglayici_bagli_degil"`.

Sessizce `"gonderildi": true` deyip hiçbir şey göndermek, kullanıcıyı olmayan
bir SMS'i beklerken bırakırdı — bu depoda P217'de ölçülmüş kusur sınıfı.

**Pratik sonucu:** prod'da F2 akışı **tamamlanamaz**. İşletme kaydı yalnızca
SMS sağlayıcısı bağlandıktan sonra gerçek kullanıcılarla sürülebilir.

**Bu bir eksik, ve senin kararını bekliyor:** hangi SMS sağlayıcısı? Yönetiyor
tarafında SMS ürün genelinde kapalı (e-posta kullanılıyor), dolayısıyla
devralınacak hazır bir entegrasyon **yok**. Sağlayıcıyı söylersen bağlarım.

---

## 5. Moderatör ataması — uç YOK, elle

```sql
INSERT INTO dukkan.moderator (kullanici_id, atayan)
SELECT id, 'kerem' FROM dukkan.dukkan_kullanici WHERE telefon = '+90...';
```

**Moderatör atama ucu bilerek yok.** Bir uçtan moderatör yapılabilseydi o uç
ürünün en tehlikeli yüzeyi olurdu: moderatör her başvurunun telefonunu, vergi
numarasını ve sahip bilgisini görüyor.

Aynı sebeple `moderator` **ayrı tablo**, `dukkan_kullanici` üzerinde bayrak
değil: bayrak olsaydı bir `UPDATE` hatası sıradan bir kullanıcıyı moderatör
yapabilirdi. Ayrı tabloya satır eklemek **kasıtlı** bir eylemdir.

---

## 6. `dukkan-web` yine DAĞITILMIYOR

Depoda duruyor ve derleniyor; `docker-compose.prod.yml`'ye servis, Caddy'ye
alan adı eklenmedi.

> **P215 dersi burada bekliyor:** servis eklendiğinde `networks: [tesisnet]`
> **mutlaka** yazılacak ve bu belgeye ağ doğrulama komutu girecek.

---

## 7. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0114_dukkan_veri_kaynagi
```

10 tabloyu düşürür. Lokasyon ve kategori verisi (F1) **korunur**.
Yönetiyor verisine dokunmaz — zaten dokunamaz.

---

## 8. Risk

| Risk | Değerlendirme |
|---|---|
| Yönetiyor verisine etki | **Yok.** Yeni tablolar `dukkan` şemasında; mevcut tablolara DDL yok |
| Mevcut uçlara etki | **Yok.** 18 yeni `/dukkan/*` ucu |
| Yönetiyor tablolarını OKUMA | **Var ama dar ve RLS'e tabi.** SSO köprüsü `app_user` + `tenant` okur; `set_tenant` ile RLS bağlamı kurulur, yani yalnız jetondaki tesisin satırları görünür |
| Bağlantı havuzu | Değişmedi (`pool_size=3, overflow=2`) |
| SMS maliyeti | **Yok** — sağlayıcı bağlı değil (§4) |
