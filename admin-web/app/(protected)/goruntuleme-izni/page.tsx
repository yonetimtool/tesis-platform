"use client";

/**
 * (P251 §8) GORUNTULEME IZNI — web'e eklendi (mobilde vardi).
 *
 * KVKK: yonetim bir dairenin ziyaretci ve kargo kayitlarini VARSAYILAN
 * GOREMEZ. Sakinden TEK SEFERLIK izin ister; sakin onaylarsa yonetici o
 * dairenin kayitlarini BIR KEZ gorur (ilk okuma izni tuketir — sunucu
 * `try_consume_unit_permission`). Toplu istek her dairenin kendi sakin
 * onayina baglidir; hicbir onayi atlamaz.
 *
 * Sakinin onay/ret karari mobilde kalir: anlik bildirimden acilir.
 *
 * TEK OKUMA = TEK SECIM: ziyaretci ve kargo ayni izinle okunur ve izin
 * ilk okumada biter. Bu yuzden onayli dairede kullanici HANGISINI
 * gorecegini secer (mobil ekranla ayni kural) ve secmeden once uyarilir.
 */
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  AlanSarmal,
  Dugme,
  HataDurumu,
  Kart,
  Modal,
  Rozet,
  SayfaBasligi,
  Secim,
  Tablo,
  TabloBasligi,
  Td,
  Th,
  Tr,
  useOnay,
  type RozetDurumu,
} from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

type Talep = {
  id: string;
  unit_id: string;
  unit_no: string | null;
  yonetici_ad: string | null;
  resident_ad: string | null;
  durum: string;
  used: boolean;
  requested_at: string;
};
type Izinli = { request_id: string; unit_id: string; unit_no: string | null; decided_at: string | null };
type Daire = { id: string; no: string; blok?: string | null };
type Kayit = { id: string; baslik: string; ayrinti: string; tarih: string };

const DURUM: Record<string, [SozlukAnahtari, RozetDurumu]> = {
  bekliyor: ["izinDurumBekliyor", "uyari"],
  onaylandi: ["izinDurumOnaylandi", "olumlu"],
  reddedildi: ["izinDurumReddedildi", "kritik"],
};
const ZIYARETCI = "ziyaretci" as const;
const KARGO = "kargo" as const;
type KayitTuru = typeof ZIYARETCI | typeof KARGO;
const KAYIT_BASLIGI: Record<KayitTuru, SozlukAnahtari> = {
  ziyaretci: "izinZiyaretciler",
  kargo: "izinKargolar",
};
const KAYIT_UCU: Record<KayitTuru, string> = { ziyaretci: "/api/visitors", kargo: "/api/kargo" };
const KUCUK = "kucuk" as const;
const BIRINCIL = "birincil" as const;

export default function GoruntulemeIzniPage() {
  const t = useT();
  const toast = useToast();
  const { onayla, diyalog } = useOnay();
  const talepler = useSWR<{ items: Talep[] }>("/api/unit-access-request?limit=200", jsonFetcher);
  const izinli = useSWR<{ items: Izinli[] }>("/api/unit-access-request/granted-units", jsonFetcher);
  const daireler = useSWR<{ items: Daire[] }>("/api/units?limit=200&aktif=true", jsonFetcher);
  const [daire, setDaire] = useState("");
  const [gonderiyor, setGonderiyor] = useState(false);
  const [gorunum, setGorunum] = useState<{ izin: Izinli; tur: KayitTuru; kayitlar: Kayit[] | null; hata: string | null } | null>(null);

  async function yenile() {
    await Promise.all([talepler.mutate(), izinli.mutate()]);
  }

  async function tekDaire() {
    if (!daire) return;
    setGonderiyor(true);
    try {
      await apiSend("/api/unit-access-request", "POST", { unit_id: daire });
      toast.success(t("izinIstekGonderildi"));
      setDaire("");
      await yenile();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakHataOlustu")));
    } finally {
      setGonderiyor(false);
    }
  }

  async function tumDaireler() {
    const evet = await onayla({
      baslik: t("izinTumDaireler"),
      mesaj: t("izinTumDaireUyari"),
      onayMetni: t("izinIstekGonder"),
    });
    if (!evet) return;
    setGonderiyor(true);
    try {
      const r = await apiSend<{ created: number; skipped: number }>("/api/unit-access-request/bulk", "POST");
      toast.success(t("izinTopluGonderildi", { n: r.created, atlanan: r.skipped }));
      await yenile();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakHataOlustu")));
    } finally {
      setGonderiyor(false);
    }
  }

  /** TEK OKUMA: izin burada tukenir (sunucu). Sonra liste tazelenir. */
  async function goster(izin: Izinli, tur: KayitTuru) {
    const evet = await onayla({
      baslik: t(KAYIT_BASLIGI[tur]),
      mesaj: t("izinTekSeferlikUyari"),
      onayMetni: t("izinGoster"),
    });
    if (!evet) return;
    setGorunum({ izin, tur, kayitlar: null, hata: null });
    try {
      const yol = KAYIT_UCU[tur];
      const r = await jsonFetcher<{ items: Record<string, string | null>[] }>(
        `${yol}?unit_id=${izin.unit_id}&limit=200`,
      );
      const kayitlar: Kayit[] = r.items.map((k) =>
        tur === ZIYARETCI
          ? { id: String(k.id), baslik: k.ziyaretci_ad ?? "—", ayrinti: k.notlar ?? "", tarih: String(k.created_at) }
          : { id: String(k.id), baslik: k.firma ?? "—", ayrinti: k.notlar ?? "", tarih: String(k.created_at) },
      );
      setGorunum({ izin, tur, kayitlar, hata: null });
    } catch (e) {
      setGorunum({ izin, tur, kayitlar: [], hata: alanliHataMetni(e, t("izinKullanildiUyari")) });
    } finally {
      await izinli.mutate();
    }
  }

  const izinliler = izinli.data?.items ?? [];
  const liste = talepler.data?.items ?? [];

  return (
    <div className="space-y-6">
      <SayfaBasligi baslik={t("kabukGoruntulemeIzni")} aciklama={t("izinAlt")} />

      <Kart>
        <div className="flex flex-wrap items-end gap-3">
          <AlanSarmal etiket={t("izinDaireSec")}>
            {(b) => (
              <div className="min-w-[12rem]">
                <Secim {...b} value={daire} onChange={(e) => setDaire(e.target.value)}>
                  <option value="">—</option>
                  {(daireler.data?.items ?? []).map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.blok ? `${d.blok} / ${d.no}` : d.no}
                    </option>
                  ))}
                </Secim>
              </div>
            )}
          </AlanSarmal>
          <Dugme tur={BIRINCIL} boy={KUCUK} disabled={!daire || gonderiyor} onClick={() => void tekDaire()}>
            {t("izinIstekGonder")}
          </Dugme>
          <Dugme boy={KUCUK} disabled={gonderiyor} onClick={() => void tumDaireler()}>
            {t("izinTumDaireler")}
          </Dugme>
        </div>
      </Kart>

      <section className="space-y-2">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("izinGoruntulenebilir", { n: izinliler.length })}
        </h2>
        <HataDurumu mesaj={izinli.error ? t("ortakHataOlustu") : null} />
        {izinliler.length === 0 ? (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("izinGoruntulenebilirYok")}</p>
        ) : (
          <ul className="space-y-2">
            {izinliler.map((i) => (
              <li key={i.request_id} data-test={`izinli-${i.unit_id}`}>
                <Kart>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <span style={{ color: "var(--yz-text)" }}>{i.unit_no ?? "—"}</span>
                    <div className="flex gap-2">
                      <Dugme boy={KUCUK} onClick={() => void goster(i, ZIYARETCI)}>{t("izinZiyaretciler")}</Dugme>
                      <Dugme boy={KUCUK} onClick={() => void goster(i, KARGO)}>{t("izinKargolar")}</Dugme>
                    </div>
                  </div>
                </Kart>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="space-y-2">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("izinTalepler")}</h2>
        <HataDurumu mesaj={talepler.error ? t("ortakHataOlustu") : null} />
        {liste.length === 0 ? (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("izinTalepYok")}</p>
        ) : (
          <div className="overflow-x-auto">
            <Tablo>
              <TabloBasligi>
                <Th>{t("tanimAlanDaire")}</Th>
                <Th>{t("ortakDurum")}</Th>
                <Th>{t("izinKarariVeren")}</Th>
                <Th>{t("ortakTarih")}</Th>
              </TabloBasligi>
              <tbody>
                {liste.map((r) => {
                  const d = DURUM[r.durum];
                  return (
                    <Tr key={r.id} data-test={`izin-talep-${r.id}`}>
                      <Td>{r.unit_no ?? "—"}</Td>
                      <Td>
                        {d ? <Rozet durum={d[1]}>{t(d[0])}</Rozet> : r.durum}
                        {r.used ? (
                          <span className="ms-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                            {t("izinKullanildi")}
                          </span>
                        ) : null}
                      </Td>
                      <Td>{r.resident_ad ?? "—"}</Td>
                      <Td className="whitespace-nowrap">{formatDateTime(r.requested_at)}</Td>
                    </Tr>
                  );
                })}
              </tbody>
            </Tablo>
          </div>
        )}
      </section>

      <Modal
        acik={gorunum !== null}
        onKapat={() => setGorunum(null)}
        baslik={
          gorunum
            ? t("izinKayitBasligi", { tur: t(KAYIT_BASLIGI[gorunum.tur]), daire: gorunum.izin.unit_no ?? "" })
            : ""
        }
      >
        {gorunum?.hata ? (
          <HataDurumu mesaj={gorunum.hata} />
        ) : gorunum?.kayitlar === null ? (
          <p>{t("ortakYukleniyor")}</p>
        ) : (gorunum?.kayitlar ?? []).length === 0 ? (
          <p style={{ color: "var(--yz-text-2)" }}>{t("izinKayitYok")}</p>
        ) : (
          <ul className="space-y-2" data-test="izin-kayitlar">
            {(gorunum?.kayitlar ?? []).map((k) => (
              <li key={k.id}>
                <span className="block" style={{ color: "var(--yz-text)" }}>{k.baslik}</span>
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {formatDateTime(k.tarih)}
                  {k.ayrinti ? ` · ${k.ayrinti}` : ""}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Modal>
      {diyalog}
    </div>
  );
}
