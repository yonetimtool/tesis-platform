-- (P228 ek) EYLEM — teshisten SONRA, sirayla.
--
-- =========================================================================
-- ONERILEN YOL: SILME DE ANONIMLESTIRME DE DEGIL -> `is_active = false`
-- =========================================================================
--   SERT SILME      -> tahsilat SAHIPSIZ kalir (FK SET NULL). Geri donusu
--                      yok.
--   ANONIMLESTIRME  -> bu hesapta ZATEN TETIKLENMEZ (teshis §1). Elle
--                      zorlanirsa kimlik alanlari silinir ve tahsilat
--                      "Anonim" bir satira baglanir. O bir KVKK aracidir;
--                      burada silinmesi gereken bir KISI yok, kaldirmak
--                      istediginiz bir UYELIK var.
--   is_active=false -> sahiplik KORUNUR, satir "Tesis degistir"
--                      listesinden DUSER (`/me/tesislerim` `is_active`
--                      suzer), o tesise GIRIS reddedilir (login yalniz
--                      `is_active` satirlari degerlendirir), P192'nin
--                      append-only korumasina DOKUNULMAZ, GERI ALINABILIR.
--
-- 4. sorunun yaniti: ters kayit GEREKMIYOR. Ters kayit defteri netler ama
-- sert silmeyi engellemez; pasiflestirme zaten silmiyor, o yuzden tahsilat
-- kaydina HIC dokunmaya gerek yok.

-- ---------------------------------------------------------------------
-- ADIM 1 — ASIL SORUN: seciciyi geri kazan (P228 sonrasi SART)
-- ---------------------------------------------------------------------
-- Bu YAPILMAZSA, P228 dagitildiktan sonra Oltu oturumundan platforma
-- GECEMEZSINIZ: `/me/tesis-degistir` dogrulanmamis e-postayi kimlik
-- saymiyor. Giris yolu etkilenmez (orada parola kanit yerine gecer).
BEGIN;
UPDATE app_user SET eposta_dogrulandi = true
WHERE lower(email) = 'yonetimtool@gmail.com';
SELECT t.ad, u.role, u.eposta_dogrulandi
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE lower(u.email) = 'yonetimtool@gmail.com' ORDER BY t.ad;
COMMIT;

-- ---------------------------------------------------------------------
-- ADIM 2 — Oltu yonetici uyeligini PASIFLESTIR (silme degil)
-- ---------------------------------------------------------------------
-- ONCE ADIM 1'i yapin ve panele girebildiginizi DOGRULAYIN. Girebiliyorsaniz
-- bu adim gerekmeyebilir; karari ondan sonra verin.
--
-- BEGIN;
-- UPDATE app_user u
-- SET is_active = false
-- FROM tenant t
-- WHERE t.id = u.tenant_id
--   AND lower(u.email) = 'yonetimtool@gmail.com'
--   AND t.ad = 'Oltu Sitesi'
--   AND u.role = 'yonetici';
-- SELECT t.ad, u.role, u.is_active
-- FROM app_user u JOIN tenant t ON t.id = u.tenant_id
-- WHERE lower(u.email) = 'yonetimtool@gmail.com' ORDER BY t.ad;
-- COMMIT;

-- GERI ALMA: ayni UPDATE'i `is_active = true` ile calistirin.
