-- (P228 ek) yonetimtool@gmail.com'un Oltu Sitesi kaydi — ONCE TESHIS.
--
-- =========================================================================
-- OLCULEN UC SEY (dev semasi; prod'la ayni goc seviyesi)
-- =========================================================================
--
-- 1. `finansal_hareket.user_id` FK'si RESTRICT DEGIL, ON DELETE SET NULL:
--
--      finansal_hareket_user_id_tenant_id_fkey
--        FOREIGN KEY (user_id, tenant_id) REFERENCES app_user(id, tenant_id)
--        ON DELETE SET NULL (user_id)
--
--    Sonucu beklentinin TERSI: `hesabi_sil_veya_anonimlestir` ONCE SERT
--    SILME dener ve ancak `IntegrityError` alirsa anonimlestirir. Tahsilat
--    kaydi sert silmeyi ENGELLEMEZ — yani hesap ANONIMLESTIRILMEZ,
--    GERCEKTEN SILINIR ve tahsilat sahipsiz kalir. "Anonimlestirme devreye
--    girer" varsayimi YANLIS.
--
--    app_user'a RESTRICT ile bagli tablolar (bu hesapta hicbirinde kaydi
--    yok): announcement, asset_checkout, budget_entry, complaint,
--    dues_payment, etkinlik, kargo, rezervasyon, scan_event, site_kurali,
--    task_completion, unit_access_permission, vehicle_pass, violation,
--    visitor.
--
-- 2. TERS KAYIT SERT SILMEYI ENGELLEMEZ. `iade_edilen_id` ile ters kayit
--    deftere IKINCI satir ekler; ORIJINAL satir hala hesabi isaret eder ve
--    silmede yine NULL'a duser. Ters kayit defteri NETLER, sahipligi
--    KORUMAZ.
--
-- 3. MIDDLEWARE BU SATIRI OKUMUYOR. `admin-web/middleware.ts` rolu
--    JETONDAN cozer (`tokenRolu(req.cookies.get(ACCESS_COOKIE))`),
--    veritabanindan DEGIL. Panele girememenin sebebi Oltu satirinin
--    VARLIGI degil, OTURUMUN o tesise ait olmasi. Satiri silmek panel
--    erisimini KENDILIGINDEN duzeltmez.

\echo '=== A) UC SATIRIN DURUMU ==='
SELECT u.id, t.ad AS tesis, u.role, u.is_active, u.eposta_dogrulandi,
       (u.password_hash IS NOT NULL) AS parola_var
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE lower(u.email) = 'yonetimtool@gmail.com'
ORDER BY t.ad;

\echo ''
\echo '=== B) PAROLALAR AYNI MI? ==='
\echo '    Ayni hash = ayni parola = giriste TESIS SECICI cikar (409).'
\echo '    Farkli hash = yazdiginiz parola HANGI satira uyuyorsa oraya'
\echo '    dusersiniz; Oltu yoneticisine duserseniz panel sizi app.*a atar.'
SELECT count(DISTINCT password_hash) AS farkli_parola_sayisi,
       count(*) AS satir_sayisi
FROM app_user WHERE lower(email) = 'yonetimtool@gmail.com';

\echo ''
\echo '=== C) TAHSILATIN SAHIBI VE KAYDEDENI ==='
SELECT fh.id, fh.tarih, fh.tip, fh.tutar_kurus,
       fh.user_id, fh.kaydeden_user_id, t.ad AS tesis
FROM finansal_hareket fh JOIN tenant t ON t.id = fh.tenant_id
WHERE fh.user_id IN (
        SELECT id FROM app_user WHERE lower(email) = 'yonetimtool@gmail.com')
   OR fh.kaydeden_user_id IN (
        SELECT id FROM app_user WHERE lower(email) = 'yonetimtool@gmail.com');
