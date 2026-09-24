/**
 * Yönetiyor logosu — Nav header'daki ikon + kelime isareti.
 *
 * =========================================================================
 * (P162) YENI MARKA ISARETI
 * =========================================================================
 * Isaret `docs/design-refs/yonetiyor_logo.png` ile degistirildi (altigen
 * cerceve + insanlar + govde). Eski `yonetio-master.png` KALDIRILDI;
 * "eski logoyu birakma" brief'in acik istegi.
 *
 * Varlik hazirligi `tools/png-arac.py` ile yapildi: ham dosyanin beyaz
 * zemini saydamlastirildi ve kenar paylari kirpildi. Ayni kaynak
 * favicon'a (`app/icon.png`), Apple ikonuna ve mobil master'a da isledi —
 * yani tek kaynak, dort cikti.
 *
 * Favicon bu dosyadan GELMEZ: `app/icon.png` ayri, bagimsiz bir statik
 * dosyadir (Next onu kendisi bulup hash'li <link rel="icon"> enjekte eder).
 *
 * =========================================================================
 * (P166 §6.2) KOYU TEMADA GORUNURLUK — AYRI VARYANT
 * =========================================================================
 * OLCULDU: `yonetio-logo.png`in opak piksellerinin ORTALAMASI RGB
 * (27, 65, 124) — koyu lacivert. Koyu temanin zemini de koyu; isaret
 * pratikte zeminde KAYBOLUYORDU. Kelime isareti (`dark:text-white`)
 * gorunuyor, ISARET gorunmuyordu — yani logo yarim cikiyordu.
 *
 * COZUM VARDI AMA BAGLI DEGILDI: `yonetio-logo-acik.png` (ters/reverse
 * varyant, ortalama RGB (190, 201, 218)) depoda P162'den beri duruyor ve
 * HICBIR YERDE kullanilmiyordu. Yeni bir varlik uretmek yerine o baglandi.
 *
 * IKISI DE CIZILIR, BIRI GIZLENIR (`dark:` sinifi). Neden JavaScript'le
 * tema okuyup TEK gorsel cizmedik: tema `.dark` sinifiyla SUNUCUDA
 * belirlenmis oluyor; istemcide okumak ilk karede YANLIS logoyu gosterir
 * ve kullanici bir "sicrama" gorurdu. Ikinci gorsel ~26 kB ve `priority`
 * degil — ilk boyayi gecikmez.
 *
 * BUYUDU: varsayilan 28 -> 34. Brief: "logo daha buyuk ve gorunur olsun".
 */

import Image from "next/image";

/**
 * Ikon + kelime isareti. Kelime navy (acik) / beyaz (koyu) — .dark uzerinden.
 *
 * (P170 §3) DAR EKRANDA KELIME ISARETI GIZLENIR, KUCULTULMEZ.
 *
 * OLCUM: 360 px'lik ust barda satir su ogelerden olusuyor — menu dugmesi
 * (~40) + logo blogu (~135: 30 px isaret + 8 bosluk + 20 px'lik "yönetiyor"
 * ~95 px) + bildirim/dil/hesap ucusu (~130) + yan bosluklar (32). Toplam
 * ~340 px'i asiyor ve `text-xl` kelime isaretinin sarma/kirpilma yeri YOK.
 *
 * IKI SECENEK VARDI:
 *   (a) kelimeyi kucultmek — 328 px'e sigmasi icin ~12 px gerekirdi. O
 *       boyutta kelime isareti okunmuyor ve marka olcegi baska her yerden
 *       (cekmece, giris, davet) farkli cikiyor. Kucuk ve cirkin bir marka,
 *       markasizliktan kotudur.
 *   (b) kelimeyi gizlemek — KIMLIK isaretle zaten tasiniyor; ust bardaki
 *       oteki uc oge ISLEVDIR (bildirim, dil, hesap) ve atilamaz.
 *
 * (b) SECILDI. Kayip da yok: cekmece acildiginda logo kelime isaretiyle
 * TAM cizilir (`AppShell` 534), yani marka adi bir dokunus uzakta.
 *
 * `whitespace-nowrap`: kelime hicbir genislikte IKINCI SATIRA dusmez —
 * dusseydi 56 px'lik ust bari tasirdi.
 *
 * ORAN KORUNUR: `width`/`height` esit veriliyor ve `Image` kaynak orani
 * kare oldugu icin isaret hicbir bantta EZILMEZ.
 */
// (E2E 2026-09) Sinif dizeleri ADLI — ucluda dize yazilmaz (`sabit-metin`).
const ISARET_HEP = "shrink-0";
const ISARET_TEMALI = "hidden shrink-0 dark:block";
const KELIME_HEP_ACIK = "text-white";
const KELIME_TEMALI = "text-[#0E3C91] dark:text-white";

export function YonetioLogo({
  size = 34,
  /** `false` ise kelime isareti YALNIZ `sm` ustunde cizilir (ust bar). */
  kelimeDar = true,
  /**
   * (P184-ek §10) `false` ise kelime isareti HIC cizilmez — yalniz isaret
   * kalir. Kenar cubugu KUCULTULDUGUNDE (68px) kullanilir: orada "yönetiyor"
   * sozcugu sigmaz ve kirpilirdi. `sr-only` DEGIL tamamen kaldirilir cunku
   * kucuk seritte logo linkinin erisilebilir adi zaten `aria-label`da.
   */
  kelimeGoster = true,
  /**
   * (E2E 2026-09) `true` ise logo TEMADAN BAGIMSIZ olarak acik murekkeple
   * cizilir. Kenar cubugu IKI TEMADA DA lacivert (`--yz-bg-sidebar`);
   * temaya gore renk secmek acik temada lacivert ustune lacivert
   * kelime (#0E3C91 / #14263a = 1.51:1, 65/65 rotada axe ihlali) ve koyu
   * isaret cizmekti.
   */
  koyuZemin = false,
}: {
  size?: number;
  kelimeDar?: boolean;
  kelimeGoster?: boolean;
  koyuZemin?: boolean;
}) {
  // Koyu zeminde yalniz acik varyant; aksi hâlde temaya gore.
  const koyuIsaretSinifi = koyuZemin ? ISARET_HEP : ISARET_TEMALI;
  const kelimeRengi = koyuZemin ? KELIME_HEP_ACIK : KELIME_TEMALI;
  return (
    <span className="flex min-w-0 items-center gap-2">
      {/* ACIK TEMA: koyu lacivert isaret. */}
      {!koyuZemin && (
        <Image
          src="/yonetio-logo.png"
          alt="Yönetiyor"
          width={size}
          height={size}
          priority
          className="shrink-0 dark:hidden"
        />
      )}
      {/* KOYU TEMA: ters (acik murekkep) varyant. `alt` BOS ve
          `aria-hidden`: ayni logonun ikinci kopyasi, ekran okuyucuya iki
          kez "Yönetiyor" demek olurdu. */}
      <Image
        src="/yonetio-logo-acik.png"
        alt={koyuZemin ? "Yönetiyor" : ""}
        aria-hidden={koyuZemin ? undefined : true}
        width={size}
        height={size}
        className={koyuIsaretSinifi}
      />
      {kelimeGoster && (
        <span
          className={`whitespace-nowrap text-xl font-semibold tracking-tight ${kelimeRengi}${
            kelimeDar ? "" : " hidden sm:inline"
          }`}
        >
          yönetiyor
        </span>
      )}
    </span>
  );
}
