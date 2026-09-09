"use client";

import { useCallback, useEffect, useState } from "react";

import { useT } from "@/lib/i18n/kullan";
import { useDukkanAcik } from "@/lib/ozellikler";

/**
 * ==========================================================================
 * (DUKKAN F6) YEREL İŞLETMELER — yöneticinin bölgesindeki esnaf
 * ==========================================================================
 * `/dis-hizmetler` İLE AYRI VE BİLİNÇLİ:
 *   `dis-hizmetler` = yöneticinin ÖZEL defteri (tesise bağlı, elle girer,
 *                     yalnız o tesis görür — kurumsal hafıza)
 *   burası          = KAMU pazar yeri (işletme kendi kaydolur, yorum ve
 *                     doğrulama taşır, herkes görür)
 *
 * İkisini aynı sayfada birleştirmek, yöneticiden kendi defterini almak
 * olurdu (docs/dukkan/00-mimari.md §4).
 *
 * VERİ KİMLİKSİZ UÇTAN: Dukkan arama ucu `security: []`. Yönetici burada
 * Dukkan hesabı AÇMADAN bakabiliyor — hesap açtırmak, sadece "bölgemde
 * kim var" diye bakan yöneticiyi gereksiz bir kayıt akışına sokardı.
 */
type Isletme = {
  ad: string;
  slug: string;
  aciklama: string | null;
  telefon: string;
  whatsapp: string | null;
  dogrulama_seviyesi: number;
  ortalama_puan: number | string | null;
  yorum_sayisi: number;
  kategoriler: string[];
};

type Kategori = { ad: string; slug: string; alt: { ad: string; slug: string }[] };
type Yer = { ad: string; slug: string };

export default function YerelIsletmeler() {
  const t = useT();
  // (P221) AYNI SUNUCU BAYRAGI — mobildeki `dukkanAcikProvider` ile tek
  // kaynak. Menu girisi DURUYOR (bkz. asagidaki gerekce), icerik degisiyor.
  const dukkanAcik = useDukkanAcik();
  const [iller, setIller] = useState<Yer[]>([]);
  const [ilceler, setIlceler] = useState<Yer[]>([]);
  const [kategoriler, setKategoriler] = useState<Kategori[]>([]);
  const [il, setIl] = useState("");
  const [ilce, setIlce] = useState("");
  const [kategori, setKategori] = useState("");
  const [q, setQ] = useState("");
  const [sonuc, setSonuc] = useState<Isletme[] | null>(null);
  const [toplam, setToplam] = useState(0);
  const [hata, setHata] = useState<string | null>(null);
  const [bekle, setBekle] = useState(false);

  useEffect(() => {
    // HER FETCH YANIT DURUMUNU DENETLER: `r.json()`i dogrudan cagirmak,
    // 502 gelen bir yanitin hata govdesini "liste" sanip SESSIZCE bos
    // suzgec cizmek olurdu (`tests/sessiz-fetch.test.ts` bunu yakaladi).
    fetch("/api/dukkan/lokasyon/il")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("il"))))
      .then((d) => setIller(d.items ?? []))
      .catch(() => setIller([]));
    fetch("/api/dukkan/kategori")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("kategori"))))
      .then((d) => setKategoriler(d.items ?? []))
      .catch(() => setKategoriler([]));
  }, []);

  useEffect(() => {
    if (!il) {
      setIlceler([]);
      return;
    }
    fetch(`/api/dukkan/lokasyon/il/${il}/ilce`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("ilce"))))
      .then((d) => setIlceler(d.items ?? []))
      .catch(() => setIlceler([]));
  }, [il]);

  const ara = useCallback(async () => {
    setBekle(true);
    setHata(null);
    try {
      const p = new URLSearchParams();
      if (il) p.set("il", il);
      if (ilce) p.set("ilce", ilce);
      if (kategori) p.set("kategori", kategori);
      if (q) p.set("q", q);
      const r = await fetch(`/api/dukkan/isletme-ara?${p}`);
      if (!r.ok) throw new Error();
      const d = await r.json();
      setSonuc(d.items ?? []);
      setToplam(d.toplam ?? 0);
    } catch {
      // SESSİZ BAŞARISIZLIK YOK: boş liste çizip "sonuç yok" demek,
      // servis çökmüşken yöneticiye YANLIŞ bilgi vermek olurdu.
      setHata(t("dukkanAramaBasarisiz"));
      setSonuc(null);
    } finally {
      setBekle(false);
    }
  }, [il, ilce, kategori, q, t]);

  if (!dukkanAcik) {
    // MENU GIRISI KALDIRILMIYOR, ICERIK DEGISIYOR: girisi gizlemek
    // yoneticiye ozelligin var oldugunu hic anlatmazdi; bos bir pazar
    // yeri gostermek ise kotu izlenim birakirdi. Ucuncu yol: yer tutucu.
    // TARIH TAAHHUDU YOK — kacirilan bir tarih guvensizlik yaratir.
    return (
      <div className="space-y-6">
        <div>
          <h1 className="text-xl font-semibold">{t("dukkanYerelIsletmeler")}</h1>
        </div>
        <div className="rounded border border-[--yz-border] p-8 text-center">
          <p className="text-base font-medium">{t("dukkanYakindaBaslik")}</p>
          <p className="mt-2 text-sm text-[--yz-text-2]">
            {t("dukkanYakindaMetin")}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">{t("dukkanYerelIsletmeler")}</h1>
        <p className="mt-1 text-sm text-[--yz-metin-soluk]">
          {t("dukkanYerelIsletmelerAciklama")}
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <select
          aria-label={t("dukkanIl")}
          value={il}
          onChange={(e) => {
            setIl(e.target.value);
            setIlce("");
          }}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">{t("dukkanTumIller")}</option>
          {iller.map((x) => (
            <option key={x.slug} value={x.slug}>
              {x.ad}
            </option>
          ))}
        </select>
        <select
          aria-label={t("dukkanIlce")}
          value={ilce}
          onChange={(e) => setIlce(e.target.value)}
          disabled={!il}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">{t("dukkanTumIlceler")}</option>
          {ilceler.map((x) => (
            <option key={x.slug} value={x.slug}>
              {x.ad}
            </option>
          ))}
        </select>
        <select
          aria-label={t("dukkanHizmet")}
          value={kategori}
          onChange={(e) => setKategori(e.target.value)}
          className="rounded border px-3 py-2 text-sm"
        >
          <option value="">{t("dukkanTumHizmetler")}</option>
          {kategoriler.map((k) => (
            <optgroup key={k.slug} label={k.ad}>
              {k.alt.map((a) => (
                <option key={a.slug} value={a.slug}>
                  {a.ad}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
        <div className="flex gap-2">
          <input
            aria-label={t("dukkanAra")}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") ara();
            }}
            placeholder={t("dukkanAra")}
            className="min-w-0 flex-1 rounded border px-3 py-2 text-sm"
          />
          <button
            onClick={ara}
            disabled={bekle}
            className="rounded bg-[--yz-birincil] px-4 py-2 text-sm text-white disabled:opacity-60"
          >
            {t("dukkanAraDugme")}
          </button>
        </div>
      </div>

      {hata && (
        <p
          role="alert"
          className="rounded bg-red-50 px-3 py-2 text-sm text-red-800 dark:bg-red-950 dark:text-red-200"
        >
          {hata}
        </p>
      )}

      {sonuc !== null && (
        <>
          <p className="text-sm text-[--yz-metin-soluk]">
            {t("dukkanSonucSayisi")}: {toplam}
          </p>
          {sonuc.length === 0 ? (
            <p className="text-sm text-[--yz-metin-soluk]">
              {t("dukkanSonucYok")}
            </p>
          ) : (
            <ul className="space-y-3">
              {sonuc.map((i) => (
                <li key={i.slug} className="rounded border p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h2 className="font-medium">{i.ad}</h2>
                      <p className="mt-1 text-xs text-[--yz-metin-soluk]">
                        {i.kategoriler.slice(0, 4).join(" · ")}
                      </p>
                      <p className="mt-1 text-sm">
                        {i.yorum_sayisi > 0 && i.ortalama_puan !== null
                          ? `★ ${Number(i.ortalama_puan).toFixed(1)} (${i.yorum_sayisi})`
                          : t("dukkanDegerlendirmeYok")}
                        {i.dogrulama_seviyesi >= 2 &&
                          ` · ✔ ${t("dukkanDogrulanmis")}`}
                      </p>
                      {i.aciklama && (
                        <p className="mt-2 line-clamp-2 text-sm text-[--yz-metin-soluk]">
                          {i.aciklama}
                        </p>
                      )}
                    </div>
                    <a
                      href={`tel:${i.telefon}`}
                      className="shrink-0 rounded bg-[--yz-birincil] px-3 py-2 text-sm text-white"
                    >
                      {i.telefon}
                    </a>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </div>
  );
}
