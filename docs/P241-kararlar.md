# P241 — kararlar

İki bölüm: periyodik bakım takibi (§1), vardiya ekranı yeniden tasarım
(§2). Her bölüm ayrı commit.

---

# §1 — PERİYODİK BAKIM TAKİBİ

## §1.0 ÖNCE ÖLÇÜM — "Demirbaş modülüne mi bağlansın?"

İstek bunu açıkça sordu. Ölçtüm.

**`asset` (Demirbaş) tablosunun tuttuğu şey:**

| Alan | Değer |
|---|---|
| `ad`, `aciklama`, `aktif` | — |
| `kategori` | ekipman / araç / alet / diğer |
| `durum` | müsait / **zimmetli** / bakımda |
| `nfc_tag_uid` | etiket okutma |
| + `asset_checkout` | `alan_user_id`, `birakan_user_id`, zaman damgaları |

Yani demirbaş **kime zimmetlendiğini** takip eder: taşınabilir, elden ele
geçen, geri getirilmesi beklenen eşya (matkap, telsiz, araç). Modülün
tamamı — ikinci tablo dahil — bu soruyu yanıtlamak için var.

**Bakım takibinin sorduğu soruların HİÇBİRİ orada yok:** konum yok,
periyot yok, geçmiş bakım kaydı yok, maliyet yok, yasal zorunluluk yok,
sonraki tarih yok.

**Karar: AYRI MODÜL.** Gerekçe tek cümleyle: **asansör kimseye
zimmetlenmez.** Asansörü `asset`e koymak, `asset_checkout` tablosunu onun
için anlamsız kılar ve "müsait / zimmetli" durumunu bir asansör için
yorumlanamaz hale getirirdi.

**Ama köprülü:** `bakim_ekipmani.asset_id` **opsiyonel**. Jeneratörü
demirbaş olarak da kaydetmiş bir site iki ayrı kayıt tutmak zorunda
kalmasın.

**Üçüncü bir komşu daha var:** `duzenli_gider` — tablonun kod içindeki
örneği bile "asansör bakımı". Ama o **parayı** tutuyor (her ay çıkan
tutar), bu modül **tarihi ve uygunluğu** (ne zaman yapıldı, ne zaman
yapılmalı, yasal mı). İkisi ayrı sorular; bağ kurmak isteyen bakım
kaydına gider yazdırabilir (aşağıda).

## §1.1 Şema kararları

**`sonraki_bakim` türetilmiyor, SÜTUN.** `son_bakim + periyot` her zaman
doğru değil: asansör muayenesi firmanın takvimine göre kayar. İstek de
"otomatik hesaplansın, **elle de değiştirilebilsin**" diyor — türetilmiş
bir ifade elle değiştirilemez. Hesaplama **yazarken** yapılır.

**`durum` sütun DEĞİL, türetiliyor.** Sütun olsaydı her gece bir işin onu
güncellemesi gerekirdi ve iş koşmadığı gün **gecikmiş bir yasal kontrol
"tamam" görünürdü**. Tarih aritmetiği ucuz, yanlış gösterilen bir yasal
kontrol pahalı.

**Ay = 30 gün DEĞİL.** "6 aylık" bakım aynı ayın gününe gitmeli; gün
sayısıyla çarpmak yılda iki kez yapılan bir bakımı her seferinde
kaydırırdı. 31 Ocak + 1 ay = **28 Şubat** (ayın sonuna kırpılır); kırpma
olmasaydı ayın 31'inde girilen bir bakım kaydı 500 verirdi. Ölçüldü:
`test_AY_SONU_TASMASI_KIRPILIR`.

**`tur` serbest metin, enum değil.** Enum olsaydı "su arıtma" ekleyen bir
site göç beklemek zorunda kalırdı. Sabit liste **arayüzde** önerilir.

**Uyarı eşiği iki katmanlı:** `tenant.bakim_uyari_gun` (varsayılan 30) +
ekipman başına `uyari_gun`. Tek eşik, yangın tüpünü (30 gün yeter) ile
asansör muayenesini (randevu için 60 gün gerekir) aynı kefeye koyardı.
İstek "ekipmana göre farklı olabilir mi?" diye sordu — **evet, olmalı.**

## §1.2 Bildirimler — üç kademe, üç damga

`yaklasti` / `bugun` / `gecikti` **ayrı ayrı** damgalanır. Tek damga
olsaydı, "yaklaşıyor" bildirimi gönderilen bir ekipman için **"bugün"
bildirimi hiç gitmezdi** — yani en önemli gün sessiz geçerdi.

**Gecikmede HER GÜN hatırlatma YOK — haftada bir.** İstek "bildirim
yorgunluğunu gözet, karar ver ve gerekçelendir" dedi. Gerekçe: unutulmuş
bir yangın tüpü için ayda 30 bildirim, tüpün bakılmasını sağlamaz;
kullanıcının **bildirimleri kapatmasını** sağlar. Ve kapatılan kanal
panik alarmını da taşıyor (P240 §1). Haftalık tekrar hatırlatmaya yetiyor,
kapatmaya itmiyor. Ölçüldü: `test_GECIKME_HER_GUN_DEGIL_HAFTADA_BIR`.

**Kime gidiyor:** yönetim (admin + yönetici) üç kademeyi de alır. **Saha
yalnız `bugun` kademesini alır** — kapıda duran görevli "bugün asansör
firması gelecek" bilgisini *kullanır* (geleni içeri alır); "3 hafta sonra
bakım var" bilgisi onun işine yaramaz, yalnız kutusunu doldurur. **Sakin
hiç almaz:** bu bir işletme kaydı.

**Bildirim satırı `user_id = NULL`** — tesis alarmı. Kişi başına satır
yazmak onu GÖRÜNMEZ kılardı (`notifications._kapsam`, P240 §4'te
ölçülmüştü).

**Beat günde bir koşuyor.** Bakım tarihleri gün çözünürlüklü; 15 dakikada
bir koşmak aynı gün içinde hiçbir yeni bilgi üretmezdi.

**Tarih değişince damgalar temizlenir** (bakım kaydı girilince de, tarih
elle değiştirilince de): yeni dönem yeniden bildirilsin.

## §1.3 Bakım kaydı — üç iş tek işlemde

Kayıt yazılır **+** `son_bakim`/`sonraki_bakim` ilerler **+** tutar
girildiyse deftere gider düşer. Üçü aynı işlemde; ikisi yazılıp üçüncüsü
yazılmazsa "bakım yapıldı ama tarih ilerlemedi" ya da "para çıktı ama
bakım kaydı yok" gibi **kendini gizleyen** bir tutarsızlık olurdu.

**Maliyet deftere yazılır mı? EVET — onay bekleyen gider olarak.** İstek
"değerlendir; yazılacaksa onay bekleyen gider olarak (P192 kuralı)" dedi.
Yazmamak, yıl sonunda "bakımlara ne kadar ödedik" sorusunu yanıtsız
bırakırdı. `durum='odendi'` **yazılmaz**: kaydı giren kişi (bakımı yapan
görevli de olabilir) harcamayı onaylamış sayılmamalı. Onay/red uçları
finansta zaten var. Bedel başka bir faturaya dahilse `gidere_yaz=false`.

**Tutar hem kayıtta hem defterde durur ama tek gerçek defterdedir:**
`hareket_id` o satırı gösterir. Tutarı burada tutup deftere yazmamak, iki
farklı "toplam bakım gideri" üretirdi.

**Fotoğraf ve belge: var olan ek mekanizması.** Ayrı bir `bakim_eki`
tablosu **açılmadı** — `varlik_eki` + `/ekler` zaten çalışıyor ve
`VARLIKLAR` kaydına `bakim_kaydi` + `bakim_ekipmani` eklendi (göç, CHECK
kümesini genişletiyor). Asansör muayene raporu da gider fişi de aynı
şeydir: bir kaydın yanındaki kanıt.

## §1.4 Görünüm

**Renk tek başına anlam taşımıyor:** her satırda rozetin **yanında** gün
sayısı yazılı ("12 gün kaldı" / "4 gün gecikti"). Renk körlüğü bir yana,
**yazdırılan bir listede renk kaybolur** ve denetime verilen kâğıtta
"hangisi gecikmişti" sorusu yanıtsız kalırdı. Mobilde de aynı (test:
`GUN SAYISI YAZILI`). Gecikme "−4 gün kaldı" diye değil "4 gün gecikti"
diye yazılıyor — negatif gün anlamsız bir cümledir.

**Sıralama sunucuda:** en yakın tarih üstte. Gecikmişler tarihleri
geçmişte olduğu için doğal olarak en başta — ayrı bir "önce gecikmişler"
kuralı, 3 ay önce gecikmiş bir kaydı **bugün** yapılacak olanın üstüne
çıkarırdı.

**Durum süzgeci tüm kayıtları tarar.** Türetilmiş alan SQL'de
süzülemiyor; sayfalamadan sonra süzmek "gecikmiş yok" yanılgısı üretirdi.
Ölçüldü: `test_DURUM_SUZGECI_TUM_KAYITLARI_TARAR`.

**Takvim görünümü: YAPILMADI ve bu bir karar.** Değerlendirdim: bakım
kayıtları yılda 1–4 kez tekrar eden, onlarla ölçülen sayıda olaydır. Bir
ay takviminde çoğu gün boş kalır; "yaklaşan bakım" sorusunu sıralı liste
takvimden daha iyi yanıtlar (kaç gün kaldığı doğrudan yazılı). Takvim,
vardiya gibi **her gün doluluk** olan verilerde kazanıyor — §2'de orada
yapılıyor.

## §1.5 Roller

| | ekipman/kayıt yaz | liste oku | yıllık özet |
|---|---|---|---|
| admin, yönetici | ✓ | ✓ | ✓ |
| denetçi | ✗ | ✓ | **✓** |
| güvenlik amiri, güvenlik, tesis görevlisi | ✗ | ✓ | ✗ |
| sakin | ✗ | **✗** | ✗ |

Denetçi özeti okur: rapor site işletmesinin belgesidir. Sakin görmez: bu
bir işletme kaydı, kişisel bir hizmet değil.

**Web'de sayfa admin+yönetici+denetçi'de.** Saha rolleri sunucuda listeyi
okur ama `app.*`ta sayfa görmez (P129) — onların yüzeyi **mobil**, ve
orada kayıt düğmesi çizilmez.

## §1.6 Yıllık rapor

`yasal_eksik`: yasal zorunlu olduğu halde yıl içinde **hiç bakım
görmemiş** ekipmanlar, toplamların arasında değil **ayrı alanda**.
Denetimin ilk soracağı şey budur ve bir toplamın içinde kaybolmamalı.

## §1.7 ÖLÇTÜĞÜM — istekteki doğrulama cümlesi

> "Bir asansör bakımı tanımla, periyodunu 6 ay yap, yaklaşan bildirimini
> gör, bakım kaydı gir, sonraki tarihin ilerlediğini gör."

`test_ASANSOR_AKISI_bastan_sona` bunu **gerçekten sürüyor** (taklit yok):

1. "A Blok asansörü", 6 aylık, yasal, bakım 10 gün sonra →
   `durum=yaklasti`, `kalan_gun=10`.
2. Hatırlatma işi **gerçekten koşuldu** → veritabanında `bakim_yaklasti`
   satırı, `user_id IS NULL`.
3. Bakım kaydı + 4.800 TL fatura girildi → defterde `onay_bekliyor`
   gider satırı oluştu.
4. `sonraki_bakim` **altı ay ilerledi**, durum `planli`ya döndü.
5. Yıllık özette 1 bakım / 480000 kuruş, `yasal_eksik`te **değil**.

22 test yeşil.

## §1.8 ÖLÇEMEDİĞİM

* **Gerçek push bildirimi** cihaza düşmedi: bu makinede emülatör yok ve
  dev'de kayıtlı cihaz yok (`PUSH hedef yok` uyarısı testte görünüyor).
  Ölçülen şey bildirim **satırının** yazıldığı ve `dispatch_external`in
  doğru rollerle çağrıldığı.
* **Beat zamanlaması** gerçek zamanda doğrulanmadı; iş doğrudan
  çağrılarak ölçüldü (`bugun` parametresiyle — saat bağımlı flake
  olmasın diye).
* Ekipman **fotoğrafının** MinIO'ya yüklenmesi ölçülmedi; ölçülen şey ek
  mekanizmasının bakım kaydını **kabul ettiği** (not eki ile sürüldü).

---

# §2 — VARDİYA EKRANI YENİDEN TASARIM

## §2.0 ÖNCE ÖLÇÜM — bugün ne var

| Sorulan | Ölçülen |
|---|---|
| Izgara var mı? | **Var ve zaten kişi eksenli**: `/vardiya-plani/cizelge` → `personel[] × bloklar[]`, vardiyası olmayan personel de dönüyor (P205 §2). |
| Görünümler? | gün / hafta / ay (yatay zaman şeridi). **Takvim yok.** |
| Vardiya ekleme? | **Tek modal** (P235): takvim → kişi/saat → grup → önizleme. Kalıp + rotasyon içinde. **Mola, rol etiketi, lokasyon yok.** |
| Araçlar? | "Haftayı kadrodan doldur" (P203), "Kalıp uygula" (P207), şablon bölümü (P232). **Haftadan kopyala yok.** |
| Excel? | **Yok.** |
| Filtre? | Rol + kişi araması var. **Takım / yalnızca vardiyalı / sorunlu yok.** |
| Toplu işlem? | Ay görünümünde **gün** seçimi var (kalıp uygulamak için). **Hücre seçimi yok.** |
| Taslak/yayınla? | **Yok** — eklenen vardiya anında sahaya yansıyor. |
| İzin? | **Yok.** |

Yani izgaranın **omurgası zaten vardı**; eksik olan gruplama, saat
toplamı, izin, yayın ve araçlardı. Sıfırdan yazmak, test edilmiş bir
ekranı atmak olurdu.

## §2.1 Referans körü körüne kopyalanmadı

| Referansta | Bizde | Gerekçe |
|---|---|---|
| Şube seçimi | **Blok / ortak alan** | Bizde şube yok; site var. Vardiya "A Blok"ta ya da "Otopark"ta geçer. |
| Çalışanı sıfırdan ekle | **Kayıtlı personelden seç** | Personel zaten `app_user`. İkinci bir kişi kaydı, aynı insanı iki kez tutmak olurdu. |
| "Takımlar / Kişiler / Roller" görünüm seçici | **Rol grupları + Atanmamış** | Bizde takım = rol. Ayrı bir "takım" kavramı uydurmak, doldurulmayan bir alan üretirdi. |

## §2.2 İzin — ayrı tablo, ayrı uç

`vardiya_plani`ya "tür=izin" yazmak kolay görünürdü ve **mesai hesabını
sessizce bozardı**: `routers/mesai.py` `durum='planli'` satırları okuyor;
izinli gün **çalışma sayılır** ve izne çıkan kişiye fazla mesai yazılırdı.

**Onay — istekteki soruların yanıtı:**
* Yönetim (admin/yönetici) ya da amir kendi ekibi için girerse kayıt
  **doğrudan `onaylandi`**: onaylayacak makam zaten odur.
* Personel kendisi için girerse **`onay_bekliyor`** — bu bir *talep*tir.
* **Başkası adına giremez** (403). Sessizce kendi adına yazmak daha kötü
  olurdu: kayıt görünür ama yanlış kişide.
* Onaylayan: admin/yönetici her zaman; güvenlik amiri yalnız güvenlik
  personeli için (P231 ile aynı sınır, `gorunur_roller` tek kaynak).

**İzinli güne vardiya atanamaz** — kapı `ata` / `toplu` / `kalip-uygula`
/ `haftayi-doldur` / `haftadan-kopyala` yollarının **hepsinde**, tek bir
yardımcıyla. Tek yolda kontrol etmek, ötekilerden sessizce geçilmesi
demekti.

İki istisna, ikisi de bilinçli:
* **Saatlik izin engellemez**: iki saatlik mazeret izni o günkü vardiyayı
  imkânsız kılmaz; kişi izinden sonra işe gelir.
* **Bekleyen talep engellemez**: onaylanmamış bir talep henüz bir gerçek
  değildir; onu engel saymak, yöneticiyi kendi onaylamadığı bir şeyle
  bağlı tutardı.

## §2.3 Molalar — kanun metni, isteğin sayıları değil

İstek "4 saate kadar 15 dk" diyordu. **4857 md. 68 şöyle diyor:** dört
saate kadar **25 dk**, dört–yedi buçuk arası **30 dk**, üstü **1 saat**.

Kanun metni alındı çünkü 15 dakika **kanunun altındadır** ve yazılımın
önerdiği sayı yöneticinin hukuki dayanağı olur. Eksik bir öneri, onu
ihlale yaklaştırırdı. Sayı zaten **yalnızca öneri**; yönetici
değiştirebilir.

**Mola çalışma süresinden düşer** (md. 68/son). Bu yalnızca ızgaradaki
toplamı değil **mesai hesabını da** düzeltiyor: bugüne kadar 12 saatlik
bir vardiyanın 1 saatlik molası da fazla mesai olarak ücretlendiriliyordu.
Tek kaynak `vardiya.plan_saat`.

## §2.4 Taslak / Yayınla — bugünkü davranış değişiyor

İstek sordu: "Bu, bugünkü davranışı değiştirir mi?"

**Evet, değiştiriyor.** Bugüne kadar yönetici bir vardiya ekler eklemez
personel onu görüyordu; yarım kalmış bir plan (önce ekle, sonra düzelt)
sahaya anında yansıyordu ve görevli bir saat sonra değişecek bir
vardiyaya göre program yapabiliyordu.

Bundan sonra yeni satırlar **taslak** açılır, personel görmez, yönetici
"Yayınla" deyince görünür.

Üç koruma:
1. **Mevcut satırlar göçte yayınlanmış sayıldı** — aksi hâlde göç
   çalıştığı anda sahadaki herkesin planı ekrandan kaybolurdu.
2. **Yayınlanmış satırın değişikliği gizlenmez**, yalnız sayaca girer.
   Gizlemek "vardiyam kayboldu" telefonları üretirdi.
3. **Mesai hesabı etkilenmez**: taslak da bir plandır ve yöneticinin
   yaptığı iş, yayınlanmamış olsa da maliyet öngörüsüdür.

**Enum değil zaman damgası:** `yayinlandi_at` NULL = taslak;
`updated_at > yayinlandi_at` = "tekrar yayınlanmalı". Tek sütun, iki
soruya yanıt.

## §2.5 Sürükle-bırak — yine açılmadı

İstek "masaüstünde açılsın mı?" diye sordu. **Hayır.**

P205'teki gerekçe hâlâ geçerli ve masaüstüne özel bir kapı açmak onu
yarı yarıya delerdi: aynı ekranı hem dokunmatik hem fare ile kullanan
bir yönetici, birinde çalışan bir hareketin ötekinde çalışmadığını
öğrenmek zorunda kalırdı. Bedel de aynı: yanlışlıkla bırakılan bir blok,
kimsenin fark etmediği bir vardiya değişikliği üretir — ve saat = maaş.

Toplu işlem yerine **açık seçim**: Ctrl/Shift ile hücre seçilir, altta
çubuk açılır. Sade tıklama ayrıntı açar (tersi olsaydı tek vardiyayı
düzenlemek isteyen önce seçim moduna girerdi). **Toplu silme tek tek
gider**: her satırın kendi denetim kaydı oluşsun.

## §2.6 Mobil — web'in küçültülmüşü değil

**Izgara mobile getirilmedi** ve bu P205 kararının sürdürülmesi: 360 dp'de
24 saatlik eksen 15 px/saat'e düşer, dokunma hedefleri 44 dp'nin altına
iner. Sahadaki soru "bugün kim var"dır; **gün gün liste** bunu tek bakışta
yanıtlar.

Mobile eklenenler: taslak rozeti (**yazıyla** — sahada güneş altında renk
farkı kaybolur), rol + lokasyon + mola düşülmüş çalışma saati, o gün
izinli olanlar **ayrı satır**, sayılı "Yayınla" düğmesi, izin formu,
ekleme akışında mola/rol/lokasyon.

Filtreleme mobilde **bilinçli olarak sade**: rol süzgeci zaten menüde
değil listenin kendisinde anlamlı değil — günlük listede yedi günün
tamamı zaten ekranda. Web'deki dört süzgeci mobile taşımak, üç satırlık
bir listeyi süzmek için üç ekranlık bir form açmak olurdu.

## §2.7 Eski ekranlar

**Hiçbir ekran ölü kalmadı** — ölçüldü:
* Web `/shifts` zaten P232'de yönlendirmeye dönüşmüştü (yer imleri 404
  olmasın diye silinmedi).
* Mobil `/vardiyalar` **şablon + varsayılan kadro** ekranı ve hâlâ
  gerekli: "Haftayı doldur" onu tüketiyor.

**Ama bir giriş noktası yanlış yere gidiyordu ve düzeltildi:** ana
ekrandaki "Vardiya Durumu" kartı (*günlük* soru: şu an kim görevde)
**şablon** ekranını açıyordu (*ayda bir* yapılan iş). P232 aynı kusuru
menüde düzeltmişti, ana ekranda kalmıştı. Kart artık plan ekranına
gidiyor; şablon ekranı plan ekranının içinden açılıyor (web'deki
"Vardiya şablonları" bölümüyle aynı karar).

## §2.8 Korunacaklar — her biri ölçüldü

| Kural | Ölçüm |
|---|---|
| Gün aşırı vardiya (P205) | `test_KORUNDU_gun_asiri_vardiya` — 20:00–08:00, `gece_asiyor=true`, 12 saat |
| Çakışma kesin red (P205) | `test_KORUNDU_cakisma_KESIN_RED` |
| Sessiz atlama yok (P205) | `haftadan-kopyala` ve `ice-aktar` satır satır sebep döner |
| Planlanan/gerçekleşen (P214) | Mesai ucu ayakta; mola artık doğru düşülüyor |
| Amir yalnız güvenliği görür (P231) | `test_KORUNDU_amir_YALNIZ_guvenligi_gorur` — izinde de aynı sınır |
| Çok gruplu plan (P232) | `kalip-uygula` dokunulmadı; modal hâlâ grup biriktiriyor |
| Parti geri alma (P207) | `test_KORUNDU_parti_geri_alma` |

## §2.9 ÖLÇEMEDİĞİM

* **Gerçek Excel dosyası bir tarayıcıda seçilip yüklenmedi.** Sunucu
  tarafı (sablon üretimi, satır doğrulama, uygulama) testlerle sürüldü;
  istemcideki dosya okuma `lib/xlsx-oku` ile yapılıyor ve o modülün kendi
  testleri var, ama **uçtan uca tarayıcı akışı ölçülmedi**.
* **Yayınlanan planın push bildirimi gönderilmedi**: `vardiya_yayinlandi`
  bildirim tipi göçte açıldı ama gönderim bu turda **yapılmadı** —
  yayınlama şu an sessiz. Açık madde.
* **Takvim görünümü 42 hücreyi çiziyor**; yoğun bir ayda (günde 10+
  vardiya) hücre içi kaydırma davranışı gerçek veriyle denenmedi.
* Mobil **emülatörde** çalıştırılmadı (bu makinede emülatör yok).
