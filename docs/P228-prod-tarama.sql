-- (P228) PROD TARAMASI — sızıntıdan kimler etkilendi?
-- Bu dosya dev makinede ÇALIŞTIRILAMAZ (prod'a erişim yok). Prod'da:
--   docker compose -f infra/docker-compose.prod.yml exec -T db \
--     psql -U tesis_owner -d tesis -f - < docs/P228-prod-tarama.sql

\echo '=== 1) BİLDİRİLEN VAKA ==='
SELECT u.id, u.ad, u.email, u.eposta_dogrulandi, u.telefon, u.role,
       t.ad AS tesis
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE lower(u.email) = lower('keremasci34@gmail.com')
   OR u.telefon = '+905071531323'
ORDER BY t.ad;

\echo ''
\echo '=== 2) ETKİLENEN HERKES: aynı e-posta birden çok tesiste, EN AZ BİR'
\echo '    taraf DOĞRULANMAMIŞ. Bu satırların her biri bir sızıntıydı. ==='
SELECT lower(u.email) AS eposta,
       count(*)                                   AS tesis_sayisi,
       count(*) FILTER (WHERE u.eposta_dogrulandi) AS dogrulanmis,
       string_agg(t.ad || ' [' || u.role || (CASE WHEN u.eposta_dogrulandi
              THEN '/dogrulandi' ELSE '/DOGRULANMADI' END) || ']', ' | '
              ORDER BY t.ad) AS tesisler
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE u.email IS NOT NULL AND t.arsivlendi_at IS NULL
GROUP BY lower(u.email)
HAVING count(DISTINCT u.tenant_id) > 1
   AND count(*) FILTER (WHERE NOT u.eposta_dogrulandi) > 0
ORDER BY tesis_sayisi DESC, eposta;

\echo ''
\echo '=== 3) DÜZELTME SONRASI HÂLÂ ÇOK-TESİSLİ OLANLAR (meşru) ==='
\echo '    Telefonu aynı OLAN veya her iki tarafı da doğrulanmış olanlar.'
SELECT lower(u.email) AS eposta, count(DISTINCT u.tenant_id) AS tesis_sayisi
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE u.email IS NOT NULL AND u.eposta_dogrulandi AND t.arsivlendi_at IS NULL
GROUP BY lower(u.email)
HAVING count(DISTINCT u.tenant_id) > 1
ORDER BY tesis_sayisi DESC;

\echo ''
\echo '=== 4) GERÇEKTEN GEÇİŞ YAPILDI MI? (denetim kaydı) ==='
\echo '    Sızıntının SÖMÜRÜLÜP sömürülmediğini bu gösterir.'
SELECT created_at, actor_user_id, action, meta
FROM audit_log
WHERE action ILIKE '%tesis%degis%' OR action ILIKE '%tenant%switch%'
ORDER BY created_at DESC
LIMIT 100;
