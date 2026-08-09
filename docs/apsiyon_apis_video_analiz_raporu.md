# Apsiyon Apsis -- Video Özellik Analizi ve Uygulama Gereksinim Raporu

## 1. Analiz kapsamı

-   Kaynak video: yaklaşık **9 dakika 41.6 saniye (581.6 sn)**.
-   Video boyunca web tabanlı **Apsiyon Apsis** yönetim arayüzünde
    menüler, liste ekranları, detay ekranları, formlar, açılır menüler,
    işlem menüleri, Excel dosyası ve ayarlar gösteriliyor.
-   Bu raporun amacı, videodaki UI davranışlarını ve görünen
    fonksiyonları yeni geliştirilecek uygulamanın gereksinimlerine
    dönüştürmektir.
-   "Görüldü" olarak yazılan özellikler doğrudan videodaki ekranlardan
    çıkarılmıştır.
-   "Doğrulama / kapsam dışı" bölümü ise videoda açılmayan fakat ürünün
    mevcut resmi kaynaklarında belirtilen özellikleri ayırır; bunlar
    videoda görülmüş gibi kabul edilmemelidir.

------------------------------------------------------------------------

# 2. Üst seviye uygulama yapısı

Sol menüde görülen ana navigasyon:

1.  Özet
2.  Kişiler
3.  Bağımsız Bölümler
4.  Firmalar
5.  Toplu Borçlandırma
6.  Banka Hareketleri
7.  Finansal İşlemler
    -   Borçlandırmalar
    -   Tahsilatlar
    -   Giderler
    -   Gelirler
    -   Hesaplar Arası Virman
    -   Ödeme İadesi
    -   Açılış Fişleri
8.  İcra Dosyaları
9.  Sayaç İşlemleri
10. İletişim

-   SMS Gönderimi
-   E-posta Gönderimi
-   İş Takibi
-   Karar Defteri
-   Doküman Yönetimi
-   Geri Bildirim

11. Tanımlar

-   Blok
-   Tipler / Gruplar
-   Kasa
-   Gelir / Gider
-   Personel
-   Araç
-   Sayaç

12. Raporlar
13. Web Sitesi
14. Ayarlar

Üst header'da: - Global arama alanı: "Kişi, bağımsız bölüm veya daha
fazlasını ara..." mantığında. - Bildirim ikonu. - Uygulama/menü grid
ikonu. - Kullanıcı/profil alanı. - "13 gün kaldı" şeklinde abonelik/süre
göstergesi. - Sağ alt tarafta turuncu yardım/destek balonu. - Bazı
ekranlarda sağ üstte Excel ile ilgili aktarım/indirme aksiyonları.

------------------------------------------------------------------------

# 3. Saniye bazlı video zaman çizelgesi

## 00:00 -- 00:08

### OBS / kayıt başlangıcı

Video önce OBS Studio kayıt ekranını gösteriyor. Sonrasında Chrome
içerisindeki Apsiyon Apsis uygulamasına geçiliyor.

## 00:09 -- 00:18

### Özet / Dashboard

Ana ekran açılıyor.

Görünen özet kartları: - Borçlandırma / aidat toplamları - Tahsil /
finansal durum göstergeleri - POS ile ilgili bölüm - Nakit kasa -
Borçlanan / alacaklı toplamları - Onay bekleyen hareketler - Ödenmiş
faturalar - Finansal durum göstergeleri - Sağ tarafta "Kasalar" alanı ve
toplam - Takvim / aylık görünüm

Takvim: - Ay/yıl seçimi - Önceki/sonraki ay - Günlük / haftalık / aylık
benzeri görünüm kontrolleri - "Ekle" ile etkinlik oluşturma

### Yeni Etkinlik formunda görülen alanlar

-   Tarih
-   Saat
-   Bitiş tarihi/saat bilgisi
-   Konu
-   Açıklama
-   İptal
-   Kaydet

Bu bölüm yeni uygulamada **dashboard + takvim + hızlı etkinlik
oluşturma** şeklinde tasarlanmalı.

------------------------------------------------------------------------

## 00:18 -- 00:27

### Web Sitesi

"Web Sitesi" ekranına geçiliyor.

Görülen yapı: - Siteleriniz listesi - "+ Yeni Site" - Site kartları -
Yönetici bilgileri - Kullanıcı/profil bilgileri - Siteye ait iletişim
bilgileri - Kampanya / ürün kartları - Apsiyon Mobile - Apsiyon
Kampanyaları - Apsiyon Kira - Apsiyon Sigorta - Yönetici tarafına
yönelik ek ürün/hizmet tanıtımları

Sağ tarafta: - Hesap bilgileriniz - Kullanıcı adı - Telefon - E-posta -
Profil ayarları / düzenleme - Çıkış

Yeni uygulamada bu alanın karşılığı: **Site/tenant yönetimi + site
portalı + kullanıcı hesabı + ürün/hizmet bağlantıları**.

------------------------------------------------------------------------

# 4. Kişiler

## Yaklaşık 00:27 -- 01:25

"Kişiler" listesi açılıyor.

Liste kolonları: - Ad Soyad - Blok - Bağımsız Bölüm - Durumu - E-Posta -
Telefon Numarası - Araç Plakası - Sonra Durumu - Adres - Bakiye -
İşlemler

Liste özellikleri: - Kolon bazlı sıralama - Filtreleme ikonları - Güncel
/ Hepsi şeklinde durum filtresi - Sayfalama - Kayıt sayısı - Satır
işlemleri

## Kişi Ekle

İlk form bölümünde: - T.C. Kimlik No / Vergi No / Pasaport No - Doğum
Tarihi - Telefon Numarası (Varsayılan) - Telefon Numarası (İkincil) -
E-Posta (Varsayılan) - E-Posta (İkincil)

Form aşağı doğru kaydırıldığında: - Adres - Araç Plakası - Meslek -
Öğrenim Durumu - Uyruk - Cinsiyet - Kadın - Erkek - Açılış Bakiye Girişi

Aksiyonlar: - İptal - Kaydet

Bu formdan çıkarılacak veri modeli: `Person` - identity_number -
tax_number - passport_number - birth_date - primary_phone -
secondary_phone - primary_email - secondary_email - address -
vehicle_plate - profession - education_status - nationality - gender -
opening_balance

------------------------------------------------------------------------

# 5. Excel ile veri aktarımı

## Yaklaşık 01:20 -- 01:30

Video Excel dosyasına geçiyor.

"Bağımsız Bölüm" isimli Excel tablosunda görülen kolonlar: - Blok Adı -
Kapı Numarası - Kat Maliki - Kat Maliki / ilgili kişi bilgisi - Bakiye -
Net Alan - Brüt Alan - Arsa Payı

Bu ekran çok önemli:

Yeni uygulamada Excel: - Import - Export - Şablon oluşturma - Kolon
eşleştirme - Hatalı satır raporlama - Toplu veri yükleme

mantığıyla ele alınmalı.

------------------------------------------------------------------------

# 6. Bağımsız Bölümler

## Yaklaşık 01:30 -- 02:20

Liste kolonları: - Blok Adı - Kapı Numarası - Kat Maliki - Kiracı -
Bakiye - Net Alan - Brüt Alan - Arsa Payı - İşlemler

Liste: - checkbox ile satır seçimi - sıralama - filtreleme - sayfalama -
satır bazlı üç nokta işlem menüsü

## Bağımsız bölüm detay ekranı

Detayda görülen bilgiler: - Bağımsız bölüm kodu - Bakiye - Kullanım
Durumu - Aidat Tutarı - Bulunduğu Kat - Tip - Brüt m² - Net m² - Arsa
Payı

Üst aksiyonlar: - Düzenle - Kredi Kartı ile Tahsilat - Borçlandır -
Tahsil Et

Sağ tarafta: - Notlar - Ekler

Notlar: - Mevcut notlar listesi - "+ Yeni Not"

Ekler: - Dosya yükleme - Dosya seçme

Kişiler bölümü: - "Kişi Ekle" - İlişki tipi: - Kat Maliki - Kiracı -
Daire Sakini

Bu ilişki modeli kritik: **Bir bağımsız bölüm ↔ birden fazla kişi ↔ kişi
rolü**.

Satır işlem menüsünde: - Borçlandır - Tahsil Et - Sil - E-Posta Gönder -
SMS Gönder

------------------------------------------------------------------------

# 7. Firmalar / Cari

## Yaklaşık 02:20 -- 02:35

"Firmalar" ekranı açılıyor.

Firma ekleme formunda görülen alanlar:

-   Firma Adı
-   Vergi No / T.C. Kimlik Numarası
-   Vergi Dairesi
-   İş Telefonu
-   Cep Telefonu
-   Faks
-   Hesap Adı
-   E-Posta
-   Adres
-   Yetkili Kişi
-   Açılış Tarihi
-   Açılış Bakiyesi
-   Borç / Alacak

Bu yapı bir **cari hesap** modülü olarak tasarlanmalı.

Firma için: - Cari bakiye - İşlem geçmişi - Gelir/gider bağlantısı -
Ödeme/tahsilat - Firma iletişim bilgileri - Yetkili kişi

desteklenmeli.

------------------------------------------------------------------------

# 8. Toplu Borçlandırma

## Yaklaşık 02:35 -- 02:50

"Toplu Borçlandır" ekranı:

-   Excel ile Toplu Borçlandırma aktarımı
-   "+ Yeni"
-   Liste
-   Sayfalama
-   Kayıt sayısı

Bu ekranın temel amacı: **çok sayıda bağımsız bölüme aynı veya
parametrik borçlandırmayı tek işlemde uygulamak.**

Excel aktarımı özel olarak önemli.

------------------------------------------------------------------------

# 9. Finansal İşlemler

## Yaklaşık 02:50 -- 04:30

Finansal İşlemler menüsü açıldığında aşağıdaki alt menüler görülüyor:

1.  Borçlandırmalar
2.  Tahsilatlar
3.  Giderler
4.  Gelirler
5.  Hesaplar Arası Virman
6.  Ödeme İadesi
7.  Açılış Fişleri

------------------------------------------------------------------------

## 9.1 Borçlandırmalar

Liste ekranı: - + Yeni - Liste - Sayfalama

Borçlandırma, kişi/bağımsız bölüm/cari hesap üzerine finansal yükümlülük
oluşturma işlemidir.

------------------------------------------------------------------------

## 9.2 Tahsilatlar

Ekranda: - + Yeni - + Toplu Tahsilat

Yeni Tahsilat Hareketi formu:

Her satırda: - Tarih - Kişi - Tutar - Kasa - Açıklama - Tahsilat
Yöntemi - Silme işlemi

Birden fazla satır eklenebiliyor.

Alt bölüm: - Toplam Kayıt - Toplam Tutar - "+ Yeni Satır"

Tahsilat yöntemleri seçilebilir.

Bu yapı: **multi-line transaction entry** olarak geliştirilmelidir.

------------------------------------------------------------------------

## 9.3 Giderler

Liste: - + Yeni - filtre: Tümü

Yeni Gider Hareketi formunda: - Hareket Tipi - Belge No - Tarih -
Firma - Gider Türü - Durumu - Kasa - Tutar - Açıklama - Sil

Gider Türü dropdown'ında videoda görülen örnekler: - Aidat - Elektrik -
Su - Kırtasiye - Doğal Gaz

Birden fazla gider satırı eklenebiliyor.

------------------------------------------------------------------------

## 9.4 Gelirler

Yeni Gelir Hareketi formu: - Hareket Tipi - Belge No - Tarih - Firma -
Gelir Türü - Durumu - Kasa - Tutar - Açıklama - Sil

Örnek hareket tipi seçeneklerinde: - Gelir Faturası - Tahsilat - Kasa
vb. finansal işlem tipleri görülüyor.

Birden fazla satır eklenebiliyor.

------------------------------------------------------------------------

## 9.5 Hesaplar Arası Virman

"Virman" ekranında "Hesaplar Arası Virman Ekle" formu:

-   Tarih
-   Açıklama
-   Tutar
-   Borçlandırılacak Hesap Tipi
-   Alacaklandırılacak Hesap Tipi
-   İptal
-   Kaydet

Amaç: **bir finansal hesaptan diğerine tutar aktarmak /
mahsuplaştırmak.**

------------------------------------------------------------------------

## 9.6 Ödeme İadesi

"Ödeme İadesi Ekle" formu:

-   Tarih
-   Kişi
-   Bağımsız Bölüm
-   Borçlandırma Tipi

Borçlandırma türü dropdown'ında videoda: - Seçiniz - Aidat - Elektrik -
Su - Kırtasiye - Doğal Gaz

gibi seçenekler görülüyor.

Amaç: **daha önce alınmış ödemenin kişiye/bağımsız bölüme geri
verilmesi.**

------------------------------------------------------------------------

## 9.7 Açılış Fişleri

"Açılış Fişi Ekle":

-   Tarih
-   Tip
-   Tutar
-   Borç / Alacak seçimi
-   İptal
-   Kaydet

Amaç: **sisteme başlangıç bakiyelerini / açılış finansal kayıtlarını
girmek.**

------------------------------------------------------------------------

# 10. İcra Dosyaları

## Yaklaşık 04:30 -- 04:40

"Yeni İcra Dosyası" formu:

-   Dosya No
-   Kişi
-   Tarih
-   Açıklama
-   Avukat
-   Dosya Durumu

Ekranda ayrıca: - Kişiye ait evrak bulunamadığında uyarı gösterimi

görülüyor.

Bu modül: - Borçlu kişiyle ilişkilendirilmeli - Bağımsız bölüm/cari
kayıtla ilişkilendirilebilmeli - Dosya durumu tutulmalı - Avukat bilgisi
tutulmalı - Evraklar eklenebilmeli.

------------------------------------------------------------------------

# 11. Sayaç İşlemleri

## Yaklaşık 04:40 -- 05:10

### Sayaç ile Borçlandırma sihirbazı

4 adımlı bir wizard görülüyor:

1.  Dağıtım Şekli
2.  Ana Sayaç
3.  Tüketim Değerleri
4.  Borçlandırma

### Dağıtım şekli seçenekleri

Videoda görülen seçenekler: - Fatura ile Tek Sayaç - Birim Fiyat ile Tek
Sayaç - Fatura ile Sıcak ve Soğuk Su - Fatura ile Isınma + Sıcak Su

Bu yapı uygulamanın en önemli workflow'larından biri.

------------------------------------------------------------------------

## Ana Sayaç

"Yeni Ana Sayaç" formu:

-   Adı
-   Tipi
-   Tesisat No
-   Birim / dağıtım yöntemi

Dağıtım yöntemi seçenekleri: - Seçiniz - Kullanım Oranına Göre -
Bağımsız Bölümlere Eşit - Arsa Payına Göre - Brüt m² - Net m² -
Dağıtılmayacak

Bu dağıtım motoru yeni uygulamada ayrı bir servis/domain olarak
tasarlanmalı.

------------------------------------------------------------------------

## Yeni Fatura

Sayaç borçlandırma akışında fatura ekleme formu:

-   Belge No
-   Tarih
-   Firma
-   Gider Türü
-   Kullanım Durumu
-   Tutar
-   Açıklama

Zorunlu alanlar doldurulmadığında üstte uyarı mesajı çıkıyor: "Lütfen
zorunlu alanları doldurunuz."

------------------------------------------------------------------------

## Sayaç işlemlerinin genel amacı

-   Ana sayaç tanımlama
-   Dağıtım yöntemi seçme
-   Fatura tanımlama
-   Tüketim değeri alma
-   Bağımsız bölümlere tüketim dağıtma
-   Dağıtım sonucunu borçlandırmaya dönüştürme

------------------------------------------------------------------------

# 12. İletişim

## Yaklaşık 05:10 -- 06:10

İletişim menüsü açılıyor.

Alt menüler:

-   SMS Gönderimi
-   E-posta Gönderimi
-   İş Takibi
-   Karar Defteri
-   Doküman Yönetimi
-   Geri Bildirim

------------------------------------------------------------------------

## 12.1 SMS Şablonları

Liste kolonları: - Şablon Adı - Gönderilecek Mesaj - Açıklama - İşlemler

Örnek şablonlar: - Bakiye Bildirimi - Borç Girişi - Davetiye - Tahsilat
Girişi - Toplantı Çağrı - Yeni Duyuru

Bu yapı: **template engine + değişken destekli mesaj oluşturma**
şeklinde ele alınmalı.

------------------------------------------------------------------------

## 12.2 E-posta Şablonları

Liste kolonları: - Şablon Adı - Gönderim Konusu - Açıklama

SMS tarafındaki örnek şablonlara benzer şablonlar bulunuyor: - Bakiye
Bildirimi - Borç Girişi - Davetiye - Tahsilat Girişi - Toplantı Çağrı -
Yeni Duyuru

------------------------------------------------------------------------

## 12.3 İş Takibi

"İş Takibi Ekle" formu:

-   Konu
-   Talep Eden
-   Talep Tipi
-   Öncelik
-   Atanan Personel
-   Durum
-   Açıklama
-   Dosya Seç

Videoda örnek: - Talep eden: Kerem Dermancı - Öncelik: Çok düşük -
Durum: Beklemede

Bu modül klasik ticket/task management yapısında tasarlanmalı.

Önerilen veri modeli: `Task` - subject - requester - request_type -
priority - assignee - status - description - attachment - created_at -
updated_at

------------------------------------------------------------------------

## 12.4 Karar Defteri

"Karar Ekle":

-   Konu
-   No
-   Tarih
-   Karar Metni
-   Başkan
-   Üye

Amaç: **site yönetimi toplantı kararlarının dijital kaydı.**

------------------------------------------------------------------------

## 12.5 Doküman Yönetimi

Liste: - Eklenme Tarihi - Doküman Adı - İşlemler

Aksiyon: - "+ Dosya Yükle"

Bu modül: - dosya yükleme - doküman adı - tarih - listeleme - işlem
menüsü

içermeli.

------------------------------------------------------------------------

## 12.6 Geri Bildirim

"Geri Bildirim" sayfasında şu an kayıt bulunmadığı görülüyor.

Bu modülün temel işlevi: - kullanıcı geri bildirimi toplama -
listeleme - takip

olarak düşünülmeli.

------------------------------------------------------------------------

# 13. Tanımlar

## Yaklaşık 06:10 -- 07:50

Tanımlar menüsü açılıyor.

Alt menüler: - Blok - Tipler / Gruplar - Kasa - Gelir / Gider -
Personel - Araç - Sayaç

------------------------------------------------------------------------

# 14. Bloklar

Liste kolonları: - Blok Adı - Daire Sayısı - Doluluk Oranı - İşlemler

Örnek: - A - B1 - B2 - B3 - B4 - B5 - C10 - C11

Blok düzenleme: - Blok Adı - Kaydet / İptal

Doluluk oranı sistem tarafından hesaplanıyor gibi görünüyor.

------------------------------------------------------------------------

# 15. Bağımsız Bölüm Grupları

"Bağımsız Bölüm Grupları" ekranında:

Örnek gruplar: - Daire - Villa - Dükkan

"Bağımsız Bölüm Grubu Ekle": - Bağımsız Bölüm Grubu - Aidat Tutarı

Bu yapı farklı bağımsız bölüm tiplerini sınıflandırmak için
kullanılıyor.

------------------------------------------------------------------------

# 16. Kasa

"Kasa" listesi:

Kolonlar: - Tip - Ad - Bakiye - Entegrasyon - Aktif - İşlemler

Örnek kasa: - Nakit

Durum göstergeleri: - Bakiye - Entegrasyon durumu - Aktif/pasif

Satır işlem menüsünde silme işlemi görülüyor.

------------------------------------------------------------------------

# 17. Gelir / Gider Tanımları

"Gelir/Gider Tanımı Ekle":

-   Adı
-   Tür
    -   Gelir/Gider
    -   Gider
    -   Gelir
-   Grup seç
-   Dağıtım Şekli
-   Açılış Tarihi
-   Açılış Bakiyesi
-   Borç / Alacak
-   Aktif

Bu ekran finansal kategori master-data yönetimidir.

------------------------------------------------------------------------

# 18. Personel

"Personel Ekle" formunda:

-   T.C. Kimlik No
-   Görevi
-   E-Posta (Varsayılan)
-   Telefon Numarası
-   Giriş Tarihi
-   Çıkış Tarihi
-   Maaş
-   Devamında aktiflik / çalışma durumuna ilişkin alanlar

Personel modülü: - çalışan kartı - işe giriş - işten çıkış - maaş -
iletişim - görev

bilgilerini tutmalı.

------------------------------------------------------------------------

# 19. Araç

"Araç Ekle":

-   Plaka
-   Kişi seçiniz
-   Daire seçiniz
-   Renk
-   Marka seçiniz
-   Model seçiniz
-   Aktif

Araç: **kişi + bağımsız bölüm ilişkili bir varlık** olarak modellenmeli.

------------------------------------------------------------------------

# 20. Sayaç Tanımı

"Yeni Ana Sayaç":

-   Ad
-   Tip
-   Tesisat No
-   Dağıtım yöntemi

Dağıtım seçenekleri: - Kullanım oranı - Bağımsız bölüm eşit - Arsa
payı - Brüt m² - Net m² - Dağıtılmayacak

Ayrıca "Bağımsız Bölüm Sayaçları" ekranı mevcut.

Bu ekran ana sayaç ile bağımsız bölüm sayaçlarının ayrıştırıldığını
gösteriyor.

------------------------------------------------------------------------

# 21. Ayarlar

## Yaklaşık 07:50 -- 09:40

Ayarlar ekranı ikon tabanlı bir yönetim paneli.

## Genel Ayarlar

Görünen seçenekler: - Yapı - Raporlar - Yetki - Destek Ekranı - Erişim
İzinleri - Excel ile Site Aktar

## Parametreler

-   Kasa
-   Borçlandırma
-   Sayaç
-   Kredi Kartı
-   Evrak Seri-Sıra No
-   Banka Ayarları
-   Para Birimi

## İletişim Ayarları

-   SMS
-   E-Posta

## İşlem Geçmişi

Ayarlar altında ayrıca işlem geçmişi bölümü olduğu görülüyor.

------------------------------------------------------------------------

# 22. Yapı Ayarları

"Yapı" modalında görülen alanlar:

-   Site Adı
-   Site Dili
-   Vergi Kimlik No
-   Toplam alan / yapı bilgileri
-   Telefon Numarası
-   E-Posta
-   Şehir
-   İlçe
-   Köy
-   Mahalle
-   Adres
-   UAVT
-   Blok
-   Cadde / Sokak
-   Bina Numarası
-   Kod

Bu yapı: **tenant/site master configuration** olarak ele alınmalı.

------------------------------------------------------------------------

# 23. Rapor Ayarları

Ayarlar içindeki "Raporlar" ekranında:

-   Dosya Seç
-   Rapor Adı
-   Rapor Alt Yazısı
-   Yeni Rapor Alt Yazısı Ekle

Bu bölüm özel rapor şablonlarının sisteme tanımlanmasına yönelik.

------------------------------------------------------------------------

# 24. Yetki

"Yetkili Kişiler" bölümü:

-   Yetkili kişi
-   Yetki türü
-   Yönetim yetkisi vb.
-   Bağlantı / davet işlemleri

Ayrıca "Yetki" matrisi bulunuyor.

Matriste çok sayıda modül/sütun için: - Denetim Yetkisi - Yönetim
Yetkisi

satırları ve aktif/pasif yetki göstergeleri var.

Bu nedenle RBAC sistemi gerekli.

Önerilen yapı:

`Role` - id - name

`Permission` - id - module - action

`RolePermission` - role_id - permission_id

`UserRole` - user_id - role_id

------------------------------------------------------------------------

# 25. Erişim İzinleri

Modalda görülen seçenekler checkbox mantığında:

-   Mobil uygulamada site finansal durumu göster
-   Mobil uygulama ve web sitesinde talepleri göster
-   Mobil uygulama ve web sitesinde kişi bütçesini göster
-   Mobil uygulamada gecikme / rapor bilgisini göster

Bu bölüm: **mobil/web kullanıcı görünürlüğü ve finansal veri gizlilik
izinleri** olarak tasarlanmalı.

------------------------------------------------------------------------

# 26. Evrak Seri-Sıra No

Bu ayar ekranında finansal belgeler için seri/sıra numarası yönetimi
bulunuyor.

Bölümler: - Borçlandırma ve Tahsilat - Gider Hareketleri - Gelir
Hareketleri - Hesaplar Arası Virman

Her belge tipinin kendi seri/sıra numarası tutuluyor.

Bu özellik finansal kayıtların benzersiz belge numarası üretmesi için
kullanılmalı.

------------------------------------------------------------------------

# 27. Borçlandırma Ayarları

"Borçlandırma" ayarlarında görülenler:

-   Borçlandırma şekli
-   Bağımsız bölümlere eşit gibi dağıtım yaklaşımı
-   Adet / Tutar
-   Dağıtım yapılacak toplam tutar
-   Son borçlandırma günü
-   Tazminat / gecikme ile ilgili seçenekler
-   Gecikme tazminatı uygula
-   Ek finansal parametreler

Bu ekranın temel amacı: **otomatik borçlandırma kuralları + gecikme
politikası + dağıtım parametreleri**.

------------------------------------------------------------------------

# 28. Excel ile Site Aktar

Ayarlar ekranında "Excel ile Site Aktar" fonksiyonu bulunuyor.

Bu özellik yeni sistemde: - Excel template - import validation -
preview - column mapping - transaction import - error report - rollback

ile geliştirilirse güçlü olur.

------------------------------------------------------------------------

# 29. UI / UX davranışları

Videodan çıkarılan ortak UI davranışları:

### Liste ekranları

-   Başlık
-   -   Yeni butonu
-   Checkbox
-   Kolon sıralama
-   Kolon filtreleme
-   Üç nokta işlem menüsü
-   Sayfa başına kayıt sayısı
-   Toplam kayıt
-   Önceki/sonraki sayfa
-   Boş veri durumunda "Kayıt Bulunmuyor"

### Formlar

-   Modal / drawer tarzı açılır formlar
-   Zorunlu alanlar
-   Dropdown
-   Radio button
-   Checkbox
-   Tarih seçici
-   Tutar alanı
-   Açıklama alanı
-   Dosya yükleme
-   İptal / Kaydet
-   Validation mesajları

### Finansal formlar

-   Çoklu satır ekleme
-   Satır silme
-   Toplam kayıt
-   Toplam tutar
-   Kasa seçimi
-   İşlem türü
-   Borç/Alacak

### Detay sayfaları

-   Özet bilgi kartları
-   Üst aksiyon butonları
-   Notlar
-   Ekler
-   İlişkili kişiler
-   İşlem geçmişi mantığı

------------------------------------------------------------------------

# 30. Önerilen veri modeli

Ana entity'ler:

-   Site
-   User
-   Role
-   Permission
-   Person
-   IndependentUnit
-   Block
-   IndependentUnitGroup
-   Firm / Cari
-   CashAccount
-   IncomeExpenseDefinition
-   Employee
-   Vehicle
-   Meter
-   MainMeter
-   MeterReading
-   MeterDistribution
-   Debt
-   Collection
-   Expense
-   Income
-   Transfer
-   Refund
-   OpeningEntry
-   Invoice
-   EnforcementCase
-   SMS template
-   Email template
-   Task
-   Decision
-   Document
-   Feedback
-   Event
-   Note
-   Attachment
-   ReportTemplate
-   AuditLog

İlişkiler: - Site → Block - Block → IndependentUnit - IndependentUnit →
Person - Person → Vehicle - Person → FinancialTransactions -
IndependentUnit → FinancialTransactions - Firm →
Income/Expense/Invoice - Meter → MainMeter - Meter → IndependentUnit -
MeterReading → Meter - MeterDistribution → IndependentUnit - User →
Role - Role → Permission - Entity → Note - Entity → Attachment - Entity
→ AuditLog

------------------------------------------------------------------------

# 31. Yeni uygulama için kritik workflow'lar

## Workflow 1 -- Kişi oluştur

Kişi → iletişim → adres → araç → bakiye → kaydet

## Workflow 2 -- Bağımsız bölüm oluştur

Blok → kapı no → tip/grup → malik → kiracı → m² → arsa payı → aidat →
kaydet

## Workflow 3 -- Borçlandırma

Borçlandırma tipi → hedef kişi/daire → tutar → tarih → kasa/hesap →
belge → kaydet

## Workflow 4 -- Tahsilat

Kişi/daire → borç seç → ödeme yöntemi → kasa → tutar → makbuz → kaydet

## Workflow 5 -- Sayaç

Ana sayaç → dağıtım yöntemi → fatura → tüketim → hesaplama → bağımsız
bölümlere dağıt → borçlandır

## Workflow 6 -- Gider

Firma → belge → gider türü → kasa → tutar → açıklama → kaydet

## Workflow 7 -- İcra

Kişi → borç → dosya no → avukat → tarih → durum → evrak

## Workflow 8 -- İletişim

Şablon → alıcı segmenti → kanal → önizleme → gönderim → log

## Workflow 9 -- Yetki

Kullanıcı → rol → modül → action → görünürlük

## Workflow 10 -- Excel

Template → upload → validation → preview → import → error report

------------------------------------------------------------------------

# 32. Video içinde açıkça GÖRÜLMEYEN / doğrulanması gereken alanlar

Aşağıdaki alanlar menüde bulunmasına rağmen videoda ayrıntılı olarak
açılmamış veya fonksiyonu tam gösterilmemiştir:

-   Banka Hareketleri ekranının detaylı işlemleri
-   Raporlar ana ekranı ve rapor çeşitleri
-   Gerçek banka entegrasyonu
-   Kredi kartı entegrasyonunun tüm akışı
-   Web Sitesi'nin gerçek site düzenleme/publishing akışı
-   Destek Ekranı'nın içeriği
-   İşlem Geçmişi'nin detaylı ekranı
-   Excel ile Site Aktar'ın gerçek import adımları
-   Yetki matrisindeki tüm sütunların gerçek isimleri
-   Sayaç sihirbazının 3. ve 4. adımlarındaki tüm alanlar
-   İcra dosyasının detay ekranı
-   Tahsilat yöntemlerinin tüm seçenekleri
-   Raporların gerçek çıktıları
-   Bildirim merkezinin tüm davranışları
-   Kullanıcı profil ayarlarının tüm alanları

Bu özellikler yeni uygulamada "varsayım" olarak değil, ayrıca
doğrulanması gereken gereksinimler olarak tutulmalıdır.

------------------------------------------------------------------------

# 33. Uygulama mimarisi için öneri

Bu sistem basit bir CRUD uygulaması olarak yapılmamalı.

Önerilen modüler yapı:

1.  Authentication
2.  Tenant/Site Management
3.  CRM / People
4.  Property / Independent Units
5.  Finance
6.  Billing
7.  Collections
8.  Metering
9.  Enforcement
10. Communication
11. Task Management
12. Document Management
13. Definitions / Master Data
14. Reporting
15. Website / Portal
16. Authorization
17. Audit
18. Import/Export
19. Integrations

Özellikle Finance modülünü diğer modüllerden bağımsız domain olarak
tasarlamak önemli.

------------------------------------------------------------------------

# 34. En kritik tasarım kararları

### 1. Tenant isolation

Her site/apartman kendi verisini tamamen izole etmeli.

### 2. Role Based Access Control

Yetki sistemi sadece menü gizlemekten ibaret olmamalı; API seviyesinde
de uygulanmalı.

### 3. Audit log

Finansal işlemlerde: - kim - ne zaman - ne yaptı - eski değer - yeni
değer

tutulmalı.

### 4. Immutable financial records

Finansal hareketler doğrudan silinmek yerine iptal/ters kayıt
mekanizması kullanmalı.

### 5. Document numbering

Borç, tahsilat, gelir, gider ve virman belgelerinde seri/sıra üretimi
merkezi olmalı.

### 6. Distribution engine

Sayaç ve aidat dağıtımı ayrı hesaplama motoru olmalı.

### 7. Notification engine

SMS + e-posta aynı template/recipient altyapısını kullanmalı.

### 8. File/attachment service

Notlar, icra, bağımsız bölüm, görev ve dokümanlarda ortak attachment
sistemi kullanılmalı.

### 9. Import engine

Excel aktarımı ortak bir import framework üzerinden yapılmalı.

### 10. Search

Header'daki global arama nedeniyle kişi + bağımsız bölüm + firma + işlem
gibi entity'ler arasında merkezi arama altyapısı kurulmalı.

------------------------------------------------------------------------

# 35. Claude'a verilecek en önemli özet

Bu video, basit bir apartman kayıt uygulamasından çok daha geniş bir
**site/apartman yönetim ERP + CRM + finans + iletişim + sayaç + icra +
doküman + yetki sistemi** gösteriyor.

Uygulamanın merkezindeki ilişki:

**Site → Blok → Bağımsız Bölüm → Kişi**

Bu yapının etrafında:

**Kişi / Bağımsız Bölüm → Borç → Tahsilat → Bakiye → İcra**

ve:

**Firma → Fatura → Gider/Gelir → Kasa → Virman**

ve:

**Ana Sayaç → Tüketim → Dağıtım → Bağımsız Bölüm → Borçlandırma**

workflow'ları bulunuyor.

Bunun yanında:

**İletişim → SMS/E-posta → Şablon → Alıcı → Gönderim Logu**

ve:

**Kullanıcı → Rol → Yetki → Modül/İşlem**

yapıları var.

Yeni uygulama geliştirilirken bu domain ilişkileri UI'dan önce
tasarlanmalı.

------------------------------------------------------------------------

# 36. Sonuç

Videodan çıkarılan ana özellik seti:

-   Dashboard
-   Takvim / etkinlik
-   Global arama
-   Kişi CRM
-   Bağımsız bölüm yönetimi
-   Malik/kiracı/daire sakini ilişkileri
-   Firma/cari yönetimi
-   Toplu borçlandırma
-   Borçlandırma
-   Tahsilat
-   Toplu tahsilat
-   Gider
-   Gelir
-   Virman
-   Ödeme iadesi
-   Açılış fişi
-   İcra dosyası
-   Sayaç
-   Sayaç dağıtım sihirbazı
-   Fatura
-   SMS şablonları
-   E-posta şablonları
-   İş takibi
-   Karar defteri
-   Doküman yönetimi
-   Geri bildirim
-   Blok
-   Bağımsız bölüm grupları
-   Kasa
-   Gelir/gider tanımları
-   Personel
-   Araç
-   Ana sayaç
-   Bağımsız bölüm sayaçları
-   Web sitesi
-   Rapor ayarları
-   Yetkilendirme
-   Erişim izinleri
-   Evrak seri/sıra
-   Borçlandırma parametreleri
-   Yapı/site ayarları
-   SMS/e-posta ayarları
-   Excel aktarımı
-   Notlar
-   Ekler
-   İşlem geçmişi
-   Liste filtreleme/sıralama
-   Sayfalama
-   CRUD işlemleri
-   Dosya yükleme
-   Finansal belge numaralandırma
-   Çoklu satır finansal işlem
-   Mobil/web görünürlük izinleri

**Geliştirme açısından en önemli nokta:** Bu özelliklerin tamamını tek
bir "admin paneli CRUD" mantığında değil, ilişkisel ve finansal
tutarlılığı olan modüler bir ERP mimarisinde ele almak gerekir.
