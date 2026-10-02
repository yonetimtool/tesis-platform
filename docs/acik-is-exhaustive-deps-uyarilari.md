# Açık iş — 4 `react-hooks/exhaustive-deps` uyarısı (sonraki tur)

**Durum:** KAPANDI 2026-10-02 (P252 §4) — sonuç en altta. Kullanıcı talimatı: "Bir sonraki
turda kontrol et: gerçek kusur mu, bilinçli mi? Bilinçliyse yorumla
gerekçesini yaz, değilse düzelt."

Prod derlemesinde (`npm run dogrula` → `next build`) engelleyici olmayan
dört uyarı çıkıyor. Eksik bağımlılık, ekranın eski veriyle ya da eski
işleyiciyle kalmasına yol açabilir. Aşağıdaki satır numaraları
2026-10-02 derleme çıktısından (`dbda3166`).

| Sayfa | Satır | Kanca | Eksik bağımlılık | İlk bakış (DOĞRULANMADI) |
|---|---|---|---|---|
| `app/(protected)/dokumanlar/page.tsx` | 315 | `useMemo` | `gorunurluk`, `sil` | Kolon tanımı eylem işleyicilerini kapatıyor; işleyici güncel durumu okumuyorsa eski kapanış riski |
| `app/(protected)/gurultu-uyarilari/page.tsx` | 96 | `useMemo` | `yapildi` | Aynı desen (satır eylemi) |
| `app/(protected)/ice-aktarim/page.tsx` | 174 | `useEffect` | `tur` | Etki `tur` değişince yeniden çalışmalı mı? Tür değişiminde eski şablon/eşleme kalabilir; **en olası gerçek kusur** |
| `app/(protected)/raporlar/page.tsx` | 218 | `useMemo` | `indir` | Kolon tanımı indirme işleyicisini kapatıyor |

## Her biri için yapılacak

1. İşleyicinin kapattığı durumları oku: işleyici `setState(prev => …)`
   ya da `mutate()` gibi her zaman güncel kalan bir şey mi kullanıyor?
   - **Evet:** eksik bağımlılık zararsız. Satıra
     `// eslint-disable-next-line react-hooks/exhaustive-deps` ve
     **gerekçeli yorum** (bkz. `kullanici-listesi.tsx` kolon tanımı
     deseni).
   - **Hayır:** bağımlılığı ekle ya da işleyiciyi `useCallback`/ref ile
     kararlı hale getir.
2. **Ölç:** gerçek kusur olanlar için önce kusuru gösteren bir DOM testi
   yaz (ör. içe aktarımda türü değiştirince eski eşleme kalıyor mu), sonra
   düzelt.
3. **Kilit:** dört uyarı da kapanınca derleme uyarısız bitmeli; gerekirse
   `next lint` çıktısında `exhaustive-deps` sayısını sıfır olarak kilitle.


## Kapanış (P252 §4)

| Sayfa | Sonuç |
|---|---|
| `ice-aktarim` (`useEffect`, `tur`) | **Gerçek kusur, ama uyarının söylediği değil.** |
| `dokumanlar` (`gorunurluk`, `sil`) | Zararsız: gerekçeli yorum |
| `gurultu-uyarilari` (`yapildi`) | Zararsız: gerekçeli yorum |
| `raporlar` (`indir`) | Zararsız: gerekçeli yorum |

**İçe aktarım:**

* `tur` bağımlılığa eklenmez. Türün içeriği sunucuda değişirse yeniden
  doğrulama yeni nesne getirir ve kullanıcının yazdığı tablo silinirdi.
  Bu testle ölçüldü: `tur`'a bağlayınca test düşüyor.
* Ölçülen asıl kusur: tür **adresten** değişince (tarayıcıda geri)
  kolon eşlemesi sıfırlanmıyordu ve eski türün alanı yeni türe
  gidiyordu. Önce test yazıldı ve düştü, sonra düzeltildi. Sıfırlama artık
  `tur?.kod` etkisinde.
* Test: `tests/p252-ice-aktarim-tur-degisimi.dom.test.ts`.

**Zararsız üç `useMemo`:** satır eylemleri yalnız kararlı şeyleri kapatıyor.
Bunlar `set*`, SWR `mutate` (anahtarı `keyRef`'ten güncel okur),
`useCallback`'li `onayla`, `toast` ve bağımlılıkta olan `t`.

**Kilit:** `lint` ve `dogrula` artık `next lint --max-warnings 0`. Yeni bir
uyarı derlemeyi kırar.
