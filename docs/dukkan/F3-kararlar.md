# DUKKAN F3 — KARARLAR

SEO yüzeyi: bölge/kategori sayfaları, arama, işletme profili, sıralama,
üretilen sitemap. Mobil karşılığı da bu fazda.

---

## 1. Görünürlük koşulu tek sabitte

```python
_GORUNUR = "i.durum = 'onayli' AND i.dogrulama_seviyesi >= 1"
```

Arama, profil, SEO sayfası ve sitemap — **dördü de** bu sabiti kullanıyor.
İki ayrı yerde tekrarlansaydı biri bir gün unutulur ve onaysız ya da
doğrulanmamış bir işletme aramaya **sızardı** — sahte işletme (T3) için
aranan tam da bu.

**Kırarak doğrulandı:** koşulu `1=1` yapınca iki test kırmızı yandı.

---

## 2. Eşleşme hizmet alanından, adresten değil

Bir usta Çekmeköy'de oturup Kadıköy'e gidebilir. İşletmenin **adresine**
göre eşleştirmek onu Kadıköy aramalarından dışlardı.

Eşleşmenin tamamı `isletme_hizmet_alani`. Bir test bunu davranıştan
ölçüyor: adresi hiç girilmemiş bir işletme, hizmet alanı Kadıköy ise
Kadıköy aramasında **çıkıyor**, Çekmeköy'de **çıkmıyor**.

**Konum süzgeci hiyerarşik ve mahalle için il+ilçe zorunlu (422).**
Sessizce il/ilçeyi yok saymak, Türkiye'deki onlarca "Merkez" ilçesini
birleştirirdi.

---

## 3. İnce içerik eşiği — üç kademe

| İşletme | Davranış |
|---|---|
| **0** | Uç **404**; sayfa yok, iç bağlantı yok, sitemap'te yok |
| **1..eşik-1** | Sayfa çalışır, **`noindex, follow`**, sitemap'te **yok** |
| **≥ eşik** | Tam indekslenir, sitemap'e girer |

Türkiye'de ~45.000 mahalle × ~50 hizmet = **2+ milyon** olası URL ve ezici
çoğunluğunda tek işletme bile yok. Hepsini üretmek arama motoruna *"bu alan
adı boş sayfa fabrikası"* demenin en hızlı yolu — ve ceza sayfa başına değil
**alan adı geneline** işler; 10 iyi sayfa da düşer.

**Eşik değeri tek yerde:** `config/site.ts` → `INCE_ICERIK_ESIGI`, ortam
değişkeninden okunuyor. Backend eşiği **bilmiyor**; sitemap ucu onu
**parametre olarak** alıyor. İki yerde tutmak, birinin bir gün ötekinden
ayrışması demekti.

**Uçtan uca ölçüldü** (gerçek sunucuda, gerçek veriyle):

```
/istanbul/cekmekoy/catalmese/elektrikci   200, 19 işletme, noindex YOK, sitemap'te VAR
/istanbul/cekmekoy/catalmese/mobilya-tamiri  404
/istanbul/bagcilar/100-yil/cilingir       200, "noindex, follow", sitemap'te YOK
```

---

## 4. İç bağlantı yalnız dolu sayfalara

Komşu mahalle ve diğer kategori listeleri, uçta **gerçekten işletmesi
olanlarla** sınırlı. Boş sayfaya bağlantı vermek, arama motoruna var
olmayan sayfaların haritasını çizmek olurdu.

---

## 5. Sıralama puanı — formül ve gerekçeler

`isletme.siralama_puani` sütunda; `siralama_puani_hesapla()` **tek yazma
yolu** (P192 "tek defter" dersi). Her okumada hesaplamak ISR ile
önbelleklenen sayfalarda N+1 maliyetini her yenilemede ödetirdi.

| Bileşen | Ağırlık | Gerekçe |
|---|---|---|
| Yorum (A×1.0 + B×0.3) × güven çarpanı | 0–50 | `03` §2.2b'de kararlaştırılan ağırlıklar |
| Doğrulama seviyesi | ×8 | Belge doğrulanmış işletme yukarı |
| Profil eksiksizliği | 0–10 | Eksiksiz profil kullanıcıya daha çok bilgi verir |
| Hizmet alanı genişliği | 0–5, **tavanlı** | 20 mahalle ile 400 mahalle arasında fark **olmamalı**; yoksa "her yere gidiyorum" diyen haksız avantaj kazanır |
| Yenilik | 0–6, 30 günde söner | "Zengin daha zengin" döngüsünü kırar — yeni işletme hiç görünmeden ölmemeli |

**Rastgelelik kullanılmadı ve bu bilinçli.** `05-seo.md` §6 "rastgele küçük
bir bileşen" öneriyordu; uygularken şu görüldü: rastgele bir terim aynı
sorgunun iki çağrısında **farklı sıra** üretir ve ISR ile önbelleklenmiş bir
sayfada bu "sıra değişip duruyor" şikâyetine ve sayfalama tutarsızlığına yol
açar. Yerine **deterministik bir yaş fonksiyonu** kondu — aynı amacı
(yeniye şans) tutarlılığı bozmadan sağlıyor.

**Gecelik yeniden hesap** (`dukkan.siralama_yenile`, 02:00 UTC): yenilik
bileşeni zamana bağlı ve kendiliğinden söner, ama sütunda saklandığı için
yeniden hesaplanmadıkça eski değer kalır. Bu iş olmasa bir yıl önce
onaylanmış işletme sonsuza dek "yeni" puanı taşırdı.

**Celery sarmalayıcısı kopyalandı, paylaşılmadı:** Yönetiyor'unki
`app.db.engine`'i dispose ediyor. Dukkan'ın ayrı engine'i dispose edilmezse
P187'de prod'da 90/100 bağlantıyla ölçülen `idle in transaction` birikmesi
**birebir tekrarlanırdı**.

---

## 6. Sayfalama tutarlılığı — ölçemediğim şey

Her sıralama seçeneği `i.id` ile bitiyor. Eşit değerlerde PostgreSQL sırayı
**garanti etmez**; sayfa 2'de aynı kayıt tekrar çıkabilir ya da biri hiç
görünmeyebilir.

**Bunu davranışsal olarak kırdıramadım — ve bu bir eksiklik olarak yazılı.**
İkincil anahtarı kaldırıp testi koşturdum: puanları eşitledikten sonra bile
**geçti**. Sebep, PostgreSQL'in bu veri boyutunda kararlı bir plan (tek iş
parçacıklı tarama) seçmesi. Risk gerçek — `ORDER BY` toplam sıralama
tanımlamadığında sonuç şartname gereği belirsizdir ve plan veri büyüdükçe
ya da paralel tarama devreye girdiğinde değişir — ama tetiklemesi bana bağlı
değil.

Bu yüzden kilit **yapısal**: AST ile her sıralama ifadesinin benzersiz bir
sütunla bittiği doğrulanıyor. Davranışsal test *"bugün bozuk değil"* der;
yapısal test *"bozulması mümkün değil"* der. **Yapısal olan kırılarak
doğrulandı.**

---

## 7. İlk yazımda iki testim boş yere yeşildi

Kilitleri kırma alışkanlığı iki **test kusuru** ortaya çıkardı:

1. **Sayfalama testi** — ikincil anahtarı kaldırınca yine geçti, çünkü
   üretilen işletmelerin puanları `yenilik` ve `profil` bileşenleri yüzünden
   birbirinden farklıydı: **ortada eşitlik yoktu**. Test artık eşitliği
   kendisi kuruyor (`UPDATE ... siralama_puani = 42`).
2. **Sitemap testi** — sabit bir ilçe ("üsküdar") seçiyordu ve aynı takımda
   daha önce koşan testler oraya işletme bırakınca eşiği geçiyordu; test
   **izolasyonda geçip tam takımda düşüyordu**. Artık gerçekten boş bir
   mahalle **arıyor**. (Aynı sınıf kırılganlık bu depoda
   `patrol-windows-pollution-flake` olarak kayıtlı.)

---

## 8. Kamu profili ayrı uç

`/dukkan/isletme-profil/{slug}`, sahibin gördüğü `/dukkan/isletme/{id}`'den
**ayrı ve dar**: `vergi_no`, `red_sebebi`, `askiya_alma_sebebi`,
`sahip_kullanici_id` yok.

Tek uç kullanıp alan gizlemeye çalışmak, bir gün eklenen bir alanı gizlemeyi
unutmak demekti. Bir test yanıt gövdesinde bu alanların **hiçbirini** arayıp
bulamıyor.

**Görünmeyen işletme 404 — 403 değil:** *"bu işletme var ama askıda"*
bilgisi kamuya açık olmamalı.

**Hizmet bölgeleri ilçe düzeyinde özetleniyor:** 40 mahalle seçen bir
işletmenin profilinde 40 satır sayfayı boğardı.

---

## 9. Schema.org — koşullu `aggregateRating`

`aggregateRating` **yalnız gerçek yorum varsa** üretiliyor. Yorumu olmayan
işletmeye rating işaretlemek **yapılandırılmış veri ihlalidir** ve manuel
işlem sebebidir (`05-seo.md` §5). Ölçüldü: 19 işletmeli sayfada
`LocalBusiness` 38 kez geçiyor, `aggregateRating` **hiç** — çünkü henüz
yorum yok.

---

## 10. Mobil — uyarlandı, kopyalanmadı

**Karar: F3'ün mobil karşılığı kimliksiz.** Arama ve profil uçları
`security: []` olduğu için mobilde jeton gerekmiyor. Önce Dukkan hesabı
açtırmak, kullanıcıyı ürünün değerini **görmeden** bir kayıt formuna sokmak
olurdu. SSO köprüsü F4'e alındı (talep oluşturma jeton ister) — yol
haritasında F6'daydı; **öne çekildi** çünkü mobil parite her fazda isteniyor.

| Web | Mobil | Neden farklı |
|---|---|---|
| Süzgeçler yan yana bir satırda | **Dikey** | O satır telefonda okunmaz hale gelir |
| "Ara" küçük bir düğme | **Tam genişlik**, baş parmak menzilinde | Telefonda arama asıl dönüşüm; dokunma hedefi 48dp'den küçük olmamalı |
| Açıklama tam metin | **İki satır kırpma** | Uzun metin listeyi kaydırılmaz yapar |
| Rozet açıklaması ipucu balonu olabilir | **Açık metin** | Dokunmatikte hover yok; balon keşfedilmez |
| İletişim düğmesi yan sütunda | **En üstte** | Telefonda ilk soru "arayabilir miyim" |

**Rota ayrı:** `/dukkan` ve `/dis-hizmetler` **ayrı yollar**. `dis_hizmet`
yöneticinin özel defteri (tesise bağlı), Dukkan kamu pazar yeri. Aynı yola
koymak iki farklı kavramı birleştirirdi.

**7 dil eklendi** (26 anahtar × 7). Sözlük kilidi `dukkanWhatsapp`'ı
"çevrilmemiş TR kopyası" sandı — **marka adı**, latin alfabesi kullanan
dillerde aynı yazılır; Arapçası zaten farklı. Gerekçesiyle istisna listesine
eklendi.

---

## 11. Ölçemediklerim

1. **Sayfalama kararsızlığı** (§6) — davranışsal olarak tetiklenemedi.
2. **Gerçek arama motoru davranışı**: `noindex`, canonical ve JSON-LD
   üretildiğini ölçtüm; Google'ın bunlara **nasıl tepki vereceğini**
   ölçemem. Eşik "3" hâlâ bir başlangıç değeri.
3. **ISR önbellek davranışı prod'da**: disk üzerinde tutuluyor ve konteyner
   yeniden kalkınca sıfırlanıyor; ilk isteklerde yavaşlama olur. Tek
   sunucuda kalıcı ISR için ek yapılandırma gerekip gerekmediğini
   **ölçmedim**.
4. **`yorum` tablosu boş** — sıralamanın yorum bileşeni F5'te gerçek veriyle
   ilk kez sınanacak.
