# contracts/veri — dis kaynakli sabit veri

## `tr-lokasyon.json`

Turkiye il / ilce / mahalle-koy hiyerarsisi. Dukkan'in lokasyon agacini
(`dukkan.il`, `dukkan.ilce`, `dukkan.mahalle`) besler.

| | |
|---|---|
| **Kaynak** | https://github.com/ferhat-mousavi/turkiye-il-ilce-mahalle-koy |
| **Ham dosya** | https://raw.githubusercontent.com/ferhat-mousavi/turkiye-il-ilce-mahalle-koy/master/turkiye-il-ilce-mahalle-koy.json |
| **Lisans** | **MIT** (depoda LICENSE dosyasi var; ticari kullanima uygun, yeniden dagitima izinli) |
| **Indirme tarihi** | 2026-09-06 |
| **sha256** | `defbf445b2169c16417a27a7b4bf9149da2e97bea82abac9663e5f4f4573c695` |

### NEDEN DEPODA, NEDEN "INDIR" TALIMATI DEGIL

Ilk dagitim notu operatorden dosyayi indirmesini istiyordu. Bu YANLISTI:

1. **Tekrarlanabilirlik.** Ham dosya GitHub'da `master` dalinda duruyor ve
   ustteki depo onu her an degistirebilir. "Indir" talimati, prod'a dev'de
   DOGRULANMAMIS bir veri gitmesi anlamina gelirdi — ve fark ancak
   binlerce SEO yolu uretildikten sonra gorunurdu.
2. **Dis bagimlilik.** GitHub'in erisilemedigi bir anda dagitim durur.
   Depodaki dosya icin boyle bir an yok.
3. **Denetlenebilirlik.** Veri bir kez ONARILDI (asagi bak). Onarimin
   dogrulandigi GIRDI ile prod'a giden girdi AYNI olmali.

Lisans MIT oldugu icin yeniden dagitim serbest; kaynak ve lisans burada
belirtiliyor.

### VERI HAM HALIYLE KULLANILAMAZ — ONARIM YUKLEYICIDE

Bu dosya **kaynaktan geldigi gibi** duruyor, yani BOZUK:

* 74.402 Turkce adda `ı` harfi **SIFIR** kez geciyor (Turkcede `ı` cok
  yaygin oldugu icin istatistiksel olarak imkansiz),
* adlarin **%83,6**'si U+0307 birlesen nokta tasiyor (`"Mahallesi̇"`),
* il adlari bile bozuk: `Balikesi̇r`, `Di̇yarbakir`, `Afyonkarahi̇sar`.

Teshis: kaynak metin BUYUK HARFTI ve Turkce OLMAYAN bir yerel ayarla
kucultulmus (`'İ'.lower()` -> `'i'`+U+0307, `'I'.lower()` -> `'i'`).

**Onarim AYRI BIR KOMUT DEGIL** — `app/dukkan/lokasyon_yukle.py` icindeki
`_onar()` yukleme sirasinda otomatik uygular. Bozulma deterministik
oldugu icin birebir geri dondurulebiliyor; dogrulama tahmin degil olcum:
81/81 il ve 39/39 Istanbul ilcesi bilinen dogru adla eslesti
(`backend/tests/test_dukkan_lokasyon.py`).

Dosyayi ELLE onarma. Onarilmis bir dosya yuklenirse `_onar()` ikinci kez
calisir ve adlari yeniden bozar.

### GUNCELLEME YOLU

Yilda 1-2 kez: yeni dokumu indir, **fark raporu** uret (yeni / silinen /
adi degisen), **elle onayla**, sonra bu dosyayi degistir ve
`sha256`'yi yukaridaki tabloda guncelle.

Otomatik uygulama YOK: silinen bir mahalle, ona bagli isletmeleri ve
canli SEO sayfalarini sessizce dusurur.
