import Link from "next/link";

import { DilSecici } from "@/components/DilSecici";
import { TanitimForm } from "@/components/TanitimForm";
import { YonetioLogo } from "@/components/YonetioLogo";
import { DIL_ADLARI, yon, type Dil } from "@/lib/i18n/diller";
import { APP_GIRIS, PANEL_GIRIS } from "@/lib/tanitim/adres";
import { TANITIM } from "@/lib/tanitim/icerik";

// (P127) TANITIM SAYFASI — kok alan adinin (yönetiyor.com / www) yuzu.
//
// NEDEN AYRI BIR BILESEN, `app/page.tsx` DEGIL: `app/page.tsx` PANEL
// yuzeyinin koku olarak kalir (`/dashboard`a yonlendirir). Kok alan adinda
// middleware bu sayfayi cizdirir. Ikisini ayni dosyaya sikistirmak, panel
// kokunun davranisini konak basligina bagimli kilardi.
//
// SUNUCUDA CIZILIR ve JS GEREKTIRMEZ: bir tanitim sayfasi, tarayici
// betigi calismadan da okunabilmelidir (SEO tarayicilari, yavas cihazlar).
// Tek istemci parcasi dil secicidir.
export function TanitimSayfasi({ dil }: { dil: Dil }) {
  const i = TANITIM[dil];
  const yonu = yon(dil);

  return (
    <div dir={yonu} className="min-h-screen bg-white text-ink">
      <header className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-5 py-5">
        <YonetioLogo />
        <DilSecici />
      </header>

      <main className="mx-auto max-w-5xl px-5 pb-16">
        {/* IKI DEGER ONERISI YAN YANA: yonetici ve sakin ayni sayfaya bakar
            ama ayni seyi aramaz. */}
        <section className="grid gap-6 py-8 sm:grid-cols-2">
          <article className="rounded-kart border kart-kenar bg-yuzey-bg p-6">
            <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
              {i.yoneticiBaslik}
            </h1>
            <p className="mt-3 text-metin-body">{i.yoneticiAlt}</p>
          </article>
          <article className="rounded-kart border kart-kenar p-6">
            <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">
              {i.sakinBaslik}
            </h2>
            <p className="mt-3 text-metin-body">{i.sakinAlt}</p>
          </article>
        </section>

        <section id="ozellikler" className="py-8">
          <h2 className="text-xl font-semibold">{i.ozelliklerBaslik}</h2>
          <div className="mt-5 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {i.ozellikler.map((o) => (
              <article key={o.baslik} className="rounded-xl border kart-kenar p-5">
                <h3 className="font-medium">{o.baslik}</h3>
                <p className="mt-2 text-sm text-metin-body">{o.metin}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="hakkimizda" className="py-8">
          <h2 className="text-xl font-semibold">{i.hakkimizdaBaslik}</h2>
          {i.hakkimizdaParagraflar.map((p) => (
            <p key={p} className="mt-3 max-w-3xl text-metin-body">
              {p}
            </p>
          ))}
        </section>

        <section id="uygulama" className="py-8">
          <h2 className="text-xl font-semibold">{i.uygulamaBaslik}</h2>
          {/* MAGAZA ROZETI UYDURULMAZ (P129 ile ayni karar): uygulama henuz
              yayinda degil; sahte bir rozet 404'e giden bir sozdur. */}
          <p className="mt-3 max-w-3xl text-metin-body">{i.uygulamaYakinda}</p>
        </section>

        <section id="iletisim" className="py-8">
          <h2 className="text-xl font-semibold">{i.iletisimBaslik}</h2>
          <p className="mt-3 max-w-3xl text-metin-body">{i.iletisimMetin}</p>
          {/* (P127.2) FORM ARTIK GERCEKTEN TESLIM EDIYOR: BFF -> API ->
              veritabani (kayit once) -> e-posta denemesi. `mailto:`
              baglantisi KALDI ama artik YEDEK: e-posta istemcisiyle
              yazmayi tercih eden ziyaretci icin. */}
          <TanitimForm />
          <p className="mt-4 text-satiralt text-metin-mutedBg">
            <a className="font-medium text-primary underline" href={`mailto:${i.iletisimEposta}`}>
              {i.iletisimEposta}
            </a>
          </p>
        </section>

        <section id="giris" className="py-8">
          <h2 className="text-xl font-semibold">{i.girisBaslik}</h2>
          {/* GIRIS BU ALAN ADINDA DEGIL: yuzeyler ayridir (P125/P126/P129).
              Baglantilar kullaniciyi DOGRU adrese goturur. */}
          <div className="mt-4 flex flex-wrap gap-3">
            <a
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium"
              href={APP_GIRIS}
            >
              {i.girisTesis}
            </a>
            <a
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium"
              href={PANEL_GIRIS}
            >
              {i.girisYonetim}
            </a>
          </div>
        </section>
      </main>

      <footer className="border-t kart-kenar">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-4 px-5 py-6 text-sm text-metin-body">
          {/* HUKUKI SAYFALAR TEK KAYNAKTAN: `lib/hukuki/` — buraya
              KOPYALANMAZ (P113). */}
          <Link className="underline" href="/gizlilik">
            {i.gizlilik}
          </Link>
          <Link className="underline" href="/kosullar">
            {i.kosullar}
          </Link>
          <span className="ms-auto">{DIL_ADLARI[dil]}</span>
        </div>
      </footer>
    </div>
  );
}
