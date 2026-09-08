# DUKKAN F5 — DAĞITIM NOTU

> F5 = **güven katmanı**: iki katmanlı yorum, davet kotası, cevap hakkı,
> şikâyet, askı adayları, **moderasyon paneli** ve **belge yükleme ekranı**
> (F2'den kalan iki açık madde).

---

## 1. Yeni ortam değişkeni

**Yok.**

---

## 2. Göç

**`0119_dukkan_guven`**

- `dukkan.yorum_daveti` — kod **hash'li** (telefon doğrulamayla aynı ilke)
- `dukkan.yorum_cevap` — `yorum_id` UNIQUE (bir yoruma bir cevap)
- `dukkan.sikayet` — `sikayetci_id` **NULLABLE** (kimliksiz şikâyet)
- `dukkan.yorum` + `inceleyen_id`, `incelendi_at`, `supheli_sebep`, `ip`

**Yönetiyor tablolarına DDL yok.**

---

## 3. Uygulama

> Kanonik komut **`docs/DAGITIM-SABLONU.md`**'den gelir ve `beat` HER
> ZAMAN listededir. Üç kez atlandı (P187/P192/F8b) ve zamanlayıcı
> sessizce eski kodla çalıştı — dördüncüsü olmasın diye artık şablondan
> türüyor ve `GET /health` → `beat` ile **ölçülüyor**.


```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api admin-web worker beat
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

---

## 4. Doğrulama

### 4.1 Güven kilitleri — **atlama**

```bash
docker compose -f docker-compose.prod.yml run --rm \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB" \
  api python -m pytest tests/test_dukkan_guven.py tests/test_dukkan_kvkk.py \
                       tests/test_dukkan_isletme_idor.py -q
# BEKLENEN: 63 passed
```

Kırmızı çıkarsa **dur ve bildir**.

### 4.2 Şikâyet gerçekten kimliksiz mi

```bash
API=https://api.yonetiyor.com
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$API/dukkan/sikayet" \
  -H 'content-type: application/json' \
  -d '{"tip":"odeme","metin":"Dagitim dogrulama kaydi, dikkate almayin."}'
# BEKLENEN: 201
```

**401 dönerse dur ve bildir:** kimlik zorunlu hâle gelmiş demektir ve
dolandırılan, hesabı olmayan kullanıcı şikâyet edemez.

> Bu istek prod'da **gerçek bir şikâyet kaydı** oluşturur. Moderasyon
> kuyruğundan kapatmayı unutma (sonuç: "dağıtım doğrulaması").

### 4.3 Yorum silme ucu OLMAMALI

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE \
  "$API/dukkan/yorum/00000000-0000-0000-0000-000000000000"
# BEKLENEN: 405 (metot yok) — 200/204 görürsen DUR
```

İşletmenin yorum silebilmesi, yorum sisteminin tamamını anlamsız kılar.

### 4.4 Moderatör kapısı

```bash
# Jetonsuz -> 401
curl -s -o /dev/null -w '%{http_code}\n' "$API/dukkan/moderasyon/yorum-kuyrugu"
# BEKLENEN: 401
```

Sıradan bir kullanıcı jetonuyla **403** dönmeli; kuyruk her şikâyetçinin
iletişim bilgisini ve her başvurunun vergi numarasını taşıyor.

### 4.5 Denetim hâlâ append-only

F5 denetime yeni satırlar yazıyor (kota aşımı, moderasyon kararları):

```bash
D="postgresql://dukkan_app:$DUKKAN_DB_PASSWORD@localhost:5432/$POSTGRES_DB"
docker compose -f docker-compose.prod.yml exec db psql "$D" \
  -c "UPDATE dukkan.denetim SET eylem='x' WHERE false;"
# BEKLENEN: permission denied for table denetim
```

---

## 5. Moderatör ataması — hâlâ elle

```sql
INSERT INTO dukkan.moderator (kullanici_id, atayan)
SELECT id, 'kerem' FROM dukkan.dukkan_kullanici WHERE telefon = '+90...';
```

Atama ucu **bilinçli olarak yok**: bir uçtan moderatör yapılabilseydi o uç
ürünün en tehlikeli yüzeyi olurdu. Moderasyon paneli
`dukkan.yonetiyor.com/moderasyon` adresinde — **site yayına açıldığında**
erişilebilir olacak.

---

## 6. SMS — davet kodları da Verimor'dan gidiyor

Yorum daveti SMS ile gönderiliyor. **Başlık onayı yoksa davet gönderilemez**
ve uç bunu açıkça söylüyor (`gonderildi: false`).

Kota **yine de tüketilir mi?** Hayır: davet kaydı oluşturulur ama SMS
gitmezse kullanıcı kodu alamaz. **Bu bir açık madde** — telefon OTP'sinde
"başarısız gönderim kotayı yemesin" kuralını uygulamıştım, davet kotasında
uygulamadım. Başlık onayı gelmeden davet özelliği kullanılmamalı.

---

## 7. `dukkan-web` — hâlâ dağıtılmıyor

Moderasyon paneli ve şikâyet formu **web'de**. Site açılmadan moderatör
paneline erişilemez; şimdilik moderasyon **API üzerinden** yapılabilir.

Servis eklendiğinde `networks: [tesisnet]` **mutlaka** (P215); ağ doğrulama
komutu `F3-dagitim.md` §5'te.

---

## 8. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0118_dukkan_talep_teklif_is
```

`yorum_daveti`, `yorum_cevap`, `sikayet` düşer; `yorum` tablosundaki dört
sütun kalkar. **`yorum` tablosunun kendisi kalır** (F3'te açılmıştı).

---

## 9. Risk

| Risk | Değerlendirme |
|---|---|
| Yönetiyor'a etki | **Yok** |
| Sahte yorum | **Bitirilmedi, maliyeti yükseltildi.** Bitirdiğini iddia eden bir tasarım yanlış olurdu |
| Haksız askı | Otomatik askı **yapılmadı** — kimliksiz şikâyet ucuz olduğu için rakip saldırısına açık olurdu. Aday listesi + insan kararı |
| Moderatör yükü | Günde ~10 başvuru + ~20 yorum + ~2 şikâyet varsayımıyla 20–30 dk. Bunun üstü **ekip sorunu**, ürün sorunu değil (`03` §5.4) |
| SMS maliyeti | Davet kodları kontör harcar; kota tavanı 30/ay/işletme |
