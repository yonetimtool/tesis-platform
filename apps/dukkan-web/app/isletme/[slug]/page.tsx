import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { DogrulamaRozeti, Puan } from "@/components/Rozet";
import { Yorumlar } from "@/components/Yorumlar";
import { SITE_ADRESI } from "@/config/site";
import { sunucudanAl } from "@/lib/backend";

/** Isletme profili. Yorumlar daha sik degistigi icin bolge
 *  sayfalarindan KISA yenileme (1 sa). */
export const revalidate = 3600;

const GUNLER = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma",
  "Cumartesi", "Pazar"];

type Profil = {
  ad: string;
  slug: string;
  aciklama: string | null;
  telefon: string;
  whatsapp: string | null;
  eposta: string | null;
  dogrulama_seviyesi: number;
  ortalama_puan: number | string | null;
  yorum_sayisi: number;
  il: string | null;
  ilce: string | null;
  mahalle: string | null;
  kategoriler: { ad: string; slug: string }[];
  hizmet_bolgeleri: { il: string; ilce: string; mahalle_sayisi: number }[];
  calisma_saatleri: { gun: number; acilis: string | null;
                      kapanis: string | null; kapali: boolean }[];
};

const al = (slug: string) =>
  sunucudanAl<Profil>(`/dukkan/isletme-profil/${encodeURIComponent(slug)}`, 3600);

export async function generateMetadata(
  { params }: { params: { slug: string } },
): Promise<Metadata> {
  const d = await al(params.slug);
  if (!d) return { title: "Bulunamadı" };
  const yer = [d.ilce, d.il].filter(Boolean).join(", ");
  return {
    title: d.ad,
    description:
      d.aciklama?.slice(0, 155) ??
      `${d.ad}${yer ? ` — ${yer}` : ""}. ${d.kategoriler
        .map((k) => k.ad)
        .join(", ")}`,
    alternates: { canonical: `/isletme/${params.slug}` },
  };
}

export default async function IsletmeProfili(
  { params }: { params: { slug: string } },
) {
  const d = await al(params.slug);
  if (!d) notFound();

  // `aggregateRating` YALNIZ gercek yorum varsa. Yorumu olmayan
  // isletmeye rating isaretlemek yapilandirilmis veri ihlalidir.
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "LocalBusiness",
    name: d.ad,
    url: `${SITE_ADRESI}/isletme/${d.slug}`,
    telephone: d.telefon,
    ...(d.aciklama ? { description: d.aciklama } : {}),
    ...(d.il
      ? {
          address: {
            "@type": "PostalAddress",
            addressLocality: d.ilce ?? undefined,
            addressRegion: d.il,
            addressCountry: "TR",
          },
        }
      : {}),
    areaServed: d.hizmet_bolgeleri.map((b) => ({
      "@type": "Place",
      name: `${b.ilce}, ${b.il}`,
    })),
    ...(d.yorum_sayisi > 0 && d.ortalama_puan !== null
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: Number(d.ortalama_puan).toFixed(1),
            reviewCount: d.yorum_sayisi,
          },
        }
      : {}),
  };

  return (
    <main className="mx-auto max-w-3xl px-4 py-10">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <h1 className="text-2xl font-bold text-marka-koyu sm:text-3xl">{d.ad}</h1>
      <div className="mt-2 flex flex-wrap items-center gap-3">
        <Puan puan={d.ortalama_puan} sayi={d.yorum_sayisi} />
        <DogrulamaRozeti seviye={d.dogrulama_seviyesi} />
      </div>

      <div className="mt-5 flex flex-wrap gap-2">
        <a
          href={`tel:${d.telefon}`}
          className="rounded bg-marka px-5 py-3 font-medium text-white"
        >
          {d.telefon}
        </a>
        {d.whatsapp && (
          <a
            href={`https://wa.me/${d.whatsapp.replace(/\D/g, "")}`}
            rel="nofollow noopener"
            target="_blank"
            className="rounded border border-[color:var(--dk-cizgi)] px-5 py-3"
          >
            WhatsApp
          </a>
        )}
        <Link
          href={`/talep-olustur?isletme=${d.slug}`}
          className="rounded border border-marka px-5 py-3 text-marka"
        >
          Teklif iste
        </Link>
      </div>

      {d.aciklama && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold">Hakkında</h2>
          <p className="mt-2 whitespace-pre-line text-[color:var(--dk-metin-soluk)]">
            {d.aciklama}
          </p>
        </section>
      )}

      <section className="mt-8">
        <h2 className="text-lg font-semibold">Verdiği hizmetler</h2>
        <ul className="mt-3 flex flex-wrap gap-2">
          {d.kategoriler.map((k) => (
            <li
              key={k.slug}
              className="rounded-full bg-marka-acik px-3 py-1 text-sm text-marka-koyu"
            >
              {k.ad}
            </li>
          ))}
        </ul>
      </section>

      {d.hizmet_bolgeleri.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold">Hizmet verdiği bölgeler</h2>
          {/* ILCE DUZEYINDE OZET: 40 mahalle secen bir isletmenin 40
              satirini gostermek sayfayi bogardi (uc de bu yuzden
              gruplayarak donuyor). */}
          <ul className="mt-3 space-y-1 text-sm text-[color:var(--dk-metin-soluk)]">
            {d.hizmet_bolgeleri.map((b) => (
              <li key={`${b.il}-${b.ilce}`}>
                {b.ilce}, {b.il}{" "}
                <span className="text-xs">({b.mahalle_sayisi} mahalle)</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {d.calisma_saatleri.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold">Çalışma saatleri</h2>
          <ul className="mt-3 space-y-1 text-sm">
            {d.calisma_saatleri.map((s) => (
              <li key={s.gun} className="flex gap-3">
                <span className="w-24">{GUNLER[s.gun]}</span>
                <span className="text-[color:var(--dk-metin-soluk)]">
                  {s.kapali ? "Kapalı" : `${s.acilis ?? "?"} – ${s.kapanis ?? "?"}`}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <Yorumlar slug={params.slug} />

      {/* GUVEN NOTU — rozetin NE ANLAMA GELDIGINI soyluyor.
          "Dogrulanmis" rozeti bir GARANTI gibi okunmamali; ne kanitladigi
          ve ne KANITLAMADIGI acikca yazili (03-guven §3, soru 7). */}
      <section className="mt-10 rounded border border-[color:var(--dk-cizgi)] p-4 text-sm">
        <h2 className="font-semibold">Bu rozet ne anlama geliyor?</h2>
        <p className="mt-2 text-[color:var(--dk-metin-soluk)]">
          {d.dogrulama_seviyesi >= 2
            ? "İşletmenin belgesi tarafımızca incelendi. Bu, hizmet kalitesi için bir garanti değildir."
            : "İşletmenin telefon numarası doğrulandı. Bu, numaranın gerçek olduğunu gösterir; işletmenin kimliğini doğrulamaz."}
        </p>
        <p className="mt-2 text-[color:var(--dk-metin-soluk)]">
          Ödemeyi iş bitmeden yapmayın. Dükkan ödemelere aracılık etmez;
          kapora talebi bir uyarı işaretidir.
        </p>
        {/* SIKAYET YOLU HER PROFILDE VE KIMLIKSIZ: dolandirilan bir
            kullanicinin hesabi olmayabilir ve en cok onun sesi
            duyulmali. */}
        <Link
          href={`/sikayet?isletme=${d.slug}`}
          className="mt-3 inline-block text-sm text-marka underline"
        >
          Bu işletmeyle ilgili şikâyet bildir
        </Link>
      </section>
    </main>
  );
}
