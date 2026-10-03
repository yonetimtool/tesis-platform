-- (P253 §B) SALT OKUMA — "gonderdim sanilip GITMEYEN" toplu mesaj olcumu.
-- Prod'da: docker compose -f infra/docker-compose.prod.yml exec -T db \
--   psql -U <kullanici> -d <db> -f - < docs/P253-mesaj-olcumu.sql
--
-- Iki sinif:
--  (1) WEB'DEN gonderim YAPILAMIYORDU (gonder dugmesi yoktu, onizleme 422).
--      Yonetici "gonderdim" diyemezdi; ama bu sinif gonderimin HIC
--      olmadigini soyler — beklenen duyuru gitmemis olabilir.
--  (2) API/baska yuzeyden yapilan gonderimde kanal YAPILANDIRILMAMISKEN
--      (`yapilandirilmadi`) gonderene "gonderildi" sayaci donuyordu.
-- KVKK: kisi/adres SECILMEZ; yalniz tesis, gun ve sayilar.

-- (2) Gonderene "gonderildi" denip aslinda GITMEYENLER (elle gonderim:
--     gonderen_user_id dolu).
SELECT t.slug AS tesis,
       date_trunc('day', g.created_at)::date AS gun,
       g.kanal,
       count(*) FILTER (WHERE g.durum = 'yapilandirilmadi') AS gitmedi_ama_gonderildi_dendi,
       count(*) AS toplam
FROM mesaj_gonderim g
JOIN tenant t ON t.id = g.tenant_id
WHERE g.gonderen_user_id IS NOT NULL
GROUP BY 1, 2, 3
HAVING count(*) FILTER (WHERE g.durum = 'yapilandirilmadi') > 0
ORDER BY 2 DESC;

-- Elle toplu gonderim denemesi hic olmus mu (denetim kaydi)?
SELECT t.slug AS tesis, count(*) AS gonderim_istegi,
       coalesce(sum((a.meta->>'gonderildi')::int), 0) AS sayacta_gonderildi
FROM audit_log a JOIN tenant t ON t.id = a.tenant_id
WHERE a.action = 'mesaj_gonder'
GROUP BY 1 ORDER BY 2 DESC;
