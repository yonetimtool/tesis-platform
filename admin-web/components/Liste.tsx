"use client";

import { useMemo, useState, type ReactNode } from "react";

import { BosSatir, Tablo, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useT } from "@/lib/i18n/kullan";

/**
 * (P154 / Asama 6.2) TEK LISTE BILESENI.
 *
 * NEDEN: Apsiyon raporu §29 ve brief ayni bes seyi istiyor — kolon
 * siralama, suzgec, toplu secim, **sayfa basina kayit (10/25/50/100)**,
 * sayfalama. Bunlar bugun HICBIR ekranda yok; her sayfa kendi `<table>`
 * ini kuruyor.
 *
 * NEDEN `tablo.tsx` SILINMEDI: o dosya GORUNUM katmani (hucre dolgusu,
 * ayirici, hizalama) ve dashboard'dan rapora kadar her yerde kullaniliyor.
 * Burasi DAVRANIS katmani ve onun ustune biniyor. Ikisini birlestirmek,
 * tablo cizen ama sayfalamaya ihtiyaci olmayan onlarca yeri bozardi.
 *
 * SIRALAMA/SUZGEC/SAYFALAMA ISTEMCIDE — ve bu bir SINIR, gizlenmiyor:
 * bilesen kendisine verilen diziyi isler. Sunucu tarafi sayfalama gereken
 * yerlerde (`meta.total` donen uclar) `sunucuTarafi` ile kapatilir ve
 * sayfalama denetimleri disariya birakilir. Aksi hâlde bilesen "500
 * kaydin 50'sini" alip "50 kayit var" derdi — sessiz ve yanlis.
 */

export interface Kolon<T> {
  anahtar: string;
  baslik: string;
  /** Hucre cizimi. Verilmezse `deger` duz metin olarak yazilir. */
  ciz?: (satir: T) => ReactNode;
  /** Siralama/suzgec icin ham deger. Verilmezse o kolon siralanamaz. */
  deger?: (satir: T) => string | number | null | undefined;
  hizala?: "start" | "end" | "center";
  /** Kolon suzgeci kutusu cizilsin mi. */
  suzgec?: boolean;
}

export interface ListeProps<T> {
  kolonlar: Kolon<T>[];
  satirlar: T[];
  /** Satir kimligi — secim ve React `key` bunun uzerinden. */
  kimlik: (satir: T) => string;
  /** Satir sonundaki uc nokta menusunun icerigi. */
  eylemler?: (satir: T) => ReactNode;
  /** Toplu secim acik mi; secilenler yukari bildirilir. */
  secim?: { secili: string[]; degisti: (idler: string[]) => void };
  /** Bos durumda gosterilecek anlamli mesaj. */
  bosMesaj?: ReactNode;
  /** Sunucu sayfaliyorsa istemci sayfalamasi KAPANIR (bkz. modul notu). */
  sunucuTarafi?: boolean;
  baslik?: ReactNode;
}

const SAYFA_SECENEKLERI = [10, 25, 50, 100] as const;

export function Liste<T>({
  kolonlar,
  satirlar,
  kimlik,
  eylemler,
  secim,
  bosMesaj,
  sunucuTarafi = false,
  baslik,
}: ListeProps<T>) {
  const t = useT();
  const [sirala, setSirala] = useState<{ anahtar: string; yon: 1 | -1 } | null>(null);
  const [suzgecler, setSuzgecler] = useState<Record<string, string>>({});
  const [sayfa, setSayfa] = useState(0);
  const [sayfaBoyu, setSayfaBoyu] = useState<number>(25);

  const sutunSayisi =
    kolonlar.length + (secim ? 1 : 0) + (eylemler ? 1 : 0);

  const suzulmus = useMemo(() => {
    const aktif = Object.entries(suzgecler).filter(([, v]) => v.trim() !== "");
    if (aktif.length === 0) return satirlar;
    return satirlar.filter((s) =>
      aktif.every(([anahtar, aranan]) => {
        const k = kolonlar.find((c) => c.anahtar === anahtar);
        const d = k?.deger?.(s);
        return String(d ?? "")
          .toLocaleLowerCase("tr")
          .includes(aranan.toLocaleLowerCase("tr"));
      }),
    );
  }, [satirlar, suzgecler, kolonlar]);

  const sirali = useMemo(() => {
    if (!sirala) return suzulmus;
    const k = kolonlar.find((c) => c.anahtar === sirala.anahtar);
    if (!k?.deger) return suzulmus;
    // `localeCompare` TURKCE ile: `i/I` siralamasi varsayilan karsilastirmada
    // yanlis cikiyor ve liste "alfabetik degil" gorunuyor.
    return [...suzulmus].sort((a, b) => {
      const x = k.deger!(a);
      const y = k.deger!(b);
      if (typeof x === "number" && typeof y === "number") return (x - y) * sirala.yon;
      return String(x ?? "").localeCompare(String(y ?? ""), "tr") * sirala.yon;
    });
  }, [suzulmus, sirala, kolonlar]);

  const toplam = sirali.length;
  const gosterilen = sunucuTarafi
    ? sirali
    : sirali.slice(sayfa * sayfaBoyu, sayfa * sayfaBoyu + sayfaBoyu);
  const sonSayfa = Math.max(0, Math.ceil(toplam / sayfaBoyu) - 1);

  // GORUNEN sayfanin tamami secili mi — "tumunu sec" YALNIZ goruneni
  // kapsar. Suzgecten gizlenmis satirlari da secmek, kullanicinin
  // gormedigi kayitlara toplu islem yapmasi olurdu.
  const gorunenIdler = gosterilen.map(kimlik);
  const hepsiSecili =
    gorunenIdler.length > 0 && gorunenIdler.every((i) => secim?.secili.includes(i));

  function siralamayiDegistir(anahtar: string) {
    setSirala((o) =>
      o?.anahtar === anahtar
        ? { anahtar, yon: o.yon === 1 ? -1 : 1 }
        : { anahtar, yon: 1 },
    );
  }

  return (
    <div className="space-y-3">
      {(baslik || secim) && (
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>{baslik}</div>
          {secim && secim.secili.length > 0 && (
            <div className="flex items-center gap-2 text-sm">
              <span>{t("listeSecili", { n: String(secim.secili.length) })}</span>
              <button
                type="button"
                className="text-primary underline"
                onClick={() => secim.degisti([])}
              >
                {t("listeSecimiTemizle")}
              </button>
            </div>
          )}
        </div>
      )}

      <TabloKart>
        <Tablo>
          <thead>
            <tr className="bg-yuzey-divider/40">
              {secim && (
                <Th className="w-10">
                  <input
                    type="checkbox"
                    aria-label={t("listeTumunuSec")}
                    checked={hepsiSecili}
                    onChange={(e) =>
                      secim.degisti(
                        e.target.checked
                          ? Array.from(new Set([...secim.secili, ...gorunenIdler]))
                          : secim.secili.filter((i) => !gorunenIdler.includes(i)),
                      )
                    }
                  />
                </Th>
              )}
              {kolonlar.map((k) => (
                <Th key={k.anahtar} hizala={k.hizala}>
                  {k.deger ? (
                    <button
                      type="button"
                      onClick={() => siralamayiDegistir(k.anahtar)}
                      className="inline-flex items-center gap-1 hover:underline"
                      // ETIKET KOLON ADINI TASIR: iki basligin ayni
                      // "Artan sirala" adini tasimasi, ekran okuyucuda
                      // "hangi kolonu siralayacagim" sorusunu
                      // yanitsiz birakirdi (test de ayirt edemedi).
                      aria-label={`${k.baslik} — ${
                        sirala?.anahtar === k.anahtar && sirala.yon === 1
                          ? t("listeSiralaAzalan")
                          : t("listeSiralaArtan")
                      }`}
                    >
                      {k.baslik}
                      <span aria-hidden="true" className="text-metin-muted">
                        {sirala?.anahtar === k.anahtar ? (sirala.yon === 1 ? "↑" : "↓") : "↕"}
                      </span>
                    </button>
                  ) : (
                    k.baslik
                  )}
                </Th>
              ))}
              {eylemler && <Th className="w-16">{t("listeIslemler")}</Th>}
            </tr>
            {kolonlar.some((k) => k.suzgec) && (
              <tr>
                {secim && <Th />}
                {kolonlar.map((k) => (
                  <Th key={k.anahtar} dolgusuz className="px-2 pb-2">
                    {k.suzgec && (
                      <input
                        aria-label={`${k.baslik} — ${t("listeSuzgec")}`}
                        className="w-full rounded border border-slate-300 bg-yuzey-card px-2 py-1 text-xs"
                        value={suzgecler[k.anahtar] ?? ""}
                        onChange={(e) => {
                          setSayfa(0);
                          setSuzgecler((o) => ({ ...o, [k.anahtar]: e.target.value }));
                        }}
                      />
                    )}
                  </Th>
                ))}
                {eylemler && <Th />}
              </tr>
            )}
          </thead>
          <tbody>
            {gosterilen.length === 0 && (
              <BosSatir sutun={sutunSayisi}>{bosMesaj ?? t("listeKayitYok")}</BosSatir>
            )}
            {gosterilen.map((s) => {
              const id = kimlik(s);
              return (
                <Tr key={id}>
                  {secim && (
                    <Td>
                      <input
                        type="checkbox"
                        aria-label={t("listeSatirSec")}
                        checked={secim.secili.includes(id)}
                        onChange={(e) =>
                          secim.degisti(
                            e.target.checked
                              ? [...secim.secili, id]
                              : secim.secili.filter((i) => i !== id),
                          )
                        }
                      />
                    </Td>
                  )}
                  {kolonlar.map((k) => (
                    <Td key={k.anahtar} hizala={k.hizala}>
                      {k.ciz ? k.ciz(s) : String(k.deger?.(s) ?? "")}
                    </Td>
                  ))}
                  {eylemler && <Td hizala="end">{eylemler(s)}</Td>}
                </Tr>
              );
            })}
          </tbody>
        </Tablo>
      </TabloKart>

      {/* SAYFALAMA — sunucu sayfaliyorsa cizilmez (bkz. modul notu). */}
      {!sunucuTarafi && (
        <div className="flex flex-wrap items-center justify-between gap-3 text-sm">
          <label className="flex items-center gap-2">
            <span className="text-metin-muted">{t("listeSayfaBasina")}</span>
            <select
              className="rounded border border-slate-300 bg-yuzey-card px-2 py-1"
              value={sayfaBoyu}
              onChange={(e) => {
                setSayfaBoyu(Number(e.target.value));
                setSayfa(0);
              }}
            >
              {SAYFA_SECENEKLERI.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>

          <div className="flex items-center gap-3">
            <span className="text-metin-muted">
              {toplam === 0
                ? t("listeToplamKayit", { toplam: "0" })
                : t("listeSayfaBilgisi", {
                    bas: String(sayfa * sayfaBoyu + 1),
                    bit: String(Math.min(toplam, (sayfa + 1) * sayfaBoyu)),
                    toplam: String(toplam),
                  })}
            </span>
            <button
              type="button"
              className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40"
              aria-label={t("listeOncekiSayfa")}
              disabled={sayfa === 0}
              onClick={() => setSayfa((s) => Math.max(0, s - 1))}
            >
              <span aria-hidden="true">‹</span>
            </button>
            <button
              type="button"
              className="rounded border border-slate-300 px-2 py-1 disabled:opacity-40"
              aria-label={t("listeSonrakiSayfa")}
              disabled={sayfa >= sonSayfa}
              onClick={() => setSayfa((s) => Math.min(sonSayfa, s + 1))}
            >
              <span aria-hidden="true">›</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
