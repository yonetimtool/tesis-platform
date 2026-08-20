import type { Metadata } from "next";

import { cookies, headers } from "next/headers";

import { I18nProvider } from "@/lib/i18n/kullan";
import { DIL_COOKIE, istekDili, yon } from "@/lib/i18n/diller";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

import "./globals.css";
// (P160 / Asama 1) YENI TASARIM SISTEMI — `globals.css`ten SONRA.
//
// AYRI DOSYA ve bu bilincli: `tests/tasarim-token.test.ts` `globals.css`i
// mobil token'lariyla esitliyor ve KILITLI KURAL 1/6 geregi ikisine de
// dokunulamiyor. Yeni dil eskinin USTUNE degil YANINA konuldu; ayrinti
// dosyanin basliginda. Sirasi onemli: `--yz-*` degiskenleri sonra
// gelmeli ki ayni sinifa (`.dark`) baglanan tanimlar catismasin.
import "./tasarim-sistemi.css";
// (P175) Yerel Inter tanimlari — tasarim sisteminden ONCE degil SONRA da
// olabilirdi; ayri dosya olmasi tek sebep: font kurallari uzun ve tasarim
// belirtecleriyle karismamali.
import "./yazi-tipi.css";

// (P175) INTER ARTIK DEPODAN — `next/font/google` KALDIRILDI.
//
// Eski hâl yazi tipini DERLEME ANINDA Google'dan indiriyordu; ag kesintisi
// ya da DNS sorunu derlemeyi TAMAMEN dusuruyordu (test sunucusunda
// yasandi). Calisma aninda zaten Google'a istek GITMIYORDU — bu
// dogrulandi — yani degisen sey gizlilik degil AG BAGIMSIZLIGI.
//
// Tanimlar `app/yazi-tipi.css`te; gerekcesi ve alt kume ayrimi orada.

// `icons` BILEREK yazilmaz: app/icon.svg'yi Next kendisi bulup
// <link rel="icon" href="/icon.svg?<hash>"> olarak enjekte eder. Hash dosya
// degisince degisir → tarayici yeni faviconu ceker.
//
// Elle `icons: { icon: "/icon.svg" }` yazmak bu otomatigi EZIYOR ve URL'yi
// hash'siz birakiyordu; Next ise bu rotayi `immutable, max-age=31536000` ile
// sunuyor. Sonuc: logo degisse bile tarayicilar eski faviconu BIR YIL boyunca
// yeniden istemiyordu (hard refresh cogu tarayicida bunu asmaz).
// Ust veri de DILE DUYARLI (tur 17): sekme basligi ve paylasim aciklamasi
// kullanicinin dilinde uretilir. Sabit `metadata` nesnesi bunu yapamazdi.
export async function generateMetadata(): Promise<Metadata> {
  const cookieDeposu = await cookies();
  const baslikDeposu = await headers();
  const dil = istekDili(
    cookieDeposu.get(DIL_COOKIE)?.value,
    baslikDeposu.get("accept-language"),
  );
  const sozluk = SOZLUKLER[dil];
  return { title: sozluk.metaBaslik, description: sozluk.metaAciklama };
}

// Dil SUNUCUDA cozulur: ilk kare dogru dilde ve dogru YONDE boyanir.
// Istemcide cozseydik sayfa once `tr`/`ltr` cizilip sonra kendini
// duzeltirdi (mobil tarafta "metin titremesi" diye kayda gecen hata).
export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const cookieDeposu = await cookies();
  const baslikDeposu = await headers();
  const dil = istekDili(
    cookieDeposu.get(DIL_COOKIE)?.value,
    baslikDeposu.get("accept-language"),
  );

  return (
    <html lang={dil} dir={yon(dil)} suppressHydrationWarning>
      <head>
        {/* (P175) LATIN DILIMI ON YUKLENIR.
            `next/font` bunu kendiliginden yapiyordu; elle yazarken
            atlamak, ilk boyamada yazi tipinin bir kare gec gelmesi
            demekti. YALNIZ `latin`: yedi dilimin hepsini on yuklemek,
            kullanicinin HIC ihtiyac duymayacagi 160 KB'i indirtirdi. */}
        <link
          rel="preload"
          href="/fonts/inter-latin.woff2"
          as="font"
          type="font/woff2"
          crossOrigin="anonymous"
        />
        {/* Ilk boyamadan once tema sinifini ata (FOUC yok). Kayitli tercih
            yoksa/sistem ise OS temasini izle. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme');var d=t==='dark'||((!t||t==='system')&&window.matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);}catch(e){}})();`,
          }}
        />
      </head>
      <body>
        {/* (P132.5) AKTIF SOZLUK PROP OLARAK GECER — istemci paketine
            yedi dil girmesin diye. Deger RSC yukuyle serilestirilir; JS
            modulu olarak ayristirilmaz. */}
        <I18nProvider baslangicDili={dil} baslangicSozlugu={SOZLUKLER[dil]}>
          {children}
        </I18nProvider>
      </body>
    </html>
  );
}
