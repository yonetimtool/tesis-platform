// ==========================================================================
// (P177 §2) HUKUKI BELGELER — TURKCE, BIREBIR KOPYA.
// ==========================================================================
// KAYNAK: `admin-web/lib/hukuki/kosullar.ts` ve `.../gizlilik.ts` — TR
// bloklari. METIN UYDURULMADI, DEGISTIRILMEDI; oradan oldugu gibi
// alindi (sartname: "Metinleri P160-P176'da hazirlanan KVKK
// metinlerinden al ... METIN UYDURMA").
//
// NEDEN KOPYA, NEDEN IMPORT DEGIL: iki Next uygulamasi AYRI Docker yapim
// baglamlarinda derleniyor (`context: ../apps/tanitim-web`); paket
// disindan bir dosyayi import etmek imaja giremez.
//
// AYRISMA RISKI ACIK ve KAPATILDI: `tests/hukuki-esitlik.test.ts` iki
// dosyayi okuyup TR metinleri KARSILASTIRIR; panelde bir madde
// guncellenip burada unutulursa test duser. Kalici cozum (tek paylasilan
// paket) ayri bir istir ve kararlar belgesinde eksik olarak yazildi.
//
// -------------------------------------------------------------------------
// DIKKAT — ICERIK CELISKISI (kararlar belgesinde de yazili)
// -------------------------------------------------------------------------
// Kullanim Kosullari 2. maddesi "Hesaplar tesis yonetimi tarafindan
// acilir; herkese acik bir kayit formu yoktur." diyor. Bu turda acilan
// yonetici self-signup formu bu cumleyle CELISIYOR. Metin BILEREK
// duzeltilmedi: hukuki metin uydurmak yasak ve bu bir hukukcu
// kararidir. Eksik olarak raporlandi.

export interface Bolum {
  baslik: string;
  paragraflar: string[];
}

export interface Belge {
  baslik: string;
  guncelleme: string;
  giris: string;
  bolumler: Bolum[];
}

/** Kullanici Sozlesmesi = panelin "Kullanim Kosullari" belgesi. */
export const KULLANICI_SOZLESMESI: Belge =
{
      baslik: "Kullanım Koşulları",
      guncelleme: "Son güncelleme: 2 Ağustos 2026",
        giris:
        "Yönetiyor'u kullanarak aşağıdaki koşulları kabul etmiş olursunuz. Lütfen dikkatlice okuyun.",
      bolumler: [
        {
          baslik: "1. Hizmet nedir?",
          paragraflar: [
            "Yönetiyor; site, apartman ve rezidans yönetimi için bir yazılım hizmetidir. Aidat takibi, talep ve şikâyet yönetimi, duyuru, etkinlik, ziyaretçi ve güvenlik turu kayıtlarını tek yerde toplar.",
            "Yönetiyor tesisin kendisini yönetmez: kararları ve hizmetleri sağlayan taraf **tesis yönetimidir**. Yönetiyor bu işi kolaylaştıran araçtır.",
          ],
        },
        {
          baslik: "2. Hesaplar",
          paragraflar: [
            "Hesaplar tesis yönetimi tarafından açılır; herkese açık bir kayıt formu yoktur.",
            "Hesabınızın güvenliğinden siz sorumlusunuz. Parolanızı paylaşmayın; şüpheli bir durumda tesis yönetimine bildirin.",
            "Bir hesabı yalnızca size verilen yetki kapsamında kullanabilirsiniz.",
          ],
        },
        {
          baslik: "3. Ödemeler ve aidat",
          paragraflar: [
            "Uygulamada görünen aidat, gecikme ve ödeme tutarları **tesis yönetiminin belirlediği, uygulama dışında tüketilen gerçek dünya hizmetlerinin** bedelidir (yönetim, temizlik, güvenlik, bakım, ortak gider).",
            "Bu nedenle **uygulama içi satın alma (in-app purchase) kullanılmaz**; ödeme, tesisin kendi tahsilat yöntemiyle yapılır.",
            "Yönetiyor bu tutarları belirlemez, tahsil etmez ve bunlardan pay almaz; yalnızca kaydını tutar. Tutarlara ilişkin itirazlarınızı tesis yönetimine iletirsiniz.",
          ],
        },
        {
          baslik: "4. Kabul edilmeyen kullanım",
          paragraflar: [
            "Başkasının hesabını kullanmak, sistemi yetkiniz dışında bir veriye erişmek için zorlamak, hizmeti aşırı yükleyecek otomatik istek göndermek yasaktır.",
            "Yüklediğiniz içerik hakaret, tehdit, ayrımcılık ya da hukuka aykırı unsur içeremez. Başkalarının kişisel verisini izinsiz paylaşamazsınız.",
            "Bu kurallara aykırı kullanım hâlinde tesis yönetimi hesabınızı askıya alabilir.",
          ],
        },
        {
          baslik: "5. İçerik ve sorumluluk",
          paragraflar: [
            "Duyuru, talep, fotoğraf gibi içeriklerin doğruluğundan bunları giren kullanıcı sorumludur.",
            "Otomatik çeviriler bilgilendirme amaçlıdır ve bağlayıcı metin her zaman orijinaldir; çevrilen her içerik uygulamada bu notu taşır.",
            "Yönetiyor, hizmetin kesintisiz ve hatasız olacağını taahhüt etmez; makul çabayı gösterir ve bilinen sorunları giderir.",
          ],
        },
        {
          baslik: "6. Hizmette değişiklik",
          paragraflar: [
            "Özellikler zamanla değişebilir, eklenebilir veya kaldırılabilir. Önemli değişiklikler uygulama içinde duyurulur.",
            "Bakım nedeniyle kısa süreli kesintiler olabilir.",
          ],
        },
        {
          baslik: "7. Hesabın sona ermesi",
          paragraflar: [
            "**Hesabınızı istediğiniz an uygulama içinden silebilirsiniz:** Ayarlar → Hesabımı sil.",
            "Yasal olarak saklanması zorunlu olan aidat/ödeme ve denetim kayıtları, kimliğinizle bağlantısı kesilerek anonim biçimde saklanmaya devam eder. Ayrıntı için Gizlilik Politikası.",
            "Tesisten ayrılmanız hâlinde yönetim hesabınızı kapatabilir.",
          ],
        },
        {
          baslik: "8. Uygulanacak hukuk ve iletişim",
          paragraflar: [
            "Bu koşullara Türkiye Cumhuriyeti hukuku uygulanır.",
            "İletişim: **destek@yonetiyor.com**",
          ],
        },
      ],
    };

/** KVKK Aydinlatma Metni = panelin "Gizlilik Politikasi" belgesi. */
export const KVKK_AYDINLATMA: Belge =
{
      baslik: "Gizlilik Politikası",
      guncelleme: "Son güncelleme: 2 Ağustos 2026",
        giris:
        "Bu politika, Yönetiyor uygulamasını ve yönetim panelini kullandığınızda hangi kişisel verilerin işlendiğini, neden işlendiğini ve haklarınızı açıklar.",
      bolumler: [
        {
          baslik: "1. Kim veri sorumlusudur?",
          paragraflar: [
            "Yönetiyor bir yazılım hizmetidir ve her tesis (site, apartman, rezidans) kendi verisini kendi alanında tutar.",
            "KVKK anlamında **veri sorumlusu, hesabınızın bağlı olduğu tesisin yönetimidir**. Yönetiyor, o yönetim adına veriyi işleyen taraftır (veri işleyen).",
            "Bu ayrım pratikte şu anlama gelir: verinizin silinmesi, düzeltilmesi ya da kime gösterildiği konusundaki talepleriniz önce tesis yönetimine iletilir. Yönetiyor, yönetimin talimatı dışında verinizi kullanmaz.",
          ],
        },
        {
          baslik: "2. Hangi veriler işlenir?",
          paragraflar: [
            "**Kimlik ve iletişim:** ad, telefon numarası, varsa e-posta adresi, daire/blok bilgisi, profil fotoğrafı (isteğe bağlı).",
            "**Kullanım kayıtları:** giriş kayıtları, uygulamada yaptığınız işlemlerin denetim kaydı (kim, ne zaman, hangi kaydı değiştirdi).",
            "**Finansal kayıtlar:** aidat tahakkukları, ödemeler, kasa hareketleri.",
            "**Konum (yalnızca saha personeli):** devriye turu okutmalarında konum bir KANIT olarak kaydedilir. Konum izni verilmese de okutma kaydedilir; uygulama arka planda sizi izlemez.",
            "**Kamera ve fotoğraf:** görev/talep/etkinlik fotoğrafları yalnız siz seçtiğinizde yüklenir.",
            "**NFC:** tur noktalarındaki etiketleri okutmak için kullanılır; etiketten kişisel veri okunmaz.",
          ],
        },
        {
          baslik: "3. Neden işlenir?",
          paragraflar: [
            "Tesis yönetim hizmetinin yürütülmesi: aidat tahakkuku ve tahsilatı, talep/şikâyet takibi, duyuru ve etkinlik yönetimi, güvenlik turlarının kaydı.",
            "Yasal yükümlülüklerin yerine getirilmesi: defter ve muhasebe kayıtlarının saklanması.",
            "Hizmetin güvenliği: yetkisiz erişimin tespiti, denetim kaydı.",
            "Pazarlama iletileri **yalnızca açık rızanızla** gönderilir ve rızayı istediğiniz an Ayarlar'dan geri alabilirsiniz.",
          ],
        },
        {
          baslik: "4. Kimlerle paylaşılır?",
          paragraflar: [
            "**Barındırma:** veriler Yönetiyor'un kendi sunucularında tutulur.",
            "**Otomatik çeviri:** kendi altyapımızda çalışan LibreTranslate kullanılır. Metinleriniz çeviri için **üçüncü bir şirkete gönderilmez**; sunucularımızın dışına çıkmaz.",
            "**Ödeme:** kart ile ödeme özelliği **şu anda etkin değildir**. Etkinleştirildiğinde ödeme bilgileri doğrudan lisanslı ödeme kuruluşuna (iyzico) gider ve kart verisi bizim sistemimizde tutulmaz; bu politika o gün güncellenir.",
            "**Bildirim:** anlık bildirim altyapısı (Firebase Cloud Messaging) **şu anda etkin değildir**. Etkinleştirildiğinde cihaz bildirim jetonu Google'a iletilir; bildirim içeriği kişisel veri taşımayacak şekilde kurgulanır.",
            "Bunların dışında verileriniz hiçbir üçüncü tarafa satılmaz, reklam amacıyla paylaşılmaz.",
          ],
        },
        {
          baslik: "5. Yapay zekâ ve otomatik çeviri",
          paragraflar: [
            "Uygulamada **üretken yapay zekâ (metin/görsel üreten model) kullanılmamaktadır**.",
            "Kullanılan tek otomatik işlem, duyuru/site kuralı/etkinlik metinlerinin **makine çevirisidir** ve kendi sunucumuzda çalışır.",
            "Otomatik çevrilen her içerik uygulamada **\"Bu içerik otomatik çevrilmiştir\"** notunu ve **\"Orijinali gör\"** seçeneğini taşır. Çeviri bir yorumdur; bağlayıcı metin her zaman orijinaldir.",
            "Kararlarınızı etkileyen otomatik bir profilleme ya da tamamen otomatik karar verme süreci yoktur.",
          ],
        },
        {
          baslik: "6. Ne kadar süre saklanır?",
          paragraflar: [
            "Ziyaretçi ve kargo kayıtları 24 ay, tamamlanmış rezervasyonlar 24 ay, çözülmüş talep/şikâyetler 36 ay, denetim kaydı 24 ay saklanır ve süre dolunca otomatik olarak silinir veya anonimleştirilir.",
            "Muhasebe ve finans kayıtları, ilgili mevzuatın öngördüğü süre boyunca saklanır.",
          ],
        },
        {
          baslik: "7. Haklarınız",
          paragraflar: [
            "KVKK md. 11 ve GDPR kapsamında: verilerinize erişme, düzeltilmesini isteme, silinmesini isteme, işlemeye itiraz etme ve rızanızı geri alma haklarına sahipsiniz.",
            "**Hesabınızı uygulama içinden silebilirsiniz:** Ayarlar → Hesabımı sil. Adınız, telefonunuz, e-postanız, profil fotoğrafınız ve cihaz kayıtlarınız silinir; giriş yapamaz hâle gelirsiniz.",
            "**Devriye okutmalarında kaydedilen konum bilgileri ve yüklediğiniz fotoğraflar silinmez:** bunlar tesisin operasyonel ve denetim kaydıdır ve silinmeleri o kaydın geçmişini bozardı. Silme sonrasında bu kayıtlar sizinle ilişkilendirilemez hâle gelir. Ayrıntı: yonetiyor.com/hesap-silme",
            "Yasal olarak saklanması zorunlu olan aidat/ödeme ve denetim kayıtları silinemez; bu kayıtlar **adınızla ilişkisi kesilerek anonim** hâlde saklanmaya devam eder. Bu, tesisin diğer sakinlerinin doğru hesap görme hakkının korunması için zorunludur.",
            "Diğer talepleriniz için önce tesis yönetiminize, sonuç alamazsanız aşağıdaki adrese başvurabilirsiniz.",
          ],
        },
        {
          baslik: "8. Çerezler ve izleme",
          paragraflar: [
            "Yönetim panelinde yalnızca **oturum** ve **dil tercihi** çerezleri kullanılır.",
            "Reklam çerezi, üçüncü taraf analitik ya da cihazlar arası izleme **kullanılmaz**. Mobil uygulama reklam kimliği (IDFA) toplamaz.",
          ],
        },
        {
          baslik: "9. Güvenlik",
          paragraflar: [
            "Tüm bağlantılar HTTPS ile şifrelenir. Parolalar geri döndürülemez biçimde (bcrypt) saklanır.",
            "Her tesisin verisi veritabanı düzeyinde satır bazlı güvenlikle (RLS) ayrılır: bir tesisin kullanıcısı başka bir tesisin verisini göremez.",
            "Kişisel veriye erişen işlemler denetim kaydına yazılır ve bu kayıt değiştirilemez.",
          ],
        },
        {
          baslik: "10. Çocuklar",
          paragraflar: [
            "Hizmet 13 yaşından küçüklere yönelik değildir ve hesaplar tesis yönetimi tarafından yetişkin sakinler/çalışanlar için açılır.",
          ],
        },
        {
          baslik: "11. Değişiklikler ve iletişim",
          paragraflar: [
            "Bu politika değişirse yukarıdaki güncelleme tarihi değişir; önemli değişiklikler uygulama içinde duyurulur.",
            "Sorularınız için: **kvkk@yonetio.site**",
          ],
        },
      ],
    };

/**
 * =========================================================================
 * CEREZ POLITIKASI — MUSTAKIL BELGE HENUZ YOK
 * =========================================================================
 * Sartname uc belge istiyor; ilk ikisi (`KULLANICI_SOZLESMESI`,
 * `KVKK_AYDINLATMA`) P113'te yazildi ve yukarida BIREBIR duruyor.
 * MUSTAKIL BIR CEREZ POLITIKASI ISE HIC YAZILMADI — P160-P176 arasinda
 * arandi, yok. Var olan tek cerez metni, KVKK Aydinlatma Metni'nin
 * 8. bolumudur.
 *
 * "METIN UYDURMA" kurali geregi eksik bolumler YAZILMADI. Sayfa, var
 * olan bolumu OLDUGU GIBI gosterir ve ustunde belgenin tamamlanmadigini
 * ACIKCA soyleyen bir not tasir. Eksik, docs/P177-kararlar.md'de
 * raporlandi.
 *
 * Bolum METINDEN TURETILIYOR, kopyalanmiyor: KVKK metnindeki 8. bolum
 * guncellenirse burasi da kendiliginden guncellenir. Baslik esleme ile
 * bulunur; bulunamazsa bos dizi doner ve sayfa yalniz notu gosterir —
 * sessizce yanlis bir bolum gostermez.
 */
export const CEREZ_BOLUMLERI: Bolum[] = KVKK_AYDINLATMA.bolumler.filter((b) =>
  b.baslik.toLocaleLowerCase("tr").includes("çerez"),
);

/** Sayfada gorunen EKSIKLIK NOTU — hukuki metin degil, site bildirimidir. */
export const CEREZ_EKSIK_NOTU =
  "Müstakil çerez politikası belgesi hazırlanma aşamasındadır. Aşağıda, " +
  "KVKK Aydınlatma Metni’nin çerezlere ilişkin bölümü yer alır; bu bölüm " +
  "bugün için geçerli olan tam metindir.";
