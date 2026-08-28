# P184 Ek — 3D Maket: kamera + bildirim işaretleri kaldırıldı (§2)

**İstek:** P182'de metin etiketleri kaldırılmıştı ama kamera ve kaçırılan
devriye **işaretleri** (renkli daireler/noktalar) duruyordu. Bunlar da kaldırıldı.
3D maket artık **yalnız binaları ve zemini** gösterir; üzerinde hiçbir kamera veya
bildirim işareti yoktur. Bilgi zaten başka ekranlarda mevcut (kamera listesi /
`KameraSeridi`, bildirimler / alarmlar bölümü, devriye görünümü).

## Kaldırılan işaretler

- **Kamera işaretleri** (aktif/pasif renkli noktalar; en fazla 8) — `tur: "kamera"`.
- **Alarm / kaçırılan devriye işaretleri** (kırmızı noktalar; en fazla 4) —
  `tur: "alarm"`, `alarm_gruplari`'ndan üretiliyordu.

(Not: `IsaretciTuru` `yonetici`/`sakin`/`nfc` türlerini de tanımlıyordu ama panoya
hiç bu tür işaretçi geçirilmiyordu; tip tamamen silindiği için onlar da gitti.)

## Silinen kod (ölü kod bırakılmadı)

**`components/3d/bina-sahnesi.tsx`:**
- `IsaretciTuru` tip birliği ve `SahneIsaretcisi` arayüzü (dışa aktarım) — silindi.
- `TUR_RENGI` renk haritası (`--yz-*-edge` token eşlemesi) — silindi.
- `Etiket` bileşeni (yüzen tıklanabilir nokta, `Html` + hover büyüme) ve
  `ISARET_BUYUME_ACIK/KAPALI` sabitleri — silindi.
- `BinaSahnesiProps`'tan `isaretciler` ve `onIsaretciSec` propları — silindi.
- `isaretciYerleri` `useMemo`'su (noktaları platform çevresine dağıtan) ve
  bunları çizen `{isaretciYerleri.map(<Etiket…/>)}` bloğu — silindi.

**`app/(protected)/dashboard/page.tsx`:**
- `sahneIsaretcileri` `useMemo`'su (alarm + kamera işaretlerini kuran) — silindi.
- `<BinaSahnesiYukleyici … isaretciler={…}/>` prop'u — kaldırıldı.
- Yalnız bunun için kullanılan `TUR_KAMERA` / `TUR_ALARM` sabitleri — silindi.
- (`kameralar`, `gruplar`, `enumAdi`, `BILDIRIM_TIP`, `DAIRE_ALARM` **DURUYOR** —
  kamera şeridi, alarmlar bölümü ve daire renklendirmesi kullanıyor.)

**`components/3d/sahne-yukleyici.tsx`:**
- WebGL-yok erişilebilirlik metnindeki "kaç işaretçi" ifadesi güncellendi
  (artık yalnız blok sayısı).

## Korunanlar (bilerek)

- **Bina/daire seçimi** (`SahneSecimi`, blok→kat→daire, `onSecim`, yan panel):
  makete tıklayıp daire bilgisini görme akışı DEĞİŞMEDİ.
- **Bina adı etiketi** (üstüne gelince/seçince görünen isim kapsülü): kamera/
  bildirim işareti değil, binayı tanımlayan etiket — kaldı.
- `kameralar`/`alarm_gruplari` veri çekimi: ilgili widget'lar kullanıyor.

## Doğrulama

- `tsc --noEmit` temiz, ESLint temiz (kullanılmayan import/değişken yok).
- pano / 3D / tasarım-token / i18n / sabit-metin testleri yeşil.
- Yan not: item 11'den kalma tanımsız `--yz-success-tint` token'ı (tasarım-token
  kilidi) bu turda düzeltildi (`--yz-surface-2` + `--yz-success-ink`).
