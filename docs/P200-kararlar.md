# P200 — İki boşluk: parola sıfırlama + mobil sakin kaydı

**Tarih:** 2026-09-01 · **Kapsam:** admin-web testi · mobil test **+ bir hata düzeltmesi**

Kural: kaynak taraması yeterli değil. Her iki akış da **çalıştırıldı**,
sonra kilitlendi; kilitler bozularak doğrulandı.

---

# §1 — Parola sıfırlama (`/giris/sifremi-unuttum`)

## Ölçüm 1: sunucu tarafı — ÇALIŞIYOR

Dev API'de gerçek bir tesis + doğrulanmış e-postalı kullanıcıyla akış
uçtan uca koşturuldu (tenant e-posta sağlayıcısı `konsol`):

```
[1] POST /auth/sifre/kod-iste        -> 200 {"durum":"onay_bekliyor"}
[2] mesaj_gonderim satırı            -> ('gonderildi', ...,
                                         '[dogrulama kodu: sifre_sifirla · tasiyici=konsol-eposta]')
[3] kayit_dogrulama satırı           -> ('sifre_sifirla','telefon_bekliyor', ...)
[5] YANLIŞ kodla dogrula-ve-ayarla   -> 422 invalid_code
[6] DOĞRU kodla dogrula-ve-ayarla    -> 200
[7] YENİ parolayla /auth/login       -> 200, jeton geldi
[8] ESKİ parolayla /auth/login       -> 401
```

Yani P196'nın gönderim değişikliği bu akışı **kırmamış**; aksine artık
`mesaj_gonderim`de **izi var** (eskiden hiç yoktu).

**P196'nın bu uca kasıtlı dokunmadığı nokta:** kod gönderimi başarısız
olsa bile bu uç **502 dönmez**. Sebep sızdırmama: 502, "bu adres
kayıtlı ve doğrulanmış" bilgisini ele verirdi. Başarısızlık **loglanır
ve `mesaj_gonderim`e yazılır** — sessiz değil, ama kullanıcıya
yansımaz. Bu, P196-K kararının aynen korunmasıdır.

## Ölçüm 2: istemci tarafı — testi YOKTU, eklendi

`tests/p200-parola-sifirlama.dom.test.ts` akışı **düğmeden yeni
parolayla girişe kadar** sürüyor ve **giden gövdeyi** ölçüyor:

| Test | Ölçtüğü |
|---|---|
| AKIŞIN TAMAMI | iki isteğin **uç adresi + JSON gövdesi**, bitti ekranı, `/giris`e dönüş |
| BİÇİM hatası | geçersiz slug/e-posta → **sunucuya hiç istek gitmez** |
| SIZDIRMAMA | hesap yokken de 200 → ikinci adım açılır |
| 429 | ikinci adıma **geçilmez**, sunucunun mesajı görünür |
| YANLIŞ KOD | ekran ikinci adımda **kalır**, "bitti" demez |
| Bağlantıdan ön doldurma | `?tesis=&eposta=` aynen gövdeye gider |

Ortak `fetchSahtele` yalnız URL tutuyor; bu dosya **gövdeyi kaydeden**
kendi taklidini kurar — ölçülmek istenen şey tam da gövde.

## Kilit kanıtı (§1)

| Bozma | Düşen test |
|---|---|
| Gövdeden `tenant_slug` düşürüldü | AKIŞIN TAMAMI |
| Yanlış kodda `r.ok` denetimi kaldırıldı | YANLIŞ KOD |
| 429 denetimi kaldırıldı | HIZ SINIRI |

Üçü de geri alındı; 6 test yeşil.

---

# §2 — Mobil sakin kaydı (`rol-tamamla`)

## Önce düzeltme: premisin ölçülmesi

`test/kayit_rol_secimi_test.dart` bu akışı **zaten sürüyordu** (rol →
yöntem → Tesis ID → SSO/parola → tamamlama) ve çağrı argümanlarını
kontrol ediyordu. Yani "ekran akışı ölçülü değil" tam doğru değildi.

**Gerçek boşluk daha aşağıdaydı:** o test taklidi `AuthApi` /
`OauthRepository` düzeyinde kuruyor. İsteğin **gövdesini kuran katman**
(`auth_api.dart` içindeki `data: {...}`, P194'te değişen `'rol': ?rol`
dahil) testte hiç çalışmıyordu. P198'de kırılan şey tam olarak böyle
bir dikişti.

`test/p200_mobil_sakin_kaydi_test.dart` taklidi **en alta**, HTTP
adapter'ına koyar. Ekran → denetleyici → depo → api → **tel üzerindeki
JSON** zincirinin tamamı gerçektir.

## Akışı sürerken ÇIKAN GERÇEK KUSUR

Test ilk koşumda çöktü:

```
type 'String' is not a subtype of type 'GirisAkisHatasi?' in type cast
  AuthState.copyWith (auth_controller.dart:88)
  AuthController.oauthAkisi (auth_controller.dart:404)
```

`AuthController`ın **on** hata dalında `hataKimligi: e.code` yazıyordu.
`e.code` bir `String`; `copyWith` onu `GirisAkisHatasi?` olarak cast
ediyor. Sonuç bir "yanlış mesaj" değil, **yakalanmamış istisna**:
`catch` bloğunun *içinde* atılıyor, metottan dışarı sızıp ekranın
bekleme bayrağını açık bırakıyordu.

**Kullanıcının gördüğü:** sunucu bir hata döndüğünde sonsuza kadar
dönen bir düğme ve hiçbir hata metni. Kaynağa bakınca "hata
yakalanıyor" görünüyordu.

* **Ne zamandan beri:** `git log -L` ile ölçüldü — kalıp **P149**'da
  girmiş (`fa809df8`), o günden beri duruyor. P194–P199 turlarıyla
  ilgisi yok.
* **Doğru dönüştürücü zaten vardı:** `girisAgHatasi(e)` (tur 13). On
  çağrı yerinde kullanılmıyordu; iki yerinde kullanılıyordu — bu
  tutarsızlık kusurun kanıtı.
* **Düzeltme:** on çağrının hepsi `girisAgHatasi(e)` kullanır. Sunucu
  metni geldiyse kimlik `null` kalır ve kullanıcı sunucunun cümlesini
  görür; ağ hatasında kimlik üretilir ve metin çizimde çözülür.

## Eklenen testler (§2)

`p200_mobil_sakin_kaydi_test.dart` (7 test): SSO akışı + gövde ·
`otp_gerekli` dalı + ikinci gövde · parola akışı + iki ucun gövdesi ·
rolün **sunucu kimliğiyle** gitmesi (`tesis_gorevlisi`, ekran etiketi
değil) · `onay_bekliyor`da hesap açılmaması · **sunucu hata dönerse
mesajın görünüp düğmenin kilitlenmemesi** · tarayıcı kapatılınca Tesis
ID adımına geçilmemesi.

`p200_auth_hata_kimligi_test.dart` (3 test): `copyWith`in String'i
kabul etmediği, sunucu hatasında kimliğin `null` kaldığı, ağ hatasında
kimliğin üretildiği.

## Kilit kanıtı (§2)

| Bozma | Düşen test |
|---|---|
| Düzeltme geri alındı (`hataKimligi: e.code`) | SUNUCU HATA DÖNERSE |
| `auth_api` gövdesinden `tesis_kodu` düşürüldü | SSO AKIŞI |
| Ekran `rol.kimlik` yerine `rol.name` gönderdi | ROL GÖVDEDE... + SSO AKIŞI |

Üçü de geri alındı; 10 test yeşil.

---

## Ölçemediğim

* **Gerçek cihaz / emülatör yok.** Mobil akış widget testinde sürüldü;
  gerçek Google oturumuyla uçtan uca deneme yapılmadı.
* **Gerçek SMTP ile parola sıfırlama postası.** Dev'de tenant
  sağlayıcısı `konsol`du; mektubun posta kutusuna düştüğü değil,
  gönderimin `gonderildi` ile kayda geçtiği ölçüldü.
