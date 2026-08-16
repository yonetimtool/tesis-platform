"use client";

import { motion, MotionConfig } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";

import { DilSecici } from "@/components/DilSecici";
import { GlobalArama } from "@/components/GlobalArama";
import { ThemeToggle } from "@/components/ThemeToggle";
import { BildirimMerkezi, KomutPaleti } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { YonetioLogo } from "@/components/YonetioLogo";
import { useRol } from "@/lib/rol-kullan";
import {
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

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEFFAF = "transparent";
const GOLGESIZ = "none";
const YON_SOL = "sol";

/** Katlama oku. Yon MANTIKSAL degil gorsel: RTL'de `rotate-180` ile
 *  cevrilir (Tailwind `rtl:` varyanti). */
function OkKatla({ yon }: { yon: "sol" | "sag" }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={`h-4 w-4 rtl:rotate-180 ${yon === YON_SOL ? "" : "rotate-180"}`}
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M15 6l-6 6 6 6" />
    </svg>
  );
}

function CikisIkonu() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="mx-auto h-4 w-4"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4" />
      <path d="M16 17l5-5-5-5M21 12H10" />
    </svg>
  );
}

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

/**
 * Kullanicinin acik/kapali bolum tercihi (tarayici basina).
 *
 * (P166 §1) ANAHTAR SURUMLENDI (`.v2`). Eski kayit `{acik: ["guvenlik"]}`
 * gibi bir DAR kume tasiyor — o kume "yalniz bulundugum bolum acik"
 * varsayimiyla yazilmisti. Yeni varsayilan HEPSI ACIK; eski kaydi okumak,
 * kaldirdigimiz gizli menuyu kullanicinin tarayicisindan geri getirirdi.
 * Yeni anahtar, eski kaydi sessizce gecersiz kilar.
 *
 * TEKNIK TANIMLAYICI: `yonetio.` oneki BILEREK korundu (bkz. §6 marka
 * degisikligi) — depolama anahtari kullaniciya gorunen bir metin degildir
 * ve degistirmek herkesin tercihini bir kez daha sifirlardi.
 */
const MENU_DURUM_ANAHTARI = "yonetio.menu.durum.v2";
/** (P160) Kenar cubugu dar mi — KABUGA ait, menu durumundan AYRI. */
const DAR_ANAHTARI = "yonetio.menu.dar";

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
  dar = false,
}: {
  oge: MenuOgesi;
  aktif: boolean;
  onNavigate?: () => void;
  /** (P160) Kenar cubugu DAR modda mi — etiket gorsel olarak gizlenir. */
  dar?: boolean;
}) {
  const t = useT();
  const etiket = t(oge.anahtar);
  return (
    <Link
      href={ogeBaglantisi(oge)}
      onClick={onNavigate}
      // DAR MODDA `title`: fare kullanicisi ikonun ne oldugunu gorebilmeli.
      // Ekran okuyucu icin etiket `sr-only` olarak DOM'da KALIR (asagida) —
      // `title` tek basina guvenilir bir ad kaynagi degildir.
      title={dar ? etiket : undefined}
      aria-current={aktif ? "page" : undefined}
      // (P160) AKTIF OGE: hafif KABARTMALI KAPSUL + sol gosterge.
      //
      // P132'nin "mavi tint" dili TERK EDILDI (brief: renkli dolgu bloklar
      // yerine metalik yuzey; renk yalniz durum sinyali). Aktiflik artik
      // RENKLE degil YUZEYLE anlatiliyor — satir zeminden bir kademe
      // yukselir. Bu ayni zamanda daha erisilebilir: renk korlugu olan
      // kullanici da kabartmayi gorur.
      className={`odak-ic group relative flex items-center gap-3 py-2 transition-[background,box-shadow] ${
        dar ? "justify-center px-2" : "pe-3 ps-7"
      }`}
      style={{
        borderRadius: "var(--yz-radius-btn)",
        fontSize: "var(--yz-fs-body)",
        color: aktif ? "var(--yz-text)" : "var(--yz-text-2)",
        background: aktif ? "var(--yz-metal-2)" : SEFFAF,
        boxShadow: aktif ? "var(--yz-raised)" : GOLGESIZ,
        transitionDuration: "var(--yz-dur-fast)",
      }}
    >
      {aktif && (
        <motion.span
          layoutId="nav-active-bar"
          className="absolute inset-y-1.5 start-0 w-1 rounded-e-full"
          style={{ background: "var(--yz-accent-edge)" }}
          transition={{ type: "spring", stiffness: 500, damping: 40 }}
        />
      )}
      <span style={{ color: aktif ? "var(--yz-accent-edge)" : "var(--yz-text-3)" }}>
        <Icon name={oge.icon} />
      </span>
      {/* ETIKET: dar modda GORSEL olarak silinir ama DOM'da kalir —
          baglantinin erisilebilir ADI odur. Kaldirsaydik ekran okuyucu
          yalnizca "baglanti" derdi. Gecis, genislik ve solma birlikte
          (brief: "genislik gecisi, etiket solma"). */}
      <span
        className={dar ? "sr-only" : "truncate transition-opacity"}
        style={dar ? undefined : { transitionDuration: "var(--yz-dur-base)" }}
      >
        {etiket}
      </span>
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
  dar = false,
}: {
  grup: MenuGrubu;
  acik: boolean;
  pathname: string;
  sorgu: URLSearchParams | null;
  onCevir: () => void;
  onNavigate?: () => void;
  dar?: boolean;
}) {
  const t = useT();
  const baslik = t(grup.anahtar);

  // DAR MODDA BOLUM BASLIGI CIZILMEZ ve bolum HER ZAMAN ACIKTIR.
  //
  // Neden: 68px'e sigan bir baslik yok; kisaltilmis bir metin ("Guv...")
  // bilgi tasimaz. Katlanmayi da kapatmak gerekiyor cunku basligi
  // gizleyip katlamayi acik birakmak, kullanicinin ACAMAYACAGI kapali
  // bir bolum birakirdi — satirlar erisilemez olurdu.
  if (dar) {
    return (
      <div
        className="space-y-0.5 border-t pt-2 first:border-t-0 first:pt-0"
        style={{ borderColor: "var(--yz-border)" }}
        // Bolum adi GORSEL olarak yok ama gruplama ekran okuyucuda KALIR.
        aria-label={baslik}
        role="group"
      >
        {grup.ogeler.map((o) => (
          <MenuSatiri
            key={ogeBaglantisi(o)}
            oge={o}
            aktif={ogeAktif(o, pathname, sorgu)}
            onNavigate={onNavigate}
            dar
          />
        ))}
      </div>
    );
  }

  return (
    <div>
      <button
        type="button"
        onClick={onCevir}
        aria-expanded={acik}
        aria-label={acik ? t("kabukBolumKapat", { bolum: baslik }) : t("kabukBolumAc", { bolum: baslik })}
        className="odak-ic flex w-full items-center gap-2 px-3 py-1.5 text-start font-semibold uppercase transition-colors"
        style={{
          borderRadius: "var(--yz-radius-btn)",
          fontSize: "var(--yz-fs-xs)",
          letterSpacing: "var(--yz-tracking-label)",
          color: "var(--yz-text-3)",
        }}
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
  dar = false,
  onDarCevir,
}: {
  onNavigate?: () => void;
  rolBaslangic: string | null;
  yuzey: Yuzey;
  /** (P160) DAR mod — yalniz masaustu kenar cubugunda. Cekmece HER ZAMAN
   *  genistir: mobilde 68px'lik bir cekmece anlamsizdir. */
  dar?: boolean;
  onDarCevir?: () => void;
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
  // (P166 §2) Cozum `useRol`e cikarildi: sayfa aramasi da AYNI rolu bilmek
  // zorunda ve mantigi ikinci kez yazmak iki yerin ayrisabilmesi demekti.
  const rol = useRol(rolBaslangic);

  // Bilinmeyen rota ve rolde OLMAYAN rota MENUYE ALINMAZ: "varsayilan
  // olarak goster" demek, sakine yonetim menusunu cizmek olurdu.
  // (P133.1) Kume AYNI kaldi; degisen sey BOLUMLENMESI.
  const gruplar = menuGruplari(yuzey, rol);
  const profilVar = profilGorunur(yuzey, rol);

  // (P166 §1) VARSAYILAN: HEPSI ACIK.
  //
  // Eskiden yalniz bulunulan sayfanin bolumu acilirdi ve geri kalan dort
  // bolum "Daha fazla"nin ardindaydi — yani kullanici menuyu ilk actiginda
  // 40 sayfanin 8'ini goruyordu. Brief'in olcusu acik: "TUM basliklar ve
  // alt basliklari tek listede, acik sekilde gorunecek."
  //
  // KATLAMA YETENEGI DURUYOR (baslik hâlâ bir dugme) ama artik kullanicinin
  // KENDI karari; varsayilan bir gizleme degil. Liste uzarsa `nav`
  // kaydirilir — brief: "gizleme cozumu kullanma".
  const aktifGrup = rotaninGrubu(pathname);
  const varsayilanAcik: GrupId[] = gruplar.map((g) => g.id);
  const [acikGruplar, setAcikGruplar] = useState<GrupId[] | null>(null);

  // ILK KARE SUNUCUDA CIZILIR ve orada `localStorage` YOKTUR. Durum bu
  // yuzden `null` baslar ve etkide doldurulur: sunucu ve ilk istemci
  // karesi AYNI seyi cizer (hidrasyon uyusmazligi yok), kullanicinin
  // kaydi hemen ardindan uygulanir.
  //
  // BULUNULAN SAYFANIN BOLUMU HER ZAMAN ACIK OLUR — kayitli tercih
  // "kapali" dese bile. Aksi hâlde kullanici bir sayfaya gidip menude
  // KENDI satirini goremez ve nerede oldugunu kaybeder.
  useEffect(() => {
    let kayitliAcik: GrupId[] | null = null;
    try {
      const ham = localStorage.getItem(MENU_DURUM_ANAHTARI);
      if (ham) {
        const c = JSON.parse(ham) as { acik?: GrupId[] };
        if (Array.isArray(c.acik)) kayitliAcik = c.acik;
      }
    } catch {
      // Bozuk/erisilemez depolama menuyu KIRMAZ — varsayilana dusulur.
    }
    const acikKume = new Set(kayitliAcik ?? varsayilanAcik);
    if (aktifGrup) acikKume.add(aktifGrup);
    setAcikGruplar([...acikKume]);
    // `pathname` degisince yeniden calisir: gezinme aktif bolumu acar.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aktifGrup]);

  function grupCevir(id: GrupId) {
    const simdiki = acikGruplar ?? varsayilanAcik;
    const yeni = simdiki.includes(id)
      ? simdiki.filter((x) => x !== id)
      : [...simdiki, id];
    setAcikGruplar(yeni);
    yaz(yeni);
  }

  function yaz(acik: GrupId[]) {
    try {
      localStorage.setItem(MENU_DURUM_ANAHTARI, JSON.stringify({ acik }));
    } catch {
      // Gizli sekmede depolama yazilamaz; menu yine calisir, hatirlamaz.
    }
  }

  // Sunucu karesinde (`acikGruplar === null`) varsayilan cizilir: artik
  // HEPSI ACIK, yani ilk kare de tam listeyi gosterir. (Eskiden burada
  // yalniz aktif bolum acilirdi ve ilk kare eksik bir menuydu.)
  const acik = acikGruplar ?? varsayilanAcik;

  // Logo hedefi YUZEY + ROL: panelde tesis panosu yoktur; tesis yuzeyinde de
  // pano YALNIZ yonetimindir. Sabit `/dashboard` birakmak, logoya tiklayan
  // sakini middleware'in geri yollamasina birakirdi (calisir ama bir adim
  // fazladan ve adres cubugunda bir an yanlis sayfa gorunur).
  const kokHedef = kokRotaRol(yuzey, rol);

  const bolum = (g: MenuGrubu) => (
    <Bolum
      key={g.id}
      dar={dar}
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
      <div
        className={`flex h-16 shrink-0 items-center border-b ${
          dar ? "justify-center px-2" : "justify-between px-5"
        }`}
        style={{
          borderColor: "var(--yz-border)",
          borderBottomWidth: "var(--yz-border-w)",
        }}
      >
        <Link href={kokHedef} aria-label="Yönetio" onClick={onNavigate}>
          <YonetioLogo size={26} />
        </Link>
        {/* KATLAMA DUGMESI YALNIZ MASAUSTUNDE (`onDarCevir` verildiginde).
            Cekmecede cizilmez: mobilde daraltmanin karsiligi yok. */}
        {onDarCevir && !dar && (
          <button
            type="button"
            onClick={onDarCevir}
            aria-label={t("kabukMenuDaralt")}
            className="odak-ic flex h-8 w-8 items-center justify-center rounded-lg"
            style={{ color: "var(--yz-text-3)" }}
          >
            <OkKatla yon="sol" />
          </button>
        )}
      </div>
      {/* DAR MODDA genisletme dugmesi logonun ALTINDA: 68px'lik seritte
          logo ve dugme yan yana sigmaz. */}
      {onDarCevir && dar && (
        <div className="flex justify-center py-2">
          <button
            type="button"
            onClick={onDarCevir}
            aria-label={t("kabukMenuGenislet")}
            className="odak-ic flex h-8 w-8 items-center justify-center rounded-lg"
            style={{ color: "var(--yz-text-3)" }}
          >
            <OkKatla yon="sag" />
          </button>
        </div>
      )}

      {/* (P166 §1) TEK LISTE. "Daha fazla / Daha az" satiri KALDIRILDI;
          butun bolumler ayni `nav` icinde, acik olarak cizilir. Liste
          ekrandan uzunsa `overflow-y-auto` kaydirir — brief'in acik
          sarti: "Liste uzarsa menu kaydirilabilir olsun; gizleme cozumu
          kullanma." */}
      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {gruplar.map(bolum)}
      </nav>

      <div
        className="shrink-0 space-y-2 border-t px-3 py-4"
        style={{ borderColor: "var(--yz-border)", borderTopWidth: "var(--yz-border-w)" }}
      >
        {/* PROFIL BOLUMDE DEGIL: kullanicinin KENDI kaydidir, bir yonetim
            isi degil — her rolde ayni yerde, cikisin yaninda durur. */}
        {profilVar && (
          <MenuSatiri
            oge={PROFIL_OGESI}
            aktif={ogeAktif(PROFIL_OGESI, pathname, sorgu)}
            onNavigate={onNavigate}
            dar={dar}
          />
        )}
        {/* (P140.4) DIL SECICI BURADAN KALDIRILDI — sag uste tasindi.
            Iki yerde birden durmasi, "hangisi gecerli?" sorusunu ureten
            bir tekrardir. Tema anahtari burada KALIR: o bir gorunum
            tercihi ve kenar cubugunun dibi onun icin dogru yer. */}
        {/* DAR MODDA TEMA ANAHTARI GIZLENIR: bileseni 68px'e sigdirmak
            onu yeniden yazmak demekti ve tema tercihi gunluk bir islem
            degil — kullanici menuyu genisletip degistirir. Gizlenen sey
            bir YOL degil, bir kisayol. */}
        {!dar && (
          <div className="flex flex-wrap gap-2">
            <ThemeToggle />
          </div>
        )}
        <button
          onClick={logout}
          aria-label={dar ? t("kabukCikisYap") : undefined}
          title={dar ? t("kabukCikisYap") : undefined}
          className={`odak-ic w-full border px-3 py-2 transition ${
            dar ? "text-center" : "text-start"
          }`}
          style={{
            borderRadius: "var(--yz-radius-btn)",
            borderColor: "var(--yz-border)",
            borderWidth: "var(--yz-border-w)",
            background: "var(--yz-metal-1)",
            boxShadow: "var(--yz-raised)",
            color: "var(--yz-text-2)",
            fontSize: "var(--yz-fs-sm)",
          }}
        >
          <span className={dar ? "sr-only" : undefined}>{t("kabukCikisYap")}</span>
          {dar && <CikisIkonu />}
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

  // (P160) KENAR CUBUGU DAR MI — kalici tercih.
  //
  // AYRI ANAHTAR, `SidebarBody`nin menu durumuyla BIRLESTIRILMEDI: o kayit
  // (`yonetio.menu.durum`) SidebarBody'ye ait ve onu yaziyor; bu deger ise
  // KABUGA ait (genislik, icerik bosluğu). Tek kaydi iki bilesenin
  // yazmasi, birinin otekinin alanini ezmesi demekti — ikisi farkli
  // zamanlarda okuyup yaziyor.
  //
  // `false` BASLAR ve etkide doldurulur: sunucu cizimi ile ilk istemci
  // karesi AYNI olmali (hidrasyon uyusmazligi yok) — `SidebarBody`nin
  // menu durumunda kullanilan desenin aynisi.
  const [dar, setDar] = useState(false);

  useEffect(() => {
    try {
      setDar(localStorage.getItem(DAR_ANAHTARI) === "1");
    } catch {
      // Erisilemez depolama kabugu KIRMAZ — genis varsayilanda kalinir.
    }
  }, []);

  function darCevir() {
    setDar((onceki) => {
      const yeni = !onceki;
      try {
        localStorage.setItem(DAR_ANAHTARI, yeni ? "1" : "0");
      } catch {
        // Yazilamazsa tercih bu oturumda gecerli olur, kalici olmaz.
      }
      return yeni;
    });
  }

  // Rota degisince mobil cekmeceyi kapat.
  useEffect(() => setOpen(false), [pathname]);

  return (
    <MotionConfig reducedMotion="user">
      {/* (P160) Zemin DUZ RENK DEGIL GRADYAN: brief "ustten alta hafif
          acilan" bir yuzey istiyor ve metalik hissin ilk katmani bu. */}
      <div
        className="min-h-screen"
        style={{ background: "var(--yz-bg-app-grad)", color: "var(--yz-text)" }}
      >
        {/* (P160) KOMUT PALETI — kabugun KOKUNDE, cunku Ctrl+K her
            sayfada calismali. Kapaliyken hicbir sey cizmez. */}
        <KomutPaleti yuzey={yuzey} rolBaslangic={rol} />
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
        <aside
          className={`fixed inset-y-0 start-0 hidden border-e transition-[width] lg:block ${
            dar ? "w-[68px]" : "w-64"
          }`}
          style={{
            zIndex: "var(--yz-z-sidebar)" as unknown as number,
            background: "var(--yz-bg-sidebar)",
            borderColor: "var(--yz-border)",
            borderInlineEndWidth: "var(--yz-border-w)",
            transitionDuration: "var(--yz-dur-slow)",
            transitionTimingFunction: "var(--yz-ease)",
          }}
        >
          <SidebarBody
            rolBaslangic={rol}
            yuzey={yuzey}
            dar={dar}
            onDarCevir={darCevir}
          />
        </aside>

        {/* Mobil ust cubuk */}
        <header
          className="sticky top-0 flex h-14 items-center justify-between border-b px-4 lg:hidden"
          style={{
            zIndex: "var(--yz-z-header)" as unknown as number,
            background: "var(--yz-bg-sidebar)",
            borderColor: "var(--yz-border)",
            borderBottomWidth: "var(--yz-border-w)",
          }}
        >
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
              icin bos bir `span` duruyordu.
              (P160) Bildirim merkezi mobilde de gorunur: okunmamis sayisi
              masaustune ozel bir bilgi degil. */}
          <div className="flex items-center gap-2">
            <BildirimMerkezi />
            <DilSecici />
          </div>
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
          style={{
            zIndex: "var(--yz-z-drawer)" as unknown as number,
            background: "var(--yz-bg-sidebar)",
            borderColor: "var(--yz-border)",
            borderInlineEndWidth: "var(--yz-border-w)",
            boxShadow: "var(--yz-raised-hover)",
          }}
          className={`fixed inset-y-0 start-0 w-64 border-e transition-transform duration-300 lg:hidden ${
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
        {/* ICERIK BOSLUGU kenar cubugunun genisligini IZLER ve ayni sure
            ile gecis yapar — ikisi ayri hizda hareket etseydi icerik bir
            an cubugun altina girerdi. */}
        <div
          className={`transition-[padding] ${dar ? "lg:ps-[68px]" : "lg:ps-64"}`}
          style={{
            transitionDuration: "var(--yz-dur-slow)",
            transitionTimingFunction: "var(--yz-ease)",
          }}
        >
          {/* (P140.4) MASAUSTU SAG UST — dil secicinin tek yeri.
              Kendi basina bir baslik cubugu DEGIL: yalnizca hizalama
              seridi, boylece sayfa basliklari (`SayfaBasligi`) ikinci bir
              baslik seviyesiyle yarismaz. */}
          <div className="hidden items-center justify-between gap-4 px-4 pt-4 sm:px-6 lg:flex lg:px-8">
            {/* (P154 / Asama 6.3) GLOBAL ARAMA — TEK yer. Her ekrana ayri
                arama yazmak, yetki kuralini her ekranda tekrar etmek ve
                biri unutuldugunda SESSIZ bir sizinti birakmak olurdu. */}
            <GlobalArama yuzey={yuzey} rolBaslangic={rol} />
            {/* (P160) BILDIRIM MERKEZI — dil secicinin yaninda. Sayac
                ve okundu isaretleme burada; tam liste `/notifications`. */}
            <div className="flex shrink-0 items-center gap-2">
              <BildirimMerkezi />
              <DilSecici />
            </div>
          </div>
          {/* (P160 / Asama 7) SAYFA GECISI — beyaz ekran YOK.
              `key={pathname}`: rota degisince icerik yeniden monte olur ve
              giris animasyonu tetiklenir. Cikis animasyonu bilerek YOK:
              Next App Router'da eski sayfa zaten soklulmus oluyor ve
              `exit` beklemek gecisi YAVASLATIR.

              8px kayma + solma: brief "gosteris degil, geri bildirim ve
              hiyerarsi" diyor. Buyuk kayma her gezinmede sayfayi ziplatir.

              `MotionConfig reducedMotion="user"` yukarida: hareket
              azaltmada bu animasyon KENDILIGINDEN kapanir. */}
          <motion.main
            id="icerik"
            key={pathname}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.32, ease: [0.16, 1, 0.3, 1] }}
            className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8 lg:pt-4"
          >
            {children}
          </motion.main>
        </div>
      </div>
    </MotionConfig>
  );
}
