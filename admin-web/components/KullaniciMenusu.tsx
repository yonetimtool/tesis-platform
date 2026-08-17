"use client";

// (P167 §1.7) SAG UST KULLANICI MENUSU — avatar + tesis adi + kullanici adi.
//
// NEDEN SOL MENUDEN TASINDI
// -------------------------
// "Profilim" kenar cubugunun dibinde, cikis dugmesinin ustunde duruyordu.
// Iki sorun vardi:
//
//   1. YANLIS LISTE. Sol menu SITEYE ait ekranlarin listesidir (daireler,
//      aidat, gorevler). Kullanicinin KENDI kaydi o listeye ait degil;
//      orada durunca bir "yonetim isi" gibi okunuyordu.
//   2. YANLIS YER. Hesap islemleri (bilgiler, guvenlik, bildirim, parola,
//      cikis) her uygulamada sag ust kosede aranir. Konvansiyona uymayan
//      yer, kullaniciyi menuyu taramaya zorlar.
//
// NEDEN TESIS ADI DA BURADA: ayni tarayicida birden fazla tesise giren
// yonetici var (P155 coklu yonetici). "Hangi sitedeyim?" sorusunun cevabi
// hesabin YANINDA olmali — ikisi birlikte tek bir kimlik kartidir.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import useSWR from "swr";

import { Avatar } from "@/components/Avatar";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { PROFIL_BOLUMLERI, profilBaglantisi } from "@/lib/profil-bolumleri";

type Kimlik = { ad: string; email: string | null; avatar_url: string | null };
type TesisAyari = { ad: string };

export function KullaniciMenusu() {
  const t = useT();
  const router = useRouter();
  const [acik, setAcik] = useState(false);
  const [cikisHatasi, setCikisHatasi] = useState(false);
  const kutu = useRef<HTMLDivElement>(null);

  // IKI AYRI KAYIT, IKI AYRI ISTEK — bilincli: kimlik kullaniciya,
  // tesis adi TESISE aittir ve ikisi farkli hizda degisir. Tek uca
  // birlestirmek, tesis adini her profil tazelemesinde yeniden cekmek
  // (ya da tersi) demekti. SWR ikisini de onbellekler; kabuk her sayfada
  // cizildigi icin gercek istek sayisi oturum basina birer tanedir.
  const { data: kimlik } = useSWR<Kimlik>("/api/me", jsonFetcher);
  const { data: tesis } = useSWR<TesisAyari>("/api/tenant/settings", jsonFetcher);

  useEffect(() => {
    if (!acik) return;
    function disariTikla(e: MouseEvent) {
      if (!kutu.current?.contains(e.target as Node)) setAcik(false);
    }
    // ESC ILE KAPANIR: acilir menuden cikmanin klavyedeki karsiligi budur;
    // olmadan klavye kullanicisi menuyu ancak icindeki bir baglantiya
    // giderek kapatabilirdi.
    function esc(e: KeyboardEvent) {
      if (e.key === "Escape") setAcik(false);
    }
    document.addEventListener("mousedown", disariTikla);
    document.addEventListener("keydown", esc);
    return () => {
      document.removeEventListener("mousedown", disariTikla);
      document.removeEventListener("keydown", esc);
    };
  }, [acik]);

  // CIKIS BASARISIZSA GIRIS EKRANINA GIDILMEZ — kabuktaki (`AppShell`)
  // gerekcenin aynisi: yanit denetlenmeden /login'e gecmek, oturumu ACIK
  // kalmis kullaniciya cikmis gibi gostermek demektir ve ortak bir
  // bilgisayarda bedeli oturumun devridir.
  async function cikis() {
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

  const ad = kimlik?.ad ?? "";
  const tesisAdi = tesis?.ad ?? "";

  return (
    <div className="relative" ref={kutu}>
      <button
        type="button"
        onClick={() => setAcik((a) => !a)}
        aria-haspopup="menu"
        aria-expanded={acik}
        // ERISILEBILIR AD: gorunen metin iki satira bolunmus (tesis + ad)
        // ve dar ekranda gizleniyor. Tek bir acik ad vermezsek ekran
        // okuyucu yalnizca "dugme" derdi.
        aria-label={t("kabukHesabim")}
        className="odak-ic flex items-center gap-2 border px-2 py-1.5 transition"
        style={{
          borderRadius: "var(--yz-radius-btn)",
          borderColor: "var(--yz-border)",
          borderWidth: "var(--yz-border-w)",
          background: "var(--yz-surface-1)",
          color: "var(--yz-text-2)",
        }}
      >
        <Avatar ad={ad} src={kimlik?.avatar_url} boy={28} />
        {/* METIN DAR EKRANDA GIZLENIR, avatar kalir: 360px'te tesis adi +
            kullanici adi ust cubugu tasirdi. Bilgi kaybi yok — ikisi de
            menunun basliginda tekrar yaziyor. */}
        <span className="hidden text-start leading-tight sm:block">
          <span
            className="block max-w-[10rem] truncate"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
          >
            {tesisAdi}
          </span>
          <span
            className="block max-w-[10rem] truncate"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          >
            {ad}
          </span>
        </span>
        <svg
          viewBox="0 0 24 24"
          className={`h-3.5 w-3.5 shrink-0 transition-transform ${acik ? "rotate-180" : ""}`}
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </button>

      {acik && (
        <div
          role="menu"
          aria-label={t("kabukHesabim")}
          // `end-0`: RTL'de de dogru kenara yaslanir (`right-0` Arapcada
          // menuyu ekranin disina iterdi).
          className="absolute end-0 z-50 mt-2 w-64 overflow-hidden border py-1"
          style={{
            borderRadius: "var(--yz-radius-card)",
            borderColor: "var(--yz-border)",
            borderWidth: "var(--yz-border-w)",
            background: "var(--yz-surface-1)",
            boxShadow: "var(--yz-raised-hover)",
          }}
        >
          {/* BASLIK: dar ekranda dugmede gizlenen bilgi burada tam olarak
              gorunur — menuyu acan kullanici hangi hesapta oldugunu her
              durumda okur. */}
          <div
            className="flex items-center gap-3 border-b px-3 pb-3 pt-2"
            style={{ borderColor: "var(--yz-border)" }}
          >
            <Avatar ad={ad} src={kimlik?.avatar_url} boy={40} />
            <span className="min-w-0 leading-tight">
              <span
                className="block truncate"
                style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
              >
                {ad}
              </span>
              <span
                className="block truncate"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
              >
                {kimlik?.email ?? tesisAdi}
              </span>
            </span>
          </div>

          {PROFIL_BOLUMLERI.map((b) => (
            <Link
              key={b.id}
              role="menuitem"
              href={profilBaglantisi(b.id)}
              onClick={() => setAcik(false)}
              className="odak-ic block px-3 py-2 transition-colors hover:bg-[var(--yz-metal-2)]"
              style={{
                fontSize: "var(--yz-fs-sm)",
                // TEHLIKELI EYLEM AYRI RENKTE: "Hesabimi sil" otekilerle
                // ayni gorunurse yanlislikla tiklanan bir satir olur.
                color: b.tehlikeli ? "var(--yz-danger-ink)" : "var(--yz-text-2)",
              }}
            >
              {t(b.anahtar)}
            </Link>
          ))}

          <button
            type="button"
            role="menuitem"
            onClick={() => void cikis()}
            className="odak-ic block w-full border-t px-3 py-2 text-start transition-colors hover:bg-[var(--yz-metal-2)]"
            style={{
              borderColor: "var(--yz-border)",
              fontSize: "var(--yz-fs-sm)",
              color: "var(--yz-text-2)",
            }}
          >
            {t("kabukCikisYap")}
          </button>
          {cikisHatasi && (
            <p role="alert" className="px-3 py-2 text-xs text-accent-red">
              {t("kabukCikisYapilamadi")}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
