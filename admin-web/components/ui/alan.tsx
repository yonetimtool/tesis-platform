"use client";

/**
 * (P160 / Asama 3) FORM ALANLARI — `Alan` (input), `Secim` (select),
 * `AlanSarmal` (etiket + hata + ipucu).
 *
 * =========================================================================
 * GIRINTILI YUZEY — kabartmanin TERSI
 * =========================================================================
 * Brief: "sunken: tersi — inset koyu ust, acik alt (input ve girintili
 * alanlar)". Bu, neumorphism'in okunabilirlik acisindan en ise yarar
 * tarafi: kullanici bir alanin YAZILABILIR oldugunu golgenin yonunden
 * anlar, yalnizca kenarligindan degil.
 *
 * =========================================================================
 * ETIKET HER ZAMAN VAR — `placeholder` ETIKET DEGILDIR
 * =========================================================================
 * `AlanSarmal` etiketi ZORUNLU kilar ve `htmlFor`/`id` baglantisini
 * kendisi kurar. Yer tutucuyu etiket yerine kullanmak yaygin bir hatadir:
 * kullanici yazmaya baslayinca alanin ne oldugu KAYBOLUR ve ekran
 * okuyucu bazi tarayicilarda onu hic okumaz.
 *
 * HATA `aria-describedby` ILE BAGLANIR ve `aria-invalid` isaretlenir —
 * kirmizi kenarlik tek basina renk korlugu olan kullaniciya bir sey
 * soylemez (WCAG 1.4.1).
 */
import {
  forwardRef,
  useId,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
} from "react";

/* ------------------------------------------------------------------ */

const TEMEL_KUTU: React.CSSProperties = {
  borderRadius: "var(--yz-radius-input)",
  background: "var(--yz-surface-sunken)",
  boxShadow: "var(--yz-sunken)",
  borderWidth: "var(--yz-border-w)",
  borderStyle: "solid",
  borderColor: "var(--yz-border)",
  color: "var(--yz-text)",
  // (P169 §3.3) GIRDI FONTU 16 px — DIGER METINLERDEN AYRI.
  //
  // iOS Safari, odaklanilan bir girdinin font boyutu 16 px'in ALTINDAYSA
  // sayfayi otomatik YAKINLASTIRIR ve geri cikmaz: kullanici her alana
  // dokundugunda sayfa ziplar, yatay kaydirma acilir ve duzen bozulur.
  //
  // `--yz-fs-body` 14 px ve BOYLE KALMALI — govde metni icin dogru olcu
  // odur. Bu yuzden girdilere OZEL bir token acildi; `--yz-fs-body`yi
  // 16'ya cikarmak, sitedeki butun metni buyutup masaustu duzenini
  // bozardi (brief'in kirmizi cizgisi).
  fontSize: "var(--yz-fs-input)",
};

function kutuStili(hatali: boolean): React.CSSProperties {
  return hatali
    ? { ...TEMEL_KUTU, borderColor: "var(--yz-danger-edge)" }
    : TEMEL_KUTU;
}

/* ==================================================================== */

export function AlanSarmal({
  etiket,
  children,
  hata,
  ipucu,
  id,
  zorunlu = false,
}: {
  etiket: string;
  children: (baglar: {
    id: string;
    "aria-invalid": boolean | undefined;
    "aria-describedby": string | undefined;
  }) => ReactNode;
  hata?: string | null;
  ipucu?: string;
  id?: string;
  zorunlu?: boolean;
}) {
  const otoId = useId();
  const alanId = id ?? otoId;
  const hataId = `${alanId}-hata`;
  const ipucuId = `${alanId}-ipucu`;
  // Hata VARSA yalniz hataya isaret edilir: ikisini birden okutmak,
  // kullaniciya once ipucunu sonra hatayi dinletir ve asil mesaji gomer.
  const aciklamaId = hata ? hataId : ipucu ? ipucuId : undefined;

  return (
    <div className="block">
      <label
        htmlFor={alanId}
        className="mb-1 block"
        style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
      >
        {etiket}
        {zorunlu && (
          // Yildiz DEKORATIF: zorunluluk `required` ozniteligiyle ekran
          // okuyucuya zaten bildiriliyor.
          <span aria-hidden="true" style={{ color: "var(--yz-danger-ink)" }}>
            {" *"}
          </span>
        )}
      </label>
      {children({
        id: alanId,
        "aria-invalid": hata ? true : undefined,
        "aria-describedby": aciklamaId,
      })}
      {hata ? (
        <p
          id={hataId}
          role="alert"
          className="mt-1"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger-ink)" }}
        >
          {hata}
        </p>
      ) : ipucu ? (
        <p
          id={ipucuId}
          className="mt-1"
          style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
        >
          {ipucu}
        </p>
      ) : null}
    </div>
  );
}

/* ==================================================================== */

export function Alan({
  hatali = false,
  className = "",
  style,
  ...rest
}: InputHTMLAttributes<HTMLInputElement> & { hatali?: boolean }) {
  return (
    <input
      {...rest}
      className={`odak-ic h-11 w-full px-3 outline-none ${className}`}
      style={{ ...kutuStili(hatali), ...style }}
    />
  );
}

/**
 * (P168 §4.1) `forwardRef` EKLENDI.
 *
 * Etiket cipleri metni IMLECIN OLDUGU YERE ekliyor ve bunun icin
 * `selectionStart` gerekiyor — yani cagiranin DOM dugumune erisimi
 * olmali. Ref olmadan tek secenek metni SONA eklemekti; cumlenin
 * ortasina etiket koymak isteyen kullanici, metni elle tasimak zorunda
 * kalirdi.
 */
export const CokSatir = forwardRef<
  HTMLTextAreaElement,
  React.TextareaHTMLAttributes<HTMLTextAreaElement> & { hatali?: boolean }
>(function CokSatir({ hatali = false, className = "", style, ...rest }, ref) {
  return (
    <textarea
      {...rest}
      ref={ref}
      className={`odak-ic w-full px-3 py-2 outline-none ${className}`}
      style={{ ...kutuStili(hatali), ...style }}
    />
  );
});

export function Secim({
  hatali = false,
  className = "",
  style,
  children,
  ...rest
}: SelectHTMLAttributes<HTMLSelectElement> & { hatali?: boolean }) {
  return (
    <select
      {...rest}
      className={`odak-ic h-11 w-full px-3 outline-none ${className}`}
      style={{ ...kutuStili(hatali), ...style }}
    >
      {children}
    </select>
  );
}

/**
 * ARAMA ALANI — ikonlu, temizlenebilir.
 *
 * `type="search"` KULLANILMIYOR: tarayicilarin yerlesik temizle dugmesi
 * her platformda farkli gorunur ve metalik dile uymaz; ayrica Safari'de
 * `Escape` davranisi form gonderimini tetikleyebiliyor. Temizleme
 * dugmesini kendimiz ciziyoruz.
 */
export function AramaAlani({
  deger,
  onDegisim,
  etiket,
  yerTutucu,
  temizleEtiketi,
}: {
  deger: string;
  onDegisim: (v: string) => void;
  /** Gorunmez etiket — arama kutusunun ADI olmali (ekran okuyucu). */
  etiket: string;
  yerTutucu?: string;
  temizleEtiketi: string;
}) {
  const id = useId();
  return (
    <div className="relative">
      <label htmlFor={id} className="sr-only">
        {etiket}
      </label>
      <span
        aria-hidden="true"
        className="pointer-events-none absolute inset-y-0 start-3 flex items-center"
        style={{ color: "var(--yz-text-3)" }}
      >
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
          <circle cx="11" cy="11" r="7" />
          <path d="m20 20-3.5-3.5" />
        </svg>
      </span>
      <input
        id={id}
        value={deger}
        onChange={(e) => onDegisim(e.target.value)}
        placeholder={yerTutucu}
        className="odak-ic h-11 w-full ps-9 pe-9 outline-none"
        style={TEMEL_KUTU}
      />
      {deger && (
        <button
          type="button"
          onClick={() => onDegisim("")}
          aria-label={temizleEtiketi}
          className="odak-ic yz-dokunma-44 absolute inset-y-0 end-2 my-auto flex h-7 w-7 items-center justify-center rounded-full"
          style={{ color: "var(--yz-text-2)" }}
        >
          <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
      )}
    </div>
  );
}
