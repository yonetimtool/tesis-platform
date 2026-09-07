import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { IsletmeKarti, type IsletmeOzet } from "@/components/IsletmeKarti";
import { INCE_ICERIK_ESIGI, SITE_ADI, SITE_ADRESI } from "@/config/site";
import { sunucudanAl } from "@/lib/backend";

/**
 * ==========================================================================
 * SEO BOLGE/KATEGORI SAYFASI — buyume kanali
 * ==========================================================================
 * `/istanbul/cekmekoy/catalmese/elektrikci`
 *
 * INCE ICERIK ESIGI (docs/dukkan/05-seo.md §3):
 *   0            -> 404 (uc zaten 404 doner)
 *   1..ESIK-1    -> sayfa VAR ama `noindex`, sitemap'te YOK
 *   >= ESIK      -> tam indekslenir
 *
 * Turkiye'de ~45.000 mahalle x ~50 hizmet = 2+ milyon olasi URL ve ezici
 * cogunlugunda tek isletme bile yok. Hepsini uretmek arama motoruna "bu
 * alan adi bos sayfa fabrikasi" demenin en hizli yolu — ve ceza sayfa
 * basina degil ALAN ADI GENELINE isler. Yani 10 iyi sayfa da duser.
 */
export const revalidate = 86400; // 24 sa — icerik gunde bir degisir.

type Sayfa = {
  konum: { il: string; il_slug: string; ilce: string; ilce_slug: string;
           mahalle: string; mahalle_slug: string };
  kategori: { ad: string; slug: string; aciklama: string | null };
  isletmeler: IsletmeOzet[];
  toplam: number;
  komsu_mahalleler: { ad: string; slug: string; isletme_sayisi: number }[];
  diger_kategoriler: { ad: string; slug: string; isletme_sayisi: number }[];
};

type Params = { il: string; ilce: string; mahalle: string; kategori: string };

async function veriAl(p: Params) {
  return sunucudanAl<Sayfa>(
    `/dukkan/sayfa/${encodeURIComponent(p.il)}/${encodeURIComponent(p.ilce)}` +
      `/${encodeURIComponent(p.mahalle)}/${encodeURIComponent(p.kategori)}`,
    86400,
  );
}

export async function generateMetadata(
  { params }: { params: Params },
): Promise<Metadata> {
  const d = await veriAl(params);
  if (!d) return { title: "Bulunamadı" };

  const yol = `/${params.il}/${params.ilce}/${params.mahalle}/${params.kategori}`;
  const indeksle = d.toplam >= INCE_ICERIK_ESIGI;

  return {
    // SAYIYI BASLIGA KOYMAK tiklama oranini artirir VE dogrudur; ISR
    // yenilemesi sayiyi guncel tutar.
    title: `${d.konum.mahalle} ${d.kategori.ad} — ${d.toplam} İşletme`,
    description:
      `${d.konum.mahalle} (${d.konum.ilce}/${d.konum.il}) bölgesinde hizmet ` +
      `veren ${d.toplam} ${d.kategori.ad.toLowerCase()}. Değerlendirmeleri ` +
      `oku, ara, teklif al.`,
    // Siralama/sayfalama parametreleri canonical'a GIRMEZ: aynı icerigin
    // 10 kopyasi olurdu.
    alternates: { canonical: yol },
    robots: indeksle
      ? undefined
      : // ESIK ALTI: sayfa calisir ama indekslenmez. Kullanici bir yerden
        // geldiyse bos ekrana dusmesin, ama arama motoruna ince icerik
        // tanitilmasin.
        { index: false, follow: true },
  };
}

export default async function BolgeKategoriSayfasi(
  { params }: { params: Params },
) {
  const d = await veriAl(params);
  if (!d) notFound();

  const yolBase = `/${params.il}/${params.ilce}`;
  const kirintilar = [
    { ad: "Ana sayfa", yol: "/" },
    { ad: d.konum.il, yol: `/${params.il}` },
    { ad: d.konum.ilce, yol: yolBase },
    { ad: d.konum.mahalle, yol: `${yolBase}/${params.mahalle}` },
    { ad: d.kategori.ad, yol: null },
  ];

  // ------------------------------------------------------------------ //
  // JSON-LD
  // ------------------------------------------------------------------ //
  // `aggregateRating` YALNIZ gercek yorum varsa uretiliyor. Yorumu
  // olmayan bir isletmeye rating isaretlemek YAPILANDIRILMIS VERI
  // IHLALIDIR ve manuel islem sebebidir (05-seo.md §5).
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BreadcrumbList",
        itemListElement: kirintilar.map((k, n) => ({
          "@type": "ListItem",
          position: n + 1,
          name: k.ad,
          ...(k.yol ? { item: `${SITE_ADRESI}${k.yol}` } : {}),
        })),
      },
      {
        "@type": "ItemList",
        numberOfItems: d.toplam,
        itemListElement: d.isletmeler.map((i, n) => ({
          "@type": "ListItem",
          position: n + 1,
          item: {
            "@type": "LocalBusiness",
            name: i.ad,
            url: `${SITE_ADRESI}/isletme/${i.slug}`,
            telephone: i.telefon,
            areaServed: {
              "@type": "Place",
              name: `${d.konum.mahalle}, ${d.konum.ilce}, ${d.konum.il}`,
            },
            ...(i.yorum_sayisi > 0 && i.ortalama_puan !== null
              ? {
                  aggregateRating: {
                    "@type": "AggregateRating",
                    ratingValue: Number(i.ortalama_puan).toFixed(1),
                    reviewCount: i.yorum_sayisi,
                  },
                }
              : {}),
          },
        })),
      },
    ],
  };

  return (
    <main className="mx-auto max-w-4xl px-4 py-10">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <nav aria-label="Kırıntı yolu" className="text-sm">
        <ol className="flex flex-wrap gap-1 text-[color:var(--dk-metin-soluk)]">
          {kirintilar.map((k, n) => (
            <li key={k.ad} className="flex gap-1">
              {n > 0 && <span aria-hidden>›</span>}
              {k.yol ? (
                <Link href={k.yol} className="hover:underline">
                  {k.ad}
                </Link>
              ) : (
                <span className="text-[color:var(--dk-metin)]">{k.ad}</span>
              )}
            </li>
          ))}
        </ol>
      </nav>

      <h1 className="mt-4 text-2xl font-bold text-marka-koyu sm:text-3xl">
        {d.konum.mahalle} Mahallesi&apos;nde {d.kategori.ad}
      </h1>
      <p className="mt-2 text-[color:var(--dk-metin-soluk)]">
        {d.konum.ilce} / {d.konum.il} · {d.toplam} işletme
      </p>

      <Link
        href={`/talep-olustur?kategori=${params.kategori}&il=${params.il}&ilce=${params.ilce}&mahalle=${params.mahalle}`}
        className="mt-5 inline-block rounded bg-marka px-5 py-3 font-medium text-white"
      >
        Ücretsiz teklif al
      </Link>

      <ul className="mt-8 space-y-3">
        {d.isletmeler.map((i) => (
          <IsletmeKarti key={i.slug} i={i} />
        ))}
      </ul>

      {/* IC BAGLANTI: yalniz GERCEKTEN isletmesi olanlar. Uc zaten
          filtreliyor — bos sayfaya baglanti vermek, arama motoruna var
          olmayan sayfalarin haritasini cizmek olurdu. */}
      {d.komsu_mahalleler.length > 0 && (
        <section className="mt-10">
          <h2 className="text-lg font-semibold">
            Yakındaki mahallelerde {d.kategori.ad.toLowerCase()}
          </h2>
          <ul className="mt-3 flex flex-wrap gap-2">
            {d.komsu_mahalleler.map((m) => (
              <li key={m.slug}>
                <Link
                  href={`${yolBase}/${m.slug}/${params.kategori}`}
                  className="rounded-full border border-[color:var(--dk-cizgi)] px-3 py-1 text-sm hover:border-marka"
                >
                  {m.ad} ({m.isletme_sayisi})
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      {d.diger_kategoriler.length > 0 && (
        <section className="mt-8">
          <h2 className="text-lg font-semibold">
            {d.konum.mahalle}&apos;de diğer hizmetler
          </h2>
          <ul className="mt-3 flex flex-wrap gap-2">
            {d.diger_kategoriler.map((k) => (
              <li key={k.slug}>
                <Link
                  href={`${yolBase}/${params.mahalle}/${k.slug}`}
                  className="rounded-full border border-[color:var(--dk-cizgi)] px-3 py-1 text-sm hover:border-marka"
                >
                  {k.ad} ({k.isletme_sayisi})
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-10 rounded border border-[color:var(--dk-cizgi)] p-4">
        <h2 className="font-semibold">Adresini kim görür?</h2>
        <p className="mt-2 text-sm text-[color:var(--dk-metin-soluk)]">
          Teklif aşamasında işletmeler yalnızca mahalleni görür. Adın,
          telefonun ve açık adresin, sen paylaşmayı seçmedikçe kimseye
          gösterilmez.
        </p>
      </section>
    </main>
  );
}
