# P243 — kararlar

Altı bölüm: vardiya modalı sadeleştirme (§1), "Atanmamış" tanımı (§2),
içe aktarım tablosu (§3), web görünüm modu (§4), SOS düzenlemesi (§5),
onboarding (§6). Her bölüm ayrı commit.

---

# §1 — VARDİYA EKLEME MODALI

## §1.0 ÖLÇÜM: modal sunucuya ne gönderiyordu

Alanları kaldırmadan önce modalın **çalıştığını** varsaymıştım. Ölçtüm,
çalışmıyordu:

> Modal, "serbest saat + tek kişi" durumunda `/vardiya-plani/toplu`
> ucuna `baslangic` / `bitis` gönderiyor; şema `baslangic_tarih` /
> `bitis_tarih` istiyor.

Sunucuya birebir o gövdeyi göndererek ölçüldü:
`422 baslangic_tarih: Field required`.

Yani **web'de en sık yapılan işlem — tek kişiye serbest saatle vardiya
yazmak — P235'ten beri hiç çalışmıyormuş.**

**DOM testi bunu neden görmedi:** taklit `fetch` her gövdeye 200
dönüyordu. Sözleşme uyumu ancak sunucuya karşı ölçülür; bu yüzden yeni
kilit backend'de (`test_p243_vardiya_modali.py`) ve DOM testi "hangi
uca gidildiği" kuralını ölçüyor.

**Düzeltme alan adını yamalamak değil, ikinci yolu kaldırmak oldu.**
`/kalip-uygula` serbest saati zaten tek dilimli bir grup olarak işliyor
ve çakışma akışı, önizleme, parti kimliği ve rotasyon hep orada. İki yol
demek bu kuralların iki kopyası demekti — ve biri sessizce eskimişti.

## §1.1 Kaldırılanlar

| Alan | Gerekçe |
|---|---|
| **Bu vardiyadaki rol** | Kişi sisteme eklenirken rolü zaten belirleniyor. Vardiya başına tekrar sormak aynı bilgiyi ikinci kez istemek — ve iki kaynak birbirinden sapabilir. |
| **Lokasyon** | Referanstaki "şube"nin karşılığıydı; bizde şube yok. Doldurulmayan bir alan formu uzatmaktan başka bir şey yapmıyordu. |
| **Başlangıç / bitiş tarihi** | Üstte zaten takvim var. İki yol birden açıkken hangisinin geçerli olduğu belirsizdi — **ve bu belirsizlik önizlemeyi öldürüyordu** (§1.4). |

**Sütunlar silinmedi** (göç 0145): P241'de yazılmış kayıtlar duruyor ve
ızgara onları hâlâ gösteriyor. Sütunu düşürmek var olan veriyi silmek
olurdu; yapılan şey **yeni kayıtta sormamak**.

## §1.2 Rol süzgeci (§1d)

Kişi seçiminin **üstünde**, `ortakTumu` varsayılanıyla. **Kaydedilen bir
alan değil**, gövdede gitmiyor (test bunu ayrıca ölçüyor). Rol
değiştiğinde seçili kişi süzgecin dışında kalıyorsa **düşürülüyor**:
görünmeyen bir kişiyle vardiya oluşturmak, kullanıcının görmediği bir
sonuç üretirdi. Roller **personel listesinden türer**, elle yazılmaz.

## §1.3 Aylık rotasyon (§1e) — takvim ayı, 4 haftalık döngü değil

İstek sordu. **Takvim ayı seçildi.** Dört haftalık döngü ayın ortasında
kayar ("15 Mart'tan sonra A ekibi geceye geçti") ve yöneticinin
takviminde bir karşılığı yoktur. Takvim ayı **söylenebilir** bir şeydir:
"mart gündüz, nisan gece" — personel de vardiyasını ay adıyla hatırlar.

**Kilit ayırt edici seçildi:** ilk yazımda 2 Mart ↔ 30 Mart kullanmıştım;
dört hafta = çift kaydırma olduğu için haftalık ile aylık **aynı** sonucu
veriyordu ve test iki kuralı ayırt edemiyordu. Kilidi kırarak ölçtüm,
geçti. 9 Mart (tam bir hafta sonra) ile değiştirildi.

## §1.4 Çoklu kalıp (§1f) — yeni kavram üretilmedi

Ölçüldü: **`VardiyaGunGrubu` zaten `kalip_id` taşıyor** (P232). Yani
"birden çok kalıp" için yeni bir yapı gerekmiyordu; eksik olan, modalın
kalıbı **gruba** değil formun tamamına bağlamasıydı. Artık her "Gruba
ekle" kendi kalıbını taşıyor: pazartesi 2-vardiyalı kalıp, cumartesi
3-vardiyalı kalıp — tek istek, tek parti, tek geri alma.

## §1.5 Önizleme (§1g) — kök neden

Önizleme grup üzerinden gidiyor, grup ise **seçili günlerden**
kuruluyordu. Tarih alanlarını doldurup takvimden gün seçmeyen
kullanıcının "Önizle" düğmesi **sessizce hiçbir şey yapmıyordu**
(`hepsi.length === 0` → erken dönüş).

Yani §1c ile §1g **aynı kusurun iki yüzü**. Tarih alanları kalkınca tek
yol kaldı; gün seçilmeden gönder/önizle düğmeleri **kapalı** ve neden
kapalı olduğu yazılı.

---

# §2 — "ATANMAMIŞ" BÖLÜMÜ

## §2.0 ÖLÇÜM: bugün neye göre hesaplanıyor

`/vardiya-plani/cizelge` **her aktif personeli** (güvenlik, tesis
görevlisi, amir, yönetici) boş blok listesiyle döndürüyor — P205'te
bilinçli bir karar ("kim boşta" sorusu da bir plan sorusudur). Web
ızgarası da "bloğu olmayan" herkesi "Atanmamış"a koyuyordu.

Sonuç: bölüm **bir personel rehberine** dönüşmüştü ve asıl soruyu —
*"bu hafta kimi atamayı unuttum"* — görünmez kılıyordu.

## §2.1 Yeni tanım

> **Atanmamış = vardiya düzenine dahil olduğu hâlde bu dönemde vardiyası
> olmayan kişi.**

"Vardiya düzenine dahil" ölçütü (sunucuda, `vardiya_duzeninde`):
1. **Varsayılan kadro** üyesi (`shift_assignment`), **veya**
2. **Herhangi bir tarihte** vardiya satırı var.

**Dönem dışındaki satırlar da sayılır** ve bu şart: bu hafta vardiyası
olmayan ama geçen hafta çalışmış biri *tam da* atanmamış olandır. Yalnız
dönem içine bakmak, ölçütü tanımın kendisiyle çelişirdi.

**Kadro üyeliği neden yeter:** "Haftayı doldur" tam da onları yazacak;
kadroya konmuş ama bu hafta planlanmamış kişi yöneticinin yapılacak
işidir.

**Hiç vardiya girilmemiş sitede bölüm boş** — isteğin şartı, tanımdan
doğal olarak çıkıyor (ölçüldü).

## §2.2 ÖLÇEMEDİĞİM (§1–§2)

* Gerçek tarayıcıda modal açılıp tıklanmadı; DOM testi jsdom üzerinde.
* Aylık rotasyon **bir yıllık** gerçek planla denenmedi; ölçüm üç günlük
  ayırt edici bir kurulumla yapıldı.
