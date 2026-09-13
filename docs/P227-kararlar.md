# P227 — Rapor hatası, rapor zenginleştirme, telefon alanı

Tarih: 2026-09-13

---

## §1 — Rapor üretimi SSLError

### Kök neden: tek ayar, iki farklı iş

`MINIO_ENDPOINT` aynı anda iki şeye hizmet ediyordu:

| Kullanım | Hangi adres olmalı |
|---|---|
| Presigned URL host'u (istemci oraya bağlanır) | **PUBLIC** (`https://storage.yonetio.site`) |
| Sunucu-tarafı `put_object` / `delete_objects` | **İÇ** (`http://minio:9000`) |

Prod'da tek değer public adrese ayarlıydı. `worker`, ürettiği PDF'i
yüklerken konteyner içinden **kendi genel adresine** çıkmaya çalıştı;
pfSense NAT reflection bunu engelliyor ve TLS el sıkışması koptu →
`SSLError`.

**Compose'daki yorum varsayımı yazıyordu bile:** *"api sunucu-tarafı
MinIO çağrısı YAPMAZ (presign yerel imzalanır)"*. `api` için doğruydu
ama ölçtüm, **artık doğru değil**: `banka.py` dekont PDF'ini,
`hesap_silme.py` avatar silmeyi sunucu tarafından yapıyor. `worker` için
ise en baştan yanlıştı — ve iki servise de aynı değer veriliyordu.

### Karar

`minio_internal_endpoint` eklendi. `_client(ic=True)` sunucu-tarafı
işlemlerde iç adresi, presign public adresi kullanıyor. **Boş
bırakılırsa eski davranışa düşer** — dev ve tek-adresli kurulumlar
etkilenmez.

Presign'ın public adresle imzalanması zorunlu: **imza host'a bağlıdır**.
Bunu ölçtüm — indirme URL'sindeki host'u elle değiştirince MinIO `403`
döndü.

### "SSLError" mesajı

Sınıf adı teşhis değildir: yönetici bu kelimeyle kamerasının mı,
sertifikasının mı, internetinin mi bozuk olduğunu bilemez. Gerçek sebep
**sunucu yapılandırmasıydı** — kullanıcının dokunabileceği hiçbir şey
yok.

Artık ne olduğu ve kimin düzelteceği yazılıyor, teknik sınıf adı
**parantez içinde kalıyor** (yönetici desteğe iletebilmeli). Bilinmeyen
hatada da sınıf adı veriliyor: "bilinmeyen hata" demek, desteğe
iletilebilecek tek ipucunu da silmek olurdu.

### Testler neden görmedi

`test_rapor_kuyruk.py` **yalnız kuyruğa atma ucunu** ölçüyordu: sahiplik,
biçim doğrulama, 404. Görevin gövdesi (`isi_uret`) — PDF üretimi ve
MinIO'ya yükleme — **hiçbir testte çalıştırılmıyordu**. Kırılan adım test
yüzeyinin tamamen dışındaydı.

`test_p227_rapor_zinciri.py` bu boşluğu kapatıyor: görevi gerçekten
koşuyor, dosyanın depoya yazıldığını ve **geri okunabildiğini**
doğruluyor.

Test yazarken **P187'ye çarptım**: düz `asyncio.run` ikinci çağrıda
`Future attached to a different loop` veriyor (asyncpg bağlantıları
oluşturuldukları loop'a bağlı). Deponun kendi yardımcısı
(`_async_calistir`) kullanıldı — üretimdeki Celery görevleri de aynı
yoldan geçiyor, yani test **üretimle aynı koşulda** koşuyor.

### Yan bulgu: PDF'te Türkçe harfler bozuktu

Uçtan uca ölçüm sırasında çıktı:

```
"Olu■turma", "Kad■köy", "■stanbul", "Ba■■ms■z Bölüm"
```

`ç`, `ö`, `ü` doğru çiziliyordu ama `ş`, `ğ`, `ı`, `İ` **kutu** oluyordu.
Sebep: reportlab'in gömülü `Helvetica`sı WinAnsi (cp1252) kullanır; o
küme `ş/ğ/ı/İ` içermez (onlar Latin-5). Yani "muhasebeciye verilebilecek
kalite" iddiasını doğrudan çürüten, **tanımlı** bir eksiklikti.

DejaVuSans'a geçildi — imajda **zaten kurulu**, yeni bağımlılık yok.
Font bulunamazsa Helvetica'ya düşülür ve **uyarı log'a yazılır**: rapor
üretimini font yüzünden düşürmek, birkaç bozuk harf yüzünden bütün
çıktıyı kaybettirmek olurdu.

### Uçtan uca ölçüm (gerçekten sürüldü)

Panel → kuyruk → **Celery worker** → PDF → MinIO → geri okuma:

```
borc_alacak/pdf         : hazir  46 317 bayt  sayfa:1  kutu:False  'Sayfa':True
finansal_hareketler/pdf : hazir  44 859 bayt  sayfa:1  kutu:False  'Sayfa':True
borc_alacak/excel       : hazir   6 093 bayt
```

PDF başlığı: tesis adı, rapor adı, dönem, oluşturma zamanı, **adres**
(`Örnek Mah. 1. Sk. No:5, Kadıköy, 34710 İstanbul`) ve `Sayfa n / m`.

### Ölçerken kendi tuzağıma düştüm — kayda değer

Bir süre "doğrudan çağrı temiz, kuyruk bozuk" sonucu aldım ve kodu
suçladım. Sebep koddaki bir fark değildi: kuyruk ucu Celery görevini
**worker konteynerine** gönderiyor ve ben yalnız `api` imajını yeniden
kurmuştum. Worker eski kodla yazıyordu. Bu, "beat üçüncü kez build
listesinden düştü" olayının aynı sınıfı — **rapor değişikliğinde `worker`
da yeniden kurulmalı**.

---

## §3 — Telefon alanı

### Ölçüm önce: ne vardı, ne yoktu

`lib/telefon.ts` (panel) ve `telefon_alani.dart` (mobil) **ikiz** olarak
zaten duruyordu ve paylaşılan bir test tablosuyla kilitliydi. Mevcut:
gruplama, 10 hane sert sınırı, `5` ile başlama zorunluluğu, yapıştırma
çözme, E.164 üretimi.

**Saklama biçimi ölçüldü:**

```
app_user.telefon: +905931019452 …
+90 ile başlayan: 3057    başlamayan: 0
```

Yani DB **E.164** tutuyor ve bugün **tüm kayıtlar Türkiye**. Gösterim ile
saklama zaten ayrıydı; dokunmadım — telefon global benzersiz anahtar
(P185/P197) ve normalizasyonu değiştirmek mevcut kayıtları bozardı.

### Üç boşluk kapatıldı

**1. Biçim `0(541) 922 23 88` oldu.** Eskiden `0543 199 29 04` idi. Alan
kodu parantez içinde: 10 hanenin ilk üçü operatör kodudur ve gözle ilk
ayrılması gereken parçadır. Parantez **yalnız grup tamamlanınca**
kapanıyor — yazarken yarım parantez göstermek imlecin nereye gideceğini
belirsizleştirirdi.

**2. Fazla hane artık sessizce kesilmiyor.** `telefonHaneleri` 11. haneyi
`slice(0, 10)` ile atıyordu ve ekranda hiçbir şey değişmiyordu. Kullanıcı
numarayı doğru sandığı hâlde son hanesi düşmüş oluyordu; yapıştırmada
daha sinsi — 11 haneli yanlış bir numara, 10 haneli **başka bir
numaraya** dönüşüp kaydedilebiliyordu.

Kırpma davranışı korundu (kutuya fazlası yazılamaz) ama artık
`telefonTasti()` ile **sorulabiliyor** ve hata gösteriliyor. Taşma
denetimi **önce** geliyor: numara 10 haneye kırpıldığı için öteki
denetimlerin hepsi "geçerli" görünüyordu.

Ülke kodu ekleri (`+90`, `0090`, `90`, baştaki `0`) taşma **sayılmıyor**.

`maxLength` 16 değil **18**: tam numara 16 karakter ve sınırı orada
bırakırsak tarayıcı 17. karakteri sessizce yutar — yani sessiz kesmeyi
`maxLength` üzerinden geri getirmiş olurduk.

**3. Kayıt sayfasındaki ham kullanım düzeltildi.** `onChange` içinde
`telefonGiris` çağrılıyordu; o çağrı fazla haneyi kesiyor ve taşma hiç
görülmüyordu. Artık ham değer saklanıp biçimli gösteriliyor.

### Yurt dışı numarası — değerlendirme

**Bugün desteklenmiyor ve bu turda değiştirmedim.** Gerekçe:

- 3057 kaydın **tamamı** `+90`; ürün Türkiye apartman yönetimi.
- Backend `normalize_phone` **zaten** E.164 `+<8-15 hane>` kabul ediyor,
  yani veri modeli yurt dışına kapalı değil. Kapalı olan şey **giriş
  maskesi**.
- Maskeyi çok-ülkeli yapmak, ülke seçici + ülkeye göre uzunluk tablosu +
  operatör ön ek kuralları demek. Bunu ölçülmemiş bir ihtiyaç için
  yapmak, her numara girişini karmaşıklaştırırdı.

**Önerim:** yurt dışında oturan bir sakin çıktığında, `+` ile başlayan
girdide maskeyi devre dışı bırakıp doğrudan E.164 doğrulaması yapan bir
kaçış yolu eklenebilir — backend değişikliği gerekmez. Bunu şimdi
yapmadım çünkü henüz tek bir örneği bile yok.

### Tarandı: telefonun girildiği tüm yerler

| Yer | Durum |
|---|---|
| `TelefonAlani` bileşeni (kullanıcılar, profil, tanımlar, tesisler, tesis detay, dış hizmetler) | ortak bileşen — düzeltme hepsine geldi |
| Kayıt sayfası (`/kayit`) | ham kullanım — **düzeltildi** |
| Giriş formu | tek alan (e-posta **veya** telefon); maske uygulanmaz, bilinçli — kullanıcı e-posta da yazabilir |
| Mobil `telefon_alani.dart` + 6 alan | ikiz güncellendi (`telefon_alani_kapsam_test.dart` her alanın paylaşılan biçimlendiriciyi kullandığını zorluyor) |
| `TanitimForm` (tanıtım sitesi) | `maxLength={40}` düz input — pazarlama formu, hesap açmıyor; kapsam dışı bırakıldı |

### Ölçüm

Panel 19 test, mobil 37 test yeşil; iki kırma testi (taşma denetimini
kaldır, eski biçime dön) ikisini de yakaladı.

**Test verimde bir hata yaptım ve test yakaladı:** `05431992904`'ü taşma
sandım. Baştaki `0` ulusal haneye dahil değil — o numara **geçerli**.
Gerçek taşma 11 ulusal hane (`054319929041`).
