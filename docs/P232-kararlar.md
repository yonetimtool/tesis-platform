# P232 — Vardiya: şablon birleştirme + gün başına farklı saat

## §A — `/shifts` sayfası: ölçüm ve birleştirme kararı

### Ölçüm

`/shifts` **gerçekten şablon tutuyor ve kullanılıyor.** `Shift` üç şey
taşıyor: saat aralığı, **gün tipi** (hafta içi / hafta sonu / resmi
tatil) ve **varsayılan kadro** (`ShiftAssignment` — bu vardiyada normalde
kim çalışır).

`/vardiya-plani`'daki **"Haftayı doldur"** düğmesi tam olarak bunu
tüketiyor: kadroyu okuyup haftayı otomatik dolduruyor. **Kaldırmak o
özelliği de öldürürdü.**

### Asıl kusur: web'de özelliğin yarısı yok

| | şablon tanımı | varsayılan kadro |
|---|---|---|
| Web `/shifts` | var | **yok** (`assignments` çağrısı sıfır) |
| Mobil `/vardiyalar` | var | var (`updateAssignments`) |

Web'de şablon tanımlanabiliyor ama kimse atanamıyor; onu tüketen "Haftayı
doldur" ise kadroya ihtiyaç duyuyor. Sayfanın **boş görünmesinin sebebi
bu**: kimse şablon tanımlamamış, çünkü tanımlasa da işe yaramıyor.

### Karar: kaldırma değil, birleştirme

1. Şablon yönetimi `/vardiya-plani` içine **bölüm** olarak taşınır —
   kullanıldığı yerde yönetilsin, menüde tek giriş kalsın.
2. Web'e eksik **varsayılan kadro** düzenlemesi eklenir (parite eksiği).
3. Adlandırma: menü girişi **"Vardiya planı"**, içindeki bölüm **"Vardiya
   şablonları"**. "Vardiyalar" adı kalkar — ikisi de vardiyaydı ve ayrım
   addan anlaşılmıyordu.
4. `/shifts` → `/vardiya-plani` yönlendirmesi (yer imleri kırılmasın).

---

## §B — Gün başına farklı saat

### Ölçüm: istenenin çoğu zaten vardı

`POST /vardiya-plani/kalip-uygula` (P207) şu an bile şunları yapıyor:

| istenen | durum |
|---|---|
| Takvimden keyfi gün(ler) seçimi | **var** — `gunler: list[date]` |
| Gece/gündüz kalıbı | **var** — `dilimler` |
| Saatler kalıptan gelsin, değiştirilebilsin | **var** — `kalip_id` *veya* serbest `dilimler` |
| Önizleme | **var** — `kuru=true`, **ayrı uç değil**, aynı kod yolu |
| Çakışma sessizce atlanmasın | **var** — P205 kuralı |
| Geri alınabilir | **var** — `parti_id` |
| Tekrarlama (rotasyon) | **var** — `rotasyon: haftalik` |

**Eksik olan tek şey:** bir istekte **aynı dilimler tüm günlere**
uygulanıyordu. "Pazartesi gündüz, salı-çarşamba gece" için modalı üç kez
açmak ve **üç ayrı parti** üretmek gerekiyordu — üç önizleme, üç çakışma
kontrolü ve geri alırken **üç ayrı istek**. Kullanıcı açısından tek
karar, sistemde üç iz.

### Eklenen: `gruplar`

```
gruplar: [ {gunler, dilimler|kalip_id, atamalar}, ... ]   (en çok 10)
```

* **Tek parti.** Gruplar ayrı ayrı yazılsaydı geri alma birden çok istek
  olurdu.
* **Tek önizleme, tek çakışma kontrolü.** `kuru=true` bütünü sayar.
* **Tekil biçim kaldırılmadı** — yayındaki istemciler onu gönderiyor.
  `gruplar` verilirse tekil alanlar yok sayılır.
* **Tek kod yolu:** `_gruplari_coz` her iki girişi aynı şekle indirger.
  İki ayrı döngü yazmak, çakışma kuralının ya da rotasyonun birinde
  güncellenip ötekinde eskimesi demekti.

### Tekrarlama sunucuda **yok** — bilinçli

"1 hafta / 1 ay tekrarla" istemcide **günleri çoğaltarak** ifade edilir.
Sunucuya ayrı bir `tekrar` alanı koymak, aynı gerçeği iki biçimde
anlatmak olurdu (hem `gunler` hem `tekrar`) ve ikisi ayrışabilirdi.
Önizleme sayısı zaten genişletilmiş gün listesinden çıkıyor.

### İki kalıp kavramı var — ve birleştirilmesi gereken bu

Ölçüldü, **iki ayrı kavram bulundu**:

| | `Shift` (göç 0005) | `VardiyaKalibi` (göç 0099, P207) |
|---|---|---|
| içerik | **tek** saat aralığı + gün tipi + varsayılan kadro | **dilimler listesi** (günü bölme) |
| tüketen | `haftayi-doldur`, tekil `POST /vardiya-plani` | `kalip-uygula` |

"Gece/gündüz kalıbı" doğal olarak `VardiyaKalibi.dilimler`'dir — P207'nin
kavramı **zaten** gece/gündüz kalıbıdır. **İkinci bir kavram
üretilmedi**; `gruplar` mevcut `dilimler`i kullanıyor.

`Shift`'in ayrı yaşamaya devam etmesinin tek sebebi, `VardiyaKalibi`'nde
olmayan iki şeyi taşıması: **gün tipi** ve **varsayılan kadro**. §A'daki
birleştirme bu ikisini tek ekranda toplar.

### (P231) Amir kapsamı yeni biçimde de geçerli

`_hedef_gorunur` çok gruplu istekte de uygulanıyor: **yeni bir giriş
biçimi, eski bir kapıyı atlamanın yolu olmamalı.** Test ediliyor.

### Modaldaki fazlalık — ölçüldü

Modalda hem `vardiya-ekle-ara` ("Kişi ara") hem `vardiya-ekle-kisi`
("Personel") var. Arama alanının **tek işi** açılır listenin
seçeneklerini süzmek (`personel.filter(...)`); başka bir şey yapmıyor.
Native `<select>` zaten yazarak atlamayı destekliyor. **Kaldırılıyor.**
