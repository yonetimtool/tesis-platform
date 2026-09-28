-- (P248 §3a) YENI UZUNLUK SINIRLARINI ASAN MEVCUT KAYITLAR — SALT OKUMA.
--
-- NE ICIN: P248 ile sunucu her metin girdisine dar bir uzunluk siniri
-- koydu (tek kaynak: backend/app/girdi_siniri.py). Sinirdan UZUN bir eski
-- kayit bozulmaz ve okunur; ama o kaydi DUZENLEYEN kullanici metni
-- kisaltmadan kaydedemez (422, alan + sinir kullanicinin dilinde).
-- Bu sorgu prod'da boyle kayit olup olmadigini ve nerede oldugunu gosterir.
-- Veri kirpan bir goc BILEREK yazilmadi (veri kaybi).
--
-- NASIL KOSULUR (prod sunucusunda):
--   docker compose -f infra/docker-compose.prod.yml exec -T db \
--     sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f -' \
--     < docs/P248-sinir-asan-kayitlar.sql
-- Veritabani SAHIBI ile kosulmali (prod'da `.env.prod` POSTGRES_USER; dev'de
-- tesis_owner): uygulama rolu (app_rw) RLS altinda tenant baglami olmadan
-- satir goremez ve her sey 0 cikar.
--
-- SALT OKUMA GARANTISI: tum sorgu `BEGIN TRANSACTION READ ONLY` icinde;
-- sonunda ROLLBACK. Yazma deneyen bir ifade olsaydi Postgres reddederdi.
--
-- CIKTI: yalniz ASIMI OLAN kolonlar listelenir (tablo, kolon, sinir, asan
-- kayit sayisi, en uzun deger uzunlugu). Bos sonuc = asan kayit yok.
--
-- KAPSAM (226 kolon): tablo kolonlari, ayni adli girdi semasi alanlarinin
-- (Create/Update/Istek...) max_length degeriyle eslendi; ayni kolon birden
-- cok semada ise EN KUCUK sinir alindi (fazladan raporlama yonunde hata —
-- tani sorgusu icin guvenli taraf). Tablo adiyla eslesen sema varsa YALNIZ
-- o kullanilir; ortak alan adina dayali eslesme ancak o yoksa devreye girer
-- (ilgisiz bir semanin daha kucuk `ad` siniri yanlis alarm uretmesin).
-- Elle eklenenler (sema adi tablodan farkli): asset_checkout.notlar,
-- bank_transaction.karsi_ad, bank_transaction.not_metni, complaint_status_history.sebep,
-- panik_alarm.kapanis_notu, app_user.panik_aski_nedeni, camera.stream_url,
-- camera.alt_stream_url, camera.restream_url, camera.snapshot_url,
-- building_block.ad, tenant.dis_hizmet_notu.
-- KAPSAM DISI: sunucunun kendi yazdigi kolonlar (hash, saglayici kimligi,
-- durum, hata metni, ceviri onbellegi) — kullanici girdisi olmadiklari icin
-- yeni sinirlar onlari etkilemez; tenant_portal alanlari — hicbir API ucu
-- yazmiyor.
--
-- Dev veritabaninda (2026-09-28) sonuc: 4 kolonda birer kayit
-- (app_user.ad, dues_assessment.aciklama, task.aciklama, task.ad) —
-- hepsi 10 000 karakterlik E2E test artigi.

BEGIN TRANSACTION READ ONLY;

SELECT * FROM (
  SELECT 'aidat_plani' AS tablo, 'aciklama' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM aidat_plani WHERE length(aciklama) > 500
UNION ALL
  SELECT 'aidat_plani' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM aidat_plani WHERE length(ad) > 100
UNION ALL
  SELECT 'akilli_ev_cihaz' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM akilli_ev_cihaz WHERE length(ad) > 200
UNION ALL
  SELECT 'akilli_ev_cihaz' AS tablo, 'alan' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(alan)) AS en_uzun FROM akilli_ev_cihaz WHERE length(alan) > 200
UNION ALL
  SELECT 'akilli_ev_cihaz' AS tablo, 'dis_kimlik' AS kolon, 300 AS sinir, count(*) AS asan_kayit, max(length(dis_kimlik)) AS en_uzun FROM akilli_ev_cihaz WHERE length(dis_kimlik) > 300
UNION ALL
  SELECT 'akilli_ev_kopru' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM akilli_ev_kopru WHERE length(ad) > 200
UNION ALL
  SELECT 'akilli_ev_kopru' AS tablo, 'host' AS kolon, 255 AS sinir, count(*) AS asan_kayit, max(length(host)) AS en_uzun FROM akilli_ev_kopru WHERE length(host) > 255
UNION ALL
  SELECT 'akilli_ev_senaryo' AS tablo, 'eylem' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(eylem)) AS en_uzun FROM akilli_ev_senaryo WHERE length(eylem) > 64
UNION ALL
  SELECT 'anket' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM anket WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'anket' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM anket WHERE length(baslik) > 200
UNION ALL
  SELECT 'anket' AS tablo, 'gorsel_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(gorsel_key)) AS en_uzun FROM anket WHERE length(gorsel_key) > 500
UNION ALL
  SELECT 'anket' AS tablo, 'hedef_sakin_tipi' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(hedef_sakin_tipi)) AS en_uzun FROM anket WHERE length(hedef_sakin_tipi) > 64
UNION ALL
  SELECT 'anket_secenek' AS tablo, 'metin' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(metin)) AS en_uzun FROM anket_secenek WHERE length(metin) > 200
UNION ALL
  SELECT 'announcement' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM announcement WHERE length(baslik) > 200
UNION ALL
  SELECT 'announcement' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM announcement WHERE length(foto_key) > 500
UNION ALL
  SELECT 'announcement' AS tablo, 'govde' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(govde)) AS en_uzun FROM announcement WHERE length(govde) > 5000
UNION ALL
  SELECT 'announcement' AS tablo, 'hedef_sakin_tipi' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(hedef_sakin_tipi)) AS en_uzun FROM announcement WHERE length(hedef_sakin_tipi) > 64
UNION ALL
  SELECT 'anpr_api_key' AS tablo, 'ad' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM anpr_api_key WHERE length(ad) > 120
UNION ALL
  SELECT 'anpr_event' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM anpr_event WHERE length(foto_key) > 500
UNION ALL
  SELECT 'anpr_event' AS tablo, 'kamera' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(kamera)) AS en_uzun FROM anpr_event WHERE length(kamera) > 120
UNION ALL
  SELECT 'anpr_event' AS tablo, 'kaynak' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(kaynak)) AS en_uzun FROM anpr_event WHERE length(kaynak) > 64
UNION ALL
  SELECT 'anpr_event' AS tablo, 'kaynak_olay_id' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(kaynak_olay_id)) AS en_uzun FROM anpr_event WHERE length(kaynak_olay_id) > 200
UNION ALL
  SELECT 'anpr_event' AS tablo, 'plaka' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(plaka)) AS en_uzun FROM anpr_event WHERE length(plaka) > 64
UNION ALL
  SELECT 'app_user' AS tablo, 'ad' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM app_user WHERE length(ad) > 120
UNION ALL
  SELECT 'app_user' AS tablo, 'email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(email)) AS en_uzun FROM app_user WHERE length(email) > 254
UNION ALL
  SELECT 'app_user' AS tablo, 'panik_aski_nedeni' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(panik_aski_nedeni)) AS en_uzun FROM app_user WHERE length(panik_aski_nedeni) > 500
UNION ALL
  SELECT 'app_user' AS tablo, 'telefon' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM app_user WHERE length(telefon) > 30
UNION ALL
  SELECT 'arac_kayit' AS tablo, 'marka' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(marka)) AS en_uzun FROM arac_kayit WHERE length(marka) > 50
UNION ALL
  SELECT 'arac_kayit' AS tablo, 'model' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(model)) AS en_uzun FROM arac_kayit WHERE length(model) > 50
UNION ALL
  SELECT 'arac_kayit' AS tablo, 'plaka' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(plaka)) AS en_uzun FROM arac_kayit WHERE length(plaka) > 30
UNION ALL
  SELECT 'arac_kayit' AS tablo, 'renk' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(renk)) AS en_uzun FROM arac_kayit WHERE length(renk) > 30
UNION ALL
  SELECT 'asset' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM asset WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'asset' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM asset WHERE length(ad) > 100
UNION ALL
  SELECT 'asset' AS tablo, 'nfc_tag_uid' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(nfc_tag_uid)) AS en_uzun FROM asset WHERE length(nfc_tag_uid) > 64
UNION ALL
  SELECT 'asset_checkout' AS tablo, 'notlar' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM asset_checkout WHERE length(notlar) > 2000
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM bakim_ekipmani WHERE length(ad) > 200
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'alan' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(alan)) AS en_uzun FROM bakim_ekipmani WHERE length(alan) > 200
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'notlar' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM bakim_ekipmani WHERE length(notlar) > 4000
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'sorumlu_ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(sorumlu_ad)) AS en_uzun FROM bakim_ekipmani WHERE length(sorumlu_ad) > 200
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'sorumlu_telefon' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(sorumlu_telefon)) AS en_uzun FROM bakim_ekipmani WHERE length(sorumlu_telefon) > 40
UNION ALL
  SELECT 'bakim_ekipmani' AS tablo, 'tur' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(tur)) AS en_uzun FROM bakim_ekipmani WHERE length(tur) > 100
UNION ALL
  SELECT 'bakim_kaydi' AS tablo, 'islem' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(islem)) AS en_uzun FROM bakim_kaydi WHERE length(islem) > 4000
UNION ALL
  SELECT 'bakim_kaydi' AS tablo, 'yapan_ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(yapan_ad)) AS en_uzun FROM bakim_kaydi WHERE length(yapan_ad) > 200
UNION ALL
  SELECT 'bank_transaction' AS tablo, 'aciklama' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM bank_transaction WHERE length(aciklama) > 500
UNION ALL
  SELECT 'bank_transaction' AS tablo, 'karsi_ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(karsi_ad)) AS en_uzun FROM bank_transaction WHERE length(karsi_ad) > 200
UNION ALL
  SELECT 'bank_transaction' AS tablo, 'not_metni' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(not_metni)) AS en_uzun FROM bank_transaction WHERE length(not_metni) > 500
UNION ALL
  SELECT 'budget_category' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM budget_category WHERE length(ad) > 100
UNION ALL
  SELECT 'budget_entry' AS tablo, 'aciklama' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM budget_entry WHERE length(aciklama) > 1000
UNION ALL
  SELECT 'building_block' AS tablo, 'ad' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM building_block WHERE length(ad) > 50
UNION ALL
  SELECT 'butce_hedefi' AS tablo, 'aciklama' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM butce_hedefi WHERE length(aciklama) > 500
UNION ALL
  SELECT 'butce_hedefi' AS tablo, 'donem' AS kolon, 7 AS sinir, count(*) AS asan_kayit, max(length(donem)) AS en_uzun FROM butce_hedefi WHERE length(donem) > 7
UNION ALL
  SELECT 'camera' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM camera WHERE length(ad) > 100
UNION ALL
  SELECT 'camera' AS tablo, 'alt_stream_url' AS kolon, 2048 AS sinir, count(*) AS asan_kayit, max(length(alt_stream_url)) AS en_uzun FROM camera WHERE length(alt_stream_url) > 2048
UNION ALL
  SELECT 'camera' AS tablo, 'kayit_adres' AS kolon, 2048 AS sinir, count(*) AS asan_kayit, max(length(kayit_adres)) AS en_uzun FROM camera WHERE length(kayit_adres) > 2048
UNION ALL
  SELECT 'camera' AS tablo, 'kayit_kanal' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(kayit_kanal)) AS en_uzun FROM camera WHERE length(kayit_kanal) > 64
UNION ALL
  SELECT 'camera' AS tablo, 'kayit_kullanici' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(kayit_kullanici)) AS en_uzun FROM camera WHERE length(kayit_kullanici) > 500
UNION ALL
  SELECT 'camera' AS tablo, 'konum' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konum)) AS en_uzun FROM camera WHERE length(konum) > 200
UNION ALL
  SELECT 'camera' AS tablo, 'restream_url' AS kolon, 2048 AS sinir, count(*) AS asan_kayit, max(length(restream_url)) AS en_uzun FROM camera WHERE length(restream_url) > 2048
UNION ALL
  SELECT 'camera' AS tablo, 'snapshot_url' AS kolon, 2048 AS sinir, count(*) AS asan_kayit, max(length(snapshot_url)) AS en_uzun FROM camera WHERE length(snapshot_url) > 2048
UNION ALL
  SELECT 'camera' AS tablo, 'stream_kullanici' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(stream_kullanici)) AS en_uzun FROM camera WHERE length(stream_kullanici) > 200
UNION ALL
  SELECT 'camera' AS tablo, 'stream_url' AS kolon, 2048 AS sinir, count(*) AS asan_kayit, max(length(stream_url)) AS en_uzun FROM camera WHERE length(stream_url) > 2048
UNION ALL
  SELECT 'checkpoint' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM checkpoint WHERE length(ad) > 100
UNION ALL
  SELECT 'checkpoint' AS tablo, 'nfc_tag_uid' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(nfc_tag_uid)) AS en_uzun FROM checkpoint WHERE length(nfc_tag_uid) > 64
UNION ALL
  SELECT 'complaint' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM complaint WHERE length(baslik) > 200
UNION ALL
  SELECT 'complaint' AS tablo, 'mesaj' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(mesaj)) AS en_uzun FROM complaint WHERE length(mesaj) > 5000
UNION ALL
  SELECT 'complaint_status_history' AS tablo, 'sebep' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(sebep)) AS en_uzun FROM complaint_status_history WHERE length(sebep) > 2000
UNION ALL
  SELECT 'dis_hizmet' AS tablo, 'aciklama' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM dis_hizmet WHERE length(aciklama) > 1000
UNION ALL
  SELECT 'dis_hizmet' AS tablo, 'ad' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM dis_hizmet WHERE length(ad) > 120
UNION ALL
  SELECT 'dis_hizmet' AS tablo, 'soyad' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(soyad)) AS en_uzun FROM dis_hizmet WHERE length(soyad) > 120
UNION ALL
  SELECT 'dis_hizmet' AS tablo, 'telefon' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM dis_hizmet WHERE length(telefon) > 40
UNION ALL
  SELECT 'dis_hizmet' AS tablo, 'tur' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(tur)) AS en_uzun FROM dis_hizmet WHERE length(tur) > 100
UNION ALL
  SELECT 'diyafon' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM diyafon WHERE length(ad) > 200
UNION ALL
  SELECT 'diyafon' AS tablo, 'hedef' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(hedef)) AS en_uzun FROM diyafon WHERE length(hedef) > 200
UNION ALL
  SELECT 'diyafon' AS tablo, 'host' AS kolon, 255 AS sinir, count(*) AS asan_kayit, max(length(host)) AS en_uzun FROM diyafon WHERE length(host) > 255
UNION ALL
  SELECT 'diyafon' AS tablo, 'kapi_yolu' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(kapi_yolu)) AS en_uzun FROM diyafon WHERE length(kapi_yolu) > 500
UNION ALL
  SELECT 'diyafon' AS tablo, 'kullanici' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(kullanici)) AS en_uzun FROM diyafon WHERE length(kullanici) > 200
UNION ALL
  SELECT 'diyafon' AS tablo, 'zil_yolu' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(zil_yolu)) AS en_uzun FROM diyafon WHERE length(zil_yolu) > 500
UNION ALL
  SELECT 'dues_assessment' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM dues_assessment WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'dues_assessment' AS tablo, 'donem' AS kolon, 7 AS sinir, count(*) AS asan_kayit, max(length(donem)) AS en_uzun FROM dues_assessment WHERE length(donem) > 7
UNION ALL
  SELECT 'dues_payment' AS tablo, 'donem' AS kolon, 7 AS sinir, count(*) AS asan_kayit, max(length(donem)) AS en_uzun FROM dues_payment WHERE length(donem) > 7
UNION ALL
  SELECT 'dues_payment' AS tablo, 'makbuz_no' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(makbuz_no)) AS en_uzun FROM dues_payment WHERE length(makbuz_no) > 64
UNION ALL
  SELECT 'duzenli_gider' AS tablo, 'aciklama' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM duzenli_gider WHERE length(aciklama) > 500
UNION ALL
  SELECT 'duzenli_gider' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM duzenli_gider WHERE length(ad) > 100
UNION ALL
  SELECT 'etkinlik' AS tablo, 'aciklama' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM etkinlik WHERE length(aciklama) > 5000
UNION ALL
  SELECT 'etkinlik' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM etkinlik WHERE length(baslik) > 200
UNION ALL
  SELECT 'etkinlik' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM etkinlik WHERE length(foto_key) > 500
UNION ALL
  SELECT 'etkinlik' AS tablo, 'konum' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(konum)) AS en_uzun FROM etkinlik WHERE length(konum) > 500
UNION ALL
  SELECT 'finansal_hareket' AS tablo, 'aciklama' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM finansal_hareket WHERE length(aciklama) > 500
UNION ALL
  SELECT 'finansal_hareket' AS tablo, 'belge_no' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(belge_no)) AS en_uzun FROM finansal_hareket WHERE length(belge_no) > 50
UNION ALL
  SELECT 'finansal_hareket' AS tablo, 'donem' AS kolon, 7 AS sinir, count(*) AS asan_kayit, max(length(donem)) AS en_uzun FROM finansal_hareket WHERE length(donem) > 7
UNION ALL
  SELECT 'firma' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM firma WHERE length(ad) > 200
UNION ALL
  SELECT 'firma' AS tablo, 'adres' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(adres)) AS en_uzun FROM firma WHERE length(adres) > 500
UNION ALL
  SELECT 'firma' AS tablo, 'email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(email)) AS en_uzun FROM firma WHERE length(email) > 254
UNION ALL
  SELECT 'firma' AS tablo, 'telefon' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM firma WHERE length(telefon) > 30
UNION ALL
  SELECT 'firma' AS tablo, 'vergi_dairesi' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(vergi_dairesi)) AS en_uzun FROM firma WHERE length(vergi_dairesi) > 100
UNION ALL
  SELECT 'firma' AS tablo, 'yetkili_ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(yetkili_ad)) AS en_uzun FROM firma WHERE length(yetkili_ad) > 150
UNION ALL
  SELECT 'firma' AS tablo, 'yetkili_telefon' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(yetkili_telefon)) AS en_uzun FROM firma WHERE length(yetkili_telefon) > 30
UNION ALL
  SELECT 'gelir_gider_grup' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM gelir_gider_grup WHERE length(ad) > 100
UNION ALL
  SELECT 'gelir_gider_tanim' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM gelir_gider_tanim WHERE length(ad) > 100
UNION ALL
  SELECT 'hatirlatma' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM hatirlatma WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'hatirlatma' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM hatirlatma WHERE length(baslik) > 200
UNION ALL
  SELECT 'hatirlatma' AS tablo, 'renk' AS kolon, 20 AS sinir, count(*) AS asan_kayit, max(length(renk)) AS en_uzun FROM hatirlatma WHERE length(renk) > 20
UNION ALL
  SELECT 'hatirlatma_ayari' AS tablo, 'metin' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(metin)) AS en_uzun FROM hatirlatma_ayari WHERE length(metin) > 1000
UNION ALL
  SELECT 'ice_aktarim' AS tablo, 'dosya_adi' AS kolon, 255 AS sinir, count(*) AS asan_kayit, max(length(dosya_adi)) AS en_uzun FROM ice_aktarim WHERE length(dosya_adi) > 255
UNION ALL
  SELECT 'icra_dosyasi' AS tablo, 'aciklama' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM icra_dosyasi WHERE length(aciklama) > 1000
UNION ALL
  SELECT 'icra_dosyasi' AS tablo, 'avukat' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(avukat)) AS en_uzun FROM icra_dosyasi WHERE length(avukat) > 150
UNION ALL
  SELECT 'icra_dosyasi' AS tablo, 'dosya_no' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(dosya_no)) AS en_uzun FROM icra_dosyasi WHERE length(dosya_no) > 50
UNION ALL
  SELECT 'iletisim_mesaji' AS tablo, 'ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM iletisim_mesaji WHERE length(ad) > 150
UNION ALL
  SELECT 'iletisim_mesaji' AS tablo, 'email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(email)) AS en_uzun FROM iletisim_mesaji WHERE length(email) > 254
UNION ALL
  SELECT 'iletisim_mesaji' AS tablo, 'mesaj' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(mesaj)) AS en_uzun FROM iletisim_mesaji WHERE length(mesaj) > 5000
UNION ALL
  SELECT 'iletisim_mesaji' AS tablo, 'telefon' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM iletisim_mesaji WHERE length(telefon) > 30
UNION ALL
  SELECT 'integration' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM integration WHERE length(ad) > 200
UNION ALL
  SELECT 'integration' AS tablo, 'endpoint_url' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(endpoint_url)) AS en_uzun FROM integration WHERE length(endpoint_url) > 2000
UNION ALL
  SELECT 'integration' AS tablo, 'payload_template' AS kolon, 8000 AS sinir, count(*) AS asan_kayit, max(length(payload_template)) AS en_uzun FROM integration WHERE length(payload_template) > 8000
UNION ALL
  SELECT 'karar_defteri' AS tablo, 'baskan_ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(baskan_ad)) AS en_uzun FROM karar_defteri WHERE length(baskan_ad) > 150
UNION ALL
  SELECT 'karar_defteri' AS tablo, 'karar_no' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(karar_no)) AS en_uzun FROM karar_defteri WHERE length(karar_no) > 30
UNION ALL
  SELECT 'karar_defteri' AS tablo, 'konu' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konu)) AS en_uzun FROM karar_defteri WHERE length(konu) > 200
UNION ALL
  SELECT 'karar_defteri' AS tablo, 'metin' AS kolon, 20000 AS sinir, count(*) AS asan_kayit, max(length(metin)) AS en_uzun FROM karar_defteri WHERE length(metin) > 20000
UNION ALL
  SELECT 'karar_uyesi' AS tablo, 'ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM karar_uyesi WHERE length(ad) > 150
UNION ALL
  SELECT 'karar_uyesi' AS tablo, 'gorev' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(gorev)) AS en_uzun FROM karar_uyesi WHERE length(gorev) > 100
UNION ALL
  SELECT 'kargo' AS tablo, 'firma' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(firma)) AS en_uzun FROM kargo WHERE length(firma) > 200
UNION ALL
  SELECT 'kargo' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM kargo WHERE length(foto_key) > 500
UNION ALL
  SELECT 'kargo' AS tablo, 'notlar' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM kargo WHERE length(notlar) > 1000
UNION ALL
  SELECT 'kasa' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM kasa WHERE length(ad) > 100
UNION ALL
  SELECT 'kasa' AS tablo, 'banka_adi' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(banka_adi)) AS en_uzun FROM kasa WHERE length(banka_adi) > 100
UNION ALL
  SELECT 'kasa' AS tablo, 'iban' AS kolon, 42 AS sinir, count(*) AS asan_kayit, max(length(iban)) AS en_uzun FROM kasa WHERE length(iban) > 42
UNION ALL
  SELECT 'kasa' AS tablo, 'kod' AS kolon, 20 AS sinir, count(*) AS asan_kayit, max(length(kod)) AS en_uzun FROM kasa WHERE length(kod) > 20
UNION ALL
  SELECT 'kasa' AS tablo, 'sube' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(sube)) AS en_uzun FROM kasa WHERE length(sube) > 100
UNION ALL
  SELECT 'kayit_dogrulama' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM kayit_dogrulama WHERE length(ad) > 100
UNION ALL
  SELECT 'kayit_dogrulama' AS tablo, 'telefon' AS kolon, 32 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM kayit_dogrulama WHERE length(telefon) > 32
UNION ALL
  SELECT 'kayit_onay_kuyrugu' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM kayit_onay_kuyrugu WHERE length(ad) > 100
UNION ALL
  SELECT 'kayit_onay_kuyrugu' AS tablo, 'rol' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(rol)) AS en_uzun FROM kayit_onay_kuyrugu WHERE length(rol) > 64
UNION ALL
  SELECT 'kayit_onay_kuyrugu' AS tablo, 'telefon' AS kolon, 32 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM kayit_onay_kuyrugu WHERE length(telefon) > 32
UNION ALL
  SELECT 'kvkk_metin' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM kvkk_metin WHERE length(baslik) > 200
UNION ALL
  SELECT 'kvkk_metin' AS tablo, 'govde' AS kolon, 100000 AS sinir, count(*) AS asan_kayit, max(length(govde)) AS en_uzun FROM kvkk_metin WHERE length(govde) > 100000
UNION ALL
  SELECT 'mesaj_gonderim' AS tablo, 'govde' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(govde)) AS en_uzun FROM mesaj_gonderim WHERE length(govde) > 4000
UNION ALL
  SELECT 'mesaj_gonderim' AS tablo, 'konu' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konu)) AS en_uzun FROM mesaj_gonderim WHERE length(konu) > 200
UNION ALL
  SELECT 'mesaj_sablonu' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM mesaj_sablonu WHERE length(ad) > 100
UNION ALL
  SELECT 'mesaj_sablonu' AS tablo, 'govde' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(govde)) AS en_uzun FROM mesaj_sablonu WHERE length(govde) > 4000
UNION ALL
  SELECT 'mesaj_sablonu' AS tablo, 'konu' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konu)) AS en_uzun FROM mesaj_sablonu WHERE length(konu) > 200
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'sms_baslik' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(sms_baslik)) AS en_uzun FROM mesaj_yapilandirma WHERE length(sms_baslik) > 40
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'sms_kullanici' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(sms_kullanici)) AS en_uzun FROM mesaj_yapilandirma WHERE length(sms_kullanici) > 150
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'sms_parola' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(sms_parola)) AS en_uzun FROM mesaj_yapilandirma WHERE length(sms_parola) > 200
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'sms_saglayici' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(sms_saglayici)) AS en_uzun FROM mesaj_yapilandirma WHERE length(sms_saglayici) > 40
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'smtp_gonderen' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(smtp_gonderen)) AS en_uzun FROM mesaj_yapilandirma WHERE length(smtp_gonderen) > 200
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'smtp_host' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(smtp_host)) AS en_uzun FROM mesaj_yapilandirma WHERE length(smtp_host) > 200
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'smtp_kullanici' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(smtp_kullanici)) AS en_uzun FROM mesaj_yapilandirma WHERE length(smtp_kullanici) > 200
UNION ALL
  SELECT 'mesaj_yapilandirma' AS tablo, 'smtp_parola' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(smtp_parola)) AS en_uzun FROM mesaj_yapilandirma WHERE length(smtp_parola) > 200
UNION ALL
  SELECT 'ortak_alan' AS tablo, 'aciklama' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM ortak_alan WHERE length(aciklama) > 1000
UNION ALL
  SELECT 'ortak_alan' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM ortak_alan WHERE length(ad) > 200
UNION ALL
  SELECT 'panik_alarm' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM panik_alarm WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'panik_alarm' AS tablo, 'kapanis_notu' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(kapanis_notu)) AS en_uzun FROM panik_alarm WHERE length(kapanis_notu) > 2000
UNION ALL
  SELECT 'patrol_plan' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM patrol_plan WHERE length(ad) > 100
UNION ALL
  SELECT 'personel_kayit' AS tablo, 'ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM personel_kayit WHERE length(ad) > 150
UNION ALL
  SELECT 'personel_kayit' AS tablo, 'email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(email)) AS en_uzun FROM personel_kayit WHERE length(email) > 254
UNION ALL
  SELECT 'personel_kayit' AS tablo, 'gorev' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(gorev)) AS en_uzun FROM personel_kayit WHERE length(gorev) > 100
UNION ALL
  SELECT 'personel_kayit' AS tablo, 'telefon' AS kolon, 30 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM personel_kayit WHERE length(telefon) > 30
UNION ALL
  SELECT 'platform_support_ticket' AS tablo, 'aciklama' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM platform_support_ticket WHERE length(aciklama) > 4000
UNION ALL
  SELECT 'platform_support_ticket' AS tablo, 'admin_cevap' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(admin_cevap)) AS en_uzun FROM platform_support_ticket WHERE length(admin_cevap) > 4000
UNION ALL
  SELECT 'platform_support_ticket' AS tablo, 'admin_cevap_foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(admin_cevap_foto_key)) AS en_uzun FROM platform_support_ticket WHERE length(admin_cevap_foto_key) > 500
UNION ALL
  SELECT 'platform_support_ticket' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM platform_support_ticket WHERE length(foto_key) > 500
UNION ALL
  SELECT 'platform_support_ticket' AS tablo, 'konu' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konu)) AS en_uzun FROM platform_support_ticket WHERE length(konu) > 200
UNION ALL
  SELECT 'receipt' AS tablo, 'belge_no' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(belge_no)) AS en_uzun FROM receipt WHERE length(belge_no) > 50
UNION ALL
  SELECT 'rezervasyon' AS tablo, 'notlar' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM rezervasyon WHERE length(notlar) > 1000
UNION ALL
  SELECT 'sayac_ana' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM sayac_ana WHERE length(ad) > 100
UNION ALL
  SELECT 'sayac_ana' AS tablo, 'tesisat_no' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(tesisat_no)) AS en_uzun FROM sayac_ana WHERE length(tesisat_no) > 50
UNION ALL
  SELECT 'sayac_bolum' AS tablo, 'tesisat_no' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(tesisat_no)) AS en_uzun FROM sayac_bolum WHERE length(tesisat_no) > 50
UNION ALL
  SELECT 'scan_event' AS tablo, 'foto_url' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_url)) AS en_uzun FROM scan_event WHERE length(foto_url) > 500
UNION ALL
  SELECT 'scan_event' AS tablo, 'nfc_tag_uid' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(nfc_tag_uid)) AS en_uzun FROM scan_event WHERE length(nfc_tag_uid) > 64
UNION ALL
  SELECT 'shift' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM shift WHERE length(ad) > 100
UNION ALL
  SELECT 'site_kurali' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM site_kurali WHERE length(baslik) > 200
UNION ALL
  SELECT 'site_kurali' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM site_kurali WHERE length(foto_key) > 500
UNION ALL
  SELECT 'site_kurali' AS tablo, 'icerik' AS kolon, 10000 AS sinir, count(*) AS asan_kayit, max(length(icerik)) AS en_uzun FROM site_kurali WHERE length(icerik) > 10000
UNION ALL
  SELECT 'surum_politikasi' AS tablo, 'asgari_surum' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(asgari_surum)) AS en_uzun FROM surum_politikasi WHERE length(asgari_surum) > 64
UNION ALL
  SELECT 'surum_politikasi' AS tablo, 'onerilen_surum' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(onerilen_surum)) AS en_uzun FROM surum_politikasi WHERE length(onerilen_surum) > 64
UNION ALL
  SELECT 'tanitim_iletisim' AS tablo, 'ad' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM tanitim_iletisim WHERE length(ad) > 150
UNION ALL
  SELECT 'tanitim_iletisim' AS tablo, 'dil' AS kolon, 5 AS sinir, count(*) AS asan_kayit, max(length(dil)) AS en_uzun FROM tanitim_iletisim WHERE length(dil) > 5
UNION ALL
  SELECT 'tanitim_iletisim' AS tablo, 'email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(email)) AS en_uzun FROM tanitim_iletisim WHERE length(email) > 254
UNION ALL
  SELECT 'tanitim_iletisim' AS tablo, 'mesaj' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(mesaj)) AS en_uzun FROM tanitim_iletisim WHERE length(mesaj) > 5000
UNION ALL
  SELECT 'tanitim_iletisim' AS tablo, 'telefon' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(telefon)) AS en_uzun FROM tanitim_iletisim WHERE length(telefon) > 40
UNION ALL
  SELECT 'task' AS tablo, 'aciklama' AS kolon, 5000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM task WHERE length(aciklama) > 5000
UNION ALL
  SELECT 'task' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM task WHERE length(ad) > 100
UNION ALL
  SELECT 'task_category' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM task_category WHERE length(ad) > 100
UNION ALL
  SELECT 'task_completion' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM task_completion WHERE length(foto_key) > 500
UNION ALL
  SELECT 'task_completion' AS tablo, 'foto_url' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_url)) AS en_uzun FROM task_completion WHERE length(foto_url) > 500
UNION ALL
  SELECT 'task_completion' AS tablo, 'nfc_tag_uid' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(nfc_tag_uid)) AS en_uzun FROM task_completion WHERE length(nfc_tag_uid) > 64
UNION ALL
  SELECT 'task_completion' AS tablo, 'notlar' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM task_completion WHERE length(notlar) > 2000
UNION ALL
  SELECT 'task_step' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM task_step WHERE length(ad) > 200
UNION ALL
  SELECT 'task_step' AS tablo, 'foto_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(foto_key)) AS en_uzun FROM task_step WHERE length(foto_key) > 500
UNION ALL
  SELECT 'task_step' AS tablo, 'notlar' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM task_step WHERE length(notlar) > 2000
UNION ALL
  SELECT 'tenant' AS tablo, 'ad' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM tenant WHERE length(ad) > 120
UNION ALL
  SELECT 'tenant' AS tablo, 'adres' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(adres)) AS en_uzun FROM tenant WHERE length(adres) > 500
UNION ALL
  SELECT 'tenant' AS tablo, 'dis_hizmet_notu' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(dis_hizmet_notu)) AS en_uzun FROM tenant WHERE length(dis_hizmet_notu) > 2000
UNION ALL
  SELECT 'tenant' AS tablo, 'gurultu_uyari_metni' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(gurultu_uyari_metni)) AS en_uzun FROM tenant WHERE length(gurultu_uyari_metni) > 1000
UNION ALL
  SELECT 'tenant' AS tablo, 'il' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(il)) AS en_uzun FROM tenant WHERE length(il) > 100
UNION ALL
  SELECT 'tenant' AS tablo, 'ilce' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ilce)) AS en_uzun FROM tenant WHERE length(ilce) > 100
UNION ALL
  SELECT 'tenant' AS tablo, 'konum_ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konum_ad)) AS en_uzun FROM tenant WHERE length(konum_ad) > 200
UNION ALL
  SELECT 'tenant' AS tablo, 'timezone' AS kolon, 64 AS sinir, count(*) AS asan_kayit, max(length(timezone)) AS en_uzun FROM tenant WHERE length(timezone) > 64
UNION ALL
  SELECT 'tenant' AS tablo, 'vardiya_hatirlatma_dk' AS kolon, 40 AS sinir, count(*) AS asan_kayit, max(length(vardiya_hatirlatma_dk)) AS en_uzun FROM tenant WHERE length(vardiya_hatirlatma_dk) > 40
UNION ALL
  SELECT 'tenant' AS tablo, 'yonetim_email' AS kolon, 254 AS sinir, count(*) AS asan_kayit, max(length(yonetim_email)) AS en_uzun FROM tenant WHERE length(yonetim_email) > 254
UNION ALL
  SELECT 'tenant_dokuman' AS tablo, 'aciklama' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM tenant_dokuman WHERE length(aciklama) > 1000
UNION ALL
  SELECT 'tenant_dokuman' AS tablo, 'ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM tenant_dokuman WHERE length(ad) > 200
UNION ALL
  SELECT 'tenant_dokuman' AS tablo, 'icerik_tipi' AS kolon, 150 AS sinir, count(*) AS asan_kayit, max(length(icerik_tipi)) AS en_uzun FROM tenant_dokuman WHERE length(icerik_tipi) > 150
UNION ALL
  SELECT 'tenant_dokuman' AS tablo, 'obje_anahtari' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(obje_anahtari)) AS en_uzun FROM tenant_dokuman WHERE length(obje_anahtari) > 500
UNION ALL
  SELECT 'unit' AS tablo, 'blok' AS kolon, 50 AS sinir, count(*) AS asan_kayit, max(length(blok)) AS en_uzun FROM unit WHERE length(blok) > 50
UNION ALL
  SELECT 'unit' AS tablo, 'no' AS kolon, 60 AS sinir, count(*) AS asan_kayit, max(length(no)) AS en_uzun FROM unit WHERE length(no) > 60
UNION ALL
  SELECT 'unit_complaint' AS tablo, 'notlar' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM unit_complaint WHERE length(notlar) > 1000
UNION ALL
  SELECT 'unit_grup' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM unit_grup WHERE length(ad) > 100
UNION ALL
  SELECT 'unit_tip' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM unit_tip WHERE length(ad) > 100
UNION ALL
  SELECT 'vardiya_dongu_atama' AS tablo, 'not_metni' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(not_metni)) AS en_uzun FROM vardiya_dongu_atama WHERE length(not_metni) > 500
UNION ALL
  SELECT 'vardiya_izin' AS tablo, 'not_metni' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(not_metni)) AS en_uzun FROM vardiya_izin WHERE length(not_metni) > 1000
UNION ALL
  SELECT 'vardiya_kalibi' AS tablo, 'ad' AS kolon, 100 AS sinir, count(*) AS asan_kayit, max(length(ad)) AS en_uzun FROM vardiya_kalibi WHERE length(ad) > 100
UNION ALL
  SELECT 'vardiya_plani' AS tablo, 'alan' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(alan)) AS en_uzun FROM vardiya_plani WHERE length(alan) > 200
UNION ALL
  SELECT 'vardiya_plani' AS tablo, 'not_metni' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(not_metni)) AS en_uzun FROM vardiya_plani WHERE length(not_metni) > 500
UNION ALL
  SELECT 'vardiya_plani' AS tablo, 'vardiya_rolu' AS kolon, 60 AS sinir, count(*) AS asan_kayit, max(length(vardiya_rolu)) AS en_uzun FROM vardiya_plani WHERE length(vardiya_rolu) > 60
UNION ALL
  SELECT 'varlik_eki' AS tablo, 'dosya_adi' AS kolon, 255 AS sinir, count(*) AS asan_kayit, max(length(dosya_adi)) AS en_uzun FROM varlik_eki WHERE length(dosya_adi) > 255
UNION ALL
  SELECT 'varlik_eki' AS tablo, 'dosya_key' AS kolon, 500 AS sinir, count(*) AS asan_kayit, max(length(dosya_key)) AS en_uzun FROM varlik_eki WHERE length(dosya_key) > 500
UNION ALL
  SELECT 'varlik_eki' AS tablo, 'metin' AS kolon, 4000 AS sinir, count(*) AS asan_kayit, max(length(metin)) AS en_uzun FROM varlik_eki WHERE length(metin) > 4000
UNION ALL
  SELECT 'varlik_eki' AS tablo, 'varlik_tipi' AS kolon, 32 AS sinir, count(*) AS asan_kayit, max(length(varlik_tipi)) AS en_uzun FROM varlik_eki WHERE length(varlik_tipi) > 32
UNION ALL
  SELECT 'vehicle_pass' AS tablo, 'arac_tanim' AS kolon, 120 AS sinir, count(*) AS asan_kayit, max(length(arac_tanim)) AS en_uzun FROM vehicle_pass WHERE length(arac_tanim) > 120
UNION ALL
  SELECT 'vehicle_pass' AS tablo, 'plaka' AS kolon, 32 AS sinir, count(*) AS asan_kayit, max(length(plaka)) AS en_uzun FROM vehicle_pass WHERE length(plaka) > 32
UNION ALL
  SELECT 'violation' AS tablo, 'aciklama' AS kolon, 2000 AS sinir, count(*) AS asan_kayit, max(length(aciklama)) AS en_uzun FROM violation WHERE length(aciklama) > 2000
UNION ALL
  SELECT 'violation' AS tablo, 'baslik' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(baslik)) AS en_uzun FROM violation WHERE length(baslik) > 200
UNION ALL
  SELECT 'violation' AS tablo, 'konum' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(konum)) AS en_uzun FROM violation WHERE length(konum) > 200
UNION ALL
  SELECT 'visitor' AS tablo, 'notlar' AS kolon, 1000 AS sinir, count(*) AS asan_kayit, max(length(notlar)) AS en_uzun FROM visitor WHERE length(notlar) > 1000
UNION ALL
  SELECT 'visitor' AS tablo, 'ziyaretci_ad' AS kolon, 200 AS sinir, count(*) AS asan_kayit, max(length(ziyaretci_ad)) AS en_uzun FROM visitor WHERE length(ziyaretci_ad) > 200
) asim
WHERE asan_kayit > 0
ORDER BY asan_kayit DESC, tablo, kolon;

ROLLBACK;
