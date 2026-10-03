# P253 — Mobil tam eşitlik (Aşama 0) ve şikâyet gizliliği: kararlar

Plan: `docs/P253-mobil-esitlik-plani.md` (onaylandı 2026-10-03). Bu tur:
Aşama 0 (§B), şikâyet gizliliği (§D), saat dilimi (§E). Aşama 1 kullanıcının
"devam"ıyla başlar.

## §A — Plan kararları (planın §5'i, onaylandı)

| # | Karar | Ne zaman |
|---|---|---|
| 1 | Denetçi mobilde **salt okuma** | Aşama 2 |
| 2 | Platform admin mobil menüsü kapsam dışı | — |
| 3 | Demirbaş: ayrı **Envanter** (yönetici) / **Zimmet** (saha) sekmeleri; aynı ekranda karışmaz | Aşama 3 |
| 4 | 3D sahne ve site planı mobile gelmez; tabloda `yapisal` | — |
| 5 | Tablo araçları (sütun gizleme, sayfa boyu): kart + sırala/süz yeterli; `yapisal` | — |
| 6 | Paylaşım hedefi Android Aşama 3, iOS share extension ayrı tur. iOS'ta Dosyalar'dan seçim share extension'sız da mümkün; içe aktarım onunla yapılır | Aşama 3 |
| 7 | Web mesaj gönderim kusuru | Aşama 0 (§B) |
| 8 | Harita karo kaynağı web ve mobil için **birlikte** değerlendirilir. OSM'nin karo politikası yoğun/ticari kullanımı yasaklar. Seçenekler: MapTiler, Stadia, kendi karo sunucusu (maliyet, lisans, boyut). Öneri Aşama 2 başında; **onaysız bağımlılık eklenmez** | Aşama 2 başı |

## §C — Finans işlemleri kuralı (Aşama 1–2'de uygulanacak)

Telefonda yanlış dokunma kolay, finans hatası pahalı. Mobilde şu işlemlerin
hepsi bu kurala uyar:

* onayla / reddet;
* iptal (ters kayıt);
* toplu tahakkuk;
* virman;
* iade;
* toplu tahsilat.

1. **Onay diyaloğu:** her biri ayrı bir onay adımından geçer. Diyalogda
   **tutar** ve **hedef** açıkça yazılı. Örnek: "A-12 · Ahmet YILMAZ ·
   1.250,00 ₺ tahsilatını iptal et". Genel "Emin misiniz?" yasak.
2. **Sebep zorunlu:** iptal, ters kayıt ve redde. Boş sebeple düğme
   etkin olmaz; sunucu da reddeder (web'le aynı uç ve kural).
3. **Sunucu kuralları aynen geçer:** mobil için ayrı uç ya da gevşetilmiş
   doğrulama yazılmaz. Web'le aynı uç çağrılır.
4. **Geri al:** mümkün olan yerde işlemden sonra "Geri al" görünür. Toplu
   tahakkukta ters kayıt partisi, virmanda ters virman. Geri alınamayan
   işlemde (örneğin onaylanmış ve kasaya girmiş tahsilat iadesi) bu durum
   onay diyaloğunda **önceden** söylenir.
5. **Denetim kaydında yüzey:** her finans eyleminin denetim kaydına
   `yuzey: "web" | "mobil"` yazılır.
   * Kaynak: istek başlığı `X-Istemci-Yuzey`. Mobil Dio istemcisi
     ekler, web BFF ekler.
   * Başlıksız istek `bilinmiyor` olarak yazılır.
   * Aşama 1'in ilk işi; ortak `audit_user` yardımcısında tek yerden.

## §B — Aşama 0

### Web toplu mesaj gönderimi

**Ölçüm: web'den toplu mesaj hiç gönderilemiyordu.** Üç kusur üst üste
biniyordu:

1. "Gönderim" sekmesinde **gönder düğmesi yoktu**. `mesaj-gonder` BFF beyaz
   listesinde duruyordu ama hiçbir ekran çağırmıyordu.
2. Sekmedeki **önizleme de çalışmıyordu**.
   * Web sunucuya yalnız `sablon_id` gönderiyordu; sunucu `govde`
     istediği için **her önizleme 422 dönüyordu**.
   * Yanıt biçimi de uyuşmuyordu: web sayacı üst düzeyde, sunucu `sms`
     altında veriyor.
   * DOM testi sahte yanıtla geçtiği için kimse görmedi.
3. Sunucuda sağlayıcı **yapılandırılmamışken** dönen `yapilandirilmadi`
   sonucu **"gönderildi" sayacına** ekleniyordu. API'den gönderen, gitmeyen
   mesajı gitti sanırdı. Kayıt satırı doğru yazılıyordu, sayaç yanlıştı.

**Düzeltme:**

* **Yeni uç `POST /mesajlar/alicilar`:** gönderim **öncesi** özet; hiçbir
  şey göndermez. Döndürdükleri: toplam, gönderilecek, rıza yok, adres yok,
  kanal hazır mı, kalan kota.
  * Gönderimle **aynı** sınıflandırma (`_hedefler`): onay ekranındaki sayı
    gerçek olmalı.
* **Web akışı:** şablon → kime (tüm sakinler / blok / borçlular / rol) →
  önizle → "Gönder…" → **onay penceresi**.
  * Pencere: "247 kişiye E-posta gidecek. Onaylıyor musunuz?", atlananlar,
    önizleme.
  * Kanal hazır değilse ya da kota aşılıyorsa onay düğmesi kapalı.
  * Gönderince sonuç: gönderildi / kuyrukta (yeniden denenecek) /
    gönderilemedi (kanal yapılandırılmamış) / rıza yok / adres yok.
* **Sonuç sayaçları:** `kuyrukta` ve `gonderilemedi` ayrıldı. `basarisiz`
  geriye uyumluluk için ikisinin toplamı.
* **Kota** artık **gönderilecek** sayısıyla ölçülür: rızası ya da adresi
  olmayanlar kotadan yemez.

**"Gönderdim sanılıp gitmeyen gönderim olmuş mu?"**

* **Web'den:** hayır. Web'de gönder düğmesi yoktu, önizleme de hata
  veriyordu; kullanıcı "gönderildi" diyen bir ekran görmedi. Ama beklenen
  duyuruların **hiç gitmemiş** olması mümkün.
* **API'den:** olmuş olabilir. Kanal yapılandırılmamış bir tesiste gönderen
  "gönderildi: N" görüyordu.
* Geliştirme veritabanında elle gönderimlerin 765 satırı `yapilandirilmadi`,
  1'i gerçekten gönderilmiş; bunlar test koşularından.
* **Prod ölçümü kullanıcıda:** `docs/P253-mesaj-olcumu.sql` (salt okuma;
  kişi ya da adres seçmez).

**Kilit:**

* `tests/p253-mesaj-gonderim.dom.test.ts`: onay ekranı, aynı süzgeç, sonuç
  sayıları, kanal yok ya da kota aşılıyorsa düğme kapalı.
* Eski `mesaj.dom.test.ts` artık **gerçek sunucu biçimiyle** sahteliyor ve
  önizleme isteğinin `govde` taşıdığını doğruluyor.
* Backend `test_p253_mesaj_gonderim.py`: özet hiçbir şey göndermez ve
  gönderimle aynı sayıyı verir; kanal yoksa `gonderildi == 0`.
* "Gönderildi" bekleyen iki eski test kusurun kendisine dayanıyordu;
  kapsama ölçecek biçimde düzeltildi.

## §E — "Şimdi çalıştır" saat dilimi

### Ölçüm

* Uygulama saati UTC. Tesis tablosunda `timezone` alanı var (varsayılan
  `Europe/Istanbul`) ama **hiçbir "bugün" hesabı onu okumuyordu**.
* İstek yolunda 17 yerde UTC "bugün" vardı.
  * **Elle tetiklenenler:**
    * maaş "Şimdi çalıştır";
    * gecikme faizi önizle ve işle;
    * aidat planı önizlemesi;
    * hatırlatma önizlemesi.
  * **İstek yolundakiler:**
    * finans özeti (ay başı);
    * tahsilat göstergesi (bu ay);
    * aidat gecikme gösterimi;
    * bakım durumu (bugün / gecikti);
    * maaş kartının ilk dönemi (gece yarısından sonra girilen maaş);
    * personel detayı (bu ay);
    * mesaj şablonundaki `{tarih}`;
    * rapor varsayılan tarihleri.
  * **Defter ve gecikme varsayılanları;** günlük görev ise tek UTC günüyle
    bütün tesisleri koşuyordu.
* **Etki:** İstanbul'da 00:00–03:00 arası elle tetiklenen işler bir önceki
  günü görüyordu. Ayın 1'i gecesi maaş **önceki ayı** hesaplardı.

### Düzeltme

* Yeni `app/tesis_saati.py`:
  * `yerel_bugun(saat_dilimi, simdi)`: saf işlev;
  * `tesis_bugun(db)`: oturumun tesisinden okur (RLS).
* Gecersiz saat dilimi finans işlemini düşürmez; varsayılan bölge kullanılır.
* Yukarıdaki her yer `tesis_bugun(db)` kullanır.
* Günlük görev, gün verilmediyse **her tesis için kendi gününü** hesaplar.
* **Bilinçli istisna (2):** tahsilat tarihinin ve devriye ek tarihinin
  "ileri/geçmiş" doğrulaması UTC'ye **bir gün pay** tanıyor. Tesis günü
  UTC'den en fazla bir gün farklı olabilir; pay bunu zaten karşılıyor.

### Kilit

`tests/test_p253_saat_dilimi.py`:

* **Ay sınırı:** 31 Ekim 22:30 UTC, İstanbul'da 1 Kasım 01:30 eder; maaş
  dönemi Kasım olmalı.
* **Yıl sınırı ve geçersiz saat dilimi.**
* **Kaynak taraması:** istek yolunda UTC "bugün" yasak; yalnız gerekçeli
  istisnalar geçer. Kırılarak doğrulandı: bir yönlendiriciye `date.today()`
  eklenince test düşüyor.

### Aynı hatanın başka yerleri (tarandı)

* **SMS/e-posta günlük kotası:** gün sınırı UTC'ydi ve kodda "bilinen sınır"
  diye yazılıydı. Artık tesisin gün başı (`tesis_gun_basi`): İstanbul'da
  00:00–03:00 arası gönderimler dünün kotasına yazılmıyor.
* Diğer elle tetiklenen uçlar yukarıdaki listede.
