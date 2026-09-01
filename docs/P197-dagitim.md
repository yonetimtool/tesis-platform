# P197 — dağıtım notları

**Göç 0089** (`app_user.email` NOT NULL). Yedek aldıktan sonra.

---

## 1. ÖNCE: neyin değişeceğini görün

Göçten **önce** çalıştırın — hangi satırların sentetik adres alacağını
gösterir:

```sql
SELECT u.id, u.ad, u.role, u.is_active, u.created_at, t.ad AS tesis
  FROM app_user u JOIN tenant t ON t.id = u.tenant_id
 WHERE u.email IS NULL OR btrim(u.email) = ''
 ORDER BY u.created_at;
```

Beklenen: **12 satır** (sizin ölçtüğünüz test kayıtları). Sayı farklıysa
**durun** — göç, beklemediğiniz bir hesabı da işaretleyecek demektir.

## 2. Göç

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml run --rm migrate
docker compose -f docker-compose.yml -f docker-compose.prod.yml build api admin-web worker
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d api admin-web worker
```

Göç şunları yapar:
1. NULL/boş e-postaları `gecersiz+<user_id>@yonetiyor.invalid` ile
   doldurur, `eposta_dogrulandi=false` yapar.
2. `email` sütununu NOT NULL yapar + boş dizge CHECK'i ekler.
3. İki SECURITY DEFINER fonksiyonunu e-posta yazacak şekilde değiştirir
   ve `add_tenant_yonetici`nin **eski imzasını düşürür**.

## 3. SONRA: doğrulayın

```sql
-- Dokunulan satırlar (beklenen: 12)
SELECT count(*) FROM app_user WHERE email LIKE 'gecersiz+%@yonetiyor.invalid';

-- E-postasız satır kalmamalı (beklenen: 0)
SELECT count(*) FROM app_user WHERE email IS NULL OR btrim(email) = '';

-- Eski imza gitmeli (beklenen: 0)
SELECT count(*) FROM pg_proc
 WHERE proname = 'add_tenant_yonetici'
   AND pg_get_function_identity_arguments(oid) = 'uuid, text, text, text';
```

## 4. Geri alma

```bash
docker compose ... run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0088_tesis_adresi
```

Sentetik adresler NULL'a döner, NOT NULL ve CHECK kalkar, fonksiyonlar
eski imzalarına döner. Dev'de ölçüldü: 953 satır tam simetrik geri döndü.

> **`api` ve `admin-web` birlikte dağıtılmalı.** Panel `POST /tenants`
> gövdesine artık `email` koyuyor; eski panel + yeni sunucu = tesis
> açarken 422.

## 5. Davranış değişiklikleri

1. **`POST /tenants` ve `POST /tenants/{id}/yoneticiler` e-posta ister.**
   Panelde yönetici satırına e-posta alanı eklendi.
2. **`POST /residents` e-posta ister** (eskiden opsiyoneldi).
3. **`PATCH /residents/{id}` e-postayı temizleyemez** — `email: null`
   artık "dokunma" demek (eskiden boşaltıyordu).
4. **`POST /me/hesap-sil/kod-iste` (SMS) KALDIRILDI.** Hesap silme yalnız
   `/me/hesap-sil/eposta-kod-iste` üzerinden. Mobil zaten yalnız onu
   çağırıyordu.
5. **`POST /auth/kayit/tesis-olustur`**: sağlayıcı e-posta paylaşmadıysa
   422 `eposta_gerekli` (eskiden e-postasız yönetici açıyordu).

## 6. Sentetik adresli 12 hesap ne olacak?

Hiçbir şey yapmanız gerekmiyor — zaten kullanılamıyorlardı. İsterseniz
sonra temizleyebilirsiniz:

```sql
-- Önce bakın: bağlı geçmişleri var mı?
SELECT u.id, u.ad, u.is_active,
       (SELECT count(*) FROM finansal_hareket f WHERE f.olusturan_id = u.id) AS finans,
       (SELECT count(*) FROM complaint c WHERE c.acan_user_id = u.id)        AS talep
  FROM app_user u
 WHERE u.email LIKE 'gecersiz+%@yonetiyor.invalid';
```

Geçmişi olmayanları panelden silebilirsiniz (Kullanıcılar → Sil, akıllı
silme). Geçmişi olanlar anonimleştirilir ve defter korunur.
