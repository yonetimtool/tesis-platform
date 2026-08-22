import { Fragment } from "react";

import type { Bolum } from "@/lib/hukuki";

/**
 * (P177 §2) HUKUKI BELGE SUNUMU.
 *
 * `**kalin**` isaretlemesi METIN OLARAK islenir — `dangerouslySetInnerHTML`
 * YOK. Belge metinleri depodan geliyor, yani bugun guvenli; ama HTML
 * enjekte eden bir sunum, metnin bir gun veritabanindan ya da yonetici
 * girdisinden gelmesi hâlinde sessizce bir XSS kapisi olurdu. Ayristirma
 * ucuz, kapiyi acmak geri alinmasi zor.
 */
function kalinla(metin: string) {
  return metin.split(/(\*\*[^*]+\*\*)/g).map((parca, i) =>
    parca.startsWith("**") && parca.endsWith("**") ? (
      <strong key={i} className="font-bold text-baslik">
        {parca.slice(2, -2)}
      </strong>
    ) : (
      <Fragment key={i}>{parca}</Fragment>
    ),
  );
}

export function HukukiBelge({
  baslik,
  guncelleme,
  giris,
  bolumler,
  not,
}: {
  baslik: string;
  guncelleme?: string;
  giris?: string;
  bolumler: Bolum[];
  /** Sayfaya ozel bildirim (orn. "belge hazirlaniyor"). Hukuki metin degil. */
  not?: string;
}) {
  return (
    <article className="kapsayici bolum max-w-metin">
      <h1 className="text-bolum">{baslik}</h1>
      {guncelleme ? <p className="mt-3 text-kucuk text-soluk">{guncelleme}</p> : null}

      {not ? (
        <p className="mt-6 rounded-kart border border-cizgi bg-kart p-5 text-kucuk font-semibold text-govde">
          {not}
        </p>
      ) : null}

      {giris ? <p className="mt-6 text-[1.05rem] leading-relaxed">{giris}</p> : null}

      {bolumler.map((b) => (
        <section key={b.baslik} className="mt-10">
          <h2 className="text-kartbaslik text-[1.25rem]">{b.baslik}</h2>
          {b.paragraflar.map((p, i) => (
            <p key={i} className="mt-3 leading-relaxed">
              {kalinla(p)}
            </p>
          ))}
        </section>
      ))}
    </article>
  );
}
