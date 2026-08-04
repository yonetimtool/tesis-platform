// Tesisin PUBLIC web sayfasi (P38).
//
// TEKNIK KARAR — AYRI BIR UYGULAMA DEGIL, admin-web'in ICINDE public rota:
//   * sozluk (7 dil), tasarim belirtecleri, `API_BASE` cozumu ve derleme/
//     dagitim hatti ZATEN burada; ikinci bir Next uygulamasi bunlarin
//     hepsini KOPYALARDI ve biri guncellenip digeri unutulurdu,
//   * Caddy zaten bu uygulamaya yonlendiriyor — ek bir upstream, ek bir
//     TLS/health yapilandirmasi demekti,
//   * oturum kapisi `middleware.config.matcher` ile YOL BAZLIDIR; `/site/*`
//     listede OLMADIGI icin public kalir (tests/middleware.test.ts yalniz
//     app/(protected) agacini zorunlu tutar — bu sayfa oraya KOYULMADI).
//
// Sunucu bileseni: veriyi sunucuda ceker, istemciye JS tasimaz ve
// arama motoru sayfayi dolu gorur (SEO).
import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { API_BASE } from "@/lib/config";

export const dynamic = "force-dynamic";

type Galeri = { id: string; foto_url: string | null; baslik: string | null };
type Duyuru = { id: string; baslik: string; ozet: string; created_at: string };
type Secenek = { id: string; metin: string; oy: number | null };
type Anket = {
  id: string;
  baslik: string;
  aciklama: string | null;
  acik: boolean;
  toplam_oy: number | null;
  secenekler: Secenek[];
};
type Portal = {
  slug: string;
  tesis_adi: string;
  hero_baslik: string | null;
  hero_alt: string | null;
  hakkimizda: string | null;
  iletisim_adres: string | null;
  iletisim_telefon: string | null;
  iletisim_email: string | null;
  konum_lat: number | null;
  konum_lon: number | null;
  galeri: Galeri[];
  duyurular: Duyuru[];
  anketler: Anket[];
};

async function portalGetir(slug: string): Promise<Portal | null> {
  const res = await fetch(`${API_BASE}/public/${encodeURIComponent(slug)}`, {
    cache: "no-store",
  });
  // 404 = yayinda degil VEYA yok. Ayrimi YAPMIYORUZ: "var ama kapali"
  // bilgisi slug tahminiyle tesis envanteri cikarmaya yarardi.
  if (!res.ok) return null;
  return (await res.json()) as Portal;
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const portal = await portalGetir(slug);
  if (!portal) return { title: "—" };
  const baslik = portal.hero_baslik ?? portal.tesis_adi;
  return {
    title: baslik,
    description: portal.hero_alt ?? portal.hakkimizda?.slice(0, 160) ?? baslik,
    openGraph: { title: baslik, type: "website" },
  };
}

export default async function SitePortali({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const portal = await portalGetir(slug);
  if (!portal) notFound();

  const haritaVar = portal.konum_lat != null && portal.konum_lon != null;

  return (
    <main className="mx-auto max-w-5xl px-4 py-10">
      {/* ---------------------------- hero ---------------------------- */}
      <header className="rounded-kart bg-slate-900 px-6 py-14 text-center text-white">
        <h1 className="text-3xl font-semibold sm:text-4xl">
          {portal.hero_baslik ?? portal.tesis_adi}
        </h1>
        {portal.hero_alt ? (
          <p className="mx-auto mt-3 max-w-2xl text-slate-300">{portal.hero_alt}</p>
        ) : null}
      </header>

      {/* ------------------------- hakkimizda -------------------------- */}
      {portal.hakkimizda ? (
        <section className="mt-10">
          <h2 className="text-xl font-semibold">{portal.tesis_adi}</h2>
          {/* Duz metin olarak cizilir: HTML kabul etmek, yonetim panelinden
              gelen icerigi XSS yuzeyine cevirirdi. */}
          <p className="mt-3 whitespace-pre-line leading-relaxed text-metin-body dark:text-slate-300">
            {portal.hakkimizda}
          </p>
        </section>
      ) : null}

      {/* ---------------------------- galeri --------------------------- */}
      {portal.galeri.length > 0 ? (
        <section className="mt-10">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {portal.galeri
              .filter((g) => g.foto_url)
              .map((g) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  key={g.id}
                  src={g.foto_url as string}
                  alt={g.baslik ?? ""}
                  className="h-40 w-full rounded-lg object-cover"
                  loading="lazy"
                />
              ))}
          </div>
        </section>
      ) : null}

      {/* ------------------------ duyuru + anket ----------------------- */}
      {portal.duyurular.length > 0 || portal.anketler.length > 0 ? (
        <section className="mt-10 grid gap-4 sm:grid-cols-2">
          {portal.duyurular.map((d) => (
            <article
              key={d.id}
              className="rounded-xl border kart-kenar p-4 dark:border-slate-700"
            >
              <h3 className="font-medium">{d.baslik}</h3>
              {/* Yalniz OZET: tam govde site ICINE yoneliktir. */}
              <p className="mt-2 text-sm text-metin-body dark:text-slate-400">
                {d.ozet}
              </p>
            </article>
          ))}
          {portal.anketler.map((a) => (
            <article
              key={a.id}
              className="rounded-xl border kart-kenar p-4 dark:border-slate-700"
            >
              <h3 className="font-medium">{a.baslik}</h3>
              {a.aciklama ? (
                <p className="mt-1 text-sm text-metin-body dark:text-slate-400">
                  {a.aciklama}
                </p>
              ) : null}
              <ul className="mt-3 space-y-1 text-sm">
                {a.secenekler.map((s) => (
                  <li key={s.id} className="flex justify-between gap-3">
                    <span>{s.metin}</span>
                    {/* Acik ankette sayi GELMEZ (surusel etki) — sunucu
                        `oy: null` doner ve burada hic cizilmez. */}
                    {s.oy != null ? (
                      <span className="tabular-nums text-metin-muted">{s.oy}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </section>
      ) : null}

      {/* --------------------------- iletisim -------------------------- */}
      <section className="mt-10 grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl border kart-kenar p-4 text-sm dark:border-slate-700">
          {portal.iletisim_adres ? <p>{portal.iletisim_adres}</p> : null}
          {portal.iletisim_telefon ? (
            <p className="mt-2">
              <a href={`tel:${portal.iletisim_telefon}`}>{portal.iletisim_telefon}</a>
            </p>
          ) : null}
          {portal.iletisim_email ? (
            <p className="mt-2">
              <a href={`mailto:${portal.iletisim_email}`}>{portal.iletisim_email}</a>
            </p>
          ) : null}
        </div>
        {haritaVar ? (
          <iframe
            title={portal.tesis_adi}
            className="h-56 w-full rounded-xl border kart-kenar dark:border-slate-700"
            loading="lazy"
            referrerPolicy="no-referrer-when-downgrade"
            // Anahtarsiz gomulu harita: API anahtarini public bir sayfaya
            // koymak, anahtari herkese vermek olurdu.
            src={`https://maps.google.com/maps?q=${portal.konum_lat},${portal.konum_lon}&z=16&output=embed`}
          />
        ) : null}
      </section>
    </main>
  );
}
