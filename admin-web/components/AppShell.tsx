"use client";

import { motion, MotionConfig } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";

import { DilSecici } from "@/components/DilSecici";
import { GlobalArama } from "@/components/GlobalArama";
import { KurulumHatirlatici } from "@/components/KurulumHatirlatici";
import { SayfaEylemYuvasi } from "@/components/SayfaEylemleri";
import { ThemeToggle } from "@/components/ThemeToggle";
import { BildirimMerkezi, KomutPaleti } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import { YonetioLogo } from "@/components/YonetioLogo";
import { useRol } from "@/lib/rol-kullan";
import { KullaniciMenusu } from "@/components/KullaniciMenusu";
import {
  kurulumGorunur,
  menuGruplari,
  ogeAktif,
  ogeBaglantisi,
  rotaninGrubu,
  GRUP_IKONU,
  KURULUM_OGESI,
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
    // (P167 §6) Belge/dosya — karar defteri, dokuman arsivi, KVKK metni.
    // `scan` (denetim) ile karistirilmasin diye AYRI bir ikon: ucu de
    // "yazili belge"dir ve menude yan yana dururlar.
    case "doc":
      return svg(<>
        <path d="M7 3h7l4 4v14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" />
        <path d="M14 3v5h4M9 13h6M9 17h4" />
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
    // (P167 §1.1) KALKAN — GUVENLIK ana basliginin ikonu. Bolum ikonu
    // olarak `scan` kullanilamazdi: o zaten NFC noktalari ve arac
    // gecislerinin satir ikonuydu, baslik onlardan birinin kopyasi gibi
    // gorunurdu.
    case "shield":
      return svg(<><path d="M12 3l7 3v5.5c0 4.4-3 7.6-7 9.5-4-1.9-7-5.1-7-9.5V6z" /><polyline points="9 12 11 14 15 10" /></>);
  }
}

/**
 * Kullanicinin acik/kapali bolum tercihi (tarayici basina).
 *
 * (P167 §1.2) ANAHTAR YINE SURUMLENDI (`.v3`). P166'da varsayilan "hepsi
 * acik"ti ve `.v2` kayitlari o varsayimla yazildi — cogunda sekiz bolumun
 * hepsi listelidir. Yeni varsayilan "HEPSI KAPALI"; eski kaydi okumak,
 * kullanicilarin tarayicisinda menuyu bir kez daha tamamen acik acardi ve
 * degisiklik hic yapilmamis gibi gorunurdu. Surum atlamak, eski kaydi
 * SESSIZCE gecersiz kilmanin en ucuz yolu.
 *
 * NEDEN KAPALI BASLIYOR: menu 40+ satira ciktiginda "hepsi acik" bir liste
 * degil bir DUVAR. Kapali baslik kumesi once BOLUMLERI okutur (yedi satir),
 * kullanici hedefini secip acar. Bulunabilirlik kaygisi P166'da "gizli
 * menu"ye karsiydi; burada gizlenen bir sey YOK — yedi baslik da gorunur
 * ve tercih KALICI (kullanici bir kez acar, oyle kalir).
 *
 * TEKNIK TANIMLAYICI: `yonetio.` oneki BILEREK korundu (bkz. §6 marka
 * degisikligi) — depolama anahtari kullaniciya gorunen bir metin degildir
 * ve degistirmek herkesin tercihini bir kez daha sifirlardi.
 */
const MENU_DURUM_ANAHTARI = "yonetio.menu.durum.v3";
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
  ikonlu = false,
}: {
  oge: MenuOgesi;
  aktif: boolean;
  onNavigate?: () => void;
  /** (P160) Kenar cubugu DAR modda mi — etiket gorsel olarak gizlenir. */
  dar?: boolean;
  /**
   * (P167 §1.1) IKON CIZILSIN MI?
   *
   * ALT BASLIKLARDA CIZILMEZ — hiyerarsi ikonun yoklugu + girinti ile
   * anlatilir. Yalniz BAGIMSIZ sekmeler (Ozet) ve alt cubugun satirlari
   * ikon tasir. DAR MODDA kural TERSINE doner ve zorunlu olarak: 68px'lik
   * seritte etiket gorunmez, geriye tek tanima araci olarak ikon kalir —
   * ikonsuz bir dar menu, bos kutucuklardan olusan bir liste olurdu.
   */
  ikonlu?: boolean;
}) {
  const t = useT();
  const etiket = t(oge.anahtar);
  const ikonGoster = ikonlu || dar;
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
      // GIRINTI (§1.1): ikonsuz alt satir `ps-9`, ikonlu bagimsiz sekme
      // `ps-3`. Ikisi ayni gorsel eksende hizalanir — bagimsiz sekmenin
      // ikonu, alt satirlarin metin baslangicinin SOLUNDA kalir ve iki
      // duzey birbirine karismaz.
      className={`odak-ic group relative flex items-center gap-3 py-2 transition-[background,box-shadow] ${
        dar ? "justify-center px-2" : ikonlu ? "pe-3 ps-3" : "pe-3 ps-9"
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
      {ikonGoster && (
        <span style={{ color: aktif ? "var(--yz-accent-edge)" : "var(--yz-text-3)" }}>
          <Icon name={oge.icon} />
        </span>
      )}
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
  const satirlar = (ikonlu: boolean) =>
    grup.ogeler.map((o) => (
      <MenuSatiri
        key={ogeBaglantisi(o)}
        oge={o}
        aktif={ogeAktif(o, pathname, sorgu)}
        onNavigate={onNavigate}
        dar={dar}
        ikonlu={ikonlu}
      />
    ));

  if (dar) {
    return (
      <div
        className="space-y-0.5 border-t pt-2 first:border-t-0 first:pt-0"
        style={{ borderColor: "var(--yz-border)" }}
        // Bolum adi GORSEL olarak yok ama gruplama ekran okuyucuda KALIR.
        aria-label={baslik}
        role="group"
      >
        {satirlar(true)}
      </div>
    );
  }

  // (P167 §1.3) BAGIMSIZ SEKME: baslik YOK, satir(lar) IKONLU ve her zaman
  // gorunur. Katlanacak bir sey olmadigi icin `acik` de sorulmaz.
  if (grup.bagimsiz) {
    return <div className="space-y-0.5">{satirlar(true)}</div>;
  }

  return (
    <div>
      <button
        type="button"
        onClick={onCevir}
        aria-expanded={acik}
        aria-label={acik ? t("kabukBolumKapat", { bolum: baslik }) : t("kabukBolumAc", { bolum: baslik })}
        // (P167 §1.1) ANA BASLIK ARTIK IKONLU ve satirlarla ayni agirlikta
        // bir hedef (`py-2`): eskiden 1.5px'lik ince bir etiketti ve
        // tiklanabilir oldugu anlasilmiyordu. Ok SONA alindi — bas tarafta
        // ikonla yarisiyor, sonda ise "acilir" isareti olarak okunuyor.
        className="odak-ic flex w-full items-center gap-3 px-3 py-2 text-start font-semibold uppercase transition-colors"
        style={{
          borderRadius: "var(--yz-radius-btn)",
          fontSize: "var(--yz-fs-xs)",
          letterSpacing: "var(--yz-tracking-label)",
          color: acik ? "var(--yz-text)" : "var(--yz-text-2)",
        }}
      >
        <span style={{ color: acik ? "var(--yz-accent-edge)" : "var(--yz-text-3)" }}>
          <Icon name={GRUP_IKONU[grup.id]} />
        </span>
        <span className="flex-1 truncate">{baslik}</span>
        <Ok acik={acik} />
      </button>
      {acik && <div className="space-y-0.5">{satirlar(false)}</div>}
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
  const kurulumVar = kurulumGorunur(yuzey, rol);

  // (P167 §1.2) VARSAYILAN: HEPSI KAPALI.
  //
  // Bos dizi BILINCLI bir sabit degil, `[]`in kendisi: "hicbir bolum acik
  // degil". Kullanici hangisini acarsa `localStorage`a o yazilir ve
  // tercihi kalir.
  const aktifGrup = rotaninGrubu(pathname);
  const varsayilanAcik: GrupId[] = [];
  const [acikGruplar, setAcikGruplar] = useState<GrupId[] | null>(null);

  // ILK KARE SUNUCUDA CIZILIR ve orada `localStorage` YOKTUR. Durum bu
  // yuzden `null` baslar ve etkide doldurulur: sunucu ve ilk istemci
  // karesi AYNI seyi cizer (hidrasyon uyusmazligi yok), kullanicinin
  // kaydi hemen ardindan uygulanir.
  //
  // BULUNULAN SAYFANIN BOLUMU HER ZAMAN ACIK OLUR — kayitli tercih
  // "kapali" dese bile. Aksi hâlde kullanici bir sayfaya gidip menude
  // KENDI satirini goremez ve nerede oldugunu kaybeder.
  //
  // (P167 §1.2) BU KURAL "hepsi kapali baslar" ile CELISMEZ: ilk acilista
  // gidilen yer `/dashboard`, o da bagimsiz Ozet sekmesi — hicbir bolume
  // ait degil, dolayisiyla acilista yedi baslik da kapali. Kural ancak
  // kullanici bir bolum sayfasina gectiginde devreye girer ve orada
  // istenen sey zaten yon duygusudur.
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
        <Link href={kokHedef} aria-label="Yönetiyor" onClick={onNavigate}>
          <YonetioLogo size={32} />
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

      {/* (P166 §1) TEK LISTE — "Daha fazla / Daha az" katmani KALDIRILDI:
          butun bolumler ayni `nav` icinde.
          (P167 §1.2) Bolumler artik KAPALI baslar. Bu, kaldirdigimiz gizli
          menuye donus DEGIL: orada 30+ sayfa tek bir belirsiz satirin
          ARDINDAYDI, burada yedi baslik da GORUNUR ve tercih kalici.
          Liste yine de uzayabilir (kullanici bes bolum acabilir), o yuzden
          `overflow-y-auto` duruyor. */}
      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {gruplar.map(bolum)}
      </nav>

      <div
        className="shrink-0 space-y-2 border-t px-3 py-4"
        style={{ borderColor: "var(--yz-border)", borderTopWidth: "var(--yz-border-w)" }}
      >
        {/* (P167 §1.7) PROFIL SATIRI BURADAN KALDIRILDI — sag ust kullanici
            menusune tasindi (`KullaniciMenusu`). Kenar cubugu artik yalnizca
            SITEYE ait ekranlarin listesi; kullanicinin KENDI kaydi ise
            avatarin ardinda, herkesin aradigi yerde. */}

        {/* (P167 §1.8) ALT CUBUK IKI SATIR:
              [ Kurulum sihirbazi ]      <- tam genislik
              [ Tema ] [ Cikis ]         <- ikiye bolunmus
            Sihirbaz ustte ve tam genislikte cunku bir AKIS: yeni yonetici
            icin en onemli tek dugme. Tema ve cikis ise gunluk kucuk
            islemler — ayni satiri paylasmalari onlari dogru agirliga
            indiriyor ve alt cubugu iki satirda tutuyor. */}
        {/* DAR MODDA DA CIZILIR (yalnizca ikon): sihirbaz bir YOLDUR, tema
            gibi bir kisayol degil — 68px'e sigdirilamadigi icin
            kaldirilmasi, kurulumunu bitirmemis yoneticiyi yolsuz
            birakirdi. */}
        {kurulumVar && (
          <MenuSatiri
            oge={KURULUM_OGESI}
            aktif={ogeAktif(KURULUM_OGESI, pathname, sorgu)}
            onNavigate={onNavigate}
            dar={dar}
            ikonlu
          />
        )}
        {/* (P140.4) DIL SECICI BURADAN KALDIRILDI — sag uste tasindi.
            Iki yerde birden durmasi, "hangisi gecerli?" sorusunu ureten
            bir tekrardir. Tema anahtari burada KALIR: o bir gorunum
            tercihi ve kenar cubugunun dibi onun icin dogru yer. */}
        {/* DAR MODDA TEMA ANAHTARI GIZLENIR: bileseni 68px'e sigdirmak
            onu yeniden yazmak demekti ve tema tercihi gunluk bir islem
            degil — kullanici menuyu genisletip degistirir. Gizlenen sey
            bir YOL degil, bir kisayol. Dar modda cikis TEK BASINA ve tam
            genislikte kalir. */}
        <div className={dar ? undefined : "grid grid-cols-1 sm:grid-cols-2 gap-2"}>
          {!dar && <ThemeToggle />}
          <button
            onClick={logout}
            // ERISILEBILIR AD HER ZAMAN TAM CUMLE: gorunen etiket "Cikis"a
            // kisaldi ama ekran okuyucu kullanicisi icin "Cikis yap" daha
            // az belirsiz (bir SAYFA adi degil, bir EYLEM oldugu belli).
            aria-label={t("kabukCikisYap")}
            title={t("kabukCikisYap")}
            className="odak-ic w-full border px-3 py-2 text-center transition"
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
            {/* (P167 §1.8) KISA ETIKET: "Cikis yap" iki kolonluk satirda
                tasiyordu. Anlam kaybi yok — ikon ve konum zaten soyluyor;
                erisilebilir ad ise `aria-label` ile TAM cumle kalir. */}
            <span className={dar ? "sr-only" : undefined}>{t("kabukCikis")}</span>
            {dar && <CikisIkonu />}
          </button>
        </div>
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
  /** Cekmece govdesi — odak tuzagi bu agacin icinde calisir. */
  const cekmeceRef = useRef<HTMLElement | null>(null);
  const pathname = usePathname();
  const t = useT();

  // (P160) KENAR CUBUGU DAR MI — kalici tercih.
  //
  // AYRI ANAHTAR, `SidebarBody`nin menu durumuyla BIRLESTIRILMEDI: o kayit
  // (`yonetio.menu.durum`) SidebarBody'ye ait ve onu yaziyor; bu deger ise
  // KABUGA ait (genislik, icerik boslugu). Tek kaydi iki bilesenin
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

  // ====================================================================
  // (P169 §2.1) CEKMECE: ESC · ODAK TUZAGI · KAYDIRMA KILIDI
  // ====================================================================
  // Ucu de EKSIKTI ve ucu de dar ekranda gercek sorun:
  //
  //   ESC YOK        — klavye kullanicisi cekmeceyi kapatmak icin fareyle
  //                    ortuye tiklamak zorundaydi.
  //   ODAK TUZAGI YOK— cekmece aciken Tab, ARKADAKI sayfanin
  //                    baglantilarina kaciyordu: ekran okuyucu kullanicisi
  //                    gormedigi bir sayfada geziniyordu.
  //   KAYDIRMA KILIDI YOK — cekmece aciken parmakla kaydirinca ARKADAKI
  //                    sayfa kayiyordu; kullanici cekmeceyi kapatinca
  //                    kendini bambaska bir yerde buluyordu.
  useEffect(() => {
    if (!open) return;

    const cekmece = cekmeceRef.current;
    // ODAK CEKMECEYE TASINIR: acilan bir panelin ilk odaklanabilir ogesi
    // odagi almalidir, yoksa klavye kullanicisi paneli "goremez".
    const odaklanabilir = () => {
      const hepsi = Array.from(
        cekmece?.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])',
        ) ?? [],
      );
      // GORUNURLUK SUZGECI: kapali bir bolumun icindeki baglantilar
      // tab sirasina girmemeli.
      const gorunur = hepsi.filter((e) => e.offsetParent !== null);
      // GERI CEKILME: `offsetParent` yerlesim gerektirir ve yerlesimi
      // olmayan ortamlarda (jsdom, `display:contents` agaci, ilk cizim)
      // HER SEY icin `null` doner. O durumda suzgeci uygulamak, tuzagi
      // BOS birakmak ve odagin arkadaki sayfaya kacmasi demekti — yani
      // tuzagin var olma sebebinin ta kendisi. Hicbir sey gorunmuyorsa
      // hepsini tuzakla: fazladan tuzaklamak, hic tuzaklamamaktan iyidir.
      return gorunur.length > 0 ? gorunur : hepsi;
    };
    odaklanabilir()[0]?.focus();

    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") {
        setOpen(false);
        return;
      }
      if (e.key !== "Tab") return;
      const ogeler = odaklanabilir();
      if (ogeler.length === 0) return;
      const ilk = ogeler[0];
      const son = ogeler[ogeler.length - 1];
      // DONGU: sondan ileri gidince basa, bastan geri gidince sona.
      if (!e.shiftKey && document.activeElement === son) {
        e.preventDefault();
        ilk.focus();
      } else if (e.shiftKey && document.activeElement === ilk) {
        e.preventDefault();
        son.focus();
      } else if (cekmece && !cekmece.contains(document.activeElement)) {
        // Odak disariya kacmissa geri al (ilk Tab'da olabilir).
        e.preventDefault();
        ilk.focus();
      }
    }

    // KAYDIRMA KILIDI: `overflow: hidden` YETMEZ — iOS Safari'de govde
    // yine kayar. `position: fixed` + kaydirma konumunu geri koymak,
    // kapaninca sayfanin BASA ATLAMASINI da engeller.
    const kaydirma = window.scrollY;
    const govde = document.body;
    const eski = {
      overflow: govde.style.overflow,
      position: govde.style.position,
      top: govde.style.top,
      width: govde.style.width,
    };
    govde.style.overflow = "hidden";
    govde.style.position = "fixed";
    govde.style.top = `-${kaydirma}px`;
    govde.style.width = "100%";

    document.addEventListener("keydown", tus);
    return () => {
      document.removeEventListener("keydown", tus);
      govde.style.overflow = eski.overflow;
      govde.style.position = eski.position;
      govde.style.top = eski.top;
      govde.style.width = eski.width;
      window.scrollTo(0, kaydirma);
    };
  }, [open]);

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
        {/* (P166 §8.1) KURULUM HATIRLATICISI — kabugun KOKUNDE, cunku ilk
            acilis hangi sayfa olursa olsun karsilamali. Kurulum bittiyse,
            kullanici kapattiysa ya da rol yetkisiz ise hicbir sey cizmez
            ve istek de ATMAZ. */}
        <KurulumHatirlatici rol={rol} />
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
          <YonetioLogo size={30} />
          {/* (P140.4) Dil secici SAG UST — eskiden burada yalnizca hizalama
              icin bos bir `span` duruyordu.
              (P160) Bildirim merkezi mobilde de gorunur: okunmamis sayisi
              masaustune ozel bir bilgi degil. */}
          {/* (P167 §1.7) Kullanici menusu MOBILDE DE var: profil satiri sol
              menuden kalktigi icin cekmecede karsiligi yok — buraya
              koymasaydik mobil kullanicinin hesabina hicbir yol kalmazdi. */}
          <div className="flex items-center gap-2">
            <BildirimMerkezi />
            <DilSecici />
            <KullaniciMenusu />
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
          ref={cekmeceRef}
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
            {/* (P167 §1.7) SIRA: bildirim · dil · HESAP. Hesap menusu EN
                SAGDA cunku kullanicinin kendi kaydi konvansiyon geregi
                kosede aranir; dil secici brief'in dedigi gibi onun
                solunda kalir. */}
            <div className="flex shrink-0 items-center gap-2">
              {/* (P168 §1.3) SAYFA EYLEMLERI — bildirim ikonunun SOLUNDA.
                  Kabuk yalniz BOS BIR YUVA acar; ne gelecegini bilmez. */}
              <SayfaEylemYuvasi />
              <BildirimMerkezi />
              <DilSecici />
              <KullaniciMenusu />
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
