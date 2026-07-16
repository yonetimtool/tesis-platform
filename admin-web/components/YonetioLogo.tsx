/**
 * Yönetio marka isareti — BASITLESTIRILMIS turev, inline SVG (harici
 * asset/font yok).
 *
 * Neden tam master logo degil: saglanan logo (mavi→teal gradyan zemin + uc
 * bina + insanlar + yay) ~32px altinda okunmuyor — 32px'te render edilip
 * gozle bakildi, detaylar bulaniyor. Nav header'daki 28px bu esigin altinda.
 * Bu yuzden burada mobildeki `YonetioSimpleMarkPainter` ile BIREBIR ayni
 * geometri kullanilir: merkez bina (egik cati) + chevron/cati ucgeni.
 *
 * Geometri 0..1 normalize edilip 100 ile olceklenmistir (viewBox 0 0 100 100)
 * — mobil painter'daki sayilarla ayni.
 */

export function YonetioMark({
  size = 28,
  className = "text-[#0E3C91] dark:text-white",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      role="img"
      aria-label="Yönetio"
      className={className}
      fill="currentColor"
    >
      {/* Merkez bina — egik cati cizgisi sol-ustten saga yukselir. */}
      <path d="M35 24 L58 9 L66 9 L66 50 L35 50 Z" />
      {/* Chevron/cati — DOLU ucgen; cizgi olarak "ayrik bacaklar" gibi
          okunuyordu. */}
      <path d="M9 78 L50 44 L91 78 Z" />
    </svg>
  );
}

/** Ikon + kelime isareti. Kelime navy (acik) / beyaz (koyu) — .dark uzerinden. */
export function YonetioLogo({ size = 28 }: { size?: number }) {
  return (
    <span className="flex items-center gap-2">
      <YonetioMark size={size} />
      <span className="text-lg font-semibold tracking-tight text-[#0E3C91] dark:text-white">
        yönetio
      </span>
    </span>
  );
}
