# P184 Ek — Ozet (Dashboard) Duzenleme UX Yeniden Tasarimi (§11)

Kapsam: yalniz Ozet sayfasi (`app/(protected)/dashboard/page.tsx`), duzenleme
etkilesimi, `lib/pano-tercihi.ts` (yalniz yeni handler'in kullandigi mevcut saf
fonksiyonlar) ve pano testleri. Diger yuzeyler (auth, profil, kabuk, menu)
degismedi.

## Onceki halin sorunu — neden kalabalikti

Duzenleme modu ayni anda UC etkilesim paradigmasini yan yana tasiyordu:

1. **Per-satir kontrol cubugu** — her satirda dort sutun sayisi dugmesi
   (1/2/3/4), bir banner baslik metin girdisi ve "Satiri yukari/asagi" dugmeleri.
   Kullanicidan sutun matematiği yapmasi bekleniyordu; oysa yerlesim zaten
   yari/tam bolumleri otomatik esliyor.
2. **Per-bolum gizle/goster dugmesi** — her bolum basliginda ayri bir dugme.
3. **Surukle tutamaci + klavye oklari** — asil (ve dogru) etkilesim.

Sonuc: ekranda ne yaptigi belirsiz onlarca kucuk kontrol, iki farkli "gizleme"
zihinsel modeli (dugme mi, surukle mi?), ve "Satir ekle" gibi kullanicinin
dusunmesi gerekmeyen alt secenekler. Ustune gorsel tutarsizlik: `gap-1.5`,
`p-2`, `p-6`, `space-y-3` gibi olcek disi ad-hoc bosluklar ve baslik
agirliginin bolumden bolume degismesi.

Birakma hedefi de zayifti: soluk `2px dashed` bir cerceve, tutulan bolumun
nereye dusecegini net gostermiyordu.

## Alinan kararlar ve gerekce

**1. Duzenleme = yalniz SURUKLE-BIRAK.** Sutun dugmeleri, banner girdisi,
yukari/asagi ve satir ekleme kaldirildi. Kalan tek gorsel kontrol her bolumdeki
surukle tutamaci. Tek etkilesim, tek zihinsel model.

**2. Sutunlar otomatik.** Sutun kontrolu artik yuzeyde yok. Mevcut otomatik
paketleme (yari genislikli iki bolum tek satiri paylasir — `varsayilanSatirlar`)
korundu; kullanici yalniz siralar, yerlesim mantikli kalir. `sutun` alani model
ve `tercihGovdesi` icinde durur (saf fonksiyonlar degismedi), yalnizca UI'dan
cikti.

**3. Gizleme "Gizli bolumler" tepsisiyle.** Tuvalin altinda bir tepsi var: bir
bolumu tepsiye surukleyince `gizli=true`, tepsideki bolumu tuvale (bos alana ya
da bir bolumun onune) geri surukleyince `gizli=false`. Per-bolum gizle/goster
dugmeleri kaldirildi. Bolum, gizlense de `satirlar` modelinde AYNI konumda
kalir (sira korunur); tuval yalniz gizli-olmayanlari cizer, tepsi gizli
olanlari. Boylece durum tek yerde cevrilir, ayri bir liste tutulmaz —
`tercihGovdesi` yine ayni `bolumler`/`idler` listesini yazar.

**4. Net birakma isareti.** Soluk kesik cerceve yerine, hedef bolumun ONUNE
kalin bir accent EKLEME CIZGISI (`box-shadow` solda) ciziliyor — bolum tam
nereye dusecek belli. Tepsi hedefi vurgulaninca accent kenar + `surface-2`
zemin. Tutulan bolum ~0.4 opaklikta kaliyor (korundu).

**5. Anlik "Kaydedildi" isareti.** Otomatik kayit (her degisiklikte
`PUT /me/pano-tercihi`) korundu; ayri bir Kaydet dugmesi hala yok. Kayit
tuttugunda ust barda kisa sure bir "Kaydedildi" cipi belirip kendiliginden
soluyor (`aria-live="polite"`). Hata yolu degismedi (toast.error).

**6. Tutarli, modern gorunum.** Ad-hoc bosluklar token olcegine (`gap-2`,
`mb-kart`, `p-kart`, `space-y-bolum`) cekildi; bolum basliklari `text-bolum`
(18px/700) ile tek agirlikta — hiyerarsi netlesti.

**7. Mobil.** Duyarli izgara korundu (mobilde tek sutun; yatay kaydirma yok).
Surukle tutamaci 44x44 dokunma hedefi (`yz-dokunma-44` + `h-11 w-11`).
Duzenleme esasen masaustu; mobilde sayfa dogru cizilir ve okunur.

**8. Klavye erisimi.** Gorunur yukari/asagi dugmeleri kalktigi icin, mevcut saf
`bolumOkTasi` fonksiyonu tutamaca ok-tusu (`ArrowLeft/Right/Up/Down`) olarak
bagli kaldi (`role=button` + `aria-label` + `onKeyDown`). Tepsideki gizli
bolumler de ayni klavye tasimasini tasir. Erisim kaybolmadi.

## Kod notlari

- `lib/pano-tercihi.ts` saf fonksiyonlari (`bolumSurukleBirak`, `bolumOkTasi`,
  `varsayilanSatirlar`, `tercihGovdesi`, `satirlariCoz`...) ve 16 birim testi
  DEGISMEDI. Yeni `bolumBirak` bunlari cagirir; gizli bayragi cevirme
  (`gizliAyarla`) bilesende kalir (satir modelini bozmaz).
- Yeni sozluk anahtarlari 7 dile de gercek cevirilerle eklendi:
  `panoDuzenleIpucu`, `panoGizliBolumler`, `panoGizliBolumYok`,
  `panoGizleyeSurukle`, `panoKaydedildiKisa` (i18n parite + TR-kopya testi
  gecer).
- `pano-duzenleme.dom.test.ts` yeni UI'ya guncellendi: sutun/banner/yukari-asagi
  ve per-bolum gizle dugmelerinin YOK oldugu, surukle ile yeniden siralamanin
  ve tepsiye surukleyerek gizlemenin PUT govdesine dustugu, klavye tasimanin ve
  "Varsayilana don"un calistigi olculur (jsdom'da drag olaylari elle
  tetiklenir).

## Dogrulama

- `npx tsc --noEmit` → cikis 0.
- Istenen tum test dosyalari (pano-duzenleme, pano-yerlesim-tasima,
  pano-ozellestirme, pano, pano-widget-tiklama, i18n, sabit-metin) → 97/97 gecti.
