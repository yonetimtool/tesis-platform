# P253 — Mobil tam eşitlik: ölçüm ve plan (Aşama 1)

**Durum:** yalnız ölçüm ve plan, kod yazılmadı. Onay bekliyor.
**Tarih:** 2026-10-03. Ölçülen kod: `main` (P252 sonrası, 1.10.0+20).

**Hedef:** web'de yapılabilen her işlem mobilde de yapılabilsin.

**Kapsam dışı:** platform admin paneli (`panel.yonetiyor.com`). Ayrı bölümde
listelendi (§1.8).

---

## 0. Özet

* **Boşluk büyük ama dengesiz.**
  * Günlük işlerin çoğu (talep, duyuru, devriye, ziyaretçi, kargo, panik,
    tahsilat/gider girişi) mobilde zaten var.
  * Boşluk üç yerde toplanıyor:
    1. finans defterinin okunması ve düzeltilmesi (liste, onay/ret, iptal, dışa aktarım);
    2. tanımlar ve kurulum işleri (muhasebe tanımları, içe aktarım, tesis konumu);
    3. "yönetim masası" işleri (raporlar, karar defteri, icra, banka, mesaj).
* **Saha rolleri ve sakin için boşluk yok denecek kadar az.**
  * Güvenlik, görevli, amir ve sakin web'e giremiyor (P129/P248: mobil-yalnız
    roller). Bu rollerin web'de olup mobilde olmayan işi yok.
  * Sakin modunda tek gerçek eksik: **makbuz listesi ve PDF**.
* **Denetçi mobilde hiçbir şey yapamıyor.** Yalnız "web'e gidin"
  ekranı görüyor (P128/P129 kararı). Web'de beş sayfası var. Hedef "her
  işlem" ise bu karar da geri açılmalı (§5 karar 1).
* **İki web kusuru bulundu** (mobil eşitlikten bağımsız, §1.9):
  * Web'de toplu SMS/e-posta **gönderilemiyor**; yalnız önizleme var.
  * Yönetici mobil menüsünde **araç giriş kaydı** yok, oysa ekran mobilde var.
* **Önerilen yol:** dört aşama, her biri kendi mobil sürümüyle.

  | Aşama | İçerik | Tahmini tur |
  |---|---|---|
  | 0 | Eylem kilidi | 1 |
  | 1 | Günlük ve kolay | 3 |
  | 2 | Haftalık, finans ve tanımlar | 5 |
  | 3 | Aylık/nadir ve zor | 4–5 |

  Toplam yaklaşık **13–14 tur**.

---

## Yöntem

* Her web sayfasında çağrılan BFF adresi (`/api/...`) backend ucuna
  çevrildi (`lib/panel-vekil.ts`, `lib/tanimlar.ts`, `app/api/**/route.ts`).
  Aynı **uç + metot** mobilde (`mobile/lib/src/features/**/data/*_api.dart`)
  arandı.
  * Düğme adıyla eşleştirme yapılmadı: aynı iş iki yüzeyde farklı adla
    duruyor.
  * Uç eşleşmesi "iş yapılabiliyor mu" sorusuna en güvenilir cevap.
* Rol kapısı: web'de `ROTA_ROLLERI` (`admin-web/lib/yuzey.ts`), mobilde
  `home_menu.dart`.
* **Durum:**
  * **VAR:** mobilde aynı iş yapılabiliyor.
  * **KISMEN:** yapılabiliyor ama bir parçası eksik; not sütununda yazılı.
  * **YOK:** mobilde yapılamıyor.
* **Sıklık ve zorluk tahmindir;** kullanım verisi yok. Tahmin, işin
  doğasından ve P204/P251 kayıtlarından yapıldı. Sıklık yönetici gözünden.
* **Bilinçli olarak tek tek sayılmayan genel fark:** web'deki her tablo
  (`VeriTablosu`) sütun sıralama, sütun gizleme, sayfa boyu ve sayfalama
  veriyor; mobil listelerin hiçbirinde yok. Bunu bir kez, §2.1'de "liste
  araçları" olarak ele alıyorum.
* **"Emin değilim"** yazan satırlar uç düzeyinde kesinleştirilemedi;
  uygulama turunda ilk iş o satırı ölçmek.

---

## 1. Ölçüm — web'de olup mobilde olmayan

**Kısaltmalar:**
* Sıklık: G = günlük, H = haftalık, A = aylık, N = nadir.
* Zorluk: K = kolay, O = orta, Z = zor.

### 1.1 Rol özeti

| Rol | Web'e girebiliyor mu | Web'de olup mobilde olmayan |
|---|---|---|
| Yönetici (ve admin tesis yüzeyi) | Evet, 75+ sayfa | **Çok** — §1.2–§1.7 |
| Denetçi | Evet: `/raporlar`, `/transparency`, `/icra`, `/bakim`, `/finans/mesai`, `/profil`, `/kvkk` | **Hepsi.** Mobilde yalnız yönlendirme ekranı var (`denetci_yonlendirme_screen.dart`) |
| Güvenlik amiri | Hayır (mobil-yalnız, P248) | Yok |
| Güvenlik | Hayır (mobil-yalnız) | Yok |
| Tesis görevlisi | Hayır (mobil-yalnız) | Yok |
| Sakin | Hayır; ama yöneticinin "sakin modu" web'de var (P247) | **Makbuz listesi ve PDF** (`GET /me/makbuzlar`). Gerisi eşit. |

* Web'de `/ziyaretciler`, `/kargolar` ve `/gorevlerim` sayfaları kodda
  duruyor ama hiçbir role açık değil (`ROTA_ROLLERI` boş). Bu işler fiilen
  yalnız mobilde.
* Mobil ve web menüsü rol kümeleri farklı. Örneğin mobil yönetici
  menüsünde araç geçişi kaydı yok; araç girişini amir yapıyor (§1.9).

### 1.2 Güvenlik grubu (yönetici)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /panik | Alarmı **notla** kapat | KISMEN | H | K | API `not` alıyor; mobil göndermiyor |
| /panik | Takip listesinden daire bazında uyarı durumu | KISMEN | N | K | Yalnız alarm ekranında var |
| /panik › Tatbikat | Tatbikat raporu PDF | YOK | N | O | Paylaş menüsüyle (§2.3) |
| /kameralar | Bağlantıyı test et (RTSP) | YOK | N | K | Kamera ekleme formunda düğme |
| /kameralar | Izgara yoğunluğu, özet sayaçları | YOK | G | K | Yalnız arayüz |
| /devriye › takip | Tarih aralığı, durum ve plan süzgeci, oran | KISMEN | H | K | Mobilde tek gün |
| /devriye › takip | CSV dışa aktarım | YOK | A | O | §2.3 |
| /devriye › noktalar | Durum süzgeci, sayaçlar | YOK | N | K | |
| /devriye › noktalar | **Harita görünümü** (nokta + okutma katmanı) | YOK | H | Z | §2.6 |
| /devriye › planlar | Noktaların **sırası** (yukarı/aşağı) | KISMEN | N | K | Mobilde yalnız seçim; sürükle-sırala |
| /vardiya-plani | Hafta gezinmesi (önceki/sonraki/bugün) | KISMEN | G | K | Mobil yalnız bu hafta. **Sıklık en yüksek eksiklerden** |
| /vardiya-plani | Süzgeçler (rol, kişi, sorunlu) | YOK | H | K | |
| /vardiya-plani | Blok düzenle (saat, not) | YOK | H | K | `PATCH /vardiya-plani/{id}` |
| /vardiya-plani | Toplu sil | YOK | H | K | Uzun bas, çoklu seç |
| /vardiya-plani | Haftayı doldur (şablondan) | YOK | H | K | Tek düğme |
| /vardiya-plani | Haftadan kopyala | YOK | H | K | Tek düğme + hafta seç |
| /vardiya-plani | Son işlemi geri al (her toplu işlem) | KISMEN | H | K | Mobilde yalnız döngüden sonra |
| /vardiya-plani | Yayınla (her hafta için) | KISMEN | H | K | Gezinme gelince çözülür |
| /vardiya-plani | Excel dışa aktar, şablon, **içe aktar** | YOK | A | Z | §2.4 |
| /vardiya-plani › döngü | Döngü atamasını sonlandır | YOK | N | K | |
| /vardiya-plani › şablonlar | Vardiya şablonu ekle/düzenle/sil | YOK | N | K | Mobil yalnız listeliyor |
| /vardiya-plani | Kişi ayrıntı penceresi | YOK | H | K | Emin değilim (hangi alanlar) |
| /ziyaretciler | "İçeride" süzgeci | YOK | G | K | Rol: güvenlik; web'de açık değil, ama süzgeç işi |
| /notifications | Sayfalama | KISMEN | H | K | Mobil tek sayfa (50) çekiyor gibi; emin değilim |

### 1.3 Kişiler (yönetici)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /kisiler › sakinler | Aktifleştir / pasifleştir | YOK | H | K | |
| /kisiler › sakinler | Aktif/pasif süzgeci, özet | KISMEN | H | K | Arama var |
| /kisiler (ortak) | "Telefonla aranabilir" ayarı (kişi adına) | YOK | A | K | |
| /kisiler (ortak) | Tanılama (cihaz, bildirim e-postası/SMS durumu) | YOK | H | K | "Bildirim gelmiyor" şikayetinin ilk adımı |
| /kisiler (ortak) | Toplu yükle (içe aktarım) | YOK | N | Z | §1.6 |
| /kisiler › personel | Arama, rol/durum süzgeci, özet | KISMEN | H | K | |
| /kisiler › personel | Sil / anonimleştir | YOK | A | K | |
| /kisiler › personel | Açılabilir roller sunucudan | KISMEN | — | K | Mobilde sabit liste; tutarsızlık riski |
| /kisiler › yöneticiler | Düzenle, sil, aktif/pasif, arama | YOK | A | K | Mobilde yalnız liste + ekle |
| /finans/maas-kartlari | Kart **listesi**, kart sil | KISMEN | A | K | Mobilde kişi başına kart var (P252); liste yok |

### 1.4 Tesis ve iletişim (yönetici)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /units | Daire **metrekare, arsa payı** | KISMEN | N | K | Formda alan yok |
| /units | Arsa payı toplu giriş + özet | YOK | N | O | Kurulum işi; liste + sayı alanı |
| /units (detay) | Dairenin borç durumu | YOK | H | K | `GET /units/{id}/dues` |
| /units (detay) | Daireye tahakkuk | YOK | A | O | §1.5 aidat sihirbazıyla |
| (çok yerde) | **Ek sil** (`DELETE /ekler`) | YOK | H | K | Mobil ekleyebiliyor, silemiyor |
| /tasks | Durum süzgeci, "atanan: herhangi biri" | KISMEN | G | K | |
| /tasks | Görev ekleri | YOK | H | K | |
| /tasks | Kanban ve takvim görünümleri | YOK | H | O | Takvim: gün listesi; kanban: durum sekmeleri |
| /bakim | Ekipman **ekle / sil** | YOK | A | K | Kayıt ekleme var |
| /bakim | Yıllık özet + CSV | YOK | A | O | |
| /assets | Demirbaş kaydı ekle/düzenle, aktif/pasif | YOK | A | O | Mobil ekran NFC zimmet aracı; P251 kararı (§5 karar 3) |
| /schematic | Plan haritası sekmesi | YOK | N | Z | Emin değilim (mobilde harita bileşeni yok) |
| /rezervasyon-yonetimi | Alan ve tarih süzgeci | KISMEN | H | K | |
| /dis-hizmetler | Arama | YOK | H | K | |
| /akilli-ev | Bölüm aç/kapat | KISMEN | A | K | Mobil yalnız okuyor |
| /akilli-ev | Köprü ekle, sağlık, olay jetonu | YOK | N | O | Kurulum işi |
| /akilli-ev | Cihaz ekle/sil, senaryolar | YOK | N | O | |
| /anketler | Ankete görsel | KISMEN | A | K | |
| /integrations | Diyafon düzenle | YOK | N | K | |
| /dokumanlar | Doküman **yükle, düzenle, sil**, yönetim listesi | YOK | H | K | Mobil sakin görünümünü kullanıyor. Telefondan yükleme doğal |
| /karar-defteri | Liste, karar oluştur, PDF | YOK | A | O | P251'de yalnız web |
| /mesajlar | Şablon listesi/oluştur/sil, hazır kütüphane, önizleme, **gönderim** | YOK | A | O | Web'de de gönderim yok, §1.9 |
| /dashboard | **Hatırlatmalar** (oluştur/düzenle/sil), **takvim** | YOK | G | K | Yöneticinin kendi notları; mobilde günlük kullanım beklenir |
| /dashboard | Kasa bakiyeleri | KISMEN | G | K | Mobil özet farklı uç; kasa kırılımı yok (emin değilim) |
| /dashboard | 3D bina, site planı | KISMEN | N | Z | Mobilde 2D şema var; gerek yok (§5 karar 4) |

### 1.5 Finans (yönetici; † denetçi de görüyor)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /finans | **Hareket listesi** (tip süzgeci, sıralama, sayfalama) | YOK | G | O | Mobil bütçe ekranı `GET /budget/entries` okuyor (aynı defter, P192). Ama yalnız gelir/gider; tahsilat, virman ve iade görünmüyor |
| /finans | Kasa bazında bakiye | KISMEN | G | K | |
| /finans/tahsilatlar | Tahsilat **geçmişi** | YOK | G | K | En çok sorulan: "kim ödedi" |
| /finans/tahsilatlar | Tahsilatta tarih ve belge no | KISMEN | H | K | Mobilde yöntem sabit "elden" |
| /finans/tahsilatlar | **Toplu (gün sonu) tahsilat** | YOK | H | O | |
| /finans/giderler | Gider **listesi** | YOK | G | K | |
| /finans/giderler | Firma, tarih, belge no, çok satır | KISMEN | H | K | Mobil tek satır; fiş fotoğrafı yalnız mobilde |
| /finans/* | **Onayla / Reddet** (her onay bekleyen hareket) | KISMEN | G | K | Mobil yalnız maaş onaylıyor. Genel gider onayı yok |
| /finans/* | **İptal (ters kayıt)** | YOK | H | O | Onay diyaloğu + sebep |
| /finans/* | Excel/PDF dışa aktarım (hareketler, kasa ekstresi, makbuz dökümü) | YOK | A | O | §2.3 |
| /finans/gelirler | Gelir listesi + yeni gelir | KISMEN | A | K | Mobil bütçe ekranından gelir girilebiliyor (`POST /budget/entries`, tek defter). Kasa/kalem/belge seçimi yok. P251 menü tablosundaki "yalnız web" bu yüzden **kısmen yanlış** |
| /finans/virman | Virman | YOK | A | K | İki kasa + tutar formu |
| /finans/iade | İade (kişinin tahsilatından) | YOK | A | O | Kişi → tahsilat seç → iade |
| /finans/acilis | Açılış fişleri | YOK | N | O | Kurulumda bir kez |
| /finans/borclandirmalar, /dues | Borçlandırma **listesi** | YOK | H | O | |
| /finans/borclandirmalar, /dues | **Tekil borçlandırma** | YOK | H | K | |
| /finans/borclandirmalar, /dues | **Toplu borçlandırma / aidat tahakkuku** (önizleme + işle) | YOK | A | Z | §2.2 sihirbaz |
| /finans/borclandirmalar | Ters kayıt | YOK | A | O | |
| /finans/borclandirmalar | **Gecikme faizini işle** | YOK | A | K | Önizleme mobilde var, işleme yok |
| /finans/borclular | Toplu **faiz affı**, **ödeme planı** | YOK | A | O | Hatırlatma var |
| /finans/banka | Ekstre yükle, eşleştir, işaretle, geri al, makbuz | YOK | H | Z | §2.4 |
| /finans/butce | Hedef/gerçekleşen karşılaştırma, **hedef yaz** | YOK | A | O | |
| /finans/mesai † | Mesai özeti, katsayı, gidere yaz | YOK | H | Z | Kişi × hafta matrisi → kişi kartı |
| /finans/otomasyon | Otomasyon günlüğü, hatırlatma geçmişi | YOK | H | K | Kural ekranı mobilde tam |
| /icra † | Dosya listesi, oluştur, durum, sil, ekler | YOK | A | O | |
| /sayac-okuma | Son ödeme tarihi, açıklama | KISMEN | A | K | |
| /raporlar † | **Rapor kataloğu**, parametre, göster, Excel/PDF, kuyruk | YOK | H | Z | §2.3 |
| /reports/dues | Daire bazında borçlu listesi, CSV | KISMEN | A | K | Mobilde toplam var |
| /reports/tasks | Süzgeçler, tam tablo, CSV | KISMEN | A | K | |
| /aidatim (sakin) | **Makbuz listesi + PDF** | YOK | A | K | Sakinin tek eksiği |

### 1.6 Tanımlar ve kurulum (yönetici)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /tanimlar › kasalar (banka, IBAN) | Ekle/düzenle/sil | YOK | N | K | Mobil yalnız seçim için okuyor |
| /tanimlar › gelir-gider tanımları, grupları | Ekle/düzenle/sil | YOK | N | K | |
| /tanimlar › firmalar | Ekle/düzenle/sil | YOK | A | K | Gider girerken "firma ekle" de lazım |
| /tanimlar › araç kayıtları | Ekle/düzenle/sil, plaka süzgeci | YOK | A | K | |
| /tanimlar › sayaçlar (ana/bölüm) | Ekle/düzenle/sil, bölüm sayaçlarını otomatik üret | YOK | N | K | |
| /tanimlar › muhasebe ayarları | Görüntüle/düzenle | YOK | N | K | |
| /tanimlar › görev kategorileri | Düzenle (ad, aktif) | KISMEN | N | K | Pasifi geri almak mümkün değil |
| /ice-aktarim | 4 tür (daire, kişi, açılış bakiyesi, araç): şablon, yükle, eşle, önizle, aktar, geçmiş, geri al | YOK | N | Z | §2.4 |
| /tesis-ayarlari | **Tesis konumu** (harita, adres ara) | YOK | N | O | §2.6 |
| /tesis-ayarlari | Otopark kapasitesi, eşikler, operasyon ayarları | YOK | N | K | |
| /kurulum | — | VAR | | | |

### 1.7 Profil (yönetici ve denetçi; sakin modunda da)

| Web sayfası | Eksik işlem | Mobil | Sıklık | Zorluk | Not |
|---|---|---|---|---|---|
| /profil | E-posta değiştir (kod iste, doğrula) | YOK | N | K | |
| /profil | Oturum açık cihazlar; tek cihazdan / tümünden çık | YOK | N | K | Güvenlik işi; telefondan doğal |
| /profil | Hesap etkinlik günlüğü | YOK | N | K | |
| /profil | Bağlı giriş yöntemleri, bağlantı kaldır | KISMEN | N | K | Bağlama var, kaldırma yok |
| /profil | KVKK onaylarım | KISMEN | N | K | |
| /profil | Avatar kaldır | KISMEN | N | K | Emin değilim |

### 1.8 Platform admin paneli (KAPSAM DIŞI, yalnız liste)

Hepsi web'de kalır; mobil karşılığı yok ve beklenmiyor.

* `/tenants`, `/tenants/[id]`:
  * liste, oluştur, yeniden adlandır;
  * arşivle / geri al, silme özeti ve onaylı sil;
  * yönetici ata, düzenle, sil; giriş bilgisi sıfırla.
* `/surum-politikasi`: iOS/Android asgari sürüm.
* `/settings`: tesis zaman dilimi ve operasyon ayarları (platform tarafı).
* `/support`: destek kayıtları, yanıt, durum, dosya.
  * Mobildeki destek ekranı yalnız kayıt **açıyor**.
* `/yetki`: yetki matrisi.
* `/audit`: denetim günlüğü süzgeçleri.
* `/mesaj-ayarlari`: SMS/e-posta sağlayıcı ayarı, test gönderimi.
* `/kvkk-metinler`: tesis KVKK metinleri.
* `/egitim-videolari`: video yönetimi.
* `/gonderim-gunlugu`: tüm tesislerin gönderim günlüğü.

### 1.9 Ölçümün yan bulguları (web kusurları ve menü tutarsızlıkları)

| Bulgu | Etkisi | Öneri |
|---|---|---|
| **Web'de toplu SMS/e-posta gönderilemiyor.** `/mesajlar` "Gönderim" sekmesinde yalnız önizleme var. `mesaj-gonder` BFF beyaz listesinde ama hiçbir ekran çağırmıyor (`app/(protected)/mesajlar/page.tsx`, `sonuc` hiç dolmuyor) | Yönetici gönderdiğini sanabilir | Aşama 1'de web'de düzelt (mobil eşitlikten önce) |
| P251 menü tablosu `/finans/gelirler` için "yalnız web" diyor, ama mobil bütçe ekranı gelir yazabiliyor (aynı defter) | Bilgisayardan listesi kullanıcıyı gereksiz yere web'e yolluyor | Gelir girişi Aşama 1'de "Gider" ile aynı ekrana; tablo düzeltilir |
| Yönetici mobil menüsünde **araç geçişi kaydı** yok, yalnız otopark var. Kayıt ekranı (`vehicle_pass_screen`) amirde. Web'de sayfa salt okunur | Yönetici araç girişini telefondan da göremiyor (liste) | Menüye ekle (K) |
| Admin rolünün mobil menüsünde Kişiler yok | Admin = platform; kapsam dışı olabilir | Emin değilim; karar senin |

**Ters yön** (bilgi için; bu turun konusu değil): yalnız mobilde olup web'de
olmayanlar.
* Şeffaflık ayını yayınlama/geri alma.
* Araç giriş/çıkış kaydı.
* Olay durumu değiştirme.
* Kartla aidat ödeme.
* Gider fişi fotoğrafı.
* Talebi göreve çevirme.
* Etkinlik katılım, anket oyu.
* NFC zimmet, tur okutma.

---

## 2. Zor işler için mobil tasarım önerileri

Amaç web ekranını küçültmek değil, işi telefona göre yeniden kurmak.

### 2.1 Geniş tablolar → kart listesi + "Sırala / Süz" alt sayfası

* Satır bir karttır: üstte ana bilgi, altta 2–3 ikincil bilgi. Dokununca
  detay açılır, detayda eylemler durur.
* Web'deki sütun gizleme mobilde **gerekmez**; kart zaten neyi göstereceğini
  seçmiştir. Sıralama ve süzgeç tek bir alt sayfada toplanır. Seçili süzgeç
  liste başında çip olarak görünür ve tek dokunuşla kaldırılır.
* Sayfalama yerine sonsuz kaydırma: sunucu sayfalaması (`limit/offset`) korunur.
* **Ortak bileşen:** `ListeEkrani(kart, suzgecler, siralamalar, eylemler)`. Bir
  kez yazılır, finans hareketleri, borçlandırmalar, demirbaş, icra ve
  vardiya listeleri onu kullanır. Bu, Aşama 1'in ilk işidir; sonraki her
  liste ucuzlar.

### 2.2 Aidat / borçlandırma sihirbazı (toplu tahakkuk)

Beş adım, her adım tek ekran:

1. **Ne?** Dönem (ay seçici) + kalem (gelir-gider tanımı). Varsayılan: bu ay, "Aidat".
2. **Ne kadar?** Daire başına sabit **ya da** toplam tutarı dağıt (eşit /
   arsa payı / metrekare / tip). Seçim kart düğmeleriyle; açıklama altta.
   (Otomasyon sihirbazıyla aynı dil.)
3. **Kime?** Tüm daireler / blok seç / tek tek seç (uzun bas, çoklu seç).
   Hariç tutulanlar sayıyla gösterilir.
4. **Önizleme özeti:** "143 daireye toplam 214.500 ₺; 4 daire atlandı
   (tutar tanımsız)". Daire bazında tablo **yok**:
   * özet + "en yüksek 5 / en düşük 5";
   * "atlananlar" listesi;
   * arama kutusu ("A-12 ne kadar?").

   Web'deki geniş tablo bu üç soruyu yanıtlamak içindi.
5. **Onay:** son ödeme tarihi, gecikme faizi uygulansın mı, tek düğme. Sonuç
   ekranında "Geri al" (ters kayıt partisi) 24 saat görünür.

* **Tekil borçlandırma** aynı sihirbazın 3. adımında "tek daire" seçimi.
  Ayrı ekran gerekmez.
* Önizleme sunucudan gelir: `/borclandirma/toplu/onizleme` hesabı zaten
  sunucuda. Mobil yalnız özetler.

### 2.3 Raporlar ve dışa aktarım → "Oluştur ve paylaş"

* Rapor kataloğu kategorili liste. Rapora dokununca parametre formu açılır;
  parametreler katalogdan gelir, web'le aynı kaynak (P167).
* Üç çıktı:
  * **Göster:** kısa tablo → kart listesi. 200 satırdan fazlasında "Excel
    olarak al" önerilir.
  * **Excel:** dosya oluşur, **paylaş menüsü** açılır (WhatsApp, e-posta,
    Drive, Dosyalar).
  * **PDF:** aynı.
* Ağır raporlar kuyruğa gider (P252'de düzeltilen işçi). "Hazır olunca
  bildir" ile push gelir, bildirime dokununca paylaş menüsü açılır.
  Telefonda beklemek yerine bildirim doğal yol.
* Aynı paylaş bileşeni her yerde kullanılır:
  * makbuz PDF, tatbikat raporu PDF, karar PDF, kasa ekstresi;
  * devriye/bakım/görev CSV (CSV yerine Excel önerilir; telefonda CSV açan
    uygulama zayıf).

### 2.4 Excel içe aktarım, banka ekstresi, vardiya içe aktarım → "Dosya → özet → sorunlular"

Üçü aynı kalıp:

1. **Dosyayı seç:** sistem dosya seçicisi (Drive, e-posta eki, Dosyalar,
   WhatsApp'tan "Paylaş → Yönetiyor"). Paylaşım hedefi olarak kayıt Android
   intent ve iOS share extension ister; iOS tarafı ayrı iş (§3, Aşama 3).
2. **Tür ve eşleme:** sütunlar otomatik eşlenir; başlık adları şablonla aynıysa
   eşleme ekranı **atlanır**. Eşlenemeyen sütun varsa tek ekranda "Bu sütun
   ne?" listesi gösterilir.
3. **Özet:** "187 satır geçerli, 13 sorunlu, 4 güncellenecek". Sunucu
   önizlemesi zaten var (`uygulanmadi: true`).
4. **Sorunlular:** kart başına bir satır: hata cümlesi + düzenlenebilir alan.
   "Düzelt" ya da "Bu satırı atla". Toplu: "sorunluların hepsini atla" (P193
   ilkesi: varsayılan kapalı, açık karar).
5. **Aktar:** sonuç + "Geri al" (`/ice-aktarim/{id}/geri-al` var).

* Telefonda yazılabilir en kötü durum: 13 sorunlu satırı tek tek düzeltmek.
  Bu, web'de de aynı iş.
* **Banka ekstresi:** 3. adımın karşılığı otomatik eşleştirme sonucu
  ("142 eşleşti, 18 bekliyor"). 4. adım bekleyen satırlar: "kişi seç /
  ilgisiz / masraf".

### 2.5 Toplu seçim → uzun bas, alt eylem çubuğu

* Herhangi bir listede bir satıra uzun basınca seçim kipi açılır. Üst
  çubukta "3 seçili · Tümünü seç", altta işe özel eylemler görünür:
  * borçlularda hatırlat / faiz affı / ödeme planı;
  * vardiyada sil;
  * onay bekleyen giderlerde onayla / reddet.
* Bildirimlerde bu kalıp zaten var (P251); ortak bileşene çıkarılır.

### 2.6 Harita ve konum

* **Tesis konumu:**
  * "Şu anki konumumu kullan" (tesisteyken bir dokunuş);
  * "Adres ara" (`/konum/ara` zaten var).

  Sonuç küçük bir harita önizlemesinde iğneyle gösterilir; iğne sürüklenir.
  Harita için yeni bağımlılık gerekir. **Emin değilim:** hangi harita
  paketi? Web'in kullandığı kaynakla (OSM karoları) aynı olmalı. Lisans ve
  boyut ölçülecek.
* **Devriye nokta haritası:** aynı harita bileşeni. Nokta + son okutma rengi;
  dokununca nokta kartı. Okutma "akışı" ayrı sekme (liste).
* 3D bina ve site planı mobile **taşınmaz** (§5 karar 4): mobilde 2D şema
  aynı soruyu yanıtlıyor.

### 2.7 Vardiya çizelgesi

* Gün sekmeli liste (Pzt…Paz), her gün vardiya kartları. Hafta başlığında
  ‹ › ile gezinme; "Bugün" düğmesi.
* Tek dokunuşla blok düzenleme alt sayfası açılır. Uzun bas ile seçim (§2.5)
  ve toplu sil.
* "Haftayı doldur", "Haftadan kopyala", "Yayınla", "Geri al" haftalık eylem
  menüsünde (⋮) durur.
* Web'deki kişi × gün matrisi telefonda yok; "kişi görünümü" sekmesi bir
  kişinin haftasını gösterir.

### 2.8 Fazla mesai (kişi × hafta matrisi)

* Kişi kartı: "Ahmet YILMAZ · Eylül: 15 saat fazla · 3.375 ₺". Dokununca
  haftalık döküm açılır; saat düzeltilebilir.
* Altta "Seçilenleri gidere yaz" (çoklu seçim).
* Katsayı ayarı ekranın ⋮ menüsünde.

---

## 3. Aşamalandırma

* **Kural:** her aşama kendi başına bir mobil sürümdür. Sıra "sıklık ×
  kolaylık": önce yöneticinin her gün hissedeceği kazançlar.
* **Backend:** neredeyse hiçbir iş yeni uç istemiyor; uçların hemen hepsi
  web için zaten var. İstisnalar her aşamada yazıldı.

### Aşama 0 — Eylem kilidi + ortak bileşenler (1 tur, mobil sürüm gerekmez)

Kilit önce kurulur ki ölçüm bir daha elle yapılmasın ve her aşama tablodan
bir satır kapatarak ilerlesin.

* **Eylem paritesi tablosu ve iki kilit testi** (§4).
* Mobil ortak bileşenler: `ListeEkrani` (§2.1), çoklu seçim (§2.5), "Oluştur
  ve paylaş" (§2.3; `share_plus` benzeri bağımlılık, ölçülecek).
* **Web kusuru:** `/mesajlar` gönderimi bağlanır (§1.9).

### Aşama 1 — Günlük ve kolay (3 tur) → sürüm 1.11.0

Yöneticinin her gün açtığı işler. Hepsi var olan uçlar.

| Konu | İçerik |
|---|---|
| Finans defteri | Hareket listesi (tahsilat, gider, gelir; süzgeç, arama). Kasa bazında bakiye. **Onayla / Reddet** (her onay bekleyen). Tahsilat geçmişi. Gider ve tahsilatta tarih, belge no, firma; gelir girişi gider ekranında |
| Vardiya | Hafta gezinmesi, blok düzenle, toplu sil, haftayı doldur, haftadan kopyala, her toplu işlemde geri al, yayınla, şablon ekle/düzenle/sil, döngü sonlandır |
| Kişiler | Sakin/personel/yönetici aktif-pasif, düzenle, sil. Arama ve süzgeçler. Tanılama kartı. "Aranabilir" ayarı |
| Günlük küçükler | Panik notla kapat. Ziyaretçi "içeride" süzgeci. Görev durum süzgeci ve ekleri. **Ek sil** (her yerde). Dış hizmet arama. Rezervasyon süzgeçleri. Devriye tarih aralığı. Araç geçişi yönetici menüsünde |
| Dokümanlar | Yükle (telefondan dosya veya foto), düzenle, sil, yönetim listesi |
| Hatırlatmalar ve takvim | Yöneticinin kendi notları (Özet'teki web kartının karşılığı) |
| Sakin | **Makbuz listesi + PDF paylaş** |

* Bu aşamadan sonra "Bilgisayardan yapılanlar" listesinden **Gelirler** çıkar.

### Aşama 2 — Haftalık, finans düzeltmeleri, tanımlar, denetçi (5 tur) → sürüm 1.12.0

| Konu | İçerik | Tur |
|---|---|---|
| Borçlandırma | Liste, tekil borçlandırma, **toplu tahakkuk sihirbazı** (§2.2), ters kayıt, gecikme faizini işle, daire borç durumu (daire detayında) | 1,5 |
| Finans düzeltmeleri | İptal (ters kayıt), virman, iade, toplu tahsilat, faiz affı, ödeme planı | 1 |
| Raporlar | Katalog, parametre, göster, Excel/PDF paylaş, kuyruk + "hazır" bildirimi (§2.3). Dışa aktarımların hepsi buradan | 1 |
| Tanımlar | Kasalar, gelir-gider tanım/grup, firmalar, araç kayıtları, sayaçlar (+otomatik üret), muhasebe ayarları, görev kategorisi düzenle. **Tek genel defter ekranı:** web `tanimlar.tsx` gibi alan listesiyle sürülür, defter başına ayrı ekran yazılmaz | 1 |
| Tesis ayarları | Otopark ve operasyon ayarları; **tesis konumu** (§2.6) | 0,5 |
| Denetçi mobil yüzeyi | Salt okuma: raporlar, şeffaflık, icra, bakım, mesai (§5 karar 1) | (Raporlarla birlikte) |

* Sonra "Bilgisayardan yapılanlar"dan çıkanlar: **Aidat, Borçlandırmalar,
  Virman, İade.**

### Aşama 3 — Aylık/nadir ve zor (4–5 tur) → sürüm 1.13.0 (gerekirse 1.14.0)

| Konu | İçerik | Tur |
|---|---|---|
| Excel içe aktarım | 4 tür, §2.4 kalıbı; Android paylaşım hedefi. iOS share extension ayrı (emin değilim: bir tur daha gerekebilir) | 1,5 |
| Banka ekstresi | §2.4 kalıbıyla | 1 |
| Fazla mesai, maaş kartları listesi, bütçe hedefleri, açılış fişleri | §2.8 + liste ekranları | 1 |
| İcra, karar defteri, SMS/e-posta | Liste + form + PDF paylaş; mesajda alıcı süzgeci ve önizleme özeti | 1 |
| Kalanlar | Akıllı ev kurulumu (köprü, cihaz, senaryo). Demirbaş kaydı (§5 karar 3). Arsa payı toplu. Daire m²/arsa payı. Devriye haritası. Vardiya Excel içe/dışa. Bakım yıllık özet. Tatbikat PDF. Kamera bağlantı testi. Profil (cihazlar, e-posta değiştir, etkinlik, bağlantı kaldır) | 1 |

* **Aşama 3 sonunda "Bilgisayardan yapılanlar" ekranı silinir.** Kilit tablosunda
  `yalniz_web` satırı kalmaz; yalnız `yapisal` ve platform satırları kalır.

### Sıra neden böyle

* **Aşama 1:** en çok hissedilecek kazanç "kim ödedi", "bu gideri onayla" ve
  "vardiyayı gelecek haftaya kopyala". Üçü de her gün, üçü de kolay.
* **Aşama 2:** toplu tahakkuk ayda bir yapılır ama yanlış yapılırsa
  pahalıdır. Sihirbaz bu yüzden aceleye getirilmez; raporlarla aynı aşamada,
  çünkü ikisi de "Oluştur ve paylaş" bileşenini kullanır.
* **Aşama 3:** içe aktarım ve banka yılda birkaç kez yapılır; telefonda
  yapılabilir olması değerli ama acil değil.

---

## 4. Kilit önerisi — menü kilidini eylem düzeyine genişletmek

P251 menü kilidi yalnız **menü öğesini** karşılaştırıyor. Bu ölçüm,
menüde "ayni" görünen sayfalarda bile onlarca eksik eylem buldu (Vardiya
planı, Kişiler, Dokümanlar). Kilit **eylem (backend ucu)** düzeyine inmeli.

### 4.1 Tek kaynak: `contracts/eylem-paritesi.tsv`

```
web_rota   yontem  uc                              mobil   durum       gerekce
/finans    GET     /finans/hareketler              finans  ayni        -
/finans    POST    /finans/hareketler/{id}/iptal   -       planli:2    Aşama 2 (ters kayıt)
/tenants   POST    /tenants                        -       platform    Platform paneli
/dashboard PUT     /me/pano-tercihi                -       yapisal     Mobil ana ekran ızgarası ayrı kavram (/me/ana-ekran-izgarasi)
```

* `durum` değerleri:
  * `ayni` (mobilde aynı uç çağrılıyor);
  * `yapisal` (iş iki yüzeyde de var, uç farklı; gerekçe zorunlu);
  * `planli:N` (aşama N'de yapılacak);
  * `platform` (kapsam dışı);
  * `yalniz_web` (gerekçe zorunlu; hedef sıfır).

### 4.2 Web kilidi (vitest)

* `app/` ve `components/` altındaki her `apiSend` / `useSWR` / `agIstegi`
  çağrısındaki `/api/...` adresi taranır.
  `panel-vekil.ts` + `tanimlar.ts` + `app/api/**/route.ts` ile backend
  ucuna çevrilir.
* **Tabloda olmayan bir (metot, uç)** → test düşer: "Web'e yeni bir eylem
  eklendi; mobil karşılığını yaz ya da gerekçeyle tabloya ekle."
* Adres çevirisi bugün P248 SQL taraması ve P236 genişlik taraması gibi
  kaynak taramalarıyla aynı yöntem (`tests/tarama.ts`).

### 4.3 Mobil kilidi (flutter test)

* `lib/src/features/**/data/*_api.dart` dosyalarındaki Dio çağrıları
  (`_dio.get('/…')`, metot + yol) taranır.
* Tabloda `ayni` olan her satırın ucu mobilde **gerçekten çağrılıyor mu**
  bakılır; çağrılmıyorsa test düşer. Bu, "tabloya ayni yazıp yapmamak"
  kaçağını kapatır.
* `planli:N` satırı, `pubspec.yaml` sürümü o aşamanın sürümüne ulaşınca
  **kırmızı** olur: "Aşama N yayımlandı ama bu satır hâlâ planlı".

### 4.4 Sözleşme kilidi (backend, pytest)

* `contracts/openapi.yaml`daki her uç, ya tabloda ya da açık bir "web'de
  yok" listesinde olmalı (örneğin yalnız mobil uçları, webhook'lar).
* Yeni uç eklenince üç yüzeyden biri düşer. Sessiz kalamaz.

### 4.5 Ek kurallar

* **Rol de kilitlenir:** tabloya `roller` sütunu. Web `ROTA_ROLLERI` ile mobil
  menü rolü karşılaştırılır. Bu ölçümde rol tutarsızlığı çıktı (yönetici
  araç geçişi), menü kilidi bunu görmüyordu.
* **İstemci tarafı eylemler** (CSV indir, sütun gizle) uç üretmez. Bunlar
  için tabloda `istemci:<ad>` satırı ve web kaynağında
  `data-eylem="csv-indir"` işareti. Emin değilim: bu kısım kırılgan olabilir;
  Aşama 0'da örnekle denenip karar verilmeli.
* Mevcut `menu-paritesi.tsv` **kalır** (menü adı ve grup kilidi). Yeni tablo
  onu tamamlar, yerini almaz.

---

## 5. Senin kararın gereken noktalar

| # | Soru | Önerim |
|---|---|---|
| 1 | **Denetçi mobilde çalışsın mı?** P128/P129'da "masa işi, web'e yönlendir" denmişti. "Her işlem" hedefi bunu geri açıyor | Evet, Aşama 2'de salt okuma: raporlar (paylaş), şeffaflık, icra, bakım, mesai. Denetçi raporu toplantıya telefondan getirebilir |
| 2 | **Platform admin** mobil menüsü (Kişiler yok vb.) bu kapsamda mı? | Hayır; admin platform rolü, kapsam dışı. Admin'in **tesis yüzeyi** gerekiyorsa söyle |
| 3 | **Demirbaş kaydı** yöneticiye mobilde açılsın mı? P251'de "mobil ekran saha zimmet aracı" diye ayrılmıştı | Evet, ama ayrı sekme: "Envanter" (yönetici) / "Zimmet" (saha). Aynı ekranda karışmasın. Aşama 3 |
| 4 | **3D bina sahnesi ve site planı** mobile gelsin mi? | Hayır; 2D şema aynı soruyu yanıtlıyor. Tabloda `yapisal` olarak gerekçelenir |
| 5 | **Web tablo araçları** (sütun gizleme, sayfa boyu) mobilde karşılık istiyor mu? | Hayır; §2.1 kart + sırala/süz yeterli. Tabloda tek `yapisal` satırı |
| 6 | Paylaşım hedefi (WhatsApp'tan "Yönetiyor'a gönder") **iOS'ta da** olsun mu? | Android Aşama 3'te; iOS share extension ayrı imzalama ve hedef ister, ayrı tur |
| 7 | Web'deki mesaj gönderim kusuru (§1.9) bu turdan bağımsız hemen düzeltilsin mi? | Evet, Aşama 0'da; yönetici "gönderdim" sanıyor olabilir |
| 8 | Harita paketi (tesis konumu, devriye haritası) için yeni mobil bağımlılık kabul mü? | Ölçüp öneririm (boyut + lisans), Aşama 2 başında |

---

## 6. Ölçümün sınırları (dürüstlük notu)

* Sıklık tahmindir. Uygulama kullanım verisi (hangi web sayfası ne kadar
  açılıyor) yok. Varsa sırayı o belirlemeli. Web erişim günlüğünden
  çıkarılabilir; istersen Aşama 0'da ölçerim.
* Eşleştirme uç düzeyinde yapıldı. Aynı ucu çağıran iki ekranın aynı
  **alanları** gönderip göndermediği yalnız örnekleme ile bakıldı (tahsilat,
  gider, sayaç). Aşama 0 tablosu doldurulurken her satır bu gözle yeniden
  okunacak.
* "Emin değilim" satırları:
  * bildirim sayfalaması;
  * şema plan haritası;
  * avatar kaldırma;
  * mobil özet ekranında kasa kırılımı;
  * admin menüsü;
  * vardiya kişi penceresinin içeriği.
