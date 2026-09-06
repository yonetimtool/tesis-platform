# P217 — Push bildirimi yönlendirmesi: rol × tip tablosu

## Kök neden

Devriye alarmı (`uzak_okutma`, `gecikmis_okutma`) backend'de **hem**
görevliye kişi olarak **hem** yönetim rollerine gidiyor
(`app/uzak_okutma.py: ALARM_ROLLERI = admin, yonetici, guvenlik_amiri`).
Mobil ise ikisini de "Turlarım" (`/patrol`) yapıyordu — o ekran
yöneticinin menüsünde **yok** ve açılınca "yetkiniz yok" çıkıyordu.

Yani bildirim doğru kişiye gidiyordu; **yönlendirme** yanlıştı.

## Karar: iki katman

**1. Tip + rol → hedef.** Aşağıdaki tablo.

**2. Erişim süzgeci.** Hedef, o rolün erişebildiği rotalar kümesinde
değilse **yönlendirme yapılmaz** (`null`). Bu bir emniyet kemeridir:
birinci katmanda unutulan ya da ileride eklenen bir tip yanlış yere
götüremez. Tek başına yetmez (doğru hedefi bilmez) ama yanlış hedefi
**her zaman** keser.

### Erişilebilir rotalar nereden geliyor

`homeMenuForRole` (rol × menü tablosu, `auth.md` §4'ün aynası) —
**artı** bilerek menüsüz olan rotalar. Bu ikinci küme şart: P169'da
"menüde yoksa ele" süzgeci ölçülmüş ve **fazla geniş** çıkmıştı
(sakin `sikayetlerim`i, güvenlik `araç geçişi`ni kaybediyordu). Menüde
yokluk yasak anlamına gelmiyor; bu yüzden istisnalar tek tek ve
gerekçesiyle yazılı:

| rol | menüsüz ama açık | neden |
|---|---|---|
| hepsi | `/notifications`, `/profile` | modül kartı değil, kabuğun parçası |
| `resident` | `/sikayetlerim` | kendi taleplerinin tek girişi (enum notunda "bilerek menüsüz") |
| `security`, `tesis_gorevlisi` | `/nfc` | "Turlarım"/"Görevlerim" içinden açılır |

## Tip × rol → hedef

`—` = **yönlendirme yok**. Ya o rol o bildirimi almıyor, ya da hedef
ekran ona kapalı; ikisinde de doğru davranış yerinde kalmaktır.

| tip | yonetici | security | tesis_gorevlisi | resident | guvenlik_amiri | admin |
| `talep` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `talep_is_emri` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `talep_cozuldu` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `is_emri_atandi` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `sikayet_cozuldu` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `ziyaretci` | — | /visitors | — | /visitors | — | — |
| `kargo` | — | /kargo | — | /kargo | — | — |
| `erisim_talebi` | /unit-access | — | — | /unit-access | — | /unit-access |
| `erisim_sonuc` | /unit-access | — | — | /unit-access | — | /unit-access |
| `rezervasyon` | /rezervasyon | — | — | /rezervasyon | — | /rezervasyon |
| `rezervasyon_karar` | /rezervasyon | — | — | /rezervasyon | — | /rezervasyon |
| `etkinlik` | /etkinlik | /etkinlik | /etkinlik | /etkinlik | — | /etkinlik |
| `duyuru` | /announcements | /announcements | /announcements | /announcements | /announcements | /announcements |
| `gecikmis_okutma` | /patrol-tracking | /patrol | — | — | /patrol | /patrol |
| `uzak_okutma` | /patrol-tracking | /patrol | — | — | /patrol | /patrol |
| `kacirilan_tur` | /patrol-tracking | /patrol | — | — | /patrol | /patrol |
| `eksik_checkpoint` | /patrol-tracking | /patrol | — | — | /patrol | /patrol |
| `vardiya_ozeti` | /vardiyalar | /vardiyalar | /vardiyalar | — | /vardiyalar | /vardiyalar |
| `vardiya_hatirlatma` | /vardiyalar | /vardiyalar | /vardiyalar | — | /vardiyalar | /vardiyalar |
| `vardiya_baslamadi` | /vardiyalar | /vardiyalar | /vardiyalar | — | /vardiyalar | /vardiyalar |
| `gorev_atandi` | /tasks | /tasks | /tasks | — | — | /tasks |
| `aidat_borc` | — | — | — | /my-dues | — | — |
| `aidat_odendi` | — | — | — | /my-dues | — | — |
| `aidat_hatirlatma` | — | — | — | /my-dues | — | — |
| `gurultu_uyari_sakin` | — | — | — | /sikayetlerim | — | — |
| `gurultu_uyarisi` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `gurultu_esik_yonetim` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `gurultu_eskalasyon_guvenlik` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `gurultu_eskalasyon_yonetim` | /complaints | /complaints | /complaints | /sikayetlerim | /complaints | /complaints |
| `tahsilat` | — | — | — | /my-dues | — | — |
| `iade` | — | — | — | /my-dues | — | — |
| `iptal` | — | — | — | /my-dues | — | — |
| `virman` | — | — | — | /my-dues | — | — |
| `acilis` | — | — | — | /my-dues | — | — |
| `dogrulama` | — | — | — | — | — | — |
| `test` | — | — | — | — | — | — |

### Tablodan çıkan kararlar

- **Devriye ailesi** (`gecikmis_okutma`, `uzak_okutma`, `kacirilan_tur`,
  `eksik_checkpoint`): saha → **Turlarım** (alarmı üretenin
  düzeltebileceği yer), yönetici → **Devriye takibi** (ne olduğunu
  gösteren, salt izleme ekranı). `patrol-plans` bilerek seçilmedi:
  kaçırılan bir tur hakkında sorulan şey "ne oldu", "planı nasıl
  kurarım" değil.
- **`guvenlik_amiri` → Turlarım:** `patrol` onun menüsünde **var** (P35;
  sahanın başındadır, ekibinin okutmasını oradan görür).
- **Talep ailesi sakinde `/sikayetlerim`:** matris çıkarılınca görüldü —
  sakin `talep_cozuldu` / `talep_reddedildi` bildirimi **alıyor** ama
  `/complaints` onun menüsünde yok, yani bildirime dokunduğunda
  **hiçbir yere gitmiyordu**. Bu, aranan kusurdan bağımsız ikinci bir
  bulgu.
- **`dogrulama` ve `test`** kullanıcıya görünmeyen teşhis
  bildirimleridir: hiçbir yere götürmezler.
- **Rol bilinmiyorsa** (oturum henüz yüklenmemiş) yönlendirme yok.
  "Bilmiyorsak deneyelim" tam da düzeltilen davranıştı.

## Web tarafı

**Aynı kusur web'de yok — çünkü web'de bildirimden yönlendirme hiç
yok.** `/notifications` sayfası ve `bildirim-merkezi` bileşeni yalnızca
okundu/sil işlemleri yapıyor; bildirim satırı bir hedefe bağlanmıyor
(tek `Link` "tümünü gör" bağlantısı). Yani yanlış yönlendirme
üretilemiyor. Bunun kendisi bir eksiklik sayılabilir ama bu turda
istenen "yanlış hedefi düzelt" idi ve web'de düzeltilecek bir hedef
yok.

## Ölçüm

`mobile/test/p217_push_yonlendirme_test.dart`:

- İsteğin birebir iki senaryosu: **yönetici → `/patrol-tracking`**,
  **güvenlik → `/patrol`** (aynı `data`, farklı rol, farklı ekran).
- **Tüm tipler × tüm roller** taranarak: hiçbir kombinasyon, o rolün
  erişemediği bir ekrana götürmüyor.
- Süzgecin **fazla geniş olmadığı**: her çalışan rol için en az bir tip
  hedef üretiyor (aksi hâlde "her şeyi null yap" da testi geçerdi ve
  ölçüm boşa düşerdi).

`push_route_mapper_test.dart`'taki eski iddialar korundu; hiçbiri yanlış
değildi, **eksikti** — hedefin role bağlı olabileceğini hesaba
katmıyorlardı. Sakine giden bildirimler (kargo, ziyaretçi, aidat) artık
sakin rolüyle ölçülüyor; yönetici rolüyle ölçmek gerçekte olmayan bir
akışı ölçmekti.

`routeForPushData` **silindi** (taşınmadı): iki fonksiyonu yan yana
bırakmak, çağıranın yanlış olanı seçmesi demekti.
