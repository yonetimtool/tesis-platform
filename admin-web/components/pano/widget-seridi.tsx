"use client";

// (P167 §2.1) WIDGET SERIDI — yoneticinin en cok kullandigi alti sekme.
//
// SECILEBILIR KUME MENUDEN GELIR, ayri bir listeden DEGIL.
// Brief'in siniri acik: "Secilebilir kume kullanicinin YETKILI OLDUGU
// sekmelerle sinirli — erisemeyecegi bir sekmeyi widget yapamaz."
// `menuGruplari(yuzey, rol)` zaten tam olarak o kumeyi donuyor. Ikinci bir
// liste yazsaydik, bir sayfanin rol kapisi degistiginde biri guncellenip
// oteki unutulurdu ve widget seridi kullaniciyi 403'e goturen bir dugme
// tasirdi — sessiz, cunku kimse "widget'im calismiyor" demeden once
// tiklamak zorunda.

import Link from "next/link";
import { useState } from "react";

import { Dugme, Kart, Modal } from "@/components/ui";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { WIDGET_SINIRI } from "@/lib/pano-tercihi";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ETIKET_DIV = "div" as const;
const ETIKET_BAG = "a" as const;

export interface WidgetAdayi {
  /** Menu ogesinin baglantisi — kayitta tutulan deger. */
  rota: string;
  etiket: string;
  /** Hangi bolumden geldigi ("Finansal Islemler > Aidat"). */
  bolum: string;
  ikon: React.ReactNode;
  /** (Varsa) sayac rozeti — UYDURULMAZ, yalniz elimizde sayi varsa. */
  rozet?: number;
}

export function WidgetSeridi({
  adaylar,
  secili,
  duzenlemede,
  onDegisti,
}: {
  adaylar: readonly WidgetAdayi[];
  secili: readonly string[];
  duzenlemede: boolean;
  onDegisti: (rotalar: string[]) => void;
}) {
  const t = useT();
  const [secimAcik, setSecimAcik] = useState(false);

  // SIRA KAYITTAN, `adaylar`dan DEGIL: kullanici sirayi kendi belirliyor.
  const gosterilen = secili
    .map((r) => adaylar.find((a) => a.rota === r))
    .filter((a): a is WidgetAdayi => Boolean(a));

  function cevir(rota: string) {
    if (secili.includes(rota)) {
      onDegisti(secili.filter((r) => r !== rota));
      return;
    }
    // SINIR SESSIZCE UYGULANMAZ: dolu listede tiklamak hicbir sey
    // yapmiyor gibi gorunurdu. Kutu `disabled` olur ve altta neden yazar.
    if (secili.length >= WIDGET_SINIRI) return;
    onDegisti([...secili, rota]);
  }

  function tasi(rota: string, yon: -1 | 1) {
    const i = secili.indexOf(rota);
    const j = i + yon;
    if (i < 0 || j < 0 || j >= secili.length) return;
    const yeni = [...secili];
    [yeni[i], yeni[j]] = [yeni[j], yeni[i]];
    onDegisti(yeni);
  }

  return (
    <div className="space-y-2">
      {duzenlemede && (
        <div className="flex flex-wrap items-center gap-2">
          <Dugme tur="ikincil" boy="kucuk" onClick={() => setSecimAcik(true)}>
            {t("panoKisayolSec")}
          </Dugme>
          <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
            {t("panoKisayolSiniri", { n: WIDGET_SINIRI })}
          </span>
        </div>
      )}

      {gosterilen.length === 0 ? (
        <Kart className="p-kart">
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("panoKisayolYok")}
          </p>
        </Kart>
      ) : (
        // TAM GENISLIK, ESIT PAY: brief "sayfanin solundan sagina uzanan
        // tam genislikte" diyor. `grid-cols-2` -> `sm:grid-cols-3` ->
        // `lg:grid-cols-6`: dar ekranda alti kutu 60 px'e dusup okunmaz
        // olurdu.
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {gosterilen.map((w) => (
            <div key={w.rota} className="relative">
              <Kart
                as={duzenlemede ? ETIKET_DIV : ETIKET_BAG}
                {...(duzenlemede ? {} : { href: w.rota })}
                className="flex h-full flex-col items-center gap-2 p-kart text-center"
              >
                <span style={{ color: "var(--yz-accent-edge)" }}>{w.ikon}</span>
                <span
                  className="line-clamp-2"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                >
                  {w.etiket}
                </span>
                {/* ROZET YALNIZ SAYI VARSA. Sifir da CIZILMEZ: "0" bir
                    bilgi degil gurultudur ve rozetin varligi "bakilacak
                    bir sey var" demektir. */}
                {typeof w.rozet === "number" && w.rozet > 0 && (
                  <span
                    className="absolute end-2 top-2 min-w-5 rounded-full px-1.5 text-center"
                    style={{
                      fontSize: "var(--yz-fs-xs)",
                      background: "var(--yz-danger-edge)",
                      color: "#fff",
                    }}
                  >
                    {w.rozet}
                  </span>
                )}
              </Kart>
              {duzenlemede && (
                <div className="mt-1 flex justify-center gap-1">
                  <button
                    type="button"
                    onClick={() => tasi(w.rota, -1)}
                    aria-label={t("panoYukariTasi")}
                    className="odak-ic rounded px-2"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    ‹
                  </button>
                  <button
                    type="button"
                    onClick={() => cevir(w.rota)}
                    aria-label={t("panoBolumGizle")}
                    className="odak-ic rounded px-2"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger-ink)" }}
                  >
                    ×
                  </button>
                  <button
                    type="button"
                    onClick={() => tasi(w.rota, 1)}
                    aria-label={t("panoAsagiTasi")}
                    className="odak-ic rounded px-2"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    ›
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      <Modal
        acik={secimAcik}
        baslik={t("panoKisayolSec")}
        onKapat={() => setSecimAcik(false)}
      >
        <div className="max-h-[60vh] space-y-1 overflow-y-auto">
          {adaylar.map((a) => {
            const isaretli = secili.includes(a.rota);
            const dolu = !isaretli && secili.length >= WIDGET_SINIRI;
            return (
              <label
                key={a.rota}
                className="flex items-center gap-3 py-1"
                style={{ opacity: dolu ? 0.5 : 1 }}
              >
                <input
                  type="checkbox"
                  checked={isaretli}
                  disabled={dolu}
                  onChange={() => cevir(a.rota)}
                />
                <span className="min-w-0">
                  <span
                    className="block truncate"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  >
                    {a.etiket}
                  </span>
                  {/* BOLUM ADI DA YAZILIR: iki bolumde ayni adi tasiyan
                      sayfalar var (orn. "Raporlar"); yalniz etiket
                      gosterseydik kullanici hangisini sectigini bilemezdi. */}
                  <span
                    className="block truncate"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    {a.bolum}
                  </span>
                </span>
              </label>
            );
          })}
        </div>
      </Modal>
    </div>
  );
}

/** Yalniz tur kontrolu — etiket anahtarlari sozlukten cozuluyor. */
export type WidgetEtiketAnahtari = SozlukAnahtari;
