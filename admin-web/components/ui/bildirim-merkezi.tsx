"use client";

/**
 * (P160 / Asama 2) BILDIRIM MERKEZI — okunmamis sayaci + acilir liste +
 * okundu isaretleme.
 *
 * =========================================================================
 * SAYAC NEREDEN GELIYOR — YENI UC ACILMADI
 * =========================================================================
 * `/api/notifications?okundu=false&limit=1` cagrilir ve `meta.total`
 * okunur. Uc ZATEN bu suzgeci ve toplami donduruyor (bkz. bildirimler
 * sayfasi); yalnizca sayac icin ayri bir uc acmak, arka uce dokunmak
 * demekti — kilitli kural 1 buna kapali.
 *
 * `limit=1`: sayac icin 20 kayit cekmenin anlami yok. Liste ACILINCA
 * gercek sayfa ayrica cekilir.
 *
 * =========================================================================
 * TAZELEME — yoklama (polling) DEGIL
 * =========================================================================
 * SWR'nin `refreshInterval`i ile 60 saniyede bir tazelenir. Daha sik
 * yoklamak, 30+ kullanicinin acik sekmesinden dakikada yuzlerce istek
 * demekti ve bildirim GERCEK ZAMANLI olmak zorunda degil — kritik
 * uyarilar push ile gidiyor (`push.py`).
 *
 * `revalidateOnFocus`: kullanici sekmeye donunce taze sayi gorur; en cok
 * ise yarayan an tam olarak odur.
 *
 * =========================================================================
 * OKUNDU ISARETLEME — IYIMSER DEGIL
 * =========================================================================
 * Once istek atilir, SONRA liste tazelenir. Iyimser guncelleme
 * (`mutate` ile onceden dusurme) burada yanlis olurdu: istek 401/500 ile
 * duserse kullanici bildirimi "okunmus" sanip bir daha bakmazdi.
 * Bildirimler sayfasi da ayni karari veriyor (P53 notu).
 */
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import useSWR from "swr";

import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { NotificationList } from "@/lib/types";

import { Dugme } from "./dugme";

const SAYAC_UC = "/api/notifications?okundu=false&limit=1&offset=0";
const LISTE_UC = "/api/notifications?okundu=false&limit=8&offset=0";
const TUM_ROTA = "/notifications";
const TAZELEME_MS = 60_000;
/** 99'dan sonrasi rozete sigmaz ve sayinin kendisi bilgi tasimaz olur. */
const AZAMI_ROZET = 99;

export function BildirimMerkezi() {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const kutuRef = useRef<HTMLDivElement | null>(null);

  const { data: sayacVeri, mutate: sayacTazele } = useSWR<NotificationList>(
    SAYAC_UC,
    jsonFetcher,
    { refreshInterval: TAZELEME_MS, revalidateOnFocus: true },
  );
  // LISTE YALNIZ ACIKKEN CEKILIR: kapaliyken sekiz kaydi tutmak, hicbir
  // zaman gorulmeyecek veriyi her dakika tazelemek olurdu.
  const { data: listeVeri, mutate: listeTazele } = useSWR<NotificationList>(
    acik ? LISTE_UC : null,
    jsonFetcher,
  );

  // `meta?.` — SAVUNMACI: uc bir hata zarfi dondugunde (401/500) govde
  // `{error:...}` olur ve `meta` BULUNMAZ. Zincirlemeden okumak, ust
  // barin komple cizilememesine yol aciyordu (baska testler yakaladi).
  const okunmamis = sayacVeri?.meta?.total ?? 0;

  // DISARI TIKLAYINCA KAPAN — acik kalan bir panel, kullanici baska ise
  // gectiginde ekranin ustunde asili kalirdi.
  useEffect(() => {
    if (!acik) return;
    function tik(e: MouseEvent) {
      if (!kutuRef.current?.contains(e.target as Node)) setAcik(false);
    }
    function tus(e: KeyboardEvent) {
      if (e.key === "Escape") setAcik(false);
    }
    document.addEventListener("mousedown", tik);
    document.addEventListener("keydown", tus);
    return () => {
      document.removeEventListener("mousedown", tik);
      document.removeEventListener("keydown", tus);
    };
  }, [acik]);

  async function okunduIsaretle(id: string) {
    try {
      await apiSend(`/api/notifications/${id}`, "PATCH", { okundu: true });
    } catch {
      // SESSIZ DEGIL: tazeleme yapilmaz, yani satir LISTEDE KALIR ve
      // kullanici isin bitmedigini gorur. Sahte bir basari bildirimi
      // gostermek, bildirimi kaybettirirdi.
      return;
    }
    await Promise.all([sayacTazele(), listeTazele()]);
  }

  return (
    <div ref={kutuRef} className="relative">
      <button
        type="button"
        onClick={() => setAcik((o) => !o)}
        aria-expanded={acik}
        aria-label={
          okunmamis > 0
            ? t("bildirimMerkeziSayac", { n: String(okunmamis) })
            : t("bildirimMerkezi")
        }
        className="odak-ic relative flex h-10 w-10 items-center justify-center border"
        style={{
          borderRadius: "var(--yz-radius-btn)",
          borderColor: "var(--yz-border)",
          borderWidth: "var(--yz-border-w)",
          background: "var(--yz-metal-1)",
          boxShadow: "var(--yz-raised)",
          color: "var(--yz-text-2)",
        }}
      >
        <ZilIkonu />
        {okunmamis > 0 && (
          // ROZET `aria-hidden`: sayi zaten dugmenin erisilebilir adinda
          // ("3 okunmamis bildirim"). Iki kez okutmak gurultu olurdu.
          <span
            aria-hidden="true"
            className="absolute -end-1 -top-1 flex h-5 min-w-[20px] items-center justify-center px-1"
            style={{
              borderRadius: "var(--yz-radius-chip)",
              background: "var(--yz-danger-fill)",
              color: "var(--yz-on-fill)",
              fontSize: "var(--yz-fs-xs)",
              fontVariantNumeric: "tabular-nums",
            }}
          >
            {okunmamis > AZAMI_ROZET ? `${AZAMI_ROZET}+` : okunmamis}
          </span>
        )}
      </button>

      {acik && (
        <div
          role="region"
          aria-label={t("bildirimMerkezi")}
          className="absolute end-0 mt-2 w-80 max-w-[90vw] overflow-hidden"
          style={{
            zIndex: "var(--yz-z-dropdown)" as unknown as number,
            borderRadius: "var(--yz-radius-card)",
            background: "var(--yz-metal-1)",
            borderWidth: "var(--yz-border-w)",
            borderStyle: "solid",
            borderColor: "var(--yz-border)",
            boxShadow: "var(--yz-raised-hover)",
          }}
        >
          <div
            className="border-b px-3 py-2"
            style={{
              borderColor: "var(--yz-border)",
              borderBottomWidth: "var(--yz-border-w)",
            }}
          >
            <p style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
              {t("bildirimMerkezi")}
            </p>
          </div>

          <div className="max-h-80 overflow-y-auto">
            {(listeVeri?.items.length ?? 0) === 0 ? (
              <p
                className="px-3 py-6 text-center"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {t("bildirimMerkeziBos")}
              </p>
            ) : (
              listeVeri?.items.map((n) => (
                <div
                  key={n.id}
                  className="flex items-start gap-2 border-b px-3 py-2 last:border-b-0"
                  style={{
                    borderColor: "var(--yz-border)",
                    borderBottomWidth: "var(--yz-border-w)",
                  }}
                >
                  <div className="min-w-0 flex-1">
                    <p
                      style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                    >
                      {n.mesaj}
                    </p>
                    <p
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                    >
                      {formatDateTime(n.created_at)}
                    </p>
                  </div>
                  <Dugme
                    tur="sessiz"
                    boy="kucuk"
                    onClick={() => void okunduIsaretle(n.id)}
                    aria-label={t("bildirimOkunduIsaretle")}
                    className="!px-2"
                  >
                    <OnayIkonu />
                  </Dugme>
                </div>
              ))
            )}
          </div>

          <div
            className="border-t p-2"
            style={{
              borderColor: "var(--yz-border)",
              borderTopWidth: "var(--yz-border-w)",
            }}
          >
            <Link
              href={TUM_ROTA}
              onClick={() => setAcik(false)}
              className="odak-ic block px-2 py-1.5 text-center"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
            >
              {t("bildirimTumunuGor")}
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}

function ZilIkonu() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-5 w-5"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M18 8a6 6 0 1 0-12 0c0 6-3 7-3 7h18s-3-1-3-7" />
      <path d="M13.7 20a2 2 0 0 1-3.4 0" />
    </svg>
  );
}

function OnayIkonu() {
  return (
    <svg
      viewBox="0 0 24 24"
      className="h-4 w-4"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M4 12.5l5 5L20 7" />
    </svg>
  );
}
