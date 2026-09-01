# P192 — Finans modülü uçtan uca test yol haritası

Sıfırdan bir tesiste finans modülünü baştan sona sürmek için adım adım
liste. Her adımda **ne yapılacak** ve **ne görülmesi gerektiği** yazılı.

> **Kullanım:** sırayla ilerleyin. Bir adımın "görülmesi gereken"i
> çıkmıyorsa durun — sonraki adımlar onun üzerine kuruluyor.
>
> **Roller:** aksi yazmadıkça *yönetici* (ya da *admin*) ile giriş yapın.
> Sakin adımları ayrıca işaretli.

---

## Hazırlık

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 0.1 | Yeni tesis oluşturun (ya da boş bir test tesisi kullanın) | Panelde `/dashboard` açılıyor |
| 0.2 | Daireler → en az **4 daire** ekleyin (A blok) | Daire listesi 4 satır |
| 0.3 | Kullanıcılar → en az **2 sakin** ekleyin ve dairelere bağlayın (malik) | Daire detayında sakin görünüyor |
| 0.4 | Bir daireye **arsa payı 30**, bir diğerine **10** girin, ikisini boş bırakın | Daire formunda "Arsa payı" alanı var |

---

## 1. Kasa ve banka hesabı

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 1.1 | Finans → Kasalar → *Yeni*: kod `KASA`, ad "Merkez Kasa", açılış bakiyesi **5.000 ₺** | Kasa listesinde görünüyor |
| 1.2 | Aynı yerden ikinci kayıt: kod `BANKA`, ad "Site Banka", **Banka hesabı** işaretli, IBAN girin | Kayıt kabul ediliyor (IBAN yalnız banka kasasında dolabilir) |
| 1.3 | Finans → ana sayfa | Kasalar tablosunda iki satır; **Bekleyen** sütunu boş (`—`); genel toplam 5.000 ₺ |

**Not:** IBAN'ı banka olmayan bir kasaya girmeye çalışırsanız reddedilir —
bu kasıtlıdır (ödeme yanlış hesaba yönlenmesin).

---

## 2. Gelir/gider tanımı ve bütçe kategorisi

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 2.1 | Tanımlar → Gelir/Gider Tanımları → *Yeni*: "Aidat", tip **gider**, hedef kuralı *kiracı öncelikli* | Listede görünüyor |
| 2.2 | Aynı yerden: "Çatı onarımı", tip **gider** | Listede görünüyor |
| 2.3 | Finans → Bütçe → kategori seçimi için önce bir bütçe kategorisi gerekiyorsa Bütçe modülünden "Bakım" (gider) ekleyin | Kategori listesinde görünüyor |

---

## 3. Tahakkuk (borç yazma)

### 3.1 Tekil tahakkuk

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 3.1.1 | Finans → Borçlandırmalar → *Yeni*: daire seçin, tür "Aidat", tutar **500 ₺**, son ödeme = bugün + 15 gün | "Kaydedildi" bildirimi |
| 3.1.2 | Daireler → o daire → Aidat sekmesi | Bakiye **500 ₺** |

### 3.2 Aynı aya ikinci kalem (P192 §3.2)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 3.2.1 | Aynı daireye, **aynı dönem** için tür "Çatı onarımı", tutar **200 ₺** | Kabul ediliyor (409 **yok**) |
| 3.2.2 | Daire bakiyesi | **700 ₺** |
| 3.2.3 | Aynı daireye, aynı dönem, **aynı tür** ile tekrar deneyin | **409** — mükerrer koruması duruyor |

### 3.3 Toplu tahakkuk + dağıtım (§3.3)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 3.3.1 | Borçlandırmalar → *Toplu*: tür "Aidat", **Dağıtım = Arsa payına göre**, dağıtılacak toplam **4.000 ₺**, *Önizle* | Önizlemede yalnız arsa payı girilmiş 2 daire; toplam 4.000 ₺ |
| 3.3.2 | Önizlemedeki uyarı listesi | Arsa payı girilmemiş 2 daire **"Arsa payı girilmemiş"** nedeniyle listeleniyor |
| 3.3.3 | *Kaydet* | Kırmızı bildirimde atlanan daireler adlarıyla görünüyor (sessiz atlama **yok**) |
| 3.3.4 | Payları kontrol edin | 30/10 oranında: **3.000 ₺** ve **1.000 ₺** |
| 3.3.5 | Aynı akışı **Dağıtım = Metrekareye göre** ile deneyin (metrekare girilmemişse) | Hepsi atlanıyor ve nedeni yazıyor |

### 3.4 Tahakkuk düzeltme (§6.3)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 3.4.1 | Yanlış bir tahakkuk yazın (örn. 9.999 ₺) | Bakiye 9.999 ₺ arttı |
| 3.4.2 | O tahakkuku **ters kayıtla** düzeltin (uç: `POST /dues/assessments/{id}/ters-kayit`) | Bakiye eski hâline döndü |
| 3.4.3 | Tahakkuk listesi | Ne yanlış kayıt ne ters kayıt listede — ikisi de borç değil |
| 3.4.4 | Aynı tahakkuku ikinci kez ters kayıtlamayı deneyin | **409** |

---

## 4. Tahsilat — üç yol, tek defter (§1)

### 4.1 Vezneden tahsilat borcu kapatır

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 4.1.1 | Finans → Tahsilatlar → *Yeni*: kişi seçin, kasa `KASA`, tutar **500 ₺** | "Kaydedildi" |
| 4.1.2 | Finans ana sayfa → Kasalar | `KASA` bakiyesi **5.500 ₺** |
| 4.1.3 | Tahsilatı bir **tahakkuka bağlayarak** tekrarlayın (uç `assessment_id` alıyor; panelde daire seçin) | O dairenin bakiyesi tahsilat kadar **düştü** |

> Bu adım P192 §1'in kalbi: eskiden vezne tahsilatı kasayı artırır ama
> **borcu kapatmazdı**.

### 4.2 Aidat tahsilatı kasayı artırır

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 4.2.1 | Daire → Aidat → ödeme kaydı (uç `POST /dues/payments`, kasa seçmeden) | Kayıt oluşuyor |
| 4.2.2 | Finans → Kasalar | Bir kasa bakiyesi **arttı** (yöntem *havale/kart* ise BANKA, *elden* ise KASA) |
| 4.2.3 | Finans → Hareketler listesi | Aynı satır burada da var |

### 4.3 Çift tıklama koruması (§6.2)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 4.3.1 | Tahsilat formunu doldurup **hızlıca iki kez** kaydedin (ya da ağı yavaşlatıp tekrar deneyin) | Kasada **tek** hareket; ikinci istek aynı kaydı döndürür |

---

## 5. Gider ve onay akışı (§2.2, §2.3)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 5.1 | Finans → Giderler → *Yeni*: tutar **1.200 ₺**, kasa `KASA`, **durum = Onay bekliyor** | Kayıt oluşuyor |
| 5.2 | Finans → Kasalar | Bakiye **değişmedi**; **Bekleyen** sütununda 1.200 ₺ |
| 5.3 | Gideri **onaylayın** (`POST /finans/hareketler/{id}/onayla`) | Bakiye 1.200 ₺ **düştü**, bekleyen sıfırlandı |
| 5.4 | İkinci bir gideri onay bekleyen yazıp **reddedin** | Bakiye değişmedi, bekleyen de sıfır (reddedilen "bekleyen" değildir) |
| 5.5 | Aynı gideri ikinci kez onaylamayı deneyin | **409** |

---

## 6. Gecikme faizi (§3.1)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 6.1 | Bir daireye **vadesi 70 gün geçmiş** 1.000 ₺ tahakkuk yazın (son ödeme tarihini geriye alın) | Bakiye 1.000 ₺ |
| 6.2 | Borçlandırmalar → **Gecikme faizi** kartı: *Gecikme faizi uygula* açık, aylık oran **%5** | Kart "2 borç için toplam … faiz işlenecek" diyor |
| 6.3 | *Faizi işle* | "n faiz kalemi yazıldı"; daire bakiyesi **1.100 ₺** (2 tam ay × %5) |
| 6.4 | *Faizi işle*'ye **tekrar** basın | Bakiye değişmiyor (idempotent) |
| 6.5 | Ana borcu tahsil edin | Bakiye **100 ₺** — faiz **buharlaşmıyor** |
| 6.6 | Faiz kalemini de tahsil edin | Bakiye **0** |
| 6.7 | *Gecikme faizi uygula*'yı kapatın, yeni bir gecikmiş borç yazın, *Faizi işle* | "İşlenecek gecikme faizi yok" |

---

## 7. Borçlular ekranı (§5.1–5.3)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 7.1 | Finans → Borçlular | Üstte **tahsilat oranı**, altında dört kova düğmesi |
| 7.2 | Vadesi 10 / 45 / 200 gün geçmiş üç borç yazın (üç ayrı daire) | Kovalar sırasıyla **0-30**, **31-60**, **90+** |
| 7.3 | Bir daireye hem 10 hem 200 günlük borç yazın | Daire **tek** kovada (90+) ve **toplam** kalanıyla |
| 7.4 | Bir kovaya tıklayın | Daire listesi açılıyor: daire, borçlu, gecikme günü, kalan |
| 7.5 | İki daire seçip *Hatırlatma gönder* | "n hatırlatma gönderildi"; borcu kapanmış daire varsa atlanır |
| 7.6 | Faizi olan bir daire seçip *Faizi affet* | Faiz kalemi bakiyeden düştü, ana borç durdu |
| 7.7 | Bir daire seçip *Ödeme planı*: 3 taksit, ilk vade gelecek ay | Bakiye **değişmedi**, vadeler aylık yayıldı |
| 7.8 | Hiç daire seçmeden düğmelere basmayı deneyin | Düğmeler pasif |

### Tahsilat oranı tek kaynak mı?

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 7.9 | Borçlular ekranındaki oranı not edin; Raporlar → *Mali özet* (aynı dönem) | **Aynı** tahakkuk, **aynı** tahsilat, **aynı** oran |
| 7.10 | Şeffaflık → aynı ay | Aidat bloğundaki tahakkuk/tahsilat da aynı |

---

## 8. Otomasyon (§4)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 8.1 | Finans → Otomasyon → *Yeni plan*: tür "Aidat", tutar **500 ₺**, tahakkuk günü **1**, vade **15**, önizleme **3** | Plan listede, "İşlenen son dönem" boş |
| 8.2 | Görevi elle tetikleyin (bkz. `docs/P192-dagitim.md` §3) | Ayın 1'i geçtiyse tahakkuklar yazıldı |
| 8.3 | Tekrar tetikleyin | Bakiyeler **değişmiyor** (idempotent) |
| 8.4 | Otomasyon günlüğü kartı | "Otomatik tahakkuk", dönem, adet, tutar satırı var |
| 8.5 | Plan satırında *Bu ayı atla* → görevi tetikleyin | Tahakkuk yazılmadı; günlükte `durum: ertelendi` |
| 8.5b | Bir ayı hiç tetiklemeyin, sonraki ayın başında tetikleyin | **Atlanan ay** yazılır (telafi), tahakkuk tarihi kendi ayından; ikinci tetiklemede sıradaki ay |
| 8.6 | **Hatırlatma** kartı: *Etkin*, vade öncesi **3**, kademeler `3, 10, 30` | Kaydediliyor |
| 8.7 | Görevi tetikleyin | Ödemeyen sakinlere bildirim; **ödeyene gitmiyor** |
| 8.8 | Aynı gün tekrar tetikleyin | İkinci bildirim **yok** |
| 8.9 | **Düzenli gider**: "Kapıcı maaşı" 15.000 ₺, aylık, sonraki tarih = bugün | Kayıt oluştu |
| 8.10 | Görevi tetikleyin | Kasalar → **Bekleyen** sütununda 15.000 ₺; bakiye değişmedi |
| 8.11 | Düzenli gider listesi | "Sonraki tarih" bir ay ileri atıldı |
| 8.12 | Görevi tekrar tetikleyin | İkinci gider **yazılmadı** |

---

## 9. Banka entegrasyonu (§2.1, §4.3)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 9.1 | Bir sakinin ödeme kodunu öğrenin (sakin → *Öde* ekranı ya da kullanıcı kaydı) | 6-8 karakterlik kod |
| 9.2 | Finans → Banka → ekstre içe aktar: **hesap = Site Banka**, satır: bugün, tutar = dairenin borcu, açıklama `HAVALE <kod> AIDAT` | "1 eklendi" |
| 9.3 | *Eşleştir* | Hareket `eslesti`; daire bakiyesi **kapandı** |
| 9.4 | Finans → Kasalar | **Site Banka** bakiyesi tahsilat kadar arttı; genel toplam = satırların toplamı |
| 9.5 | Aynı ekstreyi **tekrar** yükleyin | "0 eklendi, 1 yinelenen" |
| 9.6 | Ekstreye **çıkış** yönlü bir satır ekleyin (örn. `BANKA MASRAFI`, 25 ₺) ve eşleştirin | Kasalarda **Bekleyen çıkış** 25 ₺; bakiye değişmedi |
| 9.7 | O gideri onaylayın | Banka bakiyesi 25 ₺ düştü |
| 9.8 | **Sakin olarak** giriş yapın → **Aidatım** sayfasının altındaki *Makbuzlarım* bölümü | Eşleşen ödemenin makbuzu listede; PDF bağlantısı açılıyor |

---

## 10. Bütçe ve sapma (§5.4)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 10.1 | Finans → Bütçe: yıl = bu yıl, kategori "Bakım", hedef **12.000 ₺** → *Hedef belirle* | Tabloda satır: hedef 12.000 ₺ |
| 10.2 | Bütçe defterine "Bakım" kategorisinde **1.500 ₺** gider yazın | Tabloda gerçekleşen 1.500 ₺ |
| 10.3 | Sapma sütunu | Negatif (hedefin altında) ve **yeşil** |
| 10.4 | Aynı kategoriye 15.000 ₺ daha yazın | Sapma pozitif ve **kırmızı** (bütçe aşıldı) |

---

## 11. Raporlar ve muhasebeye aktarım (§5.5)

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 11.1 | Raporlar → **Muhasebeye Aktarım**, tarih aralığı = bu ay, biçim *tablo* | Satırlar: tarih, belge no, tür, açıklama, **borç**, **alacak**, kasa, daire, dönem |
| 11.2 | Toplamlar | Alacak = dönemdeki tahsilat + gelir; borç = onaylanmış giderler |
| 11.3 | Onay bekleyen bir gider yazıp raporu tekrar alın | O satır **yok** (yalnız gerçekleşenler) |
| 11.4 | Biçim *excel* | `.xlsx` iniyor, sütunlar aynı |
| 11.5 | Raporlar → **Borç-Alacak** ve **Tahsilat performansı** | Rakamlar Borçlular ekranıyla tutuyor |

---

## 12. Şeffaflık ve sakin görünümü

| # | Yapılacak | Görülmesi gereken |
|---|---|---|
| 12.1 | Şeffaflık → bu ay → *Yayınla* | Yayınlandı |
| 12.2 | **Sakin olarak**: Şeffaflık | Ay özeti görünüyor; ad/daire **yok** |
| 12.3 | **Sakin olarak**: Aidatım | Borcu, ödemeleri ve (varsa) faiz kalemi görünüyor |
| 12.4 | **Sakin olarak**: Aidatım → *Makbuzlarım* | Yalnız **kendi** makbuzları |

---

## 13. Kapanış kontrolleri

| # | Kontrol | Beklenen |
|---|---|---|
| 13.1 | Kasalar genel toplamı = satırların toplamı | Tutuyor |
| 13.2 | Aynı dönemin tahsilat oranı: Borçlular / Mali özet / Şeffaflık | Üçü de aynı |
| 13.3 | Denetim kaydı (Denetim ekranı) | Tahsilat, gider onayı/reddi, faiz affı, bütçe yazma satırları var |
| 13.4 | Otomasyon günlüğü | Tetiklenen her görev için satır |
| 13.5 | **Denetçi** rolüyle giriş | Borçlular ve Otomasyon **okunuyor**; toplu işlem düğmeleri **yok** |
| 13.6 | **Sakin** rolüyle `/finans/*` | Erişilemiyor |
