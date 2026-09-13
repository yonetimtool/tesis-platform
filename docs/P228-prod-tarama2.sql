-- (P228) IKINCI TUR — ilk taramanin ACIK BIRAKTIGI sorular.
--
-- BIRINCI TUR NE GOSTERDI:
--   * Kerem ASCI'nin TEK satiri var (CityAmbiance69). E-postasi hicbir
--     baska tesiste YOK, telefonu GLOBAL BENZERSIZ. Yani bildirilen vaka,
--     P228'de kapatilan mekanizmayla ACIKLANMIYOR.
--   * Buna karsilik IKI BASKA hesap gercekten sizdiriyordu.
--   * 4. sorgu kolon adi yanlisti: `audit_log.created_at` degil `ts`.

\echo '=== 4-DUZELTILMIS) TESIS DEGISTIRME DENETIM KAYITLARI ==='
\echo '    Sizintinin SOMURULUP somurulmedigini bu gosterir.'
SELECT ts, actor_user_id, action, meta
FROM audit_log
WHERE action ILIKE '%tesis%' OR action ILIKE '%tenant%' OR action ILIKE '%switch%'
ORDER BY ts DESC
LIMIT 100;

\echo ''
\echo '=== 5) KEREM ASCI HIC OLTU SITESINDE MIYDI? ==='
\echo '    Hesabi uzerindeki TUM denetim izi — satir tasinmis/silinmis'
\echo '    olabilir (kurtarma islemi ayni gunlerde yapildi).'
SELECT ts, action, tenant_id, meta
FROM audit_log
WHERE actor_user_id = '8d4edd61-09cf-411d-ac0d-daad618eb01c'
   OR meta::text ILIKE '%8d4edd61-09cf-411d-ac0d-daad618eb01c%'
ORDER BY ts DESC
LIMIT 50;

\echo ''
\echo '=== 6) OLTU SITESINDE bu telefon/e-posta HIC gecti mi? ==='
SELECT ts, action, tenant_id, meta
FROM audit_log
WHERE meta::text ILIKE '%keremasci34%'
   OR meta::text ILIKE '%905071531323%'
ORDER BY ts DESC
LIMIT 50;

\echo ''
\echo '=== 7) DAGITIM ONCESI UYARI — kimler SECICIYI KAYBEDECEK ==='
\echo '    P228 dagitilinca bu hesaplar "Tesis degistir" listesinde'
\echo '    yalnizca DOGRULANMIS satirlarini gorecek. GIRIS ETKILENMEZ'
\echo '    (giriste parola kanit yerine gecer).'
SELECT u.email,
       t.ad AS tesis,
       u.role,
       u.eposta_dogrulandi,
       CASE WHEN u.eposta_dogrulandi THEN 'kalir' ELSE 'SECICIDEN DUSER' END AS sonuc
FROM app_user u
JOIN tenant t ON t.id = u.tenant_id
WHERE t.arsivlendi_at IS NULL
  AND lower(u.email) IN (
    SELECT lower(email) FROM app_user
    WHERE email IS NOT NULL
    GROUP BY lower(email) HAVING count(DISTINCT tenant_id) > 1
  )
ORDER BY u.email, t.ad;
