import Link from "next/link";

import { IletisimFormu } from "@/components/IletisimFormu";
import { MagazaDugmeleri } from "@/components/MagazaDugmeleri";

/**
 * (P177 §2) ANA SAYFA — capa bagli tek sayfa.
 *
 * =========================================================================
 * IMZA OGESI: IKI KAPILI KAHRAMAN
 * =========================================================================
 * Bu urunun on kapisindaki en karakteristik gercek su: kapiya iki farkli
 * insan geliyor ve YALNIZ BIRI kayit olabiliyor. Cogu yazilim sitesi bunu
 * gizler ve herkese ayni "Ucretsiz dene" dugmesini gosterir; sonra sakin
 * kaydolmaya calisir, olmaz ve destege yazar.
 *
 * Burada ayrim SAYFANIN KENDISI: kahraman iki tam yukseklikte kapiya
 * bolunmus, biri koyu (yonetici — kaydolan taraf), biri acik (sakin —
 * bilgilendirilen taraf). Masaustunde egik bir dikisle bulusurlar;
 * mobilde alt alta yiginlar. Sayfanin isi bu tek ekranda bitiyor.
 *
 * =========================================================================
 * NUMARALANDIRMA YALNIZ "NASIL CALISIR"DA
 * =========================================================================
 * 01/02/03 isaretleri dekorasyon degil: o bolum GERCEKTEN bir siradir
 * (once tesis acilir, sonra kisiler eklenir, sonra kisiler katilir).
 * Yetenek kartlarinda numara YOK — orada sira bir sey anlatmazdi.
 */
export const metadata = {
  alternates: { canonical: "/" },
};

const YETENEKLER = [
  {
    baslik: "Aidat ve tahsilat",
    metin:
      "Daire bazlı borçlandırma, tahsilat kaydı, gecikme takibi ve aylık finans özeti. Ödeme, tesisin kendi yöntemiyle yapılır.",
  },
  {
    baslik: "Talep ve arıza",
    metin:
      "Sakinin bildirdiği arıza kategoriyle kaydedilir, iş emrine dönüşür, görevliye atanır ve kapanana kadar izlenir.",
  },
  {
    baslik: "Duyuru ve etkinlik",
    metin:
      "Yönetim duyurusu tüm sakinlere ulaşır; takvim, etkinlik ve site kuralları aynı yerde durur.",
  },
  {
    baslik: "Ortak alan rezervasyonu",
    metin:
      "Toplantı salonu, teras, spor alanı: sakin uygulamadan saat seçer, onay beklemeden kesinleşir; kurallar tesise göre ayarlanır.",
  },
  {
    baslik: "Ziyaretçi ve kargo",
    metin:
      "Güvenlik ziyaretçiyi ve gelen kargoyu kaydeder, sakine bildirilir. Araç geçişleri plaka okumayla eşleşir.",
  },
  {
    baslik: "Güvenlik turu",
    metin:
      "NFC noktalarıyla tur planı, gecikme alarmı ve tur geçmişi. Turun gerçekten yapıldığı kayda geçer.",
  },
];

const GUVEN = [
  { baslik: "KVKK’ya göre kurulmuş", metin: "Aydınlatma metni, saklama süreleri ve otomatik imha zaten işliyor." },
  { baslik: "Değiştirilemez denetim kaydı", metin: "Kim ne zaman ne yaptı — silinmeyen bir kayıt olarak tutulur." },
  { baslik: "Rol bazlı yetki", metin: "Yönetici, denetçi, güvenlik, görevli ve sakin farklı şeyleri görür." },
  { baslik: "iOS ve Android", metin: "Sakinler ve saha ekibi işini telefondan yapar; yönetim web panelinden." },
];

const ADIMLAR = [
  { no: "01", baslik: "Yönetici kaydolur", metin: "Ad, e-posta ve parola. E-posta doğrulanır." },
  { no: "02", baslik: "Site kurulur", metin: "Site adını yazarsınız; tesis o anda açılır ve size bir Tesis ID verilir." },
  { no: "03", baslik: "Kişiler eklenir", metin: "Sakin, güvenlik ve görevlileri tek tek ya da Excel’le eklersiniz. Herkese Tesis ID’li bir e-posta gider." },
  { no: "04", baslik: "Herkes katılır", metin: "Kişiler uygulamayı indirir, Tesis ID’yi girer ve e-postasına gelen kodla kaydını tamamlar." },
];

const SORULAR = [
  {
    soru: "Site sakini kendi başına kaydolabilir mi?",
    yanit:
      "Hayır. Sakini, güvenliği ve görevliyi siteye yönetici ekler. Eklenen kişiye e-posta gider; kayıt uygulamadan tamamlanır. Tesis ID’yi bilmek tek başına yetmez — kişinin e-postasının yönetici listesinde olması gerekir.",
  },
  {
    soru: "Aidatı uygulama mı tahsil ediyor?",
    yanit:
      "Hayır. Aidat, tesis yönetiminin belirlediği ve uygulama dışında tüketilen bir hizmetin bedelidir. Yönetiyor bu tutarı belirlemez, tahsil etmez ve pay almaz; yalnızca kaydını tutar.",
  },
  {
    soru: "Telefonuma SMS gelir mi?",
    yanit:
      "Hayır. Telefon yalnızca iletişim bilgisidir. Doğrulama e-posta ile yapılır.",
  },
  {
    soru: "Verilerimiz ne kadar saklanıyor?",
    yanit:
      "Her kayıt türünün kendi saklama süresi var ve süre dolduğunda kayıt otomatik siliniyor ya da kimlikten koparılıyor. Ayrıntılar KVKK Aydınlatma Metni’nde.",
  },
  {
    soru: "Hesabımı silebilir miyim?",
    yanit:
      "Evet, uygulama içinden. Yasal olarak saklanması gereken aidat ve denetim kayıtları kimliğinizle bağlantısı kesilerek anonim biçimde kalır.",
  },
];

export default function AnaSayfa() {
  return (
    <>
      {/* ================= KAHRAMAN: IKI KAPI ================= */}
      {/* TAM EKRAN — AMA YALNIZ `lg` USTUNDE.
          `100svh` (`vh` DEGIL): mobil tarayicilarda `vh`, adres cubugu
          kayarken degisir ve duzen zipla. `svh` en kucuk gorunur alani
          alir, yani hicbir kare kirpilmaz.
          Kucuk ekranda min-yukseklik VERILMIYOR: iki kapi alt alta
          yigiliyor ve zorlanmis bir yukseklik, telefonda ilk ekrandan
          tasan bir kahraman uretirdi. Cikarilan `4.5rem` yapiskan
          basligin yuksekligi. */}
      <section className="flex flex-col justify-between border-b border-cizgi lg:min-h-[calc(100svh-4.5rem)]">
        <div className="kapsayici pt-14 sm:pt-20">
          <p className="beliren etiket">Site ve apartman yönetimi</p>
          <h1 className="beliren gecikme-1 mt-4 max-w-[20ch] text-dev">
            Sitenin işleri
            <br />
            tek yerde.
          </h1>
          <p className="beliren gecikme-2 mt-6 max-w-[52ch] text-[1.125rem] leading-relaxed text-govde">
            Aidat, arıza, duyuru, rezervasyon, ziyaretçi ve güvenlik turları.
            Yönetici siteyi kurar; sakinler ve saha ekibi uygulamadan katılır.
          </p>
        </div>

        <div className="beliren gecikme-3 kapsayici mt-12 pb-16 sm:mt-16">
          <p className="mb-4 text-kucuk font-bold text-soluk">Başlamak için birini seçin</p>
          <div className="flex flex-col lg:flex-row">
            <Link
              href="/yonetici"
              className="kapi-sol group flex flex-1 flex-col justify-between gap-10 rounded-blok bg-lacivert p-8 text-white lg:rounded-r-none lg:pr-16"
            >
              <div>
                <p className="text-etiket uppercase text-maviAcik">Kaydolan taraf</p>
                <h2 className="mt-3 text-[clamp(1.5rem,3vw,2rem)] font-extrabold tracking-[-0.03em] text-white">
                  Yöneticiyim
                </h2>
                <p className="mt-3 max-w-[36ch] text-kucuk text-maviAcik">
                  Siteyi siz kurarsınız. Kaydolun, site adını yazın, Tesis
                  ID’nizi alın.
                </p>
              </div>
              <span className="inline-flex items-center gap-2 font-bold text-white">
                Devam et
                <span aria-hidden="true" className="transition-transform group-hover:translate-x-1">→</span>
              </span>
            </Link>

            <Link
              href="/site-sakini"
              className="kapi-sag group flex flex-1 flex-col justify-between gap-10 rounded-blok border border-cizgi bg-kart p-8 lg:rounded-l-none lg:pl-16"
            >
              <div>
                <p className="etiket">Davet edilen taraf</p>
                <h2 className="mt-3 text-[clamp(1.5rem,3vw,2rem)] font-extrabold tracking-[-0.03em] text-lacivert">
                  Site sakiniyim
                </h2>
                <p className="mt-3 max-w-[36ch] text-kucuk text-govde">
                  Siteden kayıt olunmaz. Yöneticiniz sizi ekler, kaydınızı
                  uygulamadan tamamlarsınız.
                </p>
              </div>
              <span className="inline-flex items-center gap-2 font-bold text-mavi">
                Nasıl olduğunu gör
                <span aria-hidden="true" className="transition-transform group-hover:translate-x-1">→</span>
              </span>
            </Link>
          </div>
        </div>
      </section>

      {/* ================= NE ISE YARAR ================= */}
      <section id="ne-ise-yarar" className="bolum border-b border-cizgi">
        <div className="kapsayici grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-16">
          <div>
            <p className="etiket">Ne işe yarar</p>
            <h2 className="mt-4 text-bolum">
              Yönetim işi WhatsApp gruplarında kaybolmasın.
            </h2>
          </div>
          <div className="space-y-5 text-[1.05rem] leading-relaxed">
            <p>
              Bir sitede aynı anda yürüyen çok iş var: aidat kimden alındı,
              hangi arıza kimde, asansör bakımı ne zaman, dün gece kim girdi.
              Bunlar genelde farklı defterlerde, farklı telefonlarda ve
              birbirini görmeyen gruplarda duruyor.
            </p>
            <p>
              Yönetiyor bu işleri tek kayıt düzenine alır. Yönetici panelden
              görür ve yazar; sakin, güvenlik ve görevli kendi işini
              telefondan yapar. Aynı olay iki yere yazılmaz.
            </p>
            <p className="font-semibold text-baslik">
              Sonuç: devir teslimde kaybolmayan, sorulduğunda gösterilebilen
              bir yönetim kaydı.
            </p>
          </div>
        </div>
      </section>

      {/* ================= YETENEKLER ================= */}
      <section id="yetenekler" className="bolum border-b border-cizgi">
        <div className="kapsayici">
          <p className="etiket">Öne çıkan yetenekler</p>
          <h2 className="mt-4 max-w-[18ch] text-bolum">Günlük işin tamamı.</h2>
          <ul className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {YETENEKLER.map((y) => (
              <li key={y.baslik} className="kart">
                <h3 className="text-kartbaslik">{y.baslik}</h3>
                <p className="mt-2.5 text-kucuk leading-relaxed text-govde">{y.metin}</p>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ================= GUVEN SERIDI ================= */}
      {/* Musteri logosu ve referans YOK: elimizde yayimlanabilir bir
          referans yok ve uydurmak yalan olurdu. Serit, urunun GERCEKTEN
          tasidigi ozelliklerden kurulu. */}
      <section className="border-b border-cizgi bg-lacivert text-maviAcik">
        <div className="kapsayici grid gap-8 py-14 sm:grid-cols-2 lg:grid-cols-4">
          {GUVEN.map((g) => (
            <div key={g.baslik}>
              <h3 className="text-kartbaslik text-white">{g.baslik}</h3>
              <p className="mt-2 text-kucuk leading-relaxed">{g.metin}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ================= NASIL CALISIR ================= */}
      <section id="nasil-calisir" className="bolum border-b border-cizgi">
        <div className="kapsayici">
          <p className="etiket">Nasıl çalışır</p>
          <h2 className="mt-4 max-w-[20ch] text-bolum">Dört adımda kurulur.</h2>
          <ol className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {ADIMLAR.map((a) => (
              <li key={a.no} className="kart">
                <p className="text-[1.75rem] font-extrabold leading-none tracking-[-0.04em] text-mavi">
                  {a.no}
                </p>
                <h3 className="mt-4 text-kartbaslik">{a.baslik}</h3>
                <p className="mt-2 text-kucuk leading-relaxed text-govde">{a.metin}</p>
              </li>
            ))}
          </ol>
          <div className="mt-10">
            <Link href="/yonetici/kayit" className="dugme-birincil">Kayıt Ol</Link>
          </div>
        </div>
      </section>

      {/* ================= SIK SORULANLAR ================= */}
      <section id="sorular" className="bolum border-b border-cizgi">
        <div className="kapsayici grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
          <div>
            <p className="etiket">Sık sorulanlar</p>
            <h2 className="mt-4 text-bolum">Önce şunlar soruluyor.</h2>
          </div>
          {/* `<details>` — JS'siz calisir, klavyeyle acilir, ekran
              okuyucuya durumu kendisi bildirir. Ozel bir akordeon yazmak
              bu ucunu de elle kurmak olurdu. */}
          <div className="divide-y divide-cizgi border-y border-cizgi">
            {SORULAR.map((s) => (
              <details key={s.soru} className="group py-5">
                <summary className="flex cursor-pointer list-none items-start justify-between gap-4 font-bold text-baslik">
                  {s.soru}
                  <span aria-hidden="true" className="mt-0.5 shrink-0 text-mavi transition-transform group-open:rotate-45">
                    +
                  </span>
                </summary>
                <p className="mt-3 max-w-metin leading-relaxed text-govde">{s.yanit}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ================= UYGULAMA ================= */}
      <section id="uygulama" className="bolum border-b border-cizgi">
        <div className="kapsayici grid gap-10 lg:grid-cols-2 lg:items-center lg:gap-16">
          <div>
            <p className="etiket">Mobil uygulama</p>
            <h2 className="mt-4 max-w-[18ch] text-bolum">
              Sakinler ve saha ekibi telefondan.
            </h2>
            <p className="mt-5 max-w-[46ch] leading-relaxed">
              Arıza bildirmek, aidat görmek, rezervasyon yapmak, tur okutmak
              ve ziyaretçi kaydetmek uygulamada. Yönetim panelinin tamamı ise
              web tarayıcısında.
            </p>
            <div className="mt-8">
              <MagazaDugmeleri />
            </div>
          </div>
          <div className="kart bg-zemin">
            <p className="text-kartbaslik">Uygulamaya nasıl girilir?</p>
            <ol className="mt-4 space-y-3 text-kucuk leading-relaxed text-govde">
              <li>1. Uygulamayı indirin.</li>
              <li>2. “Kayıt Ol” deyip rolünüzü seçin.</li>
              <li>3. Yöneticinizin verdiği Tesis ID’yi girin.</li>
              <li>4. E-postanıza gelen kodu yazın.</li>
            </ol>
            <p className="mt-5 text-kucuk text-soluk">
              Bu adımlar sakin, güvenlik ve tesis görevlisi içindir.
              Yöneticiler siteden kaydolur.
            </p>
          </div>
        </div>
      </section>

      {/* ================= ILETISIM ================= */}
      <section id="iletisim" className="bolum">
        <div className="kapsayici grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
          <div>
            <p className="etiket">İletişim</p>
            <h2 className="mt-4 text-bolum">Sorunuz mu var?</h2>
            <p className="mt-5 max-w-[40ch] leading-relaxed">
              Sitenizin durumu, taşıma ya da fiyatlandırma hakkında yazın;
              bıraktığınız iletişim bilgisinden dönelim.
            </p>
          </div>
          <IletisimFormu />
        </div>
      </section>
    </>
  );
}
