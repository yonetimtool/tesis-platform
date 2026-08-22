import Link from "next/link";

/**
 * Marka kilidi: isaret + kelime isareti.
 *
 * ISARET, TAM LOGO DEGIL. `assets/marka/yonetiyor-logo.png` DIKEY bir
 * kompozisyondur (1072x992, altigen + govde + kelime isareti); 36 px
 * yuksekligindeki bir baslik seridinde ic figurler tamamen kayboluyor.
 * `scripts/ikon-uret.py` ayni karar verilmis kirpmadan (§8) dolgusuz,
 * saydam bir KARE isaret uretiyor — burada kullanilan odur.
 *
 * IKI VARYANT: koyu murekkep acik zemin icin, beyaz siluet koyu
 * altbilgi icin. Tek dosyayi iki yerde kullanmak, koyu zeminde lacivert
 * bir lekeye bakmak olurdu.
 *
 * `next/image` KULLANILMIYOR: `images.unoptimized` acik oldugu icin
 * `next/image` zaten duz bir `<img>`e cozuluyor; sabit boyutlu tek bir
 * marka gorseli icin sarmalayicinin karsiligi yok. `width`/`height`
 * YAZILI — yazilmazsa gorsel inerken satir yuksekligi atlar (CLS).
 */
export function Logo({ koyu = false }: { koyu?: boolean }) {
  return (
    <Link
      href="/"
      className="inline-flex items-center gap-2.5"
      aria-label="Yönetiyor — ana sayfa"
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={koyu ? "/marka/web-marka-beyaz-160.png" : "/marka/web-marka-160.png"}
        alt=""
        width={160}
        height={160}
        className="h-8 w-8"
      />
      <span
        className={`text-[1.05rem] font-extrabold tracking-[-0.02em] ${
          koyu ? "text-white" : "text-lacivert"
        }`}
      >
        Yönetiyor
      </span>
    </Link>
  );
}
