"use client";

import { motion, MotionConfig } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import useSWR from "swr";

import { DilSecici } from "@/components/DilSecici";
import { GlobalArama } from "@/components/GlobalArama";
import { ThemeToggle } from "@/components/ThemeToggle";
import { useT } from "@/lib/i18n/kullan";
import { YonetioLogo } from "@/components/YonetioLogo";
import { jsonFetcher } from "@/lib/fetcher";
import {
  KATLI_GRUPLAR,
  menuGruplari,
  ogeAktif,
  ogeBaglantisi,
  profilGorunur,
  rotaninGrubu,
  PROFIL_OGESI,
  type GrupId,
  type IconName,
  type MenuGrubu,
  type MenuOgesi,
} from "@/lib/menu";
import { kokRotaRol, type Yuzey } from "@/lib/yuzey";

function Icon({ name }: { name: IconName }) {
  const p = {
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.75,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  const svg = (children: ReactNode) => (
    <svg viewBox="0 0 24 24" className="h-[18px] w-[18px] shrink-0" {...p}>
      {children}
    </svg>
  );
  switch (name) {
    case "grid":
      return svg(<>
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </>);
    case "building":
      return svg(<>
        <rect x="4" y="3" width="16" height="18" rx="1.5" />
        <line x1="9" y1="7" x2="9" y2="7" /><line x1="15" y1="7" x2="15" y2="7" />
        <line x1="9" y1="11" x2="9" y2="11" /><line x1="15" y1="11" x2="15" y2="11" />
        <path d="M10 21v-3h4v3" />
      </>);
    case "clock":
      return svg(<><circle cx="12" cy="12" r="8.5" /><path d="M12 7.5V12l3 2" /></>);
    case "scan":
      return svg(<>
        <path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16" />
        <circle cx="12" cy="12" r="2.5" />
      </>);
    case "route":
      return svg(<><polyline points="4 18 9 11 14 15 20 6" /><circle cx="4" cy="18" r="1.4" /><circle cx="20" cy="6" r="1.4" /></>);
    case "check":
      return svg(<><rect x="4" y="4" width="16" height="16" rx="2" /><polyline points="8.5 12 11 14.5 16 9" /></>);
    case "box":
      return svg(<><path d="M4 8l8-4 8 4v8l-8 4-8-4z" /><path d="M4 8l8 4 8-4M12 12v8" /></>);
    case "home":
      return svg(<><path d="M4 11l8-7 8 7" /><path d="M6 10v10h12V10" /></>);
    case "edit":
      return svg(<><path d="M14 5l5 5L9 20H4v-5z" /><path d="M13 6l5 5" /></>);
    case "pin":
      return svg(<><path d="M12 21s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12Z" /><circle cx="12" cy="9" r="2.5" /></>);
    case "money":
      return svg(<><rect x="3" y="6" width="18" height="12" rx="2" /><circle cx="12" cy="12" r="2.5" /></>);
    case "chart":
      return svg(<><line x1="4" y1="20" x2="20" y2="20" /><rect x="6" y="12" width="3" height="6" /><rect x="11" y="8" width="3" height="10" /><rect x="16" y="5" width="3" height="13" /></>);
    case "users":
      return svg(<><circle cx="9" cy="8" r="3" /><path d="M4 20a5 5 0 0 1 10 0" /><path d="M16 6a3 3 0 0 1 0 6M17 20a5 5 0 0 0-2-4" /></>);
    case "megaphone":
      return svg(<><path d="M4 11v2a1 1 0 0 0 1 1h2l8 4V6L7 10H5a1 1 0 0 0-1 1Z" /><path d="M17 9a3 3 0 0 1 0 6" /></>);
    case "chat":
      return svg(<path d="M5 5h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H9l-4 4v-4H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z" />);
    case "bell":
      return svg(<><path d="M6 9a6 6 0 1 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6Z" /><path d="M10 20a2 2 0 0 0 4 0" /></>);
    case "hub":
      return svg(<><circle cx="12" cy="12" r="2.5" /><circle cx="5" cy="6" r="1.6" /><circle cx="19" cy="6" r="1.6" /><circle cx="12" cy="20" r="1.6" /><path d="M6.3 7l4 3.4M17.7 7l-4 3.4M12 14.5V18.4" /></>);
    case "gear":
      return svg(<><circle cx="12" cy="12" r="3" /><path d="M12 3v2.5M12 18.5V21M4.2 7l2.2 1.3M17.6 15.7l2.2 1.3M4.2 17l2.2-1.3M17.6 8.3l2.2-1.3" /></>);
  }
}

/** Kullanicinin acik/kapali bolum tercihi (tarayici basina). */
const MENU_DURUM_ANAHTARI = "yonetio.menu.durum";

/** Bolum basliginin acilir oku — 90 derece doner. */
function Ok({ acik }: { acik: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={`h-3.5 w-3.5 shrink-0 transition-transform ${acik ? "rotate-90" : ""} rtl:-scale-x-100`}
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <polyline points="9 5 16 12 9 19" />
    </svg>
  );
}

/** Menudeki tek bir baglanti satiri. */
function MenuSatiri({
  oge,
  aktif,
  onNavigate,
}: {
  oge: MenuOgesi;
  aktif: boolean;
  onNavigate?: () => void;
}) {
  const t = useT();
  return (
    <Link
      href={ogeBaglantisi(oge)}
      onClick={onNavigate}
      aria-current={aktif ? "page" : undefined}
      // (P132) Aktif oge MAVI tint — mobil alt barin aktif sekme dili.
      // Tint %12, metin vurgu rengi: ikisi de token.
      className={`odak-ic group relative flex items-center gap-3 rounded-lg py-2 pe-3 ps-7 text-sm transition-colors ${
        aktif
          ? "bg-accent-blue/12 font-medium text-accent-blue"
          : "text-metin-body hover:bg-yuzey-divider"
      }`}
    >
      {aktif && (
        <motion.span
          layoutId="nav-active-bar"
          className="absolute inset-y-1.5 start-0 w-1 rounded-e-full bg-primary"
          transition={{ type: "spring", stiffness: 500, damping: 40 }}
        />
      )}
      <span className={aktif ? "text-accent-blue" : "text-metin-muted"}>
        <Icon name={oge.icon} />
      </span>
      <span className="truncate">{t(oge.anahtar)}</span>
    </Link>
  );
}

/**
 * Etiketli bolum: baslik (acilir dugme) + ogeler.
 *
 * BASLIK BIR DUGMEDIR, `div` degil: klavye kullanicisi bolumu Tab ile
 * bulup Enter/Space ile acabilmeli. `aria-expanded` durumu ekran
 * okuyucuya soyler; ogeler kapaliyken DOM'a HIC girmez — "gorunmez ama
 * odaklanabilir" satir, klavyeyle gezinmenin en can sikici hatasidir.
 */
function Bolum({
  grup,
  acik,
  pathname,
  sorgu,
  onCevir,
  onNavigate,
}: {
  grup: MenuGrubu;
  acik: boolean;
  pathname: string;
  sorgu: URLSearchParams | null;
  onCevir: () => void;
  onNavigate?: () => void;
}) {
  const t = useT();
  const baslik = t(grup.anahtar);
  return (
    <div>
      <button
        type="button"
        onClick={onCevir}
        aria-expanded={acik}
        aria-label={acik ? t("kabukBolumKapat", { bolum: baslik }) : t("kabukBolumAc", { bolum: baslik })}
        className="odak-ic flex w-full items-center gap-2 rounded-lg px-3 py-1.5 text-start text-[11px] font-semibold tracking-wide text-metin-muted transition-colors hover:bg-yuzey-divider"
      >
        <Ok acik={acik} />
        <span className="truncate">{baslik}</span>
      </button>
      {acik && (
        <div className="space-y-0.5">
          {grup.ogeler.map((o) => (
            <MenuSatiri
              key={ogeBaglantisi(o)}
              oge={o}
              aktif={ogeAktif(o, pathname, sorgu)}
              onNavigate={onNavigate}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function SidebarBody({
  onNavigate,
  rolBaslangic,
  yuzey,
}: {
  onNavigate?: () => void;
  rolBaslangic: string | null;
  yuzey: Yuzey;
}) {
  const pathname = usePathname();
  // (P154 / Asama 7.1) Menu artik ayni rotanin ALT GORUNUMLERINI de tasiyor
  // (`/finans?tip=gelir`). Aktif satiri bulmak icin sorgu da gerekli;
  // yalniz yola bakan bir kural yedi finans satirini birden boyardi.
  const sorgu = useSearchParams();
  const router = useRouter();
  const t = useT();
  const [cikisHatasi, setCikisHatasi] = useState(false);

  // CIKIS BASARISIZSA GIRIS EKRANINA GIDILMEZ. Cerezleri temizleyen bu
  // istek dusebilir (ag, dagitim). Yanit denetlenmeden /login'e gecmek,
  // OTURUMU ACIK KALMIS bir kullaniciya cikmis gibi gostermek demekti —
  // ortak bir bilgisayarda bunun bedeli oturumun devri olur. Basarisizsa
  // ekranda kalinir ve DURUM SOYLENIR.
  async function logout() {
    let ok = false;
    try {
      ok = (await fetch("/api/auth/logout", { method: "POST" })).ok;
    } catch {
      ok = false;
    }
    if (!ok) {
      setCikisHatasi(true);
      return;
    }
    router.replace("/login");
    router.refresh();
  }

  // (P125/P126) BULUNULAN YUZEY UCLUDAN GELIR — duzen onu istegin `Host`
  // basligindan cozdu. Eskiden burada tarayicinin konagi okunuyordu ve
  // SUNUCU CIZIMINDE `window` yok: ilk kare `app.*`ta bile platform
  // menusuyle boyaniyordu (sakine bir an "Tesisler" gorunuyordu).
  // (P126.7) MENU ROLE GORE DE SUZULUR.
  //
  // Sunucudan gelen `rol` (duzen, cerezden cozdu) BASLANGIC degeridir;
  // access cerezi dusmusse `null` gelir ve `/api/me` devreye girer — o
  // istek BFF'in yenileme akisini tetikler, yani menu KENDINI TOPARLAR.
  // SWR anahtari profil sayfasiyla AYNI: iki istek degil, tek istek.
  const { data: ben } = useSWR<{ role?: string }>(
    rolBaslangic ? null : "/api/me",
    jsonFetcher,
  );
  const rol = rolBaslangic ?? ben?.role ?? null;

  // Bilinmeyen rota ve rolde OLMAYAN rota MENUYE ALINMAZ: "varsayilan
  // olarak goster" demek, sakine yonetim menusunu cizmek olurdu.
  // (P133.1) Kume AYNI kaldi; degisen sey BOLUMLENMESI.
  const gruplar = menuGruplari(yuzey, rol);
  const profilVar = profilGorunur(yuzey, rol);

  // ACIK BOLUM: bulunulan sayfanin bolumu. Kullanici bir bolumu acip
  // kapattiginda karari SAKLANIR (kullanici basina, localStorage).
  const aktifGrup = rotaninGrubu(pathname);
  // Bulunulan rota bir bolume dusmuyorsa (orn. `/profil`, bolum disidir)
  // ILK bolum acilir: "hicbiri acik degil" hâli menuyu bos bir baslik
  // listesine cevirirdi ve kullanici tek bir sayfa adi goremezdi.
  const varsayilanAcik: GrupId[] = aktifGrup
    ? [aktifGrup]
    : gruplar.length > 0
      ? [gruplar[0].id]
      : [];
  const [acikGruplar, setAcikGruplar] = useState<GrupId[] | null>(null);
  const [dahaFazla, setDahaFazla] = useState(false);

  // ILK KARE SUNUCUDA CIZILIR ve orada `localStorage` YOKTUR. Durum bu
  // yuzden `null` baslar ve etkide doldurulur: sunucu ve ilk istemci
  // karesi AYNI seyi cizer (hidrasyon uyusmazligi yok), kullanicinin
  // kaydi hemen ardindan uygulanir.
  //
  // BULUNULAN SAYFANIN BOLUMU HER ZAMAN ACIK OLUR — kayitli tercih
  // "kapali" dese bile. Aksi hâlde kullanici bir sayfaya gidip menude
  // KENDI satirini goremez ve nerede oldugunu kaybeder; bolum KATLI ise
  // kat da acilir. Bu iki karar (kayit okuma + aktif bolumu acma) TEK
  // etkide durur: ayri etkilere bolundugunde ikincisi ilk kurulumda
  // `acikGruplar === null` gorup erken donuyordu ve katli bir bolume
  // dogrudan girildiginde satir HIC gorunmuyordu.
  useEffect(() => {
    let kayitliAcik: GrupId[] | null = null;
    let kayitliKat: boolean | null = null;
    try {
      const ham = localStorage.getItem(MENU_DURUM_ANAHTARI);
      if (ham) {
        const c = JSON.parse(ham) as { acik?: GrupId[]; dahaFazla?: boolean };
        if (Array.isArray(c.acik)) kayitliAcik = c.acik;
        if (typeof c.dahaFazla === "boolean") kayitliKat = c.dahaFazla;
      }
    } catch {
      // Bozuk/erisilemez depolama menuyu KIRMAZ — varsayilana dusulur.
    }
    const acikKume = new Set(kayitliAcik ?? varsayilanAcik);
    if (aktifGrup) acikKume.add(aktifGrup);
    setAcikGruplar([...acikKume]);
    setDahaFazla(
      (aktifGrup !== null && KATLI_GRUPLAR.includes(aktifGrup)) ||
        (kayitliKat ?? false),
    );
    // `pathname` degisince yeniden calisir: gezinme aktif bolumu acar.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aktifGrup]);

  function grupCevir(id: GrupId) {
    const simdiki = acikGruplar ?? [];
    const yeni = simdiki.includes(id)
      ? simdiki.filter((x) => x !== id)
      : [...simdiki, id];
    setAcikGruplar(yeni);
    yaz(yeni, dahaFazla);
  }

  function dahaFazlaCevir() {
    const yeni = !dahaFazla;
    setDahaFazla(yeni);
    yaz(acikGruplar ?? [], yeni);
  }

  function yaz(acik: GrupId[], fazla: boolean) {
    try {
      localStorage.setItem(
        MENU_DURUM_ANAHTARI,
        JSON.stringify({ acik, dahaFazla: fazla }),
      );
    } catch {
      // Gizli sekmede depolama yazilamaz; menu yine calisir, hatirlamaz.
    }
  }

  // Sunucu karesinde (`acikGruplar === null`) aktif bolum acik cizilir:
  // kullanici bulundugu sayfayi menude ILK karede gorur.
  const acik = acikGruplar ?? varsayilanAcik;
  // Ilk karede de ayni kural: aktif bolum katliysa kat acik cizilir.
  const katAcik =
    dahaFazla || (acikGruplar === null && !!aktifGrup && KATLI_GRUPLAR.includes(aktifGrup));
  const ustGruplar = gruplar.filter((g) => !g.katli);
  const katliGruplar = gruplar.filter((g) => g.katli);

  // Logo hedefi YUZEY + ROL: panelde tesis panosu yoktur; tesis yuzeyinde de
  // pano YALNIZ yonetimindir. Sabit `/dashboard` birakmak, logoya tiklayan
  // sakini middleware'in geri yollamasina birakirdi (calisir ama bir adim
  // fazladan ve adres cubugunda bir an yanlis sayfa gorunur).
  const kokHedef = kokRotaRol(yuzey, rol);

  const bolum = (g: MenuGrubu) => (
    <Bolum
      key={g.id}
      grup={g}
      acik={acik.includes(g.id)}
      pathname={pathname}
      sorgu={sorgu}
      onCevir={() => grupCevir(g.id)}
      onNavigate={onNavigate}
    />
  );

  return (
    <div className="flex h-full flex-col">
      <div className="kart-kenar flex h-16 shrink-0 items-center border-b px-5">
        <Link href={kokHedef} aria-label="Yönetio" onClick={onNavigate}>
          <YonetioLogo size={26} />
        </Link>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {ustGruplar.map(bolum)}

        {/* KATLI BOLUMLER tek bir satirin ardinda: menuyu 28 satirdan
            ~10'a indiren sey budur. Katlanan bolumler KAYBOLMAZ, bir
            tiklama uzaga gider. */}
        {katliGruplar.length > 0 && (
          <>
            <button
              type="button"
              onClick={dahaFazlaCevir}
              aria-expanded={katAcik}
              className="odak-ic flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm text-metin-muted transition-colors hover:bg-yuzey-divider"
            >
              <Ok acik={katAcik} />
              <span className="truncate">
                {katAcik ? t("kabukDahaAz") : t("kabukDahaFazla")}
              </span>
            </button>
            {katAcik && katliGruplar.map(bolum)}
          </>
        )}
      </nav>

      <div className="kart-kenar shrink-0 space-y-2 border-t px-3 py-4">
        {/* PROFIL BOLUMDE DEGIL: kullanicinin KENDI kaydidir, bir yonetim
            isi degil — her rolde ayni yerde, cikisin yaninda durur. */}
        {profilVar && (
          <MenuSatiri
            oge={PROFIL_OGESI}
            aktif={ogeAktif(PROFIL_OGESI, pathname, sorgu)}
            onNavigate={onNavigate}
          />
        )}
        {/* (P140.4) DIL SECICI BURADAN KALDIRILDI — sag uste tasindi.
            Iki yerde birden durmasi, "hangisi gecerli?" sorusunu ureten
            bir tekrardir. Tema anahtari burada KALIR: o bir gorunum
            tercihi ve kenar cubugunun dibi onun icin dogru yer. */}
        <div className="flex flex-wrap gap-2">
          <ThemeToggle />
        </div>
        <button
          onClick={logout}
          className="kart-kenar w-full rounded-lg border bg-yuzey-card px-3 py-1.5 text-start text-sm text-metin-body transition hover:bg-yuzey-divider"
        >
          {t("kabukCikisYap")}
        </button>
        {cikisHatasi && (
          <p role="alert" className="text-xs text-accent-red">
            {t("kabukCikisYapilamadi")}
          </p>
        )}
      </div>
    </div>
  );
}

export function AppShell({
  children,
  rol,
  yuzey,
}: {
  children: ReactNode;
  /** Sunucunun cerezden cozdugu rol; bilinmiyorsa `null` (bkz. duzen). */
  rol: string | null;
  /** Sunucunun `Host` basligindan cozdugu yuzey. */
  yuzey: Yuzey;
}) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const t = useT();

  // Rota degisince mobil cekmeceyi kapat.
  useEffect(() => setOpen(false), [pathname]);

  return (
    <MotionConfig reducedMotion="user">
      <div className="min-h-screen bg-yuzey-bg">
        {/* (P132) ICERIGE ATLA — klavye kullanicisi 30+ menu baglantisini
            tek tek gecmek zorunda kalmasin. Gorunmez durur, ODAKLANINCA
            gorunur: fareyle gelen kullaniciyi rahatsiz etmez, klavyeyle
            gelen ilk Tab'da bulur. */}
        <a
          href="#icerik"
          className="sr-only focus:not-sr-only focus:absolute focus:start-4 focus:top-4 focus:z-[60] focus:rounded-lg focus:bg-primary focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-white"
        >
          {t("kabukIcerigeAtla")}
        </a>
        {/* Masaustu sabit kenar cubugu */}
        {/* RTL: `left/border-r` yerine MANTIKSAL kenar — Arapcada kenar
            cubugu saga gecer (tur 17). */}
        <aside className="kart-kenar fixed inset-y-0 start-0 z-30 hidden w-64 border-e bg-yuzey-card lg:block">
          <SidebarBody rolBaslangic={rol} yuzey={yuzey} />
        </aside>

        {/* Mobil ust cubuk */}
        <header className="kart-kenar sticky top-0 z-20 flex h-14 items-center justify-between border-b bg-yuzey-card px-4 lg:hidden">
          <button
            onClick={() => setOpen(true)}
            aria-label={t("kabukMenuyuAc")}
            className="kart-kenar rounded-lg border p-2 text-metin-body transition hover:bg-yuzey-divider"
          >
            <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round">
              <line x1="4" y1="7" x2="20" y2="7" /><line x1="4" y1="12" x2="20" y2="12" /><line x1="4" y1="17" x2="20" y2="17" />
            </svg>
          </button>
          <YonetioLogo size={24} />
          {/* (P140.4) Dil secici SAG UST — eskiden burada yalnizca hizalama
              icin bos bir `span` duruyordu. */}
          <DilSecici />
        </header>

        {/* Mobil cekmece + arka plan */}
        {open && (
          <button
            aria-label={t("kabukMenuyuKapat")}
            onClick={() => setOpen(false)}
            className="fixed inset-0 z-40 bg-slate-900/40 backdrop-blur-sm lg:hidden"
          />
        )}
        <aside
          // Cekmece RTL'de SAGDAN girer: `start-0` + `rtl:translate-x-full`
          // (Tailwind'in `-translate-x-full`u yon farkindaligi TASIMAZ).
          className={`kart-kenar fixed inset-y-0 start-0 z-50 w-64 border-e bg-yuzey-card shadow-yuzen transition-transform duration-300 lg:hidden ${
            open
              ? "translate-x-0"
              : "-translate-x-full rtl:translate-x-full"
          }`}
        >
          <SidebarBody
            onNavigate={() => setOpen(false)}
            rolBaslangic={rol}
            yuzey={yuzey}
          />
        </aside>

        {/* Icerik */}
        <div className="lg:ps-64">
          {/* (P140.4) MASAUSTU SAG UST — dil secicinin tek yeri.
              Kendi basina bir baslik cubugu DEGIL: yalnizca hizalama
              seridi, boylece sayfa basliklari (`SayfaBasligi`) ikinci bir
              baslik seviyesiyle yarismaz. */}
          <div className="hidden items-center justify-between gap-4 px-4 pt-4 sm:px-6 lg:flex lg:px-8">
            {/* (P154 / Asama 6.3) GLOBAL ARAMA — TEK yer. Her ekrana ayri
                arama yazmak, yetki kuralini her ekranda tekrar etmek ve
                biri unutuldugunda SESSIZ bir sizinti birakmak olurdu. */}
            <GlobalArama />
            <DilSecici />
          </div>
          <main id="icerik" className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8 lg:pt-4">
            {children}
          </main>
        </div>
      </div>
    </MotionConfig>
  );
}
