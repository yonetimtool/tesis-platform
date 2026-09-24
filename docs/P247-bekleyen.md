# P247 — Kararını bekleyen konular ve ölçülemeyenler

Bu dosya P247 sonunda açık kalan konuları toplar. Bölümlerin kararları
`docs/P247-kararlar.md` dosyasındadır.

## 0. Kararlar ve uygulanışı (2026-09-24)

Üç konuya da karar verildi ve kararlar uygulandı.

**1.1 İzin notu: öneri onaylandı.** İzin tarihi ve türü ekipte görünmeye
devam ediyor. Not metni yalnızca izni alan kişiye, onun amirine
(güvenlik amiri, yalnız kendi ekibi) ve yönetime dönüyor. Süzme sunucuda
yapılıyor: yetkisi olmayan kişinin yanıtında `not_metni` anahtarı hiç
bulunmuyor, boş değer olarak bile gönderilmiyor. Bu kural izin listesi,
izin ekleme, onaylama ve reddetme yanıtlarının hepsinde geçerli. Testte
ham yanıt metninde not içeriğinin geçmediği de ölçülüyor.

**1.2 Daire notları: "saha personeli görebilir" işareti eklendi.**
İşaret varsayılan olarak kapalı. Göç 0155 mevcut tüm daire eklerini
kapalı yazıyor; göç anında hiçbir eski not sahaya açılmadı (geliştirme
veritabanındaki 16 ekin hepsi kapalı). İşareti yalnızca yönetim koyup
kaldırabiliyor: not yazılırken kutuyla, sonradan yeni `PATCH /ekler/{id}`
ucuyla. Her değişiklik denetime `ek_saha_gorunurlugu` olarak yazılıyor.
Süzme sunucuda, sorgunun içinde yapılıyor: işaretsiz not güvenlik
görevlisine ve tesis görevlisine hiç dönmüyor, sayısı bile belli olmuyor.
İşaret yalnızca daire eklerinde anlamlı; başka türde bir ekte işaret
gönderilirse sunucu 422 döndürüyor. Kural daireye eklenen dosyalar için
de geçerli, çünkü daireye eklenmiş bir belge de not kadar hassas
olabilir.

Arayüzde not yazılırken kutunun yanında "Güvenlik ve tesis görevlileri
bu notu görebilir" yazıyor. Altında da şu açıklama var: "İşaretlemezseniz
not yalnızca yönetim tarafından görülür. Borç, anlaşmazlık veya kişisel
bilgi içeren notları işaretlemeyin." Listede her notun yanında "Saha
görebilir" ya da "Yalnız yönetim" yazıyor ve tek dokunuşla
değiştirilebiliyor.

Web'de daire notları için bir ekran yoktu; daire detay çekmecesine
eklendi. Mobilde de yoktu; bina şemasındaki daire detayına eklendi. Mobilde
güvenlik görevlisi ve tesis görevlisi burada yalnızca işaretli notları
okuyor, yönetim ise not yazıp işareti yönetiyor. Uç, uç güvenlik
tablosuna (`uc-guvenlik.tsv`) ve rol matrisine eklendi.

**1.3 Sakin modunda panik uyarısı: olduğu gibi kaldı.**

## 1. Karar bekleyen bulgular (karar öncesi metin, kayıt için)

Bu iki bulgu §6 güvenlik taramasında ortaya çıktı. İkisini de düzeltmedim,
çünkü teknik bir hata değil, kimin neyi görmesi gerektiğiyle ilgili ürün
kararları.

### 1.1 Saha personeli birbirinin izin notunu görüyor

Vardiya izin listesinde (`/vardiya-izin`) güvenlik görevlileri ve tesis
görevlileri birbirlerinin izin kayıtlarını görebiliyor. Bu görünürlük
P232'de bilerek açılmıştı: ekip kimin hangi gün izinli olduğunu bilmeli
ki vardiya planlanabilsin. Sorun, kayıtla birlikte izin talebine yazılan
not alanının (`not_metni`) da görünmesi. Bu not "doktor raporu",
"ameliyat" gibi sağlık bilgisi içerebilir. KVKK'ya göre sağlık verisi
özel nitelikli kişisel veridir.

Önerim şu: tarih ve izin türü ekipte görünmeye devam etsin, not metni
yalnızca izni alan kişiye, amirine ve yönetime görünsün. Onaylarsan bu
değişikliği yaparım. Notun ekipte görünmesinin bilinçli bir tercih
olduğunu söylersen de olduğu gibi bırakırım.

### 1.2 Güvenlik ve tesis görevlisi daire notlarını okuyabiliyor

Daire kayıtlarına eklenen notlar (`/ekler?varlik_tipi=unit`) daireyi
okuyabilen her role açık. Buna güvenlik görevlisi ve tesis görevlisi de
dahil. Yöneticinin bir daireye yazdığı not borç durumu, anlaşmazlık ya da
sakin hakkında kişisel bir değerlendirme olabilir. Saha personelinin
bunları görmesi gerekmeyebilir.

İki seçenek görüyorum. Birincisi, daire notlarını yalnızca yönetime açmak.
İkincisi, not eklenirken "saha personeli görebilir" diye bir işaret
koymak ve sahaya yalnızca işaretli notları göstermek. İkincisi daha
esnektir ama bir göç ve arayüz değişikliği ister. Hangisini istediğini
söylersen yaparım.

### 1.3 Ayrıca onayını beklediğim bir karar: sakin modunda panik uyarısı

Yönetici sakin moduna geçtiğinde yönetimle ilgili hiçbir şey görmemeli.
Buna tek bir istisna bıraktım: tesiste panik alarmı çalınca açılan tam
ekran uyarı sakin modunda da gösteriliyor. Gerekçem, kişiye gelen bir
acil durumun mod ayrımından daha önemli olması. Uyarı yalnızca haber
verir, yönetim işlemi açmaz. Bunun da gizlenmesini istersen kaldırırım.

## 2. Ölçemediklerim

Aşağıdakileri bu makinede ölçemedim. Nedeni çoğunlukla gerçek cihaz,
emülatör ya da Xcode olmaması. Her maddede neyin ölçüldüğünü ve neyin
açık kaldığını yazdım.

### 2.1 Gerçek iOS cihazda bildirim görünümü

Sunucunun FCM'e gönderdiği bildirim içeriğini testle doğruladım. İçerikte
şunlar var: aynı konudaki bildirimleri gruplayan kimlik (`thread-id`),
tesis adını gösteren alt başlık, rozet sayısı ve acil bildirimler için
"zamana duyarlı" işareti. Ancak bu bildirimin bir iPhone'da gerçekten
gruplu, alt başlıklı ve doğru rozetle göründüğünü göremedim.

Uygulama açıldığında rozeti gerçek okunmamış sayısına çeken iOS kodunu
`AppDelegate.swift` dosyasına ekledim. Bu makinede Xcode olmadığı için bu
kod derlenmedi. İlk iOS derlemesinde bir hata çıkarsa ilk bakılacak yer
burasıdır.

"Zamana duyarlı" işaretinin Odak modunu delebilmesi için Xcode'da bir
yeteneğin açılması gerekiyor. Adımlar `docs/P247-kararlar.md` dosyasının
§5 bölümünde. Bu adım yapılmadan işaret iPhone'da normal bildirim gibi
davranır; bir şey bozulmaz.

### 2.2 Uygulama kapalıyken push

Bildirimin, uygulama kapalıyken de telefonun kendisi tarafından
gösterilecek biçimde gönderildiğini doğruladım. Acil bildirimlerin
Android'in pil tasarrufu modunda geciktirilmeyecek öncelikle gittiğini ve
iOS için gereken izinlerin yerinde olduğunu da doğruladım. Ama gerçek bir
telefonda şu iki durumu deneyemedim: Android'de uygulama son kullanılanlar
listesinden kaydırılıp kapatıldığında ve iOS'ta uygulama tamamen
sonlandırıldığında bildirimin gelmesi.

Bir not: Android'de ayarlardan "zorla durdur" yapılmış bir uygulamaya
hiçbir bildirim ulaşmaz. Bu işletim sisteminin kuralıdır ve uygulama
tarafından aşılamaz. Kullanıcı uygulamayı bir kez açınca bildirimler
yeniden gelmeye başlar.

### 2.3 iOS'ta kart yazılarının font ölçüsü

"Rezervasyon" kelimesinin iPhone'da ikiye bölünmesini düzelttim. Hiçbir
kart yazısının bölünmediğini 7 dilde, iki ekran genişliğinde ve iki
görünüm modunda test eden bir kilit ekledim. Bu testte iPhone'un fontu
SF Pro yerine DejaVu Sans Bold kullanılıyor, çünkü SF Pro'nun lisansı onu
depoya koymamıza izin vermiyor. DejaVu Sans Bold, Android'in fontundan
yüzde 23 ile 33 arasında daha geniş. Bu yüzden testin gerçek iPhone'dan
daha zor koşulda çalıştığını düşünüyorum, ama SF Pro ile ölçmediğim için
bunu kanıtlayamıyorum. Gerçek bir iPhone'da ana ekrandaki "Rezervasyon"
kartına ve dil Almanca'ya çevrilmişken Hızlı Özet kutularına bir kez göz
atılmasını öneririm.

### 2.4 Diğer ölçülemeyenler

Android'de uzun bir bildirim aşağı çekilip genişletildiğinde metnin
tamamının göründüğünü cihazda görmedim. Firebase kütüphanesinin bunu
yaptığını biliyorum, ama gözle doğrulamadım.

Mobilde yönetici ile sakin modu arasında geçiş yapıldığında uygulamanın
iç durumu baştan kuruluyor. Bu sırada bildirim jetonu kaydının tekrar
tetiklenmediğini yalnızca widget testiyle ölçtüm, gerçek cihazda
denemedim.

Webde bir bildirime tıklayınca gerekirse otomatik olarak doğru moda
geçilmesini birim testiyle ölçtüm. Gerçek bir yönetim bildirimiyle
tarayıcıda baştan sona sürmedim.

Ziyaretçi kayıtlarını 24 saat sonra kapatan görevi ve vardiya döngüsünün
ufkunu her gece ilerleten görevi doğrudan çağırarak test ettim. Bunların
zamanlayıcı tarafından gerçekten saatinde çalıştığını izlemedim;
zamanlama kayıtları ayrı bir testle kilitli.

Vardiya döngüsü önizlemesi 3 kişilik bir ekipte 0,44 saniye sürdü. 20
kişilik bir ekipte birkaç saniye sürmesini bekliyorum, ama ölçmedim.

Mobilde yapılan görünüm modu seçiminin (Standart ya da Büyük) webe
yansımasını tarayıcıda sürmedim. Kodu okuyarak ve mobildeki istek
gövdesini test ederek doğruladım. Android'de uygulamayı silip yeniden
kurunca seçimin hesaptan geri geldiğini de gerçek cihazda denemedim.
