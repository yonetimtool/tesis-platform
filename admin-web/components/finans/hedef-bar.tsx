"use client";

// (P244 §7b) HEDEF / GERCEKLESEN YATAY BARI.
//
// ===========================================================================
// NEDEN VAR
// ===========================================================================
// Butce ekrani hedefi ve gerceklesen tutari YAN YANA IKI SAYI KOLONU
// olarak gosteriyordu. Iki sayiyi karsilastirmak okurun isiydi: "420.000
// ile term 483.500 arasindaki fark ne kadar?" sorusunu goz yapamaz, ancak
// hesaplayarak bulur.
//
// Referansta ayni veri YATAY BAR: dolgu gerceklesenin hedefe oranini
// gosterir, gozun tek bakista okudugu sey de tam olarak budur.
//
// ===========================================================================
// SAPMANIN ISARETI TIPE BAGLIDIR — VE BU KURAL BURADA DEGIL
// ===========================================================================
// Giderde pozitif sapma "butce asildi" (kotu), gelirde "hedefin
// uzerinde" (iyi). Bu yorum SAYFADA tek yerde duruyor (`sapmaKotuMu`) ve
// bar onu PROP olarak aliyor — ikinci bir kopya, iki ekranda iki anlam
// demekti.
//
// ===========================================================================
// RENK TEK TASIYICI DEGIL
// ===========================================================================
// Barin yaninda yuzde YAZIYOR ve tablo satirinda tutarlar zaten var.
// Bar, var olan bilgiyi GORSELLESTIRIR; yeni bilgi tasimaz.

/** Yuzde — hedef sifirsa `null` (bolme yok, "sonsuz asim" da demeyiz). */
function oran(hedef: number, gerceklesen: number): number | null {
  if (hedef <= 0) return null;
  return Math.round((gerceklesen / hedef) * 100);
}

export function HedefBar({
  hedefKurus,
  gerceklesenKurus,
  kotuMu,
  etiket,
}: {
  hedefKurus: number;
  gerceklesenKurus: number;
  /** Sapma bu satir icin KOTU mu (gider asimi) — karar cagiranin. */
  kotuMu: boolean;
  /** Ekran okuyucu icin: "Temizlik: hedefin %115'i". */
  etiket: string;
}) {
  const yuzde = oran(hedefKurus, gerceklesenKurus);
  // HEDEFSIZ KATEGORI: bar cizilmez. Sifir hedefe karsi dolu bir bar
  // cizmek "sonsuz asim" demekti ve bu bir bilgi degil, bir hata.
  if (yuzde === null) {
    return (
      <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
        —
      </span>
    );
  }
  // DOLGU %100'DE DURUR ama YUZDE gercegi soyler: %180'lik bir bar
  // satirdan tasar ve tablo hizasini bozardi.
  const dolgu = Math.min(yuzde, 100);
  const asim = yuzde > 100;

  return (
    <span className="flex items-center gap-2" aria-label={etiket}>
      <span
        aria-hidden="true"
        className="relative h-2 w-24 shrink-0 overflow-hidden rounded-full"
        style={{ background: "var(--yz-surface-sunken)" }}
      >
        <span
          className="absolute inset-y-0 start-0 rounded-full"
          style={{
            width: `${dolgu}%`,
            background: asim && kotuMu ? "var(--yz-danger-edge)" : "var(--yz-success-edge)",
          }}
        />
      </span>
      <span
        className="tabular-nums"
        style={{
          fontSize: "var(--yz-fs-xs)",
          color: asim && kotuMu ? "var(--yz-danger-ink)" : "var(--yz-text-2)",
        }}
      >
        %{yuzde}
      </span>
    </span>
  );
}
