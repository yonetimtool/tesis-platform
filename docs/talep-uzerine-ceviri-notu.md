# "Bu içeriği çevir" düğmesi — değerlendirme notu (P21)

> Kısa not, uygulama YOK. Soru: kullanıcının YAZDIĞI metinler (şikâyet, talep
> açıklaması, yorum) da çevrilmeli mi — ve çevrilecekse nasıl?

## Yayın içeriğinden farkı

Bugün çevrilen içerik **yayın** içeriğidir: duyuru, site kuralı, etkinlik.
Ortak özellikleri: **az sayıda, uzun ömürlü, çoktan-aza yazılır** (yönetim
yazar, herkes okur). Bu yüzden **yazma anında** 6 dile çevirmek doğru karar:
bir kez ödenir, binlerce okumada kullanılır.

Kullanıcı üretimi metin bunun tersidir:

| | Yayın içeriği | Kullanıcı metni |
|---|---|---|
| Adet | onlarca | **binlerce** (her şikâyet, her talep, her yanıt) |
| Okuyan | tüm site | genelde **1–2 kişi** (açan + yönetici) |
| Ömür | aylar | kapanınca ölü |
| Yazan | yönetim | herkes |

Sonuç: **yazma anında 6 dile çevirmek burada yanlıştır.** 1.000 şikâyet ×
6 dil = 6.000 çeviri; bunların büyük çoğunluğu **hiç okunmayacak**.

## Öneri: TALEP ÜZERİNE, tek dile

Doğru şekil: metnin altında küçük bir **"Çevir"** bağlantısı. Basılınca
yalnızca **o metin**, yalnızca **okuyanın diline** çevrilir ve önbelleğe
alınır.

```
[şikâyet metni — orijinal dilinde]
🌐 Çevir                                   ← basmadan çeviri ÜRETİLMEZ
```

Bastıktan sonra P7'nin **aynı** arayüzü kullanılır — yeni bir görsel dil icat
edilmez:

```
[çevrilmiş metin]
🌐 Bu içerik otomatik çevrilmiştir · Orijinali gör
```

### Ne kadar iş

Backend'de **yeni sağlayıcı gerekmiyor** — `translate.py` soyutlaması ve
`icerik_ceviri` altyapısı zaten var. Gereken:

* `POST /translate/on-demand` benzeri bir uç (metin + hedef dil → çeviri),
  **tenant başına hız sınırı** ile;
* önbellek: `(kaynak_metin_hash, hedef_dil)` — aynı metin ikinci kez
  çevrilmez. Bu, mevcut `ceviri`nin `kaynak_ozet` (hash) kalıbının aynısıdır;
* mobil: metin bloğunun altına düğme + P7'deki `CeviriNotu` bileşeninin
  yeniden kullanımı (yeni bileşen YAZILMAZ).

### Maliyet

* **LibreTranslate (bugünkü kurulum):** parasal maliyet **yok**, yalnız CPU.
  PoC ölçümünde ~0,8 sn/çeviri. Talep üzerine olduğu için yük düşük kalır.
* **DeepL'e geçilirse** (bkz. `docs/ceviri-kalite-notu.md`): karakter başına
  ücret. Talep üzerine model burada **avantaja dönüşür** — yazma anında
  çevirseydik okunmayan metinler için de ödenecekti.

## Neden şimdi değil

1. **Kalite engeli önce çözülmeli.** `docs/ceviri-kalite-notu.md` ölçümü
   gösterdi ki Türkçe kaynakta alan terimleri bozuluyor. Şikâyet metni
   genellikle *daha* zor: yazım hatası, argo, eksik cümle. Bugünkü kaliteyle
   "Çevir" düğmesi çoğu zaman **anlaşılmaz** bir çıktı verir ve kullanıcının
   sisteme güvenini düşürür.
2. **Talep hacmi henüz yok.** Çok dilli sakin kütlesi oluşmadan bu düğme
   ölü kod olur.
3. **Ucuz bir ara adım var:** yönetici zaten şikâyeti okuyor; çeviri
   gerektiğinde tarayıcı/telefon çevirisi bugün de kullanılabiliyor.

## KVKK notu

Kullanıcı metni **kişisel veri içerebilir** ("3. kattaki Ahmet Bey gece
gürültü yapıyor"). Kendi barındırdığımız LibreTranslate'te bu veri dışarı
çıkmaz. **DeepL'e geçilirse bu metinler yurt dışına aktarılır** — yayın
içeriğinden farklı olarak burada üçüncü kişi verisi de vardır. O yüzden:
**sağlayıcı DeepL olursa, talep-üzerine çeviri kullanıcı metinleri için
AYRICA değerlendirilmelidir**; yayın içeriği kararı bunu kapsamaz.

## Karar

**Düşük öncelik, şimdi yapılmıyor.** Yapılacaksa sıra:
`ceviri-kalite-notu` kararı → hız sınırlı uç + hash önbelleği → mobilde
P7 bileşeninin yeniden kullanımı. Yeni sağlayıcı, yeni şema ve yeni görsel
dil **gerekmez**.
