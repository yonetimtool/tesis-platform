-- (P253 acil, goc 0170) E-POSTA HARF CAKISMASI — SALT OKUMA listesi.
--
-- Prod'da calistirma (yalniz SELECT; hicbir sey degistirmez):
--   docker compose -f docker-compose.prod.yml exec -T db \
--     psql -U <owner> -d <db> -f - < docs/eposta-harf-cakisma.sql
--
-- Goc 0170 kucuk hali bir benzersizlik kuralina takilan satiri ATLAR ve
-- birlestirmez. Atlanan satir = gocten sonra hala kucuk OLMAYAN satir.
-- Sorgu gocten ONCE de calisir (1 ve 2 ayni sonucu verir; 3 o zaman
-- kucultulecek TUM satirlari listeler).

\echo '== 1. AYNI TESISTE harf farkiyla ikiz hesap (karar sizde; goc dokunmadi) =='
SELECT t.slug AS tesis, u.id, u.email, u.role, u.ad, u.soyad,
       u.created_at, u.last_login_at, u.is_active
  FROM app_user u JOIN tenant t ON t.id = u.tenant_id
 WHERE (u.tenant_id, lower(btrim(u.email))) IN (
         SELECT tenant_id, lower(btrim(email)) FROM app_user
          WHERE email IS NOT NULL
          GROUP BY 1, 2 HAVING count(*) > 1)
 ORDER BY lower(btrim(u.email)), u.created_at;

\echo '== 2. FARKLI TESISLERDE ayni adres (bilgi; goc yalniz kucultur) =='
SELECT lower(btrim(u.email)) AS eposta,
       string_agg(t.slug || ' (' || u.role || ')', ', ' ORDER BY u.created_at) AS tesisler
  FROM app_user u JOIN tenant t ON t.id = u.tenant_id
 WHERE u.email IS NOT NULL
 GROUP BY 1 HAVING count(*) > 1
 ORDER BY 1;

\echo '== 3. Gocten sonra hala kucuk OLMAYAN satirlar (atlananlar) =='
SELECT 'app_user' AS tablo, tenant_id::text AS tesis, email AS eposta FROM app_user
 WHERE email ~ '[A-Z]' OR email <> btrim(email)
UNION ALL SELECT 'tesis_uyelik', tenant_id::text, eposta FROM tesis_uyelik
 WHERE eposta ~ '[A-Z]' OR eposta <> btrim(eposta)
UNION ALL SELECT 'oauth_kimlik', tenant_id::text, eposta FROM oauth_kimlik
 WHERE eposta ~ '[A-Z]' OR eposta <> btrim(eposta)
UNION ALL SELECT 'yonetici_basvuru', NULL, eposta FROM yonetici_basvuru
 WHERE eposta ~ '[A-Z]' OR eposta <> btrim(eposta)
UNION ALL SELECT 'kayit_onay_kuyrugu', tenant_id::text, eposta FROM kayit_onay_kuyrugu
 WHERE eposta ~ '[A-Z]' OR eposta <> btrim(eposta)
ORDER BY 1, 3;
