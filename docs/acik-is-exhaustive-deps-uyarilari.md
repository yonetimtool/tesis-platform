# Açık iş — 4 `react-hooks/exhaustive-deps` uyarısı (sonraki tur)

**Durum:** açık, kaydedildi 2026-10-02. Kullanıcı talimatı: "Bir sonraki
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
