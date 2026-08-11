"use client";

/**
 * (P154 / Asama 4) SOSYAL GIRIS DUGMELERI — TEK BILESEN, IKI KULLANIM.
 *
 * Giris ekrani (`GirisFormu`) ve profil sayfasi (`GirisYontemlerim`) AYNI
 * bileseni kullanir. Ikisine ayri dugme kumesi yazmak, saglayici listesi
 * ya da hata davranisi degistiginde birini guncelleyip digerini unutmanin
 * en kolay yoluydu — brief'in "AYNI ISI IKI KEZ YAPMA" kurali.
 *
 * FARK YALNIZ NIYETTE: `niyet="giris"` oturum acar, `niyet="bagla"` acik
 * oturuma yeni bir yontem ekler. Niyet, saglayiciya gidilmeden ONCE
 * `sessionStorage`a yazilir cunku donusteki sayfa (`/giris/oauth`) hangi
 * isi yapacagini bilmek zorunda ve saglayici bize kendi parametremizi
 * geri vermez (`state` sunucunun, bizim degil).
 *
 * SAGLAYICI LISTESI SUNUCUDAN: yapilandirilmamis bir saglayiciyi dugme
 * olarak cizmek, kullaniciyi KESIN BASARISIZ bir yola sokmak olurdu.
 */
import { useEffect, useState } from "react";

import { useT } from "@/lib/i18n/kullan";

export const OAUTH_NIYET = "yonetio.oauth.niyet";

/** Sunucunun tanidigi saglayici kodlari. */
const ETIKET: Record<string, string> = {
  google: "Google",
  microsoft: "Microsoft",
  apple: "Apple",
};

/** Niyete gore dugme metni. UCLU DEGIL SOZLUK: `sabit-metin` taramasi
 *  ucludeki her dizgeyi "cevrilmemis metin" adayi sayar ve HAKLIDIR —
 *  orada gercek bir cumle de durabilirdi. */
const DUGME_ANAHTARI = {
  giris: "sosyalIleDevam",
  bagla: "sosyalYontemEkle",
} as const;

export function niyetiYaz(niyet: "giris" | "bagla") {
  try {
    sessionStorage.setItem(OAUTH_NIYET, niyet);
  } catch {
    // Depolama yoksa donuste varsayilan "giris" uygulanir.
  }
}

export function SosyalGiris({
  niyet,
  yuzey = "web",
}: {
  niyet: "giris" | "bagla";
  yuzey?: "web" | "mobil";
}) {
  const t = useT();
  const [saglayicilar, setSaglayicilar] = useState<string[]>([]);
  const [bekleyen, setBekleyen] = useState<string | null>(null);
  const [hata, setHata] = useState<string | null>(null);

  useEffect(() => {
    let iptal = false;
    void (async () => {
      try {
        const r = await fetch("/api/auth/oauth/saglayicilar");
        if (!r.ok) return;
        const d = (await r.json()) as { saglayicilar?: string[] };
        if (!iptal) setSaglayicilar(d.saglayicilar ?? []);
      } catch {
        // Sessiz: sosyal giris bir EK yoldur. Listeyi alamamak, parola
        // girisini engellememeli (brief: "tikanirsa Asama 3 tek basina
        // calissin").
      }
    })();
    return () => {
      iptal = true;
    };
  }, []);

  async function basla(saglayici: string) {
    setHata(null);
    setBekleyen(saglayici);
    try {
      const r = await fetch(
        `/api/auth/oauth/baslat/${encodeURIComponent(saglayici)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ yuzey }),
        },
      );
      const d = (await r.json().catch(() => null)) as
        | { adres?: string; error?: { message?: string } }
        | null;
      if (!r.ok || !d?.adres) {
        setHata(d?.error?.message ?? t("ortakHataOlustu"));
        setBekleyen(null);
        return;
      }
      niyetiYaz(niyet);
      window.location.href = d.adres;
    } catch {
      setHata(t("ortakSunucuyaUlasilamadi"));
      setBekleyen(null);
    }
  }

  // HIC SAGLAYICI YOKSA HICBIR SEY CIZILMEZ — bos bir "veya" ayraci,
  // olmayan bir secenek varmis izlenimi verirdi.
  if (saglayicilar.length === 0) return null;

  return (
    <div className="space-y-3">
      {niyet === "giris" ? (
        <div className="flex items-center gap-3">
          <span className="h-px flex-1 bg-yuzey-divider" />
          <span className="text-xs text-metin-muted">{t("sosyalVeya")}</span>
          <span className="h-px flex-1 bg-yuzey-divider" />
        </div>
      ) : null}
      <div className="grid gap-2">
        {saglayicilar.map((s) => (
          <button
            key={s}
            type="button"
            disabled={bekleyen !== null}
            onClick={() => void basla(s)}
            // 44px dokunma hedefi (erisilebilirlik kurali).
            className="kart-kenar flex min-h-[44px] w-full items-center justify-center gap-2 rounded-lg border bg-yuzey-card px-4 py-2.5 text-sm font-medium text-metin-body transition hover:bg-yuzey-divider disabled:opacity-60"
          >
            {t(DUGME_ANAHTARI[niyet], { saglayici: ETIKET[s] ?? s })}
          </button>
        ))}
      </div>
      {hata ? <p className="text-sm text-vurguInk-red">{hata}</p> : null}
    </div>
  );
}

export function saglayiciEtiketi(kod: string): string {
  return ETIKET[kod] ?? kod;
}
