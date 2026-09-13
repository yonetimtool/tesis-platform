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
