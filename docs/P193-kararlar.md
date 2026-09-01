# P193 — Kurulum akışı boşlukları · kararlar ve gerekçeler

Bu tur, `docs/yonetici-kurulum-rehberi.md` sonundaki
**"C) Kurulum sırasında olması gereken ama olmayan şeyler"** listesindeki
14 maddeyi kapatıyor. Her bölümün sonunda **NE ÖLÇTÜM** başlığı var:
yalnız "test yeşil" değil, geliştirme ortamında akışı çalıştırıp ne
gördüğüm yazılı. Ölçemediklerim ayrı listeleniyor.

---

## Bölüm 1 — Excel/toplu aktarımda e-posta (14 eksik · madde 4)

### Sorun
Tek tek kullanıcı eklemede e-posta **zorunlu**, Excel aktarımında
**opsiyoneldi**. Aynı ürünün iki kapısı iki farklı kural uyguluyordu.
Sonuç: 120 kişilik bir dosyayı e-postasız aktaran yönetici, 120 kişilik
bir "hayalet" kadro yaratıyordu — hesaplar açık ama kimse giremiyor,
çünkü SMS varsayılan olarak kapalı, yani davet gidecek tek kanal e-posta.
Hiçbir ekran bunu söylemiyordu.

### Kararlar

**K1.1 — `kisi` türünde e-posta zorunlu alan oldu.**
`ice_aktarim.py` içindeki alan tanımı `zorunlu=True` yapıldı; boş satır
`zorunlu_alan_eksik` ile raporlanıyor. Zorunluluk tek yerde tanımlı
olduğu için hem sunucu doğrulaması hem panelin "Zorunlu sütunlar"
bilgisi hem de şablon aynı listeden besleniyor — ikisi ayrışamaz.

**K1.2 — Varsayılan davranış: "sorunlu satır varsa hiçbir şey yazma".**
İstek gövdesine `sorunlulari_atla` eklendi, **varsayılanı `false`**.
Aktarım artık iki geçişli: önce kuru geçiş, hata varsa `uygulanmadi=true`
ile rapor dönülür ve **tek satır yazılmaz**; kullanıcı kutucuğu bilerek
işaretlerse ikinci geçiş uygulanır.

*Neden SAVEPOINT/rollback değil:* satır uygulanırken davet e-postası
gönderiliyor. Veritabanını geri alabilirim, gönderilmiş e-postayı
alamam. "Yarısı davet aldı, kayıt yok" hali, hiç yazmamaktan daha kötü.
Bu yüzden kuru geçiş ayrı bir tam tur olarak koşuyor.

**K1.3 — Davet gerçekten gitti mi, sayılıyor.**
`davet_gonderildi` / `davet_basarisiz` / `davet_hatalari[]` sonuca
eklendi ve denetim kaydına (audit meta) yazılıyor. "Kaç kişi eklendi"
ile "kaç kişiye ulaşıldı" ayrı sorulardır; eskiden ikincisi hiç
sorulmuyordu. Panelde başarısız davetler satır numarasıyla ve
"bu kişiler giriş yapamaz" uyarısıyla gösteriliyor.

**K1.4 — Panelde önizleme bloklayıcı.**
Sorunlu satır varken **Aktar düğmesi kapalı**; yanında nedeni ve
"Sorunlu satırları atla" kutucuğu var. Çalışmayacak bir düğmeyi basılır
bırakmak kullanıcıya "sistem bozuk" hissi verir.

**K1.5 — Sayılar etiketlendi.** Okunan / Geçerli / Zaten kayıtlı /
Sorunlu ayrı ayrı yazılıyor (7 dilde). "4 satır işlendi" cümlesi
yöneticiye hiçbir şey söylemiyordu.

### NE ÖLÇTÜM

Geliştirme ortamında, `acme-plaza` tesisinde `yonetici@acme.com` ile
giriş yapıp **gerçek uca** (`POST /import/kisi`) 4 satırlık bir dosya
gönderdim: 2 satır sağlam, 1 satır e-postasız, 1 satır bozuk e-postalı.
Gördüğüm:

```
KISI ALANLARI:  ad -> ZORUNLU / telefon -> ZORUNLU / eposta -> ZORUNLU
                daire_no -> opsiyonel / rol_tipi -> opsiyonel

=== 1) ÖNİZLEME (yalniz_dogrula=true) ===
  HTTP 201 · okunan=4  gecerli=2  atlanan=0  sorunlu=2
   SATIR 3 · eposta -> Zorunlu alan boş.
   SATIR 4 · eposta -> Geçerli bir e-posta adresi girin.

=== 2) AKTAR (sorunlulari_atla YOK) ===
  HTTP 201 · uygulanmadi = True · aktarim_id = None
  → HİÇBİR SATIR YAZILMADI (veritabanında kontrol edildi)

=== 3) AKTAR (sorunlulari_atla=true) ===
  HTTP 201 · uygulanmadi = False
  olusan=2  sorunlu=2  davet_gonderildi=0  davet_basarisiz=2
   DAVET SATIR 2 -> Davet e-postası gönderilemedi...
   DAVET SATIR 5 -> Davet e-postası gönderilemedi...
```

Son satır beklenmedik ama **doğru** bir bulgu: geliştirme ortamında
SMTP yok, dolayısıyla davetlerin hiçbiri gitmiyor. Eskiden bu tamamen
görünmezdi — aktarım "2 kişi eklendi" der, kimse giremezdi. Artık
yönetici bunu ekranda görüyor. Prod'da SMTP çalıştığı için orada
`davet_gonderildi=2` beklenir; **bu sayının prod'da doğrulanması
gerekir** (aşağıdaki "ölçemediklerim").

Ekran tarafı: `admin-web/tests/ice-aktarim.dom.test.ts` sayfayı gerçekten
render edip ölçüyor (8 test, hepsi geçiyor) — hem düşen hem geçen durum:
sorunlu satırda Aktar **kapalı** ve "Aktarım YAPILMADI" + satır numarası
görünüyor; kutucuk işaretlenince düğme **açılıyor** ve istek gövdesinde
`sorunlulari_atla: true` gidiyor; davet özeti ve uyarısı basılıyor.

Backend: `backend/tests/test_ice_aktarim.py` **18 test geçti**.

### Ölçemediklerim (prod'da/cihazda doğrulanmalı)
- Gerçek SMTP ile `davet_gonderildi` sayısının dolması ve e-postanın
  gelen kutusuna düşmesi.
- Gerçek bir `.xlsx` dosyasıyla tarayıcıdan yükleme (dosyayı panel
  ayrıştırıyor; testler yapıştırılan metinle ölçüyor — ayrıştırma yolu
  aynı, dosya okuma katmanı değil).
