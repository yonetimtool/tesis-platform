import Link from "next/link";

import { SITE_ADI } from "@/config/site";
import { sunucudanAl } from "@/lib/backend";

/** Ana sayfa ISR ile onbelleklenir: kategori agaci gunde bir degisir. */
export const revalidate = 3600;

type Kategori = {
  ad: string;
  slug: string;
  ikon: string | null;
  alt: { ad: string; slug: string }[];
};

/**
 * ==========================================================================
 * ANA SAYFA — armut.com URUN KALIBI, Yonetio gorsel dili
 * ==========================================================================
 * Olculen referans yapinin bolum sirasi (docs/dukkan/05-seo.md §8):
 * hero + arama, kategori izgarasi, "nasil calisir" 3 adim, guven bolumu,
 * isletme (arz) cagrisi. Bu sira bu is kolunun YERLESIK dili; farkli bir
 * sey icat etmek ziyaretciyi zorlamak olurdu.
 *
 * VERI GERCEK: kategoriler `/dukkan/kategori` ucundan geliyor, sabit
 * liste degil. Boylece kategori eklendiginde ana sayfa kendiliginden
 * guncellenir ve iki yerde tutulan bir liste ayrisamaz.
 */
export default async function AnaSayfa() {
  const veri = await sunucudanAl<{ items: Kategori[] }>("/dukkan/kategori");
  const kategoriler = veri?.items ?? [];

  return (
    <main>
      {/* ---------------- HERO ---------------- */}
      <section className="bg-marka-acik border-b border-[color:var(--dk-cizgi)]">
        <div className="mx-auto max-w-5xl px-4 py-16">
          <h1 className="text-3xl font-bold text-marka-koyu sm:text-4xl">
            Mahallendeki ustayı bul
          </h1>
          <p className="mt-3 max-w-2xl text-[color:var(--dk-metin-soluk)]">
            İhtiyacını anlat, bölgendeki işletmelerden teklif al, karşılaştır ve seç.
          </p>
          <Link
            href="/talep-olustur"
            className="mt-6 inline-block rounded bg-marka px-5 py-3 font-medium text-white"
          >
            Ücretsiz teklif al
          </Link>
        </div>
      </section>

      {/* ---------------- KATEGORILER ---------------- */}
      <section className="mx-auto max-w-5xl px-4 py-12">
        <h2 className="text-xl font-semibold">Hizmetler</h2>
        {kategoriler.length === 0 ? (
          // SESSIZ BASARISIZLIK YOK: bos bir izgara cizip "hizmet yok"
          // izlenimi vermek yerine durumu SOYLUYORUZ (P217 dersi).
          <p className="mt-4 text-[color:var(--dk-metin-soluk)]">
            Hizmet listesi şu anda yüklenemedi. Lütfen birazdan tekrar deneyin.
          </p>
        ) : (
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {kategoriler.map((k) => (
              <div
                key={k.slug}
                className="rounded border border-[color:var(--dk-cizgi)] p-4"
              >
                <h3 className="font-medium text-marka-koyu">{k.ad}</h3>
                <ul className="mt-2 space-y-1 text-sm">
                  {k.alt.slice(0, 4).map((a) => (
                    <li key={a.slug}>
                      <Link
                        href={`/kategori/${a.slug}`}
                        className="text-[color:var(--dk-metin-soluk)] hover:text-marka"
                      >
                        {a.ad}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* ---------------- NASIL CALISIR ---------------- */}
      <section className="bg-[color:var(--dk-zemin-alt)] py-12">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-xl font-semibold">Nasıl çalışır?</h2>
          <ol className="mt-6 grid gap-6 sm:grid-cols-3">
            {[
              ["İhtiyacını anlat", "Ne yaptırmak istediğini birkaç adımda yaz."],
              ["Teklifleri al", "Bölgende hizmet veren işletmeler sana döner."],
              ["Karşılaştır ve seç", "Değerlendirmeleri oku, kararını ver."],
            ].map(([baslik, metin], i) => (
              <li key={baslik}>
                <span className="text-2xl font-bold text-marka">{i + 1}</span>
                <h3 className="mt-1 font-medium">{baslik}</h3>
                <p className="mt-1 text-sm text-[color:var(--dk-metin-soluk)]">
                  {metin}
                </p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ---------------- GUVEN ---------------- */}
      <section className="mx-auto max-w-5xl px-4 py-12">
        <h2 className="text-xl font-semibold">Adresini kim görür?</h2>
        <p className="mt-3 max-w-3xl text-[color:var(--dk-metin-soluk)]">
          Teklif aşamasında işletmeler yalnızca <strong>mahalleni</strong> görür.
          Adın, telefonun ve açık adresin, sen paylaşmayı seçmedikçe kimseye
          gösterilmez. Açık adresin yalnızca işi verdiğin işletmeye, iş kabul
          edildikten sonra açılır.
        </p>
      </section>

      {/* ---------------- ARZ TARAFI ---------------- */}
      <section className="border-t border-[color:var(--dk-cizgi)] bg-marka-koyu py-12 text-white">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-xl font-semibold">İşletme misin?</h2>
          <p className="mt-2 text-white/80">
            Bölgendeki müşterilere ulaş. Kayıt ücretsiz.
          </p>
          <Link
            href="/isletme-kaydi"
            className="mt-5 inline-block rounded bg-white px-5 py-3 font-medium text-marka-koyu"
          >
            İşletme olarak katıl
          </Link>
        </div>
      </section>

      <footer className="border-t border-[color:var(--dk-cizgi)] py-8 text-center text-sm text-[color:var(--dk-metin-soluk)]">
        {SITE_ADI} — Yönetiyor
      </footer>
    </main>
  );
}
