"use client";

import { useState } from "react";
import useSWR, { mutate as globalMutate } from "swr";

import {
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
} from "@/components/ui";
import { BILDIRIM_SAYAC_UC } from "@/components/ui/bildirim-merkezi";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { BILDIRIM_TIP, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AppNotification, NotificationList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type OkunduFiltre = "" | "true" | "false";
const LIMIT = 20;

// (P53) Harita `lib/enum-adlari.ts`e tasindi: AYNI tip panoda da rozet
// olarak ciziliyor ve iki kopya, birinin guncellenip digerinin unutulmasi
// demekti — P51'de tam olarak bu olmustu.

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_TEHLIKE = "tehlike" as const;

export default function NotificationsPage() {
  const t = useT();
  const toast = useToast();
  const [okundu, setOkundu] = useState<OkunduFiltre>("");
  const [offset, setOffset] = useState(0);
  // (P181 Bölüm 6.5) TOPLU İŞLEM seçimi — sayfa içindeki id'ler.
  const [secili, setSecili] = useState<Set<string>>(new Set());
  const [topluCalisiyor, setTopluCalisiyor] = useState(false);

  const key = `/api/notifications?limit=${LIMIT}&offset=${offset}${
    okundu ? `&okundu=${okundu}` : ""
  }`;
  const { data, error, isLoading, mutate } = useSWR<NotificationList>(key, jsonFetcher);

  // HAM `fetch` DEGIL `apiSend`: ham fetch basarisiz yanitta da cozulur,
  // yani 401/500 sonrasi "okundu olarak isaretlendi" BASARI bildirimi
  // cikiyordu — kullanici isaretledigini saniyor, bildirim okunmamis
  // kaliyordu. apiSend hata govdesini APIError mesajina cevirir.
  async function markRead(id: string) {
    try {
      await apiSend(`/api/notifications/${id}`, "PATCH", { okundu: true });
      // (P190 §4) ROZET DE TAZELENIR: ust bardaki sayac ayri bir SWR
      // anahtari kullanir; yalniz `mutate()` cagirmak rozeti 60 sn'lik
      // poll'a kadar bayat birakiyordu.
      void globalMutate(BILDIRIM_SAYAC_UC);
      mutate();
      toast.success(t("bildirimOkunduIsaretlendi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    }
  }

  function setFilter(v: OkunduFiltre) {
    setOkundu(v);
    setOffset(0);
    setSecili(new Set());
  }

  const items = data?.items ?? [];
  const total = data?.meta?.total ?? 0;
  const tumuSecili = items.length > 0 && items.every((n) => secili.has(n.id));

  function tekiliDegistir(id: string) {
    setSecili((onceki) => {
      const yeni = new Set(onceki);
      if (yeni.has(id)) yeni.delete(id);
      else yeni.add(id);
      return yeni;
    });
  }

  function tumunuDegistir() {
    setSecili(tumuSecili ? new Set() : new Set(items.map((n) => n.id)));
  }

  // Ortak toplu-işlem sarmalı: çağır, seçimi temizle, listeyi tazele.
  async function topluCalistir(
    url: string,
    govde: unknown,
    basariAnahtari: SozlukAnahtari,
  ) {
    setTopluCalisiyor(true);
    try {
      await apiSend(url, "POST", govde);
      setSecili(new Set());
      // (P190 §4) Toplu okundu / toplu sil / tumunu okundu — HEPSINDE rozet
      // aninda tazelenir (markRead'deki gerekce).
      void globalMutate(BILDIRIM_SAYAC_UC);
      await mutate();
      toast.success(t(basariAnahtari));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setTopluCalisiyor(false);
    }
  }

  const seciliListe = () => Array.from(secili);

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukBildirimler")}
      </h1>

      {/* SARILABILIR: uc filtre dugmesi 360 dp + buyuk kok yazi boyunda tek
          satira sigmiyordu (tur 28 surusu: tr +9 px, ru +79 px). Sekme
          degil dugme oldugu icin sarmak dogru cozum — kaydirma gerekmez. */}
      <div className="flex flex-wrap items-center gap-2">
        {([
          ["", t("ortakTumu")],
          ["false", t("bildirimOkunmamis")],
          ["true", t("bildirimOkunmus")],
        ] as [OkunduFiltre, string][]).map(([v, label]) => (
          // (P160) `aria-pressed` EKLENDI: eskiden secili suzgec YALNIZ
          // RENKLE anlatiliyordu ve ekran okuyucu hangisinin acik
          // oldugunu SOYLEYEMIYORDU. Secililik artik hem kabartmayla
          // (gorsel) hem `aria-pressed` ile (isitsel) belli.
          <Dugme
            key={label}
            boy="kucuk"
            tur={okundu === v ? TUR_BIRINCIL : TUR_IKINCIL}
            aria-pressed={okundu === v}
            onClick={() => setFilter(v)}
          >
            {label}
          </Dugme>
        ))}
      </div>

      {/* (P181 Bölüm 6.5) TOPLU İŞLEM ŞERİDİ: tümünü seç + seçilenlere okundu/sil + tümünü okundu. */}
      {total > 0 && (
        <div className="flex flex-wrap items-center gap-2">
          <label
            className="flex cursor-pointer select-none items-center gap-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            <input
              type="checkbox"
              checked={tumuSecili}
              onChange={tumunuDegistir}
              className="h-4 w-4 rounded"
              style={{ accentColor: "var(--yz-accent)" }}
              aria-label={t("bildirimTumunuSec")}
            />
            {t("bildirimTumunuSec")}
          </label>
          {secili.size > 0 && (
            <>
              <span
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {secili.size} {t("bildirimSecili")}
              </span>
              <Dugme
                boy="kucuk"
                disabled={topluCalisiyor}
                onClick={() =>
                  void topluCalistir(
                    "/api/notifications/toplu-okundu",
                    { ids: seciliListe(), okundu: true },
                    "bildirimOkunduIsaretlendi",
                  )
                }
              >
                {t("bildirimSeciliOkundu")}
              </Dugme>
              <Dugme
                boy="kucuk"
                tur={TUR_TEHLIKE}
                disabled={topluCalisiyor}
                onClick={() =>
                  void topluCalistir(
                    "/api/notifications/toplu-sil",
                    { ids: seciliListe() },
                    "bildirimSilindi",
                  )
                }
              >
                {t("bildirimSeciliSil")}
              </Dugme>
            </>
          )}
          <Dugme
            boy="kucuk"
            tur={TUR_IKINCIL}
            disabled={topluCalisiyor}
            onClick={() =>
              void topluCalistir(
                "/api/notifications/tumunu-okundu",
                {},
                "bildirimOkunduIsaretlendi",
              )
            }
          >
            {t("bildirimTumunuOkundu")}
          </Dugme>
        </div>
      )}

      {/* HATA VARSA LISTE HIC CIZILMEZ. Bunu ayri bir dal yapmak sart:
          uc dustugunde `data` undefined kaliyor ve liste dali "0 kayit"
          gorup BOS DURUM ciziyordu — yani "bildirim yok" diyordu, oysa
          bilinen tek sey bildirimlerin OKUNAMADIGI. Kullanici bekledigi
          uyariyi gormedigi icin her sey yolunda saniyordu. */}
      {error ? (
        <HataDurumu mesaj={error.message} onTekrar={() => void mutate()} />
      ) : /* LISTE, TABLO DEGIL — ve bu bilincli: bildirim bir CUMLEDIR,
             sutunlara bolunecek alanlari yok. `VeriTablosu` burada yapiyi
             zorlardi. */
      isLoading && !data ? (
        <Kart>
          <IskeletMetin satir={5} />
        </Kart>
      ) : items.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("bildirimYok")} />
        </Kart>
      ) : (
        <ul className="space-y-2">
          {items.map((n: AppNotification) => (
            <li key={n.id}>
              <Kart className="flex flex-wrap items-start gap-3">
                <input
                  type="checkbox"
                  checked={secili.has(n.id)}
                  onChange={() => tekiliDegistir(n.id)}
                  className="mt-1 h-4 w-4 rounded"
                  style={{ accentColor: "var(--yz-accent)" }}
                  aria-label={t("bildirimSec")}
                />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span
                      style={{
                        fontSize: "var(--yz-fs-xs)",
                        color: "var(--yz-text-2)",
                      }}
                    >
                      {enumAdi(t, BILDIRIM_TIP, n.tip)}
                    </span>
                    {!n.okundu && (
                      <Rozet durum="bilgi" nokta>
                        {t("bildirimYeniRozet")}
                      </Rozet>
                    )}
                  </div>
                  <p
                    className="mt-0.5"
                    style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
                  >
                    {n.mesaj}
                  </p>
                  <span
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    {formatDateTime(n.created_at)}
                  </span>
                </div>
                {!n.okundu && (
                  <Dugme boy="kucuk" onClick={() => void markRead(n.id)}>
                    {t("bildirimOkunduIsaretle")}
                  </Dugme>
                )}
              </Kart>
            </li>
          ))}
        </ul>
      )}

      {/* SAYFALAMA: `VeriTablosu` kullanilmadigi icin (liste, tablo
          degil) serit burada elle ciziliyor — ama dugmeler ve toplam
          ayni ilkelden. */}
      {total > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("ortakToplam")}: {total} · {offset + 1}-
            {Math.min(offset + LIMIT, total)}
          </span>
          <div className="flex gap-2">
            <Dugme
              boy="kucuk"
              disabled={offset === 0}
              onClick={() => setOffset(Math.max(0, offset - LIMIT))}
              aria-label={t("listeOncekiSayfa")}
            >
              {t("ortakOnceki")}
            </Dugme>
            <Dugme
              boy="kucuk"
              disabled={offset + LIMIT >= total}
              onClick={() => setOffset(offset + LIMIT)}
              aria-label={t("listeSonrakiSayfa")}
            >
              {t("ortakSonraki")}
            </Dugme>
          </div>
        </div>
      )}
    </div>
  );
}
