-- (P250 §7) OTOMATIK BORC HATIRLATMASI CALISIYOR MU — prod teshisi.
--
-- Bu makineden prod'a erisim yok; asagidaki sorgular prod veritabaninda
-- (owner rolu ile) calistirilir. Uc soru:
--   1. Hangi tesislerde hatirlatma ACIK?
--   2. Gece gorevi (finans_otomasyonu, 03:00 UTC) gercekten kostu mu?
--   3. Kac kisiye gitti (push/uygulama ici ve P250 sonrasi e-posta)?

-- 1) Hatirlatmasi acik tesisler ve son calisma gunu.
SELECT t.ad AS tesis, h.aktif, h.vade_oncesi_gun, h.kademeler, h.son_calisma,
       h.eposta
  FROM hatirlatma_ayari h JOIN tenant t ON t.id = h.tenant_id
 ORDER BY h.son_calisma DESC NULLS LAST;

-- 2) Son 30 gunun gorev kayitlari (borc_hatirlatma). `sonuc` P250 sonrasi
--    e-posta ve "kurala uyan alici yok" sayilarini da tasir.
SELECT t.ad AS tesis, g.calisma_zamani, g.adet AS kisi, g.tutar_kurus, g.sonuc
  FROM otomasyon_gunlugu g JOIN tenant t ON t.id = g.tenant_id
 WHERE g.tur = 'borc_hatirlatma'
   AND g.calisma_zamani > now() - interval '30 days'
 ORDER BY g.calisma_zamani DESC;

-- 3a) Uygulama ici bildirim satirlari (push ile birlikte yazilir).
SELECT date_trunc('day', created_at) AS gun, count(*)
  FROM notification
 WHERE tip = 'aidat_hatirlatma' AND created_at > now() - interval '30 days'
 GROUP BY 1 ORDER BY 1 DESC;

-- 3b) (P250) Hatirlatma e-postalari ve teslim durumu.
SELECT durum, hata, count(*)
  FROM mesaj_gonderim
 WHERE tur = 'aidat_hatirlatma' AND created_at > now() - interval '30 days'
 GROUP BY 1, 2 ORDER BY 3 DESC;

-- 4) Beat'in gorevi tanidigi: GET https://api.yonetiyor.com/health ->
--    beat.durum = 'uyumlu' (DAGITIM-SABLONU §2). 'finans-otomasyonu'
--    contracts/beat-gorevleri.txt'de kayitli.
