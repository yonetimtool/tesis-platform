# P198 — Google ile yönetici kaydı döngüye giriyordu

## Kök neden (ölçüldü)

Kayıt sayfası OAuth'u **`niyet="giris"`** ile başlatıyordu.
`admin-web/app/kayit/page.tsx`, "yöntem" adımı:

```tsx
<SosyalGiris niyet="giris" kayitRolu={rol} />
```

Sunucuda `niyet=giris` şu soruyu sorar: *"bu kimlik hangi hesaba
**bağlı**?"* Yeni bir yönetici hiçbir hesaba bağlı olmadığı için yanıt
`baglama_gerekli` oluyor ve `/giris/oauth` kullanıcıyı **Tesis ID
formuna** düşürüyordu. P185'in kabul kriteri olan "yeni tesis / katıl"
ayrımı ise `durum='kayit'` dalında yazılı — o dala hiç girilmiyordu.

**Sunucuda ölçtüm** (aynı bağlı-olmayan Google kimliği, dev API):

```
niyet=kayit -> çöz=kayit    durum='kayit'            bağlama jetonu VAR
niyet=giris -> çöz=baglama  durum='baglama_gerekli'  (Tesis ID formu)
```

Yani **sunucu doğruydu, istemci yanlış niyeti gönderiyordu.**

### Hangi tur kırdı? Hiçbiri.

`git log -L` ile satırın geçmişine baktım: `niyet="giris"` **P155r2'den
beri** orada. P194/P195/P196/P197 bu satıra dokunmadı. Yani bu bir
regresyon değil, **hiç çalışmamış bir yol**. Tanıtım sitesinden gelen
giriş (`/kayit?niyet=kayit&...`, P180) doğru niyeti taşıdığı için akış
oradan çalışıyordu; doğrudan `/kayit` sayfasından girenler düşüyordu.

## Akış, adım adım (düzeltmeden sonra)

| # | Adım | Ne oluyor |
|---|---|---|
| 1 | `/kayit` → rol: **Yönetici** | — |
| 2 | Yöntem adımı | Onaylar alınır (aşağıda), Google düğmesi çizilir |
| 3 | "Google ile devam" | `POST /api/auth/oauth/baslat/google` · gövde: **`niyet: "kayit"`** + onaylar |
| 4 | Sağlayıcı dönüşü | `POST /auth/oauth/sonuc` → **`durum='kayit'`** + bağlama jetonu |
| 5 | `/giris/oauth` | Sonucu saklar, `/kayit`a yönlendirir |
| 6 | `/kayit` | `bilgiler` adımından devam; **ad ön-dolu** |
| 7 | Bilgiler → İleri | Yöneticide **`secim`** adımı: "Yeni tesis / Katıl" |
| 8 | "Yeni tesis" | **Tesis adı** sorulur — Tesis ID **sorulmaz** |
| 9 | Gönder | `POST /auth/kayit/tesis-olustur` (bağlama jetonu + tesis adı) |
| 10 | Sonuç | **Tesis kodu sistemce üretilip gösterilir** |

## Kararlar

**K1 — Niyet role bağlı.** Yalnız **yönetici** yeni tesis açabilir;
sakin ve saha rolleri var olan bir tesise katılır ve onların doğru yolu
bağlama akışıdır (Tesis ID). Bu yüzden `niyet` sabit değil:
yönetici → `kayit`, diğerleri → `giris` (değişmedi).

**K2 — Onaylar sağlayıcıya gitmeden önce alınır.** Backend `niyet=kayit`
için iki zorunlu onayı **`baslat` çağrısında** doğruluyor. Onaylar
`bilgiler` adımında toplanıyordu ama sosyal yol oraya **hiç uğramıyor**.
Onay kutuları artık yöntem adımında da çiziliyor (aynı state, tek
bileşen — `OnayKutulari`).

**K3 — Onay verilmeden sosyal düğmeler çizilmez.** Backend 422 dönerdi ve
kullanıcı sebebini göremeden geri düşerdi. Düğme yerine ne eksik olduğu
yazılıyor.

## Testler bunu neden yakalamadı (istediğiniz açıklama)

`tests/kayit-rolleri.test.ts` bu sayfayı **kaynak taramasıyla** ölçüyor:
`readFileSync` ile dosyayı **metin olarak** okuyup düzenli ifadeyle
"adım sırası doğru mu", "rol listesi doğru mu" diye bakıyor. Dosyanın
başında bunun gerekçesi de yazılı: *"akis bir useState icinde degil,
cizim bloguna gomulu. Kaynak taramasi kirilgan secici olmadan kurali
olcer."*

Bu tarama **adımların sırasını görür, adımlar arasında gerçekten
geçilip geçilmediğini göremez** — ve kırılan tam olarak oydu. Sayfada
"secim" adımı **kod olarak vardı**, tarama onu buluyordu; ama hiçbir
kullanıcı oraya **ulaşamıyordu**.

Aynı boşluğun ikinci yüzü: backend testleri `niyet=kayit` davranışını
doğru ölçüyordu, admin-web testleri de bileşenleri ölçüyordu — ama
**hiçbir test istemcinin sunucuya hangi niyeti gönderdiğini** ölçmüyordu.
Kusur tam da o dikişte duruyordu.

### Yeni test: `p198-google-yonetici-kaydi.dom.test.ts` (5 test)

Akışı uçtan uca sürüyor: düğmeye basıyor, **giden isteğin gövdesini
okuyor**, sağlayıcı dönüşünü taklit ediyor ve tesis kodu ekranına kadar
her adımı geziyor.

**Kilidin çalıştığını kanıtladım:** düzeltmeyi geçici geri alıp koştum —
```
× 1) YONETICI + Google -> istek `niyet=kayit` TASIR
  AssertionError: niyet 'kayit' degil — Tesis ID formuna duser:
  expected undefined to be 'kayit'
```

## Aynı boşluk başka nerede var?

Kritik akışları taradım — ölçüt: **davranış testi mi (render + tıklama),
yoksa yalnız kaynak taraması mı?**

| Akış | Durum |
|---|---|
| **Yönetici kaydı (sosyal)** | ✅ artık uçtan uca (bu tur) |
| Davet tamamlama (`/davet/[jeton]`) | ✅ `davet-web.dom.test.ts` — render + çağrı gövdesi ölçüyor |
| Sosyal giriş (login) | ✅ `sosyal-giris.dom.test.ts` — 5 render testi |
| Mobil yönetici SSO girişi | ✅ `p194_mobil_yonetici_sso_test.dart` (P194) |
| **Parola sıfırlama (`/giris/sifremi-unuttum`)** | ❌ **DOM testi YOK** — 297 satırlık ekran, hiçbir davranış testi yok |
| **Sakin kaydı (mobil, rol-tamamla)** | ⚠️ backend uçları ölçülü; **mobil ekran akışı** uçtan uca ölçülmüyor |
| Kayıt sayfası genel sırası | ⚠️ yalnız kaynak taraması (`kayit-rolleri.test.ts`) — sıra doğru olsa da geçiş ölçülmüyor |

**En riskli iki tanesi:** parola sıfırlama (hiç davranış testi yok ve
P196'da gönderim yoluna dokundum) ve mobil sakin kaydı. İkisi de bu turun
kapsamı dışında; kapatılmasını isterseniz ayrıca yaparım.
