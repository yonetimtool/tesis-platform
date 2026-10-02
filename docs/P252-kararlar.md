# P252 — Personel takibi: eklerken maaş, otomatik maaş gideri

## Ölçüm (başlangıç durumu)

* **Maaş kartı** (`personel_kayit`) hesaptan (`app_user`) ayrı. P251'de
  isteğe bağlı bağ (`app_user_id`) web formuna eklendi.
  * Var: giriş/çıkış tarihi, görev, aylık maaş, saatlik ücret.
  * Yok: **ödeme günü**, **kasa**, **IBAN**, **not**.
* **Kişiler › Personel › Ekle** yalnız hesabı açıyor; maaş ayrıca Finans ›
  Maaş kartları'ndan giriliyor. Aynı kişi iki ekranda iki kez işleniyor.
* **Otomasyon altyapısı** (P192/P250, `app/otomasyon.py`, günlük beat):
  * idempotency damga + defter anahtarıyla;
  * `otomasyon_gunlugu` + "son çalışma";
  * yönetime push + uygulama içi bildirim.
* **Düzenli gider** maaşı da karşılayabiliyordu ("kapıcı maaşı" örneği)
  ama kişiye bağlı değil: kısmi ay, işten çıkış ve kişi bazında ödeme
  geçmişi yok.
* **Tek defter** `finansal_hareket`:
  * benzersizlik `(tenant_id, idempotency_key, idem_satir)` (göç 0028);
  * kişi bağı yalnız `user_id` (hesap); hesapsız personelin gideri kişiye bağlanamıyor.
* **Fazla mesai** (P203/P214): kişi × hafta hesabı, ayrı "gidere yaz"
  akışı; gider `user_id` ile kişiye bağlı, onay bekleyen.
* **Şeffaflık** gideri kalem adına göre topluyor (`defter.kategori_kirilimi`);
  açıklama göstermiyor. Kişi adı açıklamada kalırsa şeffaflığa sızmaz.

## Kararlar

### §1 — Tek form, tek kaynak

* **Personel ekleme formuna "Çalışma bilgileri" bölümü** (web + mobil):
  * işe giriş tarihi;
  * görev: hesabın rolü (güvenlik / tesis görevlisi / amir), ayrıca serbest görev metni ("temizlik" gibi);
  * aylık ücret (net, ₺);
  * ödeme günü;
  * kasa;
  * isteğe bağlı IBAN ve not.
* **Atomik kayıt:** `POST /users` isteğe bağlı bir `calisma` nesnesi alır.
  Hesap ve maaş kartı **aynı işlemde** oluşur ve birbirine bağlanır;
  biri düşerse ikisi de yazılmaz. Ücret girilmezse yalnız hesap açılır
  (sözleşmeli / dış firma personeli).
* **Tek kaynak:** çalışma bilgileri maaş kartının kendisidir.
  Kişiler › Personel satırındaki "Çalışma bilgileri" ile Finans › Maaş
  kartları aynı satırı okur ve yazar.
* **Ödeme günü kuralı:** 1–31. Seçilen gün o ayda yoksa (31 ve 30 günlük
  ay, 29–31 ve Şubat) ödeme **ayın son günü** yapılır. Kural formda
  yazılı.
* **Hesaba tek kart:** P251'deki uygulama denetimi veritabanı kısıtına
  çevrilir (kısmi benzersiz indeks).
* **Yetki:**
  * Ücret, IBAN, kasa, ödeme günü ve ödeme geçmişi yalnız **admin/yönetici**
    uçlarında döner (`/personel-kayitlari`, kişi detayı).
  * Güvenlik amiri `/users` listesini görür (P231); bu yanıtta ücret alanı
    **hiç yoktur**. Amire kişi detayı ucu 403 döner.
  * Mobil personel formunda çalışma bilgileri bölümü amire çizilmez;
    sunucu da kabul etmez (`calisma` gönderen amir → 403).
* **Personel kendi ücretini görür mü? Evet, salt okunur.**
  * Profilde giriş tarihi, görev, aylık ücret, ödeme günü ve son ödemeleri
    görür (`GET /me/calisma`).
  * Gerekçe: KVKK md. 11, kişinin kendisi hakkındaki veriyi öğrenme
    hakkı. Gizlemek bir koruma sağlamaz; kişi ücretini zaten biliyor,
    yanlış girilmişse fark etmesi ise yönetimin yararına.
  * TC, IBAN ve kasa gösterilmez: yönetimin defter bilgisi; IBAN zaten
    kişinin kendisinden alınır.
  * Saha personelinin web yüzeyi yok (P129), bu yüzden yalnız mobilde.
    Web'in atlanmasının gerekçesi budur.

#### §1 uygulama notları

* **Web:**
  * Kişiler › Personel › Ekle formunda "Çalışma bilgileri" bölümü var
    (`components/kisiler/calisma-bilgileri.tsx`).
  * Satırdaki eski "Maaş kartı oluştur/aç" eylemi yerine "Çalışma
    bilgileri" penceresi geldi: bağlı kartı okur ve PATCH'ler; kart yoksa
    hesabın adı, e-postası ve telefonuyla bağlı kart açar.
  * Finans › Maaş kartları defterine ödeme günü, kasa, IBAN ve not eklendi.
    İki ekran aynı satırı yazar.
* **Mobil:**
  * Personel ekleme formunda aynı bölüm var, yalnız yönetime
    (`UserRole.maasGorebilir`).
  * Satır menüsünde "Çalışma bilgileri".
  * Profilde saha personeline "Çalışma bilgilerim" kartı (`GET /me/calisma`).
  * Amire ne bölüm ne eylem çizilir; `/personel-kayitlari` ve `/kasalar`
    hiç çağrılmaz (testle kilitli).
* **Ödeme geçmişi:**
  * Karta bağlı giderler ile P252 öncesinden kalan, hesaba bağlı mesai
    giderleri birlikte okunur.
  * Hesaba elle yazılmış başka bir gider (avans gibi) ödeme geçmişine
    girmez.
  * Tür sistem kodundan belirlenir; kişiye bağlı her satır "maaş" sayılmaz.
* **Test bulgusu:**
  * Form uzayınca kaydet düğmesi 800×600 test yüzeyinde pencerenin dışına
    düştü.
  * Mevcut "e-posta boşsa istek atılmaz" testi bu yüzden **yanlış nedenle**
    geçiyordu: düğmeye hiç dokunulamıyordu.
  * Personel formuna dokunan bütün testler artık önce odağı bırakıp
    pencerenin kendi kaydırma alanında düğmeyi görünür kılıyor
    (`test/helpers/form_kaydir.dart`).

### §2 — Otomatik maaş gideri

* **Altyapı:** P192/P250 otomasyonu (`maaslari_isle`, aynı günlük beat
  görevi). Ayrı zamanlayıcı yok.
* **Kural cümlesi:** otomasyon kuralları ekranında ödeme gününe göre
  gruplanır, örneğin "Her ayın 5'inde 3 personelin maaşını gidere yaz".
  Aktif/pasif yapılabilir.
* **Defter:** gider `finansal_hareket`e yazılır.
  * Kartın kasası seçilir, yoksa varsayılan kasa.
  * Kalem: "Personel maaşı" (sistem kodlu tanım, yoksa oluşturulur).
  * Açıklama: "Ahmet YILMAZ — Ekim 2026 maaşı".
  * Kişi bağı: yeni `personel_kayit_id` sütunu; hesap varsa `user_id` de dolar.
* **Onay — tesis ayarı, varsayılan "otomatik onaylı":**
  * Düzenli giderde varsayılan "onay bekler"di. Gerekçe, sistemin
    kimseye sormadan kasadan para çıkarmasıydı (P192).
  * Maaş farklı: tutarı, günü ve kasası yöneticinin personeli eklerken
    açıkça verdiği bir talimattır; ödeme yasal bir yükümlülüktür.
  * Onay bekleyen maaşlar birikirse kasa bakiyesi olduğundan fazla
    görünür; bu sahte bir güvendir.
  * Ayar kapatılırsa giderler "onay bekliyor" düşer ve yönetici tek
    tıkla toplu onaylar.
  * **İstisna — kısmi ay:** tutarı oranla hesaplanan gider ayardan
    bağımsız olarak her zaman **onay bekleyen** düşer. Hesaplanmış bir
    tutarın gözden geçirilmeden kasadan çıkması istenmez.
* **İki kez yazılmaz:**
  * Anahtar `maas:<kart>:<YYYY-MM>`, defterin benzersizlik kısıtı.
  * Beat iki kez çalışsa da, elle tetiklense de ikinci yazım kısıtta düşer.
  * Kartın `son_maas_donem` damgası ilerler.
* **Telafi:** görev kaçırılan ayları sırayla yazar. İlk dönem, maaşın
  tanımlandığı andan sonraki ilk ödeme tarihidir. Geçmişe dönük yazmaz:
  maaşı bugün girilen beş yıllık personel için 60 aylık gider oluşmaz.
* **Bildirim:** tur başına bir özet, örneğin "Ekim 2026 maaşları gidere
  yazıldı: 4 personel, toplam 92.000 ₺". Push ve uygulama içi; yeni tip
  `maas_yazildi` (göç).
* **Kısmi ay — gün oranı (takvim günü):**
  * İşe giriş ayında: giriş gününden ay sonuna; çıkış ayında: ay başından
    çıkış gününe.
  * Tutar = aylık ücret × çalışılan gün / ayın gün sayısı, kuruşa yuvarlanır.
  * Tam ay vermek, 28'inde başlayana bir aylık ücret ödemekti.
  * Yönetici onay bekleyen gideri onaylamadan önce düzeltebilir.
* **İşten ayrılış:** çıkış tarihi girilince çıkış ayı oranlı yazılır;
  sonraki aylarda gider oluşmaz.
* **Fazla mesai — ayrı kalem.**
  * Mesai haftalık ve kişi × hafta hesaplanır; maaş aylık ve sabittir.
  * Tek gidere katmak, raporda "maaş neden bu ay farklı" sorusunu cevapsız
    bırakırdı. Mesai onaylanmadan maaşı bekletmek de maaşı geciktirirdi.
  * Mesai ekranının "gidere yaz"ı aynen kalır; kalemi "Fazla mesai"
    (sistem kodlu tanım) olur ve kişiye bağlanır.
  * Personel detayında maaş ile mesai aynı ödeme geçmişinde görünür.

#### §2 uygulama notları

* **Kural satırı** (web Finans › Otomasyon, mobil Otomasyon kuralları):
  * ödeme günü başına cümle; aç/kapat;
  * "Maaş giderleri onaylı yazılsın" ayarı;
  * "Şimdi çalıştır": günlük görevle aynı işlev. İkinci basışta "yazılacak
    maaş yok" der, hata vermez.
  * son çalışma cümlesi.
* **Onay bekleyen maaşlar:**
  * Satır başına tutar düzeltilerek onay. `POST /finans/hareketler/{id}/onayla`
    yeni `tutar_kurus` alır; denetim kaydında eski tutar kalır. Onaylanmış
    satır değiştirilemez (409).
  * Toplu onay: `POST /otomasyon/maaslar/onayla`. Yalnız `maas:` anahtarlı
    ve hâlâ bekleyen satırlar onaylanır; ikinci onay 0 döner.
* **Yetki:** maaş ayarı ucu yönetim dışına 403 verir. Mobilde 403 alınırsa
  satır hiç çizilmez; hata gösterilmez, çünkü hata görülmemesi gereken bir
  kuralın varlığını ilan eder.
* **Fazla mesai:** "gidere yaz" artık sistem kodlu "Fazla mesai" kalemine
  yazar ve gideri kişinin maaş kartına bağlar.
* **Yakalanan hata:** yanıt şemasındaki otomasyon türü listesinde `maas`
  yoktu. Maaş günlüğü yazıldıktan sonra `/otomasyon-gunlugu` 500 verirdi.
  Test ile kilitlendi.
* **Bildirim:** `maas_yazildi` web'de `/finans/giderler`e, mobilde Gider
  ekranına gider.

### §3 — Detay, kasa, finans özeti, şeffaflık

* **Personel detayı** (web `/kisiler/personel/<id>`, mobil Kişiler ›
  Personel › kişi):
  * çalışma bilgileri;
  * ödeme geçmişi (dönem, tutar, kasa, maaş / mesai, durum);
  * bu ay vardiya sayısı ve saati, devriye tur sayısı;
  * bu yıl toplam ödenen.
* **Kasa / finans hareketleri:** maaş giderinin kalemi "Personel maaşı",
  açıklamasında kişi adı. Satırdaki kişi adı detaya bağlanır.
* **Finans özeti:** bu ayın "Personel giderleri" toplamı (maaş + mesai) ayrı satır.
* **Raporlar:** kalem süzgeci zaten var ("Personel maaşı" ve "Fazla
  mesai" tanım olarak seçilebilir); ayrıca kişi süzgeci eklendi.
* **Şeffaflık (sakinlerin gördüğü):** sistem kodlu iki kalem tek satırda
  birleşir: **"Personel giderleri"**. Kişi bazında maaş yayınlanmaz (KVKK).
  Kalem adı yönetici tarafından değiştirilse bile birleştirme sistem
  koduna göre yapılır.

### §4 — Açık işler

`docs/acik-is-exhaustive-deps-uyarilari.md` ve
`docs/acik-is-rapor-kuyruk-kilitlenmesi.md`: ölçüm ve sonuç §4 bölümünde.
