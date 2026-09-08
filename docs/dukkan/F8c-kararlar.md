# F8c — Ödeme altyapısı: kararlar

> **Sanal POS sağlayıcısı seçilmedi, başvuru yapılmadı.** Bu faz o yüzden
> sağlayıcıdan **tamamen bağımsız** yazıldı: seçim yapıldığında değişecek
> tek şey bir sınıf + bir env satırı.
>
> Karşılaştırma ve teklif isterken sorulacaklar:
> `08-odeme-saglayici-karsilastirma.md`.

---

## 1. Desen: SMS'in birebir aynısı

`mesajlasma.py`deki kalıp kopyalandı, çünkü **aynı problem**:

| SMS (F2/F7) | Ödeme (F8c) |
|---|---|
| `MesajSaglayici` soyut taban | `OdemeSaglayici` soyut taban |
| `dukkan_sms_saglayicisi()` tek seçim noktası | `odeme_saglayicisi()` tek seçim noktası |
| `KapaliSmsSaglayici` — tanınmayan ada düşer | `KapaliOdemeSaglayici` — tanınmayan ada düşer |
| `DURUM_YAPILANDIRILMADI` | `DURUM_YAPILANDIRILMADI` (aynı ad) |
| Varsayılan **kapalı** | Varsayılan **kapalı** |

Aynı kalıbı ikinci kez *yazmak* yerine kopyalamak, iki altyapının
ileride ayrışma ihtimalini de ortadan kaldırıyor.

---

## 2. "Sessizce ödendi deme" — SMS dersinin ödemedeki karşılığı

SMS turunda ölçülen kusur: yanıt `{"gonderildi": true, "gonderim":
"saglayici_bagli_degil"}` dönüyordu; iki alan **çelişiyordu.**

Ödemede aynı kusurun bedeli çok daha ağır: "ödendi" diyen bir yanıt
reklamı **yayına alır** ve platform parasını hiç almadan hizmet verir.
Daha kötüsü, işletme ödediğini sanır.

Alınan önlemler:

- `OdemeSonucu.basarili` bir **property** ve yalnızca
  `durum == "basarili"` iken `True`. İki alanın çelişmesi **mümkün
  değil** (SMS'te bu iki ayrı alandı ve çelişebiliyordu).
- Sağlayıcı bağlı değilse uç **503** döner — `200 + basarili: false`
  **değil**. 200 dönmek, istemciyi başarılı yanıt dalına sokup "ödeme
  alındı" ekranı gösterirdi.
- Hiçbir kod yolu, sağlayıcıya **sormadan** reklam açmaz.
- Tanınmayan `ODEME_SAGLAYICI` değeri sessizce geçmez: **loglanır** ve
  kapalıya düşer.

**Dev için ayrı bir sahte sağlayıcı var** (`SahteOdemeSaglayici`) ama
**varsayılan değil** ve adı açıkça sahte. Varsayılanı "başarılı dönen
sahte" yapmak akışı test etmeyi kolaylaştırırdı — ve aynı sınıf bir
yapılandırma hatasıyla prod'a düşebilirdi.

---

## 3. Kart bilgisi hiçbir koşulda bizde değil

Üç katmanda zorlanıyor:

1. **Tip düzeyinde:** `OdemeSaglayici.kart_sakla()` imzası kart alanı
   **almaz**. `KartSaklaIstek` modelinde yalnız `takma_ad` var.
2. **Veritabanı düzeyinde:** `odeme_yontemi` tablosunda token'lar ve
   gösterim için `son_dort` + `marka` var; kart numarası, CVV, son
   kullanma tarihi **yok**.
3. **Test düzeyinde:** `test_KART_ALANI_HICBIR_TABLODA_YOK` — *belirli
   bir tabloyu değil*, `dukkan` şemasının **tamamını** tarar. Yarın
   eklenecek bir tabloda belirse de yakalanır.

**`son_dort` ve `marka` bilerek yasak listesinde değil:** ikisi de PCI
kapsamında saklanabilir ve kullanıcının "hangi kart" sorusunu ancak
onlar yanıtlar.

### Kilidi yazarken yaptığım hata

İlk yazımda düz `in` (substring) kullandım ve `"pan"` parçası
`kapanis`, `kapandi_at`, `kapanis_sebebi` sütunlarını **yakaladı** —
üç yanlış alarm. Düzeltildi: kısa tokenlar sütun adı `_` ile bölünüp
**sözcük** olarak karşılaştırılıyor.

Bu önemliydi: yanlış alarm veren bir kilit, ilk kırmızıda devre dışı
bırakılır — ve o andan sonra **hiçbir şey korumaz**.

---

## 4. Tekrarlayan ödeme: altyapıda var, üründe varsayılan değil

İki ayrı karar, karıştırılmamalı:

- **Altyapı** tekrarlayan çekimi **destekler**: `sakli_kartla_cek()`,
  `odeme_yontemi` (token), `abonelik` tablosu, gecelik
  `dukkan.abonelik_cekimi` görevi. Abonelik ve reklam **aynı
  altyapıyı** kullanıyor — isteğin şartı.
- **Reklam ürünü** varsayılan olarak **tek seferliktir**;
  `otomatik_yenile` varsayılanı `false` (F8b kararı: sessizce kart
  çekmek en çok şikâyet üreten şeydir).

Yani "recurring desteği yok" değil; **"recurring varsayılan değil"**.

**Abonelik ancak kart varsa doğar.** Kart yoksa yenileme yapılamaz;
sessizce "açıldı" demek, işletme yenilendiğini sanırken reklamın
düşmesi demekti.

### Başarısız çekim sessiz değil

Her başarısızlıkta işletme sahibine bildirim gider
(`dukkan_odeme_basarisiz`). Üç üst üste başarısızlıkta abonelik durur ve
bu **ayrıca** bildirilir (`dukkan_abonelik_durdu`) — reklamın neden
yenilenmediğini ay sonunda keşfetmesin.

**Neden 3:** sonsuza kadar denemek hem bankada hem kullanıcıda gürültü
yaratır ve bazı bankalar tekrarlayan reddi şüpheli işlem sayar. Üç,
"geçici sorun" (limit dolu, kart yenilendi) ile "gerçekten bitti"
arasını ayırmaya yetecek kadar. **Sayı tahmin** — ilk ay ölçülüp
ayarlanmalı.

**Tekrar denemede bir gün ara:** aynı gün içinde tekrar denemek, limiti
dolu bir kartta aynı sonucu verir.

**Sağlayıcı bağlı değilken görev hiçbir şey yapmaz** ve sayaçları
şişmez: denemek ve "yapılandırılmadı" ile başarısız saymak, abonelikleri
**kullanıcının hatası olmadan** durdururdu.

---

## 5. Sıra: ödeme önce, reklam sonra — ve aradaki boşluk **görünür**

Önce reklamı açıp sonra tahsil etmek daha basit olurdu; yapılmadı.
Tahsilat başarısız olursa yayında duran reklamı geri almak gerekirdi ve
o arada gösterim **zaten olmuş** olurdu.

Tersi de risksiz değil: ödeme başarılı olup reklam açma adımı patlarsa
(ör. bu arada slot doldu) **sahipsiz bir tahsilat** kalır.

**Bu gizlenmiyor.** `reklam_satin_alma.reklam_id` NULL kalır ve o
satırlar için kısmi indeks var (`ix_reklam_satin_alma_sahipsiz`). İade
edilecek para odur ve görünür olması şart. `reklam_id` NOT NULL olsaydı
o satır hiç yazılamaz, para alınır ve **iz kalmazdı**.

**Satın alma satırı çekimden ÖNCE yazılıyor ve commit ediliyor:** çekim
sırasında süreç ölürse (deploy, OOM) elimizde hiçbir iz kalmamasındansa
"beklemede" bir satır kalması yeğlenir. O satır bir sorudur ve
sorulabilir; iz bırakmayan tahsilat sorulamaz.

---

## 6. Fatura alanları satın alma anında donduruluyor

`reklam_satin_alma` unvan, VKN, vergi dairesi, adres, tutar, KDV ve
tarihi **kendi satırında** tutar — işletme tablosuna JOIN atmaz.

Fatura, kesildiği **andaki** bilgilerle kesilir. İşletme yarın unvan ya
da adres değiştirirse geçen ayın faturası **değişmemeli**. JOIN'li bir
tasarım geçmiş faturaları sessizce yeniden yazardı.

**Toplam ayrıca saklanıyor, hesaplanmıyor:** KDV oranı ya da yuvarlama
kuralı değişirse geçmiş toplam değişmemeli.

**KDV tam sayı aritmetiğiyle:** `float` ile hesaplanan KDV, yuvarlama
farkıyla faturayı bir kuruş kaydırır ve mutabakatı bozar.

V1'de fatura **elle** kesilecek (aylık ~30 satışa kadar mali müşavir
ücretine dâhil), ama gerekli her alan bugünden kayıtlı — e-Arşiv
entegratörüne geçiş veri toplamayı gerektirmeyecek.

---

## 6b. Ölçülen güvenlik kusuru: kart silmede IDOR

Otomatik güvenlik taraması `kart_sil` ucunda bir **IDOR** buldu ve
haklıydı.

**Kusur:** kart güncellemesi sahipliğe bağlıydı
(`WHERE id = :i AND kullanici_id = :k`) ama **abonelik güncellemesi
değildi** (`WHERE odeme_yontemi_id = :i`).

**Sömürüsü:** başkasının kart kimliğini gönderen bir saldırgan
`silinen: 0` alır — yani yanıt **görünürde doğrudur** — ama o
kullanıcının **abonelikleri duraklatılır**. Somut sonucu: bir işletme,
rakibinin reklam yenilemesini dışarıdan durdurabilirdi. Para ve
görünürlük kaybı.

**Düzeltme iki katmanlı:**
1. Kart silinmediyse hiç devam etme (erken dönüş).
2. Abonelik sorgusu da `oy.kullanici_id` ile sahipliğe bağlı — birinci
   katman bir gün değişirse ikincisi hâlâ korur.

**Kendi testlerimin bunu neden kaçırdığı — ve ne değişti:** F8c'de IDOR
testi yazmıştım ama yalnız *satın alma* ve *abonelik iptali* uçları
için. Kart silmede yanıt "doğru" göründüğü (`silinen: 0`) için yan
etkiyi ölçmemiştim. Kusur **dönüş değerinde değil, yan etkideydi.**

Yeni kilit ikisini birden ölçüyor: yabancı isteğin yanıtını **ve**
veritabanında ne değiştirdiğini. Kırılarak doğrulandı — sahiplik
koşulu kaldırılınca kırmızı yanıyor.

> **Bundan sonraki IDOR testlerinde kural:** yalnız yanıtı değil,
> yabancı isteğin **veritabanında bıraktığı izi** de ölç.

---

## 7. Kart silme ve abonelik iptali: sonuçlar **söyleniyor**

- **Kart silme** yanıtı `etkilenen_abonelik` sayısını döner: kartı silen
  kullanıcı, o kartla yenilenen aboneliklerin duracağını bilmeli.
  Sessizce silmek, ay sonunda "reklamım neden düştü" sorusu üretirdi.
- **Abonelik iptali yayındaki reklamı düşürmez:** işletme dönemin
  parasını ödedi, sonuna kadar yayında kalır. İptal,
  *yenilenmeyeceğini* söyler.

---

## 8. Zamanlama: 02:40 — reklam bakımından **sonra**

Bakım süresi bitenleri düşürür ve **slot açar**; çekim o slota yeni
dönemi yazar. Ters sırada, işletmenin kendi reklamı hâlâ "yayında"
olduğu için yenileme **"bölge dolu"** alırdı.

---

## 9. Ölçemediklerim

1. **Gerçek tahsilat.** Sağlayıcı yok; hiçbir karta hiç dokunulmadı.
   Ölçülen şey akışın **kendisi** (sahte sağlayıcıyla) ve sağlayıcı
   bağlı değilken davranış (503).
2. **3DS akışı.** `yonlendirme_url` dalı kodda var ama hiçbir gerçek
   3DS sayfası görülmedi. Sağlayıcı seçilince bu dal **yeniden
   ölçülmeli** — özellikle "ilk işlemde 3DS, sonraki çekimlerde MIT"
   davranışı (bkz. karşılaştırma §2.2).
3. **Başarısız çekimin gerçek sebepleri.** `yetersiz_bakiye` gibi
   kodlar sahte sağlayıcıdan geliyor; gerçek banka kodları farklı
   olacak ve kullanıcıya gösterilecek metinler o zaman
   olgunlaştırılmalı.
4. **Deneme sayısı (3) ve bir günlük ara.** Tahmin; ilk ay ölçülmeli.
5. **Sahipsiz tahsilat.** Kısmi indeks var ama o duruma **düşen bir
   kayıt hiç görülmedi** — yarış koşulu üretilemedi.
