-- (P228) DAGITIM ONCESI DUZELTME — MESRU cok-tesisli hesaplari koru.
--
-- =========================================================================
-- BUNU KORU KORUNE CALISTIRMA
-- =========================================================================
-- Bu betik, ASAGIDA ACIKCA SAYILAN adresleri "dogrulanmis" isaretler.
-- Her biri, o adresin GERCEKTEN tek bir kisiye ait oldugunu bildiginiz
-- icin yazilmalidir. Bir adresi burada dogrulanmis isaretlemek, o adresi
-- tasiyan TUM tesislerdeki satirlarin AYNI KISI oldugunu beyan etmektir —
-- P228'in kapattigi sizinti tam olarak bu beyanin YAPILMAMIS olmasiydi.
--
-- `yonetimtool@gmail.com`: platform isletmecisinin kendi hesabi, uc
-- tesiste de ayni kisi. Isaretlenmezse P228 sonrasi "Tesis degistir"
-- listesinde yalniz Oltu Sitesi'ni gorur (GIRIS calismaya devam eder;
-- giriste parola kanit yerine gecer).
--
-- `kafkasozunde@gmail.com`: CityAmbiance69'da security, Oltu'da resident.
-- AYNI KISI OLDUGUNU DOGRULAYIN — degilse bu satiri CALISTIRMAYIN;
-- o zaman P228 dogru davraniyor ve iki kisiyi ayirmis oluyor.

BEGIN;

UPDATE app_user
SET eposta_dogrulandi = true
WHERE lower(email) = lower('yonetimtool@gmail.com');

-- ONCE DOGRULAYIN, sonra yorumu kaldirin:
-- UPDATE app_user
-- SET eposta_dogrulandi = true
-- WHERE lower(email) = lower('kafkasozunde@gmail.com');

-- Sonucu GORUN, sonra COMMIT edin.
SELECT u.email, t.ad AS tesis, u.role, u.eposta_dogrulandi
FROM app_user u JOIN tenant t ON t.id = u.tenant_id
WHERE lower(u.email) IN ('yonetimtool@gmail.com', 'kafkasozunde@gmail.com')
ORDER BY u.email, t.ad;

COMMIT;
