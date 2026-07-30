# Çeviri inceleme paketi — anadil gözden geçirmesi (P14a)

Bu klasör, uygulamanın arayüz metinlerinin **anadil konuşucusu tarafından**
gözden geçirilmesi için hazırlanmıştır. Öncelik **Arapça (ar)** ve **Rusça
(ru)**: bu iki dil hem RTL/çekim açısından en riskli, hem de hedef kitlede
karşılığı en yüksek olanlar.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `ar-inceleme.csv` | 1.186 anahtar — Türkçe kaynak + mevcut Arapça + boş düzeltme sütunu |
| `ru-inceleme.csv` | aynısı, Rusça |

Sütunlar: `modul, anahtar, yer_tutucular, turkce_kaynak, <dil>_mevcut,
<dil>_duzeltme, not`.

## İnceleyene talimat (bunu olduğu gibi iletin)

1. **`<dil>_mevcut` sütununu okuyun; yalnız yanlış/doğal olmayanları
   düzeltin.** Doğru olanlara dokunmayın — `<dil>_duzeltme` boş kalsın.
   Değişmeyen satır = onaylanmış satır.
2. **`yer_tutucular` sütunu doluysa**, o metindeki `{ad}` biçimindeki
   ifadeler **AYNEN korunmalıdır** — çevrilmez, silinmez, sırası
   değiştirilebilir ama adı değişemez. Örn. `{dolu} / {kapasite}`.
3. **Sözlük tutarlılığı zorunludur** (aşağıdaki tablo). Aynı kavram her yerde
   aynı kelimeyle karşılanmalı.
4. **Marka adı `Yönetio` çevrilmez**, harf çevirisi de yapılmaz.
5. **Para birimi her dilde Türk Lirası (₺)** ve Türkçe sayı gruplamasıyla
   gösterilir — para birimi çevirisi/dönüşümü YOKTUR.
6. Metin **arayüzde dar bir alana** sığar. Türkçesinden %30'dan fazla uzayan
   bir karşılık bulduysanız `not` sütununa yazın; daha kısa bir alternatif
   düşünelim.
7. Arapça için: metin **sağdan sola** dizilir. Sayı ve saat içeren
   ifadelerde (`14:00-18:00`) yön karışıklığı yaşadıysanız `not` sütununa
   yazın.

## Sözlük (ARB'lerdeki `@@x-glossary` bloğunun aynısı)

| Türkçe | İngilizce karşılık | Arapça | Rusça |
|---|---|---|---|
| aidat | dues | رسوم الإدارة | взносы |
| vardiya | shift | الوردية | смена |
| devriye | patrol | الدورية | обход |
| kontrol noktası | checkpoint | نقطة تفتيش | контрольная точка |
| demirbaş / zimmet | asset / checkout | العهدة | инвентарь / выдача |
| talep | request / ticket | — | — |
| şikayet | complaint | — | — |
| daire | unit | الشقة | квартира |
| blok | block | البلوك | блок |
| tesis | facility / site | — | — |
| görevli | officer | — | — |
| sakin | resident | الساكن | житель |

> Tablodaki `—` hücreleri **inceleyenin dolduracağı** yerlerdir: o kavram için
> tutarlı bir karşılık seçip `not` sütununda bildirsin; sözlüğe eklenecek.

## Geri dönüş nasıl işlenir

`<dil>_duzeltme` sütunu dolu satırlar ilgili `mobile/lib/l10n/app_<dil>.arb`
dosyasına işlenir, `flutter gen-l10n` çalıştırılır ve
`test/sozluk_denetimi_test.dart` koşulur (7 dilin anahtar kümesi aynı mı,
Türkçe harf sızmış mı, yer tutucular korunmuş mu).

## Bu paket NEYİ KAPSAMAZ

Bu dosyalar **arayüz sabitleridir** (düğme, başlık, hata mesajı). Sitenin
kendi ürettiği içerik (duyuru, kural, etkinlik metni) buraya girmez — o
içerik yazıldığı dilde saklanır ve çalışma anında makine çevirisiyle servis
edilir. Makine çevirisinin kalitesi ayrı bir konudur; ölçümü ve kararı
`docs/ceviri-kalite-notu.md` dosyasındadır.
