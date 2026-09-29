-- (P249 §1) SOS TESHISI — SALT OKUMA. Prod veritabaninda sahip rolle
-- (RLS'i asan) calistirin. Hicbir satiri degistirmez.
--
-- Kullanim:
--   docker compose -f infra/docker-compose.prod.yml exec -T db \
--     psql -U <sahip> -d <db> -f /dev/stdin < docs/P249-sos-teshis.sql
--
-- Son 5 SOS alarmini ve HER ALICI icin zinciri tek satirda gosterir:
--   kategori   : alarmda saklanan kategori (bos = kategorisiz basildi)
--   cihaz      : alicinin AKTIF cihaz kaydi var mi, platform, surum
--   mobil      : bildirim_mobil (false ise P249 oncesi push HIC gitmez)
--   sesli      : bildirim_sesi  (false ise P249 oncesi SESSIZ kanal)
--   push_sonuc : push_gonderim satiri (gonderildi / basarisiz / hedef_yok
--                / yapilandirilmadi) ve FCM hata kodu
--   goruldu    : alici uygulamada "gordum" dedi mi

WITH son AS (
    SELECT id, tenant_id, tip, kategori, durum, created_at, gonderildi_at
    FROM panik_alarm
    ORDER BY created_at DESC
    LIMIT 5
)
SELECT
    s.created_at AT TIME ZONE 'Europe/Istanbul' AS alarm_saati,
    s.tip,
    COALESCE(s.kategori::text, '(kategorisiz)') AS kategori,
    s.durum,
    u.role::text AS alici_rol,
    left(u.id::text, 8) AS alici,
    (SELECT count(*) FROM user_device d
      WHERE d.user_id = u.id AND d.aktif) AS aktif_cihaz,
    (SELECT string_agg(d.platform || ' ' || COALESCE(d.uygulama_surum, '?'), ', ')
       FROM user_device d WHERE d.user_id = u.id AND d.aktif) AS cihazlar,
    u.bildirim_mobil AS mobil,
    u.bildirim_sesi AS sesli,
    (SELECT string_agg(p.durum || COALESCE('/' || p.hata_kodu, ''), ', ')
       FROM push_gonderim p
      WHERE p.user_id = u.id
        AND p.kimlik LIKE 'panik%'
        AND p.created_at BETWEEN s.created_at AND s.created_at + interval '2 minutes'
    ) AS push_sonuc,
    a.goruldu_at IS NOT NULL AS goruldu
FROM son s
JOIN panik_alici a ON a.alarm_id = s.id
JOIN app_user u ON u.id = a.user_id
ORDER BY s.created_at DESC, u.role::text;

-- Alici satiri OLMAYAN alarmlar (yayin hic calismadi mi?):
SELECT s.created_at AT TIME ZONE 'Europe/Istanbul' AS alarm_saati, s.tip,
       s.kategori, s.durum, s.gonderildi_at
FROM panik_alarm s
WHERE NOT EXISTS (SELECT 1 FROM panik_alici a WHERE a.alarm_id = s.id)
ORDER BY s.created_at DESC
LIMIT 5;

-- Hedef bulunamayan SOS gonderimleri (kullanici yok / tercih kapali):
SELECT created_at AT TIME ZONE 'Europe/Istanbul' AS saat, kimlik, durum, hata_kodu
FROM push_gonderim
WHERE kimlik LIKE 'panik%' AND user_id IS NULL
ORDER BY created_at DESC
LIMIT 10;
