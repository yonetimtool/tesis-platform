"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Ekler } from "@/components/Ekler";
import {
  ErrorBox,
  Field,
  PageHeader,
  Pager,
  btnGhost,
  btnPrimary,
  inputCls,
  panelCls,
  panelMotion,
} from "@/components/form";
import { Liste } from "@/components/Liste";
import { Modal, ModalEylemler } from "@/components/Modal";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/**
 * (P154 / Asama 7.1) ICRA DOSYALARI — brief: "ayri ust sekme".
 *
 * NEDEN YENI BIR SAYFA: uc (`/finans/icra-dosyalari`, GET+POST+PATCH) ve
 * BFF kaydi VARDI, ama HICBIR EKRAN onlari cagirmiyordu — envanterdeki
 * "olu BFF ucu" sinifinin bir uyesi. Brief bu bolumu ayri istedigi icin
 * eksik olan sey sayfaydi, uc degil.
 *
 * NEDEN FINANSIN ICINDE DEGIL: icra HUKUKI bir surectir, para hareketi
 * degil. Borc `dues_assessment`ta durur ve buraya KOPYALANMAZ (P29
 * karari); acik borc her satirda ANLIK okunur. Ikisini ayni sayfada
 * gostermek "icra bir kasa hareketidir" izlenimi verirdi.
 *
 * YAZMA YALNIZ ADMIN: uc `require_role("admin")` ile kapali (yonetici
 * OKUR, yazamaz). Bu yuzden "Yeni dosya" dugmesi yoneticiye ve denetciye
 * CIZILMEZ — basilacak ama 403 alacak bir dugme, P129'un notuyla ayni
 * hatadir ("yetkim var sandim").
 */

interface IcraDosyasi {
  id: string;
  dosya_no: string;
  user_id: string;
  user_ad: string | null;
  veris_tarihi: string | null;
  avukat: string | null;
  durum: string;
  aciklama: string | null;
  acik_borc_kurus: number;
  created_at: string;
}

const DURUMLAR = ["acik", "takipte", "tahsil_edildi", "kapandi"] as const;
type Durum = (typeof DURUMLAR)[number];
/** Suzgec: dort durumdan biri ya da "" (hepsi). */
type DurumSecimi = "" | Durum;

const LIMIT = 25;
const BOS = { dosya_no: "", user_id: "", veris_tarihi: "", avukat: "", aciklama: "" };

export default function IcraPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useSorguSecimi<DurumSecimi>("durum", DURUMLAR, "");
  const [acik, setAcik] = useState(false);
  const [form, setForm] = useState(BOS);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [kaydediliyor, setKaydediliyor] = useState(false);
  const [secili, setSecili] = useState<IcraDosyasi | null>(null);

  // Rol SUNUCUDAN: istemcide bir rol listesi tutmak, yetkinin ikinci bir
  // dogruluk kaynagi olurdu.
  const { data: ben } = useSWR<{ role?: string }>("/api/me", jsonFetcher);
  const yazabilir = ben?.role === "admin";

  const suzgec = durum ? `&durum=${durum}` : "";
  const anahtar = `/api/panel/icra-dosyalari?limit=${LIMIT}&offset=${offset}${suzgec}`;
  const { data, error, mutate } = useSWR<{
    items: IcraDosyasi[];
    meta: { total: number };
  }>(anahtar, jsonFetcher);

  async function kaydet(e: React.FormEvent) {
    e.preventDefault();
    setFormHata(null);
    setKaydediliyor(true);
    try {
      await apiSend("/api/panel/icra-dosyalari", "POST", {
        dosya_no: form.dosya_no.trim(),
        user_id: form.user_id.trim(),
        veris_tarihi: form.veris_tarihi || null,
        avukat: form.avukat.trim() || null,
        aciklama: form.aciklama.trim() || null,
      });
      setAcik(false);
      setForm(BOS);
      await mutate();
      toast.success(t("icraOlusturuldu"));
    } catch (err) {
      setFormHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setKaydediliyor(false);
    }
  }

  async function durumDegistir(d: IcraDosyasi, yeni: Durum) {
    try {
      await apiSend(`/api/panel/icra-dosyalari/${d.id}`, "PATCH", { durum: yeni });
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakHataOlustu"));
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={t("kabukIcra")}
        action={
          yazabilir ? (
            <button
              type="button"
              className={btnPrimary}
              onClick={() => {
                setForm(BOS);
                setFormHata(null);
                setAcik(true);
              }}
            >
              {t("icraYeni")}
            </button>
          ) : undefined
        }
      />

      <div className="flex flex-wrap items-end gap-2">
        <Field label={t("icraDurum")}>
          <select
            className={inputCls}
            style={{ maxWidth: 220 }}
            value={durum}
            onChange={(e) => {
              setDurum(e.target.value as DurumSecimi);
              setOffset(0);
            }}
          >
            <option value="">{t("icraDurumHepsi")}</option>
            {DURUMLAR.map((d) => (
              <option key={d} value={d}>
                {t(`icraDurum_${d}` as never)}
              </option>
            ))}
          </select>
        </Field>
      </div>

      {error && <ErrorBox message={error.message} />}

      {data && data.items.length === 0 ? (
        <EmptyState title={t("icraKayitYok")} />
      ) : (
        <Liste<IcraDosyasi>
          satirlar={data?.items ?? []}
          kimlik={(k) => k.id}
          // Sunucu sayfaliyor: istemci sayfalamasi KAPALI, denetimler
          // asagida `Pager` ile cizilir. Acik birakmak "50 kaydin 50'si"
          // deyip toplami gizlemek olurdu.
          sunucuTarafi
          kolonlar={[
            { anahtar: "dosya_no", baslik: t("icraDosyaNo"), deger: (k) => k.dosya_no },
            { anahtar: "user_ad", baslik: t("icraBorclu"), deger: (k) => k.user_ad ?? "—" },
            {
              anahtar: "acik_borc_kurus",
              baslik: t("icraAcikBorc"),
              // ANLIK okunur, kopyalanmaz — iki yerde tutulan borc, biri
              // guncellenip digeri unutuldugunda hangi rakamin dogru
              // oldugunu belirsiz birakirdi (P29).
              deger: (k) => kurusToTL(k.acik_borc_kurus),
            },
            { anahtar: "avukat", baslik: t("icraAvukat"), deger: (k) => k.avukat ?? "—" },
            {
              anahtar: "durum",
              baslik: t("icraDurum"),
              deger: (k) => t(`icraDurum_${k.durum}` as never),
            },
          ]}
          eylemler={(k) => (
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                className={btnGhost}
                onClick={() => setSecili(secili?.id === k.id ? null : k)}
              >
                {secili?.id === k.id ? t("ortakKapat") : t("icraDetay")}
              </button>
              {yazabilir &&
                DURUMLAR.filter((d) => d !== k.durum).map((d) => (
                  <button
                    key={d}
                    type="button"
                    className={btnGhost}
                    onClick={() => void durumDegistir(k, d)}
                  >
                    {t(`icraDurum_${d}` as never)}
                  </button>
                ))}
            </div>
          )}
        />
      )}

      {secili && (
        <motion.div {...panelMotion} className={`space-y-3 ${panelCls}`}>
          <h2 className="text-lg font-medium">
            {t("icraDetayBaslik", { no: secili.dosya_no })}
          </h2>
          {secili.aciklama && (
            <p className="whitespace-pre-wrap text-sm text-metin-body">{secili.aciklama}</p>
          )}
          {/* (P154 / Asama 6.4) Ortak not/ek yuzeyi — icraya OZEL bir ek
              tablosu yazilmadi. Avukat yazismasi ve tebligat belgesi tam
              da buraya iliskin "ek bilgi"dir. */}
          <Ekler varlikTipi="icra_dosyasi" varlikId={secili.id} />
        </motion.div>
      )}

      {data && (
        <Pager
          offset={offset}
          limit={LIMIT}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      )}

      <Modal
        baslik={t("icraYeni")}
        acik={acik}
        kapat={() => setAcik(false)}
        // Doldurulmus bir form kazara kapanmasin: `kirli` bayragi Modal'in
        // onay sorusunu tetikler.
        kirli={form.dosya_no !== "" || form.user_id !== ""}
      >
          <form onSubmit={kaydet} className="space-y-3">
            {formHata && <ErrorBox message={formHata} />}
            <Field label={t("icraDosyaNo")}>
              <input
                className={inputCls}
                value={form.dosya_no}
                onChange={(e) => setForm({ ...form, dosya_no: e.target.value })}
                required
                maxLength={50}
              />
            </Field>
            <Field label={t("icraBorcluId")}>
              <input
                className={inputCls}
                value={form.user_id}
                onChange={(e) => setForm({ ...form, user_id: e.target.value })}
                required
              />
            </Field>
            <Field label={t("icraVerisTarihi")}>
              <input
                type="date"
                className={inputCls}
                value={form.veris_tarihi}
                onChange={(e) => setForm({ ...form, veris_tarihi: e.target.value })}
              />
            </Field>
            <Field label={t("icraAvukat")}>
              <input
                className={inputCls}
                value={form.avukat}
                onChange={(e) => setForm({ ...form, avukat: e.target.value })}
                maxLength={150}
              />
            </Field>
            <Field label={t("icraAciklama")}>
              <textarea
                className={inputCls}
                rows={3}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
                maxLength={1000}
              />
            </Field>
            <ModalEylemler iptal={() => setAcik(false)} kaydediyor={kaydediliyor} />
          </form>
      </Modal>
    </div>
  );
}
