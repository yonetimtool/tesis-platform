\set ON_ERROR_STOP on
-- SENTETIK HACIM — tarama olcumu icin (tur 77). `infra/tarama-olcumu.sh` yukler.
--
-- Dev veritabaninda tek tenant ve 2-8 satirli tablolar var; o hacimde Postgres
-- ZATEN seq scan secer ve "tam tarama" bir kusur DEGILDIR. Tarama davranisini
-- olcmek icin tek-kullanimlik bir veritabanina temsil edici hacim yazilir.
--
-- NOT — `dues_assessment`ta (tenant_id, unit_id, donem) TEKILDIR: 500 daire x
-- 24 donem = 12.000 satirdan fazlasi yazilamaz (ilk denemede kisit ihlali oldu).
--
-- NOT — asagida bazi zaman kolonlari ACIKCA verilir. Kolon VARSAYILANINI
-- (`now()`) kullanmak, tek ifadedeki TUM satirlara AYNI damgayi yazar; olcumde
-- 50.000 satir ayni `odeme_zamani`i paylasip (zaman, id) tie-break'i yuzunden
-- tek bir sorguda 50 bin satir sıralatti. Sentetik veri bu tuzagi tasimamali.

-- Tek tenant + temel kayitlar
INSERT INTO tenant (id, ad, slug) VALUES
  ('11111111-1111-1111-1111-111111111111','Hacim','hacim');
INSERT INTO app_user (id, tenant_id, ad, email, telefon, password_hash, password_set, role) VALUES
  ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Admin H','admin@hacim.test','+905000000001','x',true,'admin'),
  ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','Guard H','guard@hacim.test','+905000000002','x',true,'security'),
  ('44444444-4444-4444-4444-444444444444','11111111-1111-1111-1111-111111111111','Resident H','res@hacim.test','+905000000003','x',true,'resident');
INSERT INTO unit (tenant_id, no, blok)
  SELECT '11111111-1111-1111-1111-111111111111', 'D'||g, 'A' FROM generate_series(1,500) g;
INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid)
  SELECT '11111111-1111-1111-1111-111111111111', 'CP'||g, 'TAG'||g FROM generate_series(1,50) g;

-- Hacim: cocuk tablolar
INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key)
  WITH cp AS (SELECT array_agg(id ORDER BY id) ids FROM checkpoint)
  SELECT '11111111-1111-1111-1111-111111111111',
         '33333333-3333-3333-3333-333333333333',
         cp.ids[1 + g % 50],
         'TAG'||(g % 50 + 1),
         now() - (g || ' minutes')::interval,
         'idem-'||g
  FROM generate_series(1,200000) g, cp;

INSERT INTO notification (tenant_id, tip, mesaj, created_at)
  SELECT '11111111-1111-1111-1111-111111111111',
         (ARRAY['kacirilan_tur','eksik_checkpoint','gecikmis_okutma']::notification_tip[])[1 + g % 3],
         'bildirim '||g, now() - (g || ' minutes')::interval
  FROM generate_series(1,100000) g;

INSERT INTO task (tenant_id, ad, created_at)
  SELECT '11111111-1111-1111-1111-111111111111', 'gorev '||g, now() - (g || ' minutes')::interval
  FROM generate_series(1,50000) g;

INSERT INTO audit_log (tenant_id, action, meta, ts)
  SELECT '11111111-1111-1111-1111-111111111111', 'action_'||(g % 20), '{}'::jsonb,
         now() - (g || ' minutes')::interval
  FROM generate_series(1,100000) g;

INSERT INTO visitor (tenant_id, unit_id, ziyaretci_ad, kaydeden_user_id, target_resident_user_id, created_at)
  WITH u AS (SELECT array_agg(id ORDER BY id) ids FROM unit)
  SELECT '11111111-1111-1111-1111-111111111111',
         u.ids[1 + g % 500],
         'ziyaretci '||g, '33333333-3333-3333-3333-333333333333',
         '44444444-4444-4444-4444-444444444444', now() - (g || ' minutes')::interval
  FROM generate_series(1,50000) g, u;

INSERT INTO kargo (tenant_id, unit_id, firma, kaydeden_user_id, created_at)
  WITH u AS (SELECT array_agg(id ORDER BY id) ids FROM unit)
  SELECT '11111111-1111-1111-1111-111111111111',
         u.ids[1 + g % 500],
         'firma '||(g % 10), '33333333-3333-3333-3333-333333333333',
         now() - (g || ' minutes')::interval
  FROM generate_series(1,50000) g, u;

INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus, created_at)
  SELECT '11111111-1111-1111-1111-111111111111', u.id,
         to_char(now() - (m || ' months')::interval, 'YYYY-MM'),
         50000 + m, now() - (m || ' days')::interval
  FROM unit u, generate_series(0,23) m;

INSERT INTO dues_payment (tenant_id, unit_id, tutar_kurus, yontem, kaydeden_user_id,
                          idempotency_key, created_at, odeme_zamani)
  WITH u AS (SELECT array_agg(id ORDER BY id) ids FROM unit)
  SELECT '11111111-1111-1111-1111-111111111111', u.ids[1 + g % 500], 50000,
         (ARRAY['elden','havale','kart']::dues_yontem[])[1 + g % 3],
         '33333333-3333-3333-3333-333333333333', 'pay-'||g,
         now() - (g || ' minutes')::interval,
         now() - (g || ' minutes')::interval
  FROM generate_series(1,200000) g, u;

ANALYZE;
