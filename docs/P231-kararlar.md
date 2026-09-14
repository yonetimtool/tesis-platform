# P231 — Güvenlik amiri rolü: tam devreye alma

## §0 — Önce ölçüm: rol bugün ne durumda

P218'de "rol var, hiçbir yüzeye giremiyor" diye ölçülmüştü. **Bugünkü
durum farklı** — arada P213 §6 bir kısmını açmış:

| soru | ölçülen yanıt |
|---|---|
| Enum'da mı? | Evet, `models.py:46`. |
| Kaç uçta tanınıyor? | Rol matrisinde **125/542 uçta IZIN** — `GET/POST/PATCH/DELETE /users` dahil. |
| Web'den giriş? | **Evet.** `yuzey.ts`te erişim kümesinde; rotaları: `/dashboard`, `/kamera-kayitlari`, `/profil`. |
| Mobilden giriş? | **Evet.** `user_role.dart`te geniş destek (tur, bildirim, kamera, araç geçişi, ihlal). Menüsü 10 girişli. |
| Bu rolde kullanıcı açılabiliyor mu? | **Evet.** `YONETILEBILIR_ROLLER["yonetici"]` içinde (P213 §6). |
| `test_guvenlik_amiri.py` neyi ölçüyor? | P35 **sahiplik devri**: `guvenlik_modu=dis_sirket` iken tur/vardiya planlama yöneticiden amire geçer. Ayrıca amirin yalnız `security` açabildiği, sakin/finans uçlarının kapalı olduğu. |

### Ölçülen sızıntı — canlı sürülerek

Amir hesabıyla giriş yapıp `GET /users?limit=1000` çektim:

```
{'admin': 1, 'guvenlik_amiri': 1, 'denetci': 1, 'tesis_gorevlisi': 1,
 'security': 1, 'resident': 1, 'yonetici': 1}
```

**Yedi rolün hepsi.** `list_users` çağıranın rolüne göre **hiç
süzmüyordu**; rol P129'dan beri o uçta izinli ve hiçbir yerde
daraltılmamıştı. Yani "dış güvenlik şirketi amiri" tesisin tüm sakin ve
personel listesini görüyordu.

Aynı ölçüm `PATCH /users/{id}` için: yönetici güvenlikçiyi amir
yapabiliyor ve geri alabiliyor (çalışıyor), **ama platform admini de
yapabiliyordu** — §1'in yasakladığı şey.

---

## §1 — Rolün atanması

### Rol değişimi mi, ek bayrak mı? → **rol değişimi**

Amirlik bir **yetki seviyesidir**. Ayrı bir bayrak, yetkinin iki
kaynaktan (rol + bayrak) türemesi ve ikisinin ayrışması demekti: bayrağı
açık kalmış bir `security` kaydı ya da rolü `guvenlik_amiri` olup bayrağı
kapalı bir kayıt. Rol zaten enum'da ve `yonetilebilir` tablosunda; ikinci
bir kavram eklemek karşılığı olmayan bir maliyet.

Ayrı kullanıcı **gerekmiyor**: `PATCH /users/{id}` ile `security` →
`guvenlik_amiri` ve geri. Ölçüldü, iki yön de çalışıyor.

### Admin ataması — istekten sapma, gerekçesiyle

İstek: *"Platform admini veya başka bir rol amir atayamasın."* Gerekçe
doğru: amir tesisin iç işidir.

Ama admin'i **koşulsuz** kapatmak, bu hafta gerçekten yaşanan kurtarma
senaryosuyla çelişiyordu: prod'da platform admini dışında kimse
kalmamıştı (P224) ve tesiste **aktif yönetici yokken** amir atamak ya da
görevden almak imkânsız hale gelirdi.

**Sizin kararınız:** admin yalnız tesiste **aktif yönetici yokken**
atayabilir. Normal işleyişte kapı kapalı, kurtarma yolu açık.

### Birden çok amir

**Serbest.** Kısıt konmadı: 7/24 çalışan bir sitede vardiyalı iki amir
olağan. Tek amir kuralı, o kişi izinli olduğunda ekibi sahipsiz
bırakırdı. Amir ikinci bir amiri **görür ama düzenleyemez**
(`YONETILEBILIR_ROLLER["guvenlik_amiri"] == {"security"}`).

### Denetim

`guvenlik_amiri_ata` ve `guvenlik_amiri_kaldir` **ayrı eylemler**.
Görevden alma da bir yetki değişimidir ve kendi başına aranır; tek tipe
indirmek "kim amir yapıldı" sorusunu "kim amirlikten alındı"dan ayırt
edilemez kılardı. `user_update` içinde kaybolmasınlar diye ayrı satır.

---

## §2 — Görünürlük ayrımı

### Tek kaynak: `GORUNUR_ROLLER`

Aynı soru **üç uçta** soruluyor (`/users`, `/shifts`, `/vardiya-plani/*`).
Üç kopya, birinin güncellenip ötekinin eskimesi demekti —
`MALI_GORUNURLUK`'un var olma gerekçesiyle aynı (P133.6).

```
admin/yonetici/denetci : None (sınırsız)
guvenlik_amiri         : {security, guvenlik_amiri}
tanınmayan rol         : boş küme (fail-closed)
```

**Amir neden kendi rolünü de görür:** `guvenlik_amiri` de güvenlik
personelidir. Kümeden çıkarmak, amirin **kendisini** ve birlikte
çalıştığı ikinci amiri listede görememesi demekti — "tesis görevlisini,
sakini, diğer çalışanları görmez" kuralını bozmadan.

### Sunucu tarafı, üç katmanda

1. **Liste** (`GET /users`): `role IN (...)`. İstemcinin `?role=` süzgeci
   **kesişir, ezmez** — `?role=resident` gönderen amir boş liste alır.
2. **Tekil** (`GET /users/{id}`): görünmeyen rol için **404**, 403 değil.
   "Var ama göremezsin", kaydın **varlığını** sızdırmak olurdu.
3. **Çizelge** (`/vardiya-plani/cizelge`, `/vardiya-plani`): bloklar *ve*
   boş satırlar süzülür. Yalnız blokları süzüp personel listesini açık
   bırakmak, amire tesis görevlisinin **adını** "vardiyası yok" satırı
   olarak yine gösterirdi.
4. **Vardiya personeli** (`/shifts`): `_personel_map` süzülür — ad ve
   avatar oradan çıkıyor.

### Amirin vardiya yetkisi — ve `/shifts` ile ayrımı

Kararınız: **tam yetki** (ekle/değiştir/sil/toplu planla), yalnız
`security` için.

Ama iki uç **aynı şey değil** ve kapıları da ayrı:

| uç | ne | kapı |
|---|---|---|
| `/shifts` | vardiya **şablonu** ("Gece 00:00–08:00") — sitenin çalışma düzeni | P35 `guvenlik_modu` belirler (dis_sirket → amir, yonetim_ici → yönetici). **Dokunulmadı.** |
| `/vardiya-plani` | **kim ne zaman çalışıyor** — ekip yönetimi | Amir tam yetkili, hedef kişi `security` olmak zorunda. |

Gerekçe sahadan: vardiya değişimini amir yönetir, her değişiklik için
yöneticiye gitmek gecikme üretir. Ama şablon **site kararıdır** ve P35'in
testli tasarımını bozmak için bir sebep yok.

---

## §3 — Amirin yetki alanı (tam matris)

| alan | yetki | gerekçe |
|---|---|---|
| Personel listesi | **yalnız güvenlik** | §2. Sunucuda üç katmanda. |
| Vardiya (`/vardiya-plani`) | **tam yetki, yalnız güvenlik** | Saha vardiya değişimini amir yönetir. |
| Vardiya şablonu (`/shifts`) | **moda bağlı** (P35) | Şablon site kararı. |
| Devriye planları | **okur**; yazma **moda bağlı** | P35 sahiplik devri; değiştirilmedi. |
| NFC noktaları | **okur**; ekleme **moda bağlı** | Aynı devir kümesinde (testli). |
| Devriye takibi / kaçırılan tur | **okur** | `GET /patrol-windows`, `GET /scans` — işin denetimi. |
| Kameralar: canlı | **evet** | P213. |
| Kameralar: geçmiş kayıt | **evet** | P213 §6 bu rolü zaten açmıştı. |
| **Ziyaretçi kayıtları** | **okur, yazmaz** | *Yeni.* Kaydı kapıdaki görevli girer; amirin işi denetlemek. Yazma yetkisi "kim kaydetti" izini bulanıklaştırırdı. |
| **Görev atama** | **evet, yalnız güvenliğe** | *Yeni.* Hedef kişi `gorunur_roller` ile daraltılır: göremediği kişiye atayamaz (422). |
| **Şikayetler** | **yalnız güvenlikle ilgili kategoriler** | *Yeni.* Göç 0134 — aşağıda. |
| Bildirimler | P34 alarmları + görev/devriye | Mevcut `canViewNotifications`. |
| **Fazla mesai / ücret** | **HAYIR** | Ücret hassas veri; test ediliyor (`/mesai`, `/mesai/ayar` → 403/404). |
| Finans | **HAYIR** | Mevcut test korunuyor. |
| Sakin bilgileri | **HAYIR** | §2 kuralının doğrudan sonucu. |
| Tesis ayarları | **HAYIR** | `PATCH /tenant/settings` yalnız admin. |

### Şikayet kapsamı — yeni bir alan gerekti (göç 0134)

Ölçtüm: şikayet kategorileri `task_category`'den geliyor ve bunlar
**yönetici-tanımlı serbest metin** ("Tesisat", "Bahçe"). "Hangi kategori
güvenliği ilgilendirir" bilgisi sistemde **hiçbir yerde yoktu**.

* **Kategori adına göre tahmin** — kırılgan: tesis "Asayiş" yazarsa
  çalışmaz, "Güvenlik Kapısı Tamiri" yazarsa yanlış çalışır. Üstelik 7
  dilde.
* **Amire tüm şikayetler** — isteğin açık şartına aykırı.
* **Kategoriye açık bayrak** — seçilen. `task_category.guvenlik_ilgili`,
  varsayılan **false** (fail-closed): yeni kategori açan yönetici,
  farkında olmadan amire yeni bir veri kümesi açmaz.

**Kategorisiz şikayet amire görünmez:** ilgisi kurulamaz bir kaydı
"ilgilendiriyor olabilir" diye göstermek, en az yetki ilkesinin tersi
olurdu.

---

## §4 — Giriş ve arayüz

Web: `/users`, `/shifts`, `/vardiya-plani`, `/tasks`, `/complaints`,
`/patrol-plans`, `/checkpoints`, `/kameralar` amire açıldı. **Rotayı
açmak sunucuyu açmaz** — her uç kendi kapısını koruyor; `ROTA_ROLLERI`
yalnız menüyü ve yönlendirmeyi belirler.

`rol-menusu` kilidi bir çakışma yakaladı ve haklıydı: menüde
`/vardiya-plani` varken `POST /vardiya-plani` 403'tü. Kilit, "menüde ama
yetkisiz" durumunu tam da bunun için ölçüyor.

Mobil: menüye `visitors` ve `tasks` eklendi; `canManageTasks` amiri
kapsıyor.

---

## §5 — Kilitler

* `rol-matrisi.txt` yeniden üretildi (542 satır).
* Tesis izolasyonu taramasına **rol içi kapsam** eklendi: o dosyanın diğer
  taramaları tenant sınırına bakıyor, P231'in sızıntısı **aynı tenant
  içindeydi** ve hiçbir RLS testi göremezdi (satırlar doğru tenant'taydı).
  İkinci test, rol süzgecinin tenant koşulunun **yerine geçmediğini**
  ölçüyor.
* IDOR: `GET /users/{id}` tekil uç (404).
* Kırarak doğrulandı: `GORUNUR_ROLLER["guvenlik_amiri"] = None` → **5 test
  düştü**.

## Ölçemediğim

Gerçek tarayıcı/cihazda amir oturumuyla gezinme — tarayıcı ve emülatör
yok. Ölçtüğüm: uçların gerçek HTTP yanıtları (amir jetonuyla giriş
yapılarak) ve rota/menü kümelerinin testleri.
