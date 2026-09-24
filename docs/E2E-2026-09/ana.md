# Ana ajan — kurulum sırasında görülenler

### ANA-1: Platformun verdiği geçici kod birleşik girişte (/auth/login) çalışmıyor
- Sınıf: Ciddi (doğrulanacak: kurulum ajanı web'de ölçüyor)
- Olan: POST /tenants → yönetici `temp_code` döner. `/auth/login` (web + tek alan) yalnız `password_hash` doğrular → 401. Yalnız eski `/auth/login-phone` temp code kabul ediyor.
- Kök neden: backend/app/routers/auth.py `login()` ~L231 — `password_set=false` dalı yok.

### ANA-2: POST /tenants yönetici alanı `phone`, POST /users `telefon` — sözleşme tutarsızlığı
- Sınıf: Küçük

### ANA-3: portal_base_url varsayılanı IDN `https://yönetiyor.com` (kanonik yonetiyor.com)
- Sınıf: Küçük — davet bağlantıları IDN ile gidiyor; bazı e-posta istemcileri punycode gösterip oltalama uyarısı verebilir.
- backend/app/config.py:133, infra/docker-compose.prod.yml:413

### ANA-4: Tekil daire no tesis genelinde benzersiz; B blokta "1" → "Daire no bu tesiste zaten kayıtlı"
- Sınıf: Orta (kurulum/tesis ajanı web formunu ölçüyor)
- uq_unit_tenant_no (tenant_id, no); bulk "A-1" üretir, tekil POST /units önek eklemez.
