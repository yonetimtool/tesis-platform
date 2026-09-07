import Link from "next/link";

import { DogrulamaRozeti, Puan } from "./Rozet";

export type IsletmeOzet = {
  ad: string;
  slug: string;
  aciklama: string | null;
  telefon: string;
  whatsapp: string | null;
  dogrulama_seviyesi: number;
  ortalama_puan: number | string | null;
  yorum_sayisi: number;
  kategoriler?: string[];
};

/** Listelerde kullanilan isletme karti.
 *
 * TELEFON DOGRUDAN GORUNUR ve tiklanabilir: bu urunde asil donusum
 * "ustayi ara"dir. Numarayi gizleyip once kayit istemek, kullanicinin
 * bir sonraki sitede aramasi demek olurdu. */
export function IsletmeKarti({ i }: { i: IsletmeOzet }) {
  return (
    <li className="rounded border border-[color:var(--dk-cizgi)] p-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h3 className="font-medium text-marka-koyu">
            <Link href={`/isletme/${i.slug}`} className="hover:underline">
              {i.ad}
            </Link>
          </h3>
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <Puan puan={i.ortalama_puan} sayi={i.yorum_sayisi} />
            <DogrulamaRozeti seviye={i.dogrulama_seviyesi} />
          </div>
          {i.kategoriler && i.kategoriler.length > 0 && (
            <p className="mt-1 text-xs text-[color:var(--dk-metin-soluk)]">
              {i.kategoriler.slice(0, 4).join(" · ")}
            </p>
          )}
          {i.aciklama && (
            <p className="mt-2 line-clamp-2 text-sm text-[color:var(--dk-metin-soluk)]">
              {i.aciklama}
            </p>
          )}
        </div>
        <div className="flex shrink-0 gap-2">
          <a
            href={`tel:${i.telefon}`}
            className="rounded bg-marka px-3 py-2 text-sm font-medium text-white"
          >
            Ara
          </a>
          {i.whatsapp && (
            <a
              href={`https://wa.me/${i.whatsapp.replace(/\D/g, "")}`}
              rel="nofollow noopener"
              target="_blank"
              className="rounded border border-[color:var(--dk-cizgi)] px-3 py-2 text-sm"
            >
              WhatsApp
            </a>
          )}
        </div>
      </div>
    </li>
  );
}
