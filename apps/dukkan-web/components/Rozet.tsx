/**
 * DOGRULAMA ROZETI — seviye farki GORUNUR olmali, ince yaziyla degil.
 *
 * Seviye 1 ("telefon dogrulandi") ile 2 ("belge dogrulandi") AYRI
 * gosteriliyor cunku ikisi farkli sey soyluyor: telefon dogrulamasi
 * numaranin kontrolunu kanitlar, KIMLIGI DEGIL (on odemeli hat 50
 * liraya alinir). Ikisini tek rozette birlestirmek kullaniciya yalan
 * soylemek olurdu — docs/dukkan/03-guven-ve-fraud.md §3.
 */
export function DogrulamaRozeti({ seviye }: { seviye: number }) {
  if (seviye >= 2) {
    return (
      <span className="inline-flex items-center gap-1 rounded bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-900">
        <span aria-hidden>✔</span> Doğrulanmış işletme
      </span>
    );
  }
  if (seviye === 1) {
    return (
      <span className="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-700">
        Telefon doğrulandı
      </span>
    );
  }
  return null;
}

/** Puan + yorum sayisi. Yorum YOKSA yildiz gostermiyoruz.
 *
 * Bos yildizlar "kotu puan" gibi okunur; "henuz yorum yok" ise NOTR bir
 * bilgidir ve dogruyu soyler. */
export function Puan({
  puan,
  sayi,
}: {
  puan: number | string | null;
  sayi: number;
}) {
  if (!sayi || puan === null) {
    return (
      <span className="text-xs text-[color:var(--dk-metin-soluk)]">
        Henüz değerlendirme yok
      </span>
    );
  }
  return (
    <span className="text-sm">
      <span aria-hidden>★</span> {Number(puan).toFixed(1)}{" "}
      <span className="text-[color:var(--dk-metin-soluk)]">
        ({sayi} değerlendirme)
      </span>
    </span>
  );
}
