"use client";

import { useState } from "react";
import useSWR from "swr";

import {
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
} from "@/components/ui";
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

export default function NotificationsPage() {
  const t = useT();
  const toast = useToast();
  const [okundu, setOkundu] = useState<OkunduFiltre>("");
  const [offset, setOffset] = useState(0);

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
      mutate();
      toast.success(t("bildirimOkunduIsaretlendi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    }
  }

  function setFilter(v: OkunduFiltre) {
    setOkundu(v);
    setOffset(0);
  }

  const total = data?.meta?.total ?? 0;

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
      ) : (data?.items ?? []).length === 0 ? (
        <Kart>
          <BosDurum baslik={t("bildirimYok")} />
        </Kart>
      ) : (
        <ul className="space-y-2">
          {(data?.items ?? []).map((n: AppNotification) => (
            <li key={n.id}>
              <Kart className="flex flex-wrap items-start justify-between gap-3">
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
