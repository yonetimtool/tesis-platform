# P204 — Mobil / web yönetici paritesi · AŞAMA 1 ANALİZ

**Tarih:** 2026-09-02 · **Durum:** analiz, kod yazılmadı

Kaynak: `admin-web/lib/menu.ts` + `admin-web/lib/yuzey.ts` (ROTA_ROLLERI,
PLATFORM_ROTALARI) ve `mobile/lib/src/features/home/domain/home_menu.dart`
(`homeMenuForRole`) ile `module_card_spec.dart`. Sayılar bu dosyalardan
**okunarak** çıkarıldı, tahmin edilmedi.

## Özet sayılar

| | Adet |
|---|---|
| Web menüsündeki toplam öğe | 67 |
| Bunlardan **yöneticinin gördüğü** | **47** |
| Mobil `homeMenuForRole(yonetici)` | **27** |
| Web'de olup mobilde **karşılığı olmayan** | **24** |
| Mobilde olup web'de ayrı ekranı olmayan | 4 (aşağıda) |

> Not: sayılar **menü öğesi** sayısıdır, işlev değil. Bir ekranda birden
> çok işlev olabilir (ör. `/tanimlar` on üç defter taşır). Aşağıdaki
> tablo işlev bazında ayrıştırıyor.

---

# 0. ÖZEL MADDE — mobilde çok tesisli yönetici

## Kısıtı yanlış tarif etmişim — düzeltiyorum

P203'te "telefonun global benzersizliği yüzünden mobilde girişte tesis
seçimi yapılamıyor" dedim. **Ölçüm bunu doğrulamıyor; asıl kısıt daha
büyük.**

`mobile/lib/src/features/auth/data/auth_api.dart` içindeki giriş yolları:

| Yol | Uç |
|---|---|
| Telefon + parola | `POST /auth/login-phone` |
| Telefon + kod (parolasız) | `POST /auth/giris/kod-iste` |
| SSO (Google/Microsoft/Apple) | `POST /auth/oauth/*` |

**Mobilde e-posta ile giriş HİÇ YOK.** Oysa P197'den beri e-posta
zorunlu, **telefon opsiyonel**. Yani:

> Web'den e-posta + parola ile kaydolmuş, telefon girmemiş bir yönetici
> **mobile hiç giremez** — SSO kullanmadıysa.

Bu, çok tesislilikten bağımsız ve **daha ağır** bir kusur. Çok tesislilik
onun bir alt kümesi: telefon global benzersiz olduğu için aynı kişi iki
tesiste aynı numarayı taşıyamaz, dolayısıyla telefonla girdiğinde
numarasının bağlı olduğu **tek** tesise düşer.

**Ama uygulama içi geçiş MOBİLDE ÇALIŞIYOR** (P203 §2'de eklendi:
Ayarlar → Tesis değiştir). Yani çok tesisli bir yönetici, telefonu hangi
tesisteyse oraya girip **içeriden** ötekine geçebiliyor. Kırık olan şey
"hangisine gireceğini seçmek", ve asıl kırık olan şey "hiç girememek".

## Çözüm yolları

| # | Yol | İş | Risk | Değerlendirme |
|---|---|---|---|---|
| **A** | Mobile **e-posta + parola girişi** ekle; slug yerine `POST /auth/tesislerim` ile tesis listesi al, tek ise doğrudan gir, çok ise **seçim ekranı** göster | **Küçük–orta** (yalnız mobil UI + 2 API çağrısı) | **Düşük** | **ÖNERİM.** Backend işi **YOK**: `/auth/tesislerim` ve `/auth/login` P203 §2'de zaten yazıldı ve web bunu kullanıyor. Mobil tam olarak web'in yaptığını yapar. |
| B | Mobile e-posta girişi ekle ama **tesis kodunu kullanıcıya yazdır** | Küçük | Düşük | A'nın kötü hâli: kullanıcıya ezberlemesi gerekmeyen bir kod yazdırmak — P203 §2'de web'de **tam bu şikâyet** düzeltildi. |
| C | E-posta **kod** ile giriş (`/auth/giris/eposta-kod-iste`) | Küçük–orta | Düşük | Uç var ama **`tenant_slug` istiyor** → yine A'daki seçim adımı gerekir. Parolasız yolu isteyenler için A'nın **üstüne** eklenebilir, A'nın yerine değil. |
| D | `uq_app_user_telefon` kısıtını **kaldır** | Orta | **Yüksek** | Aşağıya bak — **önermiyorum.** |

## D'yi neden önermiyorum: telefon benzersizliği neyi tutuyor

Kısıt "giriş anahtarı" olmaktan çıktı ama **hâlâ üç yerde taşıyıcı**:

* `POST /auth/login-phone` — *"Tenant TELEFONDAN otomatik çözülür
  (tenant_slug YOK)"*. Tenant'ı `tenant_id_by_phone` SECURITY DEFINER
  fonksiyonu buluyor.
* `POST /auth/giris/kod-iste` — aynı çözümleme.
* `routers/kayit.py` (2 yerde) — kayıt akışında tenant çözümü.

Kısıtı kaldırırsak `tenant_id_by_phone` **belirsizleşir**: aynı numara
iki tenant'a çözülür ve fonksiyon ya rastgele birini döner ya patlar.
Yani **telefonla giriş kırılır** — bugün mobilin *tek* çalışan yolu.

Kaldırmak isteniyorsa önce telefon girişinin de tesis seçimine
bağlanması gerekir; yani **A'nın yapılması D'nin ön koşuludur.** A
yapıldıktan sonra D isteğe bağlı bir sadeleştirmeye dönüşür — ve o
zaman bile faydası sınırlı (aynı kişinin iki tesiste aynı numarayı
taşıması nadir bir ihtiyaç).

**Emin değilim:** SSO ile giren çok tesisli bir yöneticinin hangi
tenant'a düştüğünü ölçmedim. `oauth_kimlik` bağı kullanıcı satırına
(dolayısıyla tenant'a) ait olduğu için muhtemelen bağlı olduğu tesise
düşüyor, ama bunu **çalıştırarak doğrulamadım.**

## Öneri

**A** — ve öncelik listesinin **1. sırası**. Backend işi yok, risk
düşük, hem "hiç giremeyen yönetici" hem "tesis seçemeyen yönetici"
sorununu birlikte çözüyor.

---

# 1. İşlev bazında parite tablosu

**Mobilde durum:** `yok` / `salt okunur` / `tam`.
**Taşıma işi:** küçük (< yarım gün) / orta / büyük.

## 1.1 Finans

| İşlev | Web ekranı | Mobil | Taşıma | Telefonda kullanılabilir mi? |
|---|---|---|---|---|
| Finans özeti (kasa, gelir/gider) | `/finans` | **tam** (`financialSummary`) | — | Evet |
| Bütçe (kategori + defter) | `/finans/butce` | **salt okunur** (`budget`) | orta | Kısmen — bkz. §2 |
| **Tahsilat girişi** (elden aidat) | `/finans/tahsilatlar` | **yok** | **küçük** | **Evet — sahada gerçek ihtiyaç** |
| Gider kaydı | `/finans/giderler` | **yok** | küçük | Evet |
| Gelir kaydı | `/finans/gelirler` | **yok** | küçük | Evet |
| Borçlular listesi | `/finans/borclular` | **yok** | küçük | Evet |
| Aidat tahakkuku (tekil) | `/dues` | **yok** | orta | Evet |
| **Toplu borçlandırma + önizleme** | `/finans/borclandirmalar` | **yok** | büyük | **Hayır — bkz. §2** |
| Açılış fişleri | `/finans/acilis` | **yok** | orta | Hayır (kurulum işi, bir kez) |
| Virman | `/finans/virman` | **yok** | küçük | Evet ama nadir |
| İade | `/finans/iade` | **yok** | küçük | Evet ama nadir |
| Banka entegrasyonu | `/finans/banka` | **yok** | büyük | Hayır (kurulum + eşleştirme) |
| Otomasyon (aidat planı, hatırlatma) | `/finans/otomasyon` | **yok** | orta | Hayır (kurulum işi) |
| **Fazla mesai** (P203 §5) | `/finans/mesai` | **yok** | orta | Kısmen — özet evet, yazma evet |
| İcra takibi | `/icra` | **yok** | orta | Kısmen |
| Sayaç okuma | `/sayac-okuma` | **yok** | orta | **Evet — sahada okuma yapılır** |
| Rapor motoru (13 rapor) | `/raporlar` | **salt okunur**, dar (`reports`) | büyük | **Hayır — bkz. §2** |
| Aidat raporu | `/reports/dues` | kısmen (`reports`) | orta | Kısmen |
| Şeffaflık yayını | `/transparency` | **tam** (`transparency`) | — | Evet |

## 1.2 Güvenlik / operasyon

| İşlev | Web | Mobil | Taşıma | Telefonda? |
|---|---|---|---|---|
| NFC noktaları | `/checkpoints` | **tam** | — | Evet |
| Devriye planları | `/patrol-plans` | **tam** | — | Evet |
| Devriye takibi | — (plan içinde) | **salt okunur** | — | Evet |
| Vardiya tanımları | `/shifts` | **tam** (`vardiyalar`) | — | Evet |
| **Vardiya planı** (P203 §4) | `/vardiya-plani` | **salt okunur + çıkarma** | küçük | Evet (atama web'de) |
| Kameralar | `/kameralar` | **tam** (ayarlardan) | — | Evet |
| Bildirimler | `/notifications` | **tam** (uygulama içi) | — | Evet |
| Araç geçişleri | `/arac-gecisleri` | **tam** (`aracGecis`) | — | Evet |
| Plaka olayları | `/olaylar` | **tam** (`plakaOlaylari`) | — | Evet |
| İhlaller | — | **tam** (`ihlaller`) | — | Evet |
| Otopark | — | **tam** (`otopark`) | — | Evet |
| Ziyaretçiler (izleme) | `/ziyaretciler` | izinle (`unitAccess`) | — | Evet |
| Kargolar | `/kargolar` | izinle | — | Evet |

## 1.3 Tesis / tanımlar

| İşlev | Web | Mobil | Taşıma | Telefonda? |
|---|---|---|---|---|
| Daireler | `/units` | **tam** (`daireTanimlari`) | — | Evet |
| **Bina/blok düzenleme (görsel)** | `/building-editor` | **tam** (`binaDuzenleme`) | — | Kısmen — bkz. §2 |
| Şikâyet haritası | `/schematic` | **tam** (`sikayetHaritasi`) | — | Kısmen |
| Görevler (oluştur/ata) | `/tasks` | **tam** (`taskTracking`) | — | Evet |
| Görev kategorileri | `/tanimlar` | **tam** (`taskCategories`) | — | Evet |
| Demirbaş | `/assets` | **tam** | — | Evet |
| Dış hizmetler | `/dis-hizmetler` | **tam** (`disHizmet`) | — | Evet |
| Rezervasyon yönetimi | `/rezervasyon-yonetimi` | **tam** (`rezervasyon`) | — | Evet |
| **Diğer 13 tanım defteri** (kasa, gelir/gider tanımı, sayaç, personel kaydı, araç, blok…) | `/tanimlar` | **kısmen** (`personel` var; ötekiler yok) | orta | Evet |
| **Excel/CSV toplu aktarım** | `/ice-aktarim` | **yok** | büyük | **Hayır — bkz. §2** |

## 1.4 İletişim

| İşlev | Web | Mobil | Taşıma | Telefonda? |
|---|---|---|---|---|
| Duyurular | `/announcements` | **tam** | — | Evet |
| Site kuralları | `/site-kurallari` | **tam** | — | Evet |
| Etkinlik yönetimi | `/etkinlik-yonetimi` | **tam** (`etkinlik`) | — | Evet |
| Anketler | `/anketler` | **tam** | — | Evet |
| Talepler / şikâyetler | `/complaints` | **tam** | — | Evet |
| **SMS / e-posta yönetimi** | `/mesajlar` | **yok** | orta | Kısmen (ayar girişi zor, gönderim kolay) |
| **Davetler** | `/davetler` | **yok** | küçük | **Evet — sahada gerçek ihtiyaç** |
| Yönetimle iletişim | `/yonetim-iletisim` | **tam** (`yoneticiIletisim`) | — | Evet |

## 1.5 Yönetişim

| İşlev | Web | Mobil | Taşıma | Telefonda? |
|---|---|---|---|---|
| **Kullanıcılar (ekle/düzenle/rol)** | `/users` | **kısmen** — `sakinler` + `personel` listeler ve ekler | orta | **Evet** |
| Tesis ayarları | `/tesis-ayarlari` | **yok** | orta | Evet |
| Dokümanlar | `/dokumanlar` | **tam** | — | Evet |
| Karar defteri | `/karar-defteri` | **yok** | orta | Kısmen (okuma evet, yazma zor) |
| Gürültü uyarıları | `/gurultu-uyarilari` | **yok** | küçük | Evet |
| KVKK tercihleri | `/kvkk` | **yok** | küçük | Evet |
| Kurulum sihirbazı | `/kurulum` | **tam** | — | Evet |
| Entegrasyonlar | — | **tam** (`integrations`) | — | Evet |

---

# 2. "Taşınmalı mı?" — sana karşı çıktığım yerler

Sen "hepsi olsun" dedin. **Aşağıdaki altısı için hayır diyorum**, ve
gerekçesi "zor" değil: **telefonda yapılırsa yanlış yapılır.**

## 2.1 Excel ile toplu aktarım → **TAŞINMAMALI**

Web akışı ölçüldü: dosya seçici `.xlsx/.csv` kabul ediyor, dosya
tarayıcıda ayrıştırılıyor, **önizleme tablosu** çiziliyor, hatalı
satırlar işaretleniyor, kullanıcı düzeltip onaylıyor.

Telefonda: 200 satırlık bir önizleme tablosu 6 inçlik ekranda
okunamaz. Hatalı satırı bulup düzeltmek imkânsıza yakın. Kullanıcı
"onayla"ya basar ve **200 daireyi yanlış açar** — geri alması saatler
sürer.

Dosya seçimi teknik olarak mümkün (iOS Dosyalar / Android SAF), sorun
**seçim değil doğrulama.**

> **Öneri: taşınmasın.** Bunun yerine mobilde tek bir satır: *"Toplu
> aktarım bilgisayardan yapılır"* + bağlantı. Kullanıcıyı yarım bir
> araçla baş başa bırakmaktansa doğru yere yönlendirmek.

## 2.2 Bütçe hedefi tablosu → **FARKLI BİÇİMDE taşınmalı**

Web'de kategori × ay ızgarası. Telefonda 12 sütunlu tablo doldurulamaz.

> **Öneri:** mobilde **okuma + tek kategori düzenleme** (kategori seç →
> aylar alt alta). Izgarayı taşımak değil, **aynı veriyi dikey kurmak.**
> Toplu doldurma web'de kalsın.

## 2.3 Muhasebeye aktarım (dosya indirme) → **TAŞINMAMALI (bugünkü hâliyle)**

Rapor motoru ağır raporları kuyruğa alıp **indiriyor**. Telefonda
indirilen dosya "İndirilenler"e düşer ve kullanıcı onu muhasebeciye
göndermek için dosya yöneticisi + e-posta uygulaması arasında dolaşır.
Yapılabilir ama **kimse yapmaz.**

> **Öneri:** taşımak yerine **"muhasebeciye e-posta gönder"** eylemi
> ekleyelim — sunucu dosyayı üretip **doğrudan e-postayla** yollasın.
> O zaman mobil de web de aynı düğmeyi kullanır ve indirme adımı
> **her iki yüzeyden de** kalkar. Bu, paritenin ötesinde bir iyileştirme.
> **Bu ayrı bir tur olmalı** — P204'ün kapsamına sıkıştırmayalım.

## 2.4 3D maket / bina düzenleme → **ZATEN VAR, GENİŞLETİLMESİN**

Mobilde `binaDuzenleme` **var ve tam**. Web'deki `/building-editor`
görsel bir editör; ölçtüm, **3D değil** — blok/kat/daire kutucukları.

> **Öneri:** olduğu gibi kalsın. Mobilde blok/daire **eklemek**
> çalışıyor; sürükle-bırak yerleşim düzenlemesi telefonda parmakla
> hassas hedefleme ister ve hatalı bırakma sessizce yanlış kat üretir.
> **Emin değilim:** mobil editörün yazma kapsamını ekran ekran
> ölçmedim, yalnız menü açıklamasını okudum.

## 2.5 Toplu tahakkuk önizlemesi → **FARKLI BİÇİMDE taşınmalı**

Web'de N daire × tutar listesi. Telefonda 200 satırlık önizlemeyi
kimse okumaz — ama **okumadan onaylamak da parayı yanlış yazmak**
demek.

> **Öneri:** mobilde **özet onay**: "142 daire · toplam 71.000 ₺ ·
> 3 daire tutarsız" + yalnız **tutarsız satırların** listesi. Tam
> listeyi görmek isteyen web'e gider. Böylece sahada aidat yazılabilir
> ama körlemesine onaylanmaz.

## 2.6 Rapor ekranları (geniş tablolar) → **FARKLI BİÇİMDE taşınmalı**

13 raporun tamamını telefona koymak, 8 sütunlu tabloları yatay kaydırma
hapishanesine sokmak demek.

> **Öneri:** mobilde **kart özeti** (en çok bakılan 4–5 rakam) + "tam
> raporu e-postala". Mobilde zaten `reports` var ve dar; onu
> **genişletmek yerine derinleştirmek** doğru yol.

---

# 3. Öncelik önerisi

Sıralama ölçütüm: **yöneticinin sahada, telefonu elindeyken, o an
yapması gereken iş.** Masa başında yapılan iş masada kalabilir.

| # | Madde | Neden bu sırada |
|---|---|---|
| **1** | **Mobilde e-posta ile giriş + tesis seçimi** (§0/A) | Diğer her şeyin ön koşulu. Telefonu olmayan yönetici bugün mobile **hiç giremiyor**; paritenin geri kalanı onun için anlamsız. Backend işi yok. |
| **2** | **Tahsilat girişi** | Kapıda elden aidat alan yönetici — senin verdiğin örnek ve doğru örnek. Bugün makbuzu deftere yazıp akşam bilgisayara giriyor; arada kaybolan tahsilat gerçek bir sorun. |
| **3** | **Davet gönderme** | Yeni sakin taşınırken yönetici oradadır. "Akşam bilgisayardan davet ederim" pratikte günlerce sürüyor. |
| **4** | **Gider kaydı** (fatura/fiş) | Fiş elde, telefon elde. Fotoğrafla birlikte anlamlı. |
| **5** | **Borçlular listesi** | Kapıda "borcum var mı" sorusuna anında yanıt. Salt okuma, küçük iş. |
| **6** | **Sayaç okuma** | Sahada yapılan iş; bugün kâğıda yazılıp sonra giriliyor. |
| **7** | **Tesis ayarları + gürültü uyarıları + KVKK** | Küçük işler, sahada ara sıra gerekir. |
| **8** | Fazla mesai özeti (P203 §5) | Ay sonu işi; masada da yapılabilir ama onay sahada verilebilir. |
| **9** | Toplu tahakkuk — **özet onay biçiminde** (§2.5) | Aylık ritim; sahada başlatmak değerli ama listeyi görmek şart değil. |
| **10** | Rapor kartları + e-postala (§2.6, §2.3) | Ayrı tur önerdiğim işle birleşir. |
| — | Bütçe ızgarası, banka, açılış fişleri, toplu aktarım, otomasyon kurulumu | **Masa işi.** Yılda bir–iki kez, oturarak, büyük ekranda yapılır. Taşımanın faydası maliyetini karşılamıyor. |

**1–6 arası, "sahada gerçekten işini engelliyor" dediğim küme.** 7+
konfor.

---

# 4. Ölçemediklerim / emin olmadıklarım

* **Mobil ekranların yazma kapsamını ekran ekran açmadım.** Tablo,
  `home_menu.dart` açıklamalarına ve menü kümelerine dayanıyor. "tam"
  dediğim bazı girişler pratikte kısmi olabilir — uygulama aşamasında
  ekran ekran doğrulanmalı.
* **SSO ile giren çok tesisli yöneticinin hangi tenant'a düştüğünü**
  çalıştırarak ölçmedim.
* **`/tanimlar` içindeki 13 defterin** hangilerinin mobilde karşılığı
  olduğunu tek tek değil, toplu değerlendirdim.
* Web menüsündeki 67 öğenin 20'si yöneticiye kapalı (platform ekranları
  ve sakin/saha ekranları); onları parite kapsamına **almadım**.

---

# 5. Onay bekleyen sorular

1. §0'daki **A yolunu** onaylıyor musun? (mobilde e-posta girişi +
   tesis seçimi, backend değişikliği yok)
2. §2'deki **altı "hayır/farklı biçimde"** kararıma katılıyor musun?
   Özellikle **Excel toplu aktarımın taşınmaması** ve **muhasebeye
   aktarımın ayrı bir tura alınması.**
3. Öncelik listesinde **1–6** ile başlayalım mı, yoksa başka bir
   sıralama mı istersin?
