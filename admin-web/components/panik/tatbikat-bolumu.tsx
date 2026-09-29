"use client";

/**
 * (P249 §2) TATBIKATLAR — planla, baslat, bitir, raporla, PDF indir.
 *
 * Tatbikat GERCEK alarm yolundan gider (ayni bildirim, ayni tam ekran,
 * ayni "Guvendeyim"); her yerde basligin onunde "TATBIKAT" yazar.
 * Planlama YALNIZ yonetimde — sunucu da zorlar; guvenlik raporu okur.
 *
 * ZAMAN: `<input type="datetime-local">` YEREL saat verir, sunucu saat
 * dilimli ISO bekler (dilimsiz zamani REDDEDER). Donusum burada, tek yerde.
 */
import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  Kart,
  Modal,
  Rozet,
  Secim,
  Tablo,
  TabloBasligi,
  Td,
  Th,
  Tr,
} from "@/components/ui";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { SINIR } from "@/lib/girdi-siniri";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type { BlockList } from "@/lib/types";

import { PanikDurumPaneli } from "./panik-durum";

type Tatbikat = {
  id: string;
  kategori: string;
  kapsam: string;
  blok: string | null;
  planlanan_at: string | null;
  duyuru_gonderildi_at: string | null;
  durum: "planli" | "aktif" | "bitti" | "iptal";
  basladi_at: string | null;
  bitis_nedeni: string | null;
  baslik: string;
  alarm_id: string | null;
};
type Rapor = {
  tatbikat: Tatbikat;
  push_denenen: number;
  push_gonderildi: number;
};

const KATEGORILER = ["deprem", "yangin", "gaz", "tahliye"] as const;
const KATEGORI_ETIKET: Record<string, SozlukAnahtari> = {
  deprem: "tatbikatKategoriDeprem",
  yangin: "tatbikatKategoriYangin",
  gaz: "tatbikatKategoriGaz",
  tahliye: "tatbikatKategoriTahliye",
};
const DURUM_ETIKET: Record<string, SozlukAnahtari> = {
  planli: "tatbikatDurumPlanli",
  aktif: "tatbikatDurumAktif",
  bitti: "tatbikatDurumBitti",
  iptal: "tatbikatDurumIptal",
};
const DURUM_ROZET = { planli: "bilgi", aktif: "kritik", bitti: "olumlu", iptal: "notr" } as const;
/** JSX ucluda sabit dize yazilamaz (depo kurali `sabit-metin`). */
const DURUM_YEDEK: SozlukAnahtari = "tatbikatDurumIptal";
const KAPSAM_SITE = "site" as const;
const KAPSAM_BLOK = "blok" as const;
const BIRINCIL = "birincil" as const;
const IKINCIL = "ikincil" as const;
const SESSIZ = "sessiz" as const;
const KUCUK = "kucuk" as const;

export function TatbikatBolumu({ yonetim }: { yonetim: boolean }) {
  const t = useT();
  const toast = useToast();
  const { data, mutate } = useSWR<Tatbikat[]>("/api/tatbikat", jsonFetcher, {
    refreshInterval: 15_000,
  });
  const [formAcik, setFormAcik] = useState(false);
  const [rapor, setRapor] = useState<Tatbikat | null>(null);

  async function eylem(id: string, e: "baslat" | "bitir" | "iptal") {
    try {
      await apiSend(`/api/tatbikat/${id}/${e}`, "POST", {});
      await mutate();
    } catch (hata) {
      toast.error(hata instanceof Error ? hata.message : t("ortakHataOlustu"));
    }
  }

  const liste = data ?? [];
  return (
    <section className="mt-6" data-test="tatbikat-bolumu">
      <div className="mb-2 flex items-center justify-between gap-2">
        <h2 style={{ fontSize: "var(--yz-fs-h2)" }}>{t("tatbikatBaslik")}</h2>
        {yonetim && (
          <Dugme tur={BIRINCIL} data-test="tatbikat-planla" onClick={() => setFormAcik(true)}>
            {t("tatbikatPlanla")}
          </Dugme>
        )}
      </div>
      <Kart>
        {liste.length === 0 ? (
          <BosDurum baslik={t("tatbikatBaslik")} aciklama={t("tatbikatYok")} />
        ) : (
          <Tablo>
            <TabloBasligi>
              <Th>{t("tatbikatTur")}</Th>
              <Th>{t("tatbikatKapsam")}</Th>
              <Th>{t("ortakTarih")}</Th>
              <Th>{t("ortakDurum")}</Th>
              <Th aria-label={t("tatbikatRapor")} />
            </TabloBasligi>
            <tbody>
              {liste.map((x) => (
                <Tr key={x.id}>
                  {/* `Tr`/`Td` data-test ILETMEZ; kimlik icerige konur. */}
                  <Td><span data-test={`tatbikat-satir-${x.id}`}>{x.baslik}</span></Td>
                  <Td>{x.kapsam === KAPSAM_BLOK ? x.blok ?? "" : t("tatbikatKapsamSite")}</Td>
                  <Td>{formatDateTime(x.basladi_at ?? x.planlanan_at ?? "")}</Td>
                  <Td>
                    <Rozet durum={DURUM_ROZET[x.durum]}>{t(DURUM_ETIKET[x.durum] ?? DURUM_YEDEK)}</Rozet>
                    {x.bitis_nedeni === "gercek_alarm" && (
                      <span className="block" style={{ fontSize: "var(--yz-fs-sm)" }}>
                        {t("tatbikatGercekAlarmlaDurdu")}
                      </span>
                    )}
                    {x.duyuru_gonderildi_at && (
                      <span className="block" style={{ fontSize: "var(--yz-fs-sm)" }}>
                        {t("tatbikatDuyuruGitti")}
                      </span>
                    )}
                  </Td>
                  <Td>
                    <div className="flex flex-wrap gap-1">
                      {yonetim && x.durum === "planli" && (
                        <Dugme boy={KUCUK} tur={IKINCIL} data-test={`tatbikat-baslat-${x.id}`} onClick={() => void eylem(x.id, "baslat")}>
                          {t("tatbikatBaslat")}
                        </Dugme>
                      )}
                      {yonetim && x.durum === "aktif" && (
                        <Dugme boy={KUCUK} tur={IKINCIL} data-test={`tatbikat-bitir-${x.id}`} onClick={() => void eylem(x.id, "bitir")}>
                          {t("tatbikatBitir")}
                        </Dugme>
                      )}
                      {yonetim && x.durum === "planli" && (
                        <Dugme boy={KUCUK} tur={SESSIZ} data-test={`tatbikat-iptal-${x.id}`} onClick={() => void eylem(x.id, "iptal")}>
                          {t("tatbikatIptal")}
                        </Dugme>
                      )}
                      {x.alarm_id && (
                        <Dugme boy={KUCUK} tur={IKINCIL} data-test={`tatbikat-rapor-${x.id}`} onClick={() => setRapor(x)}>
                          {t("tatbikatRapor")}
                        </Dugme>
                      )}
                    </div>
                  </Td>
                </Tr>
              ))}
            </tbody>
          </Tablo>
        )}
      </Kart>

      {formAcik && (
        <TatbikatFormu
          onKapat={() => setFormAcik(false)}
          onKaydedildi={async () => {
            setFormAcik(false);
            await mutate();
          }}
        />
      )}
      <Modal
        acik={rapor !== null}
        onKapat={() => setRapor(null)}
        baslik={rapor ? `${rapor.baslik} — ${t("tatbikatRapor")}` : t("tatbikatRapor")}
      >
        {rapor && <TatbikatRaporu tatbikat={rapor} />}
      </Modal>
    </section>
  );
}

function TatbikatRaporu({ tatbikat }: { tatbikat: Tatbikat }) {
  const t = useT();
  const { data } = useSWR<Rapor>(`/api/tatbikat/${tatbikat.id}`, jsonFetcher);
  return (
    <div data-test="tatbikat-rapor">
      {data && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("tatbikatPushKabul", { gonderildi: data.push_gonderildi, denenen: data.push_denenen })}
        </p>
      )}
      {tatbikat.alarm_id && <PanikDurumPaneli alarmId={tatbikat.alarm_id} />}
      <a
        href={`/api/tatbikat/${tatbikat.id}/rapor-pdf`}
        data-test="tatbikat-pdf"
        className="odak-ic mt-3 inline-block underline"
        style={{ color: "var(--yz-accent-ink)" }}
      >
        {t("tatbikatPdf")}
      </a>
    </div>
  );
}

type FormProps = {
  onKapat: () => void;
  /** Kaydedilince cagrilir (liste yenilenir). */
  onKaydedildi: () => unknown;
};

function TatbikatFormu({ onKapat, onKaydedildi }: FormProps) {
  const t = useT();
  const toast = useToast();
  const { data: bloklar } = useSWR<BlockList>("/api/blocks", jsonFetcher);
  const [kategori, setKategori] = useState<string>(KATEGORILER[0]);
  const [kapsam, setKapsam] = useState<string>(KAPSAM_SITE);
  const [blok, setBlok] = useState("");
  const [zaman, setZaman] = useState("");
  const [duyuru, setDuyuru] = useState(false);
  const [not, setNot] = useState("");
  const [bekliyor, setBekliyor] = useState(false);

  async function kaydet() {
    setBekliyor(true);
    try {
      await apiSend("/api/tatbikat", "POST", {
        kategori,
        kapsam,
        blok: kapsam === KAPSAM_BLOK ? blok : null,
        // YEREL -> UTC ISO (saat dilimli). Bos = hemen.
        planlanan_at: zaman ? new Date(zaman).toISOString() : null,
        duyuru: Boolean(zaman) && duyuru,
        aciklama: not || null,
      });
      await onKaydedildi();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setBekliyor(false);
    }
  }

  const blokAdlari = (bloklar?.items ?? []).map((b) => b.ad);
  return (
    <Modal
      acik
      onKapat={onKapat}
      baslik={t("tatbikatPlanla")}
      eylemler={
        <>
          <Dugme tur={SESSIZ} onClick={onKapat}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme
            tur={BIRINCIL}
            data-test="tatbikat-kaydet"
            yukleniyor={bekliyor}
            disabled={kapsam === KAPSAM_BLOK && !blok}
            onClick={() => void kaydet()}
          >
            {zaman ? t("tatbikatPlanla") : t("tatbikatBaslat")}
          </Dugme>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <AlanSarmal etiket={t("tatbikatTur")}>
          {(b) => (
            <Secim {...b} data-test="tatbikat-kategori" value={kategori} onChange={(e) => setKategori(e.target.value)}>
              {KATEGORILER.map((k) => (
                <option key={k} value={k}>
                  {t(KATEGORI_ETIKET[k])}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("tatbikatKapsam")}>
          {(b) => (
            <Secim {...b} data-test="tatbikat-kapsam" value={kapsam} onChange={(e) => setKapsam(e.target.value)}>
              <option value={KAPSAM_SITE}>{t("tatbikatKapsamSite")}</option>
              {blokAdlari.length > 0 && <option value={KAPSAM_BLOK}>{t("tatbikatKapsamBlok")}</option>}
            </Secim>
          )}
        </AlanSarmal>
        {kapsam === KAPSAM_BLOK && (
          <AlanSarmal etiket={t("tatbikatBlok")}>
            {(b) => (
              <Secim {...b} data-test="tatbikat-blok" value={blok} onChange={(e) => setBlok(e.target.value)}>
                <option value="">—</option>
                {blokAdlari.map((a) => (
                  <option key={a} value={a}>
                    {a}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        )}
        <AlanSarmal etiket={t("tatbikatZaman")} ipucu={zaman ? undefined : t("tatbikatHemenUyari")}>
          {(b) => (
            <Alan {...b} type="datetime-local" data-test="tatbikat-zaman" value={zaman} onChange={(e) => setZaman(e.target.value)} />
          )}
        </AlanSarmal>
        {zaman && (
          <label className="flex items-center gap-2">
            <input type="checkbox" data-test="tatbikat-duyuru" checked={duyuru} onChange={(e) => setDuyuru(e.target.checked)} />
            {t("tatbikatDuyuru")}
          </label>
        )}
        <AlanSarmal etiket={t("tatbikatAciklama")}>
          {(b) => <Alan {...b} maxLength={SINIR.NOT} value={not} onChange={(e) => setNot(e.target.value)} />}
        </AlanSarmal>
      </div>
    </Modal>
  );
}
