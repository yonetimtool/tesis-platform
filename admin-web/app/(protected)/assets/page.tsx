"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, panelCls, panelMotion,
  EksikVeriUyarisi,
} from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { kisaKimlik } from "@/lib/kimlik";
import { DEMIRBAS_DURUM, DEMIRBAS_KATEGORI, enumAdi } from "@/lib/enum-adlari";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type {
  Asset,
  AssetCheckoutList,
  AssetKategori,
  AssetList,
  UserListResponse,
} from "@/lib/types";

const LIMIT = 20;
const NFC_PLACEHOLDER = "04A1B2C3D4";
// METIN DEGIL KIMLIK (modul duzeyinde `t()` yok — README tur 18 dersi).
const KATEGORI: { value: AssetKategori; anahtar: SozlukAnahtari }[] = [
  { value: "ekipman", anahtar: "demirbasEkipman" },
  { value: "arac", anahtar: "demirbasArac" },
  { value: "alet", anahtar: "demirbasAlet" },
  { value: "diger", anahtar: "ortakDiger" },
];
const DURUM_STYLE: Record<string, string> = {
  musait: "bg-emerald-100 text-emerald-800",
  zimmetli: "bg-amber-100 text-amber-800",
  bakimda: "bg-slate-200 text-metin-body",
};

interface FormState {
  ad: string;
  kategori: string;
  nfc_tag_uid: string;
  aciklama: string;
  aktif: boolean;
}
const EMPTY: FormState = { ad: "", kategori: "", nfc_tag_uid: "", aciklama: "", aktif: true };

export default function AssetsPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [kategori, setKategori] = useState("");
  const [durum, setDurum] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (kategori) qs.set("kategori", kategori);
  if (durum) qs.set("durum", durum);
  const { data, error, isLoading, mutate } = useSWR<AssetList>(
    `/api/assets?${qs.toString()}`,
    jsonFetcher,
  );
  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Asset | null>(null);

  const { data: history } = useSWR<AssetCheckoutList>(
    detail ? `/api/assets/${detail.id}/history?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
  }

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(a: Asset) {
    setEditingId(a.id);
    setForm({
      ad: a.ad,
      kategori: a.kategori ?? "",
      nfc_tag_uid: a.nfc_tag_uid ?? "",
      aciklama: a.aciklama ?? "",
      aktif: a.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const body = {
      ad: form.ad,
      kategori: form.kategori || null,
      nfc_tag_uid: form.nfc_tag_uid.trim() || null,
      aciklama: form.aciklama || null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/assets/${editingId}`, "PATCH", body);
      else await apiSend("/api/assets", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("demirbasGuncellendi") : t("demirbasOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(/nfc/i.test(m) ? t("demirbasEtiketKullanimda") : m);
    } finally {
      setSaving(false);
    }
  }

  async function setActive(a: Asset, active: boolean) {
    try {
      await apiSend(`/api/assets/${a.id}`, "PATCH", { aktif: active });
      mutate();
      toast.success(active ? t("demirbasAktiflestirildi") : t("demirbasPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  const openCheckout = (history?.items ?? []).find((h) => !h.birakma_zamani) ?? null;

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukDemirbas")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("demirbasYeni")}</button>
        }
      />

      <EksikVeriUyarisi
        mesaj={usersErr ? t("ortakSecenekYuklenemedi") : null}
      />

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label={t("gorevKategoriAlan")}>
            <select
              className={inputCls}
              value={kategori}
              onChange={(e) => {
                setKategori(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              {KATEGORI.map((k) => (
                <option key={k.value} value={k.value}>
                  {t(k.anahtar)}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label={t("ortakDurum")}>
            <select
              className={inputCls}
              value={durum}
              onChange={(e) => {
                setDurum(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              <option value="musait">{t("demirbasMusait")}</option>
              <option value="zimmetli">{t("demirbasZimmetli")}</option>
              <option value="bakimda">{t("demirbasBakimda")}</option>
            </select>
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("demirbasDuzenle") : t("demirbasYeni")}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("ortakAd")}>
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label={t("demirbasKategoriOpsiyonel")}>
              <select
                className={inputCls}
                value={form.kategori}
                onChange={(e) => setForm({ ...form, kategori: e.target.value })}
              >
                <option value="">{t("ortakYokSecim")}</option>
                {KATEGORI.map((k) => (
                  <option key={k.value} value={k.value}>
                    {t(k.anahtar)}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              label={t("demirbasNfcUidOpsiyonel")}
              hint={t("demirbasEtiketIpucu")}
            >
              <input
                className={`${inputCls} font-mono uppercase`}
                value={form.nfc_tag_uid}
                placeholder={NFC_PLACEHOLDER}
                onChange={(e) => setForm({ ...form, nfc_tag_uid: e.target.value.toUpperCase() })}
              />
            </Field>
            <Field label={t("ortakAciklamaOpsiyonel")}>
              <input
                className={inputCls}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
              />
            </Field>
          </div>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />{t("ortakAktif")}</label>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              {t("ortakIptal")}
            </button>
          </div>
        </motion.form>
      )}

      <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <Tablo>
          <TabloBasligi>
              <Th>{t("ortakAd")}</Th>
              <Th>{t("gorevKategoriAlan")}</Th>
              <Th>NFC</Th>
              <Th>{t("ortakDurum")}</Th>
              <Th>{t("ortakAktif")}</Th>
              <Th />
            </TabloBasligi>
          <tbody>
            {(data?.items ?? []).map((a) => (
              <tr key={a.id} className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${a.aktif ? "" : "bg-yuzey-bg"}`}>
                <Td>{a.ad}</Td>
                <Td className="text-metin-body">{enumAdi(t, DEMIRBAS_KATEGORI, a.kategori)}</Td>
                <Td className="font-mono text-metin-body">{a.nfc_tag_uid ?? "—"}</Td>
                <Td>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${DURUM_STYLE[a.durum] ?? "bg-slate-100 text-metin-body"}`}
                  >
                    {enumAdi(t, DEMIRBAS_DURUM, a.durum)}
                  </span>
                </Td>
                <Td className="text-metin-body">{a.aktif ? t("ortakEvet2") : t("ortakHayir2")}</Td>
                <Td hizala="end">
                  <div className="flex justify-end gap-2">
                    <button
                      className={btnGhost}
                      onClick={() => setDetail(detail?.id === a.id ? null : a)}
                    >
                      {detail?.id === a.id ? t("ortakKapat") : t("demirbasZimmet")}
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(a)}>
                      {t("ortakDuzenle")}
                    </button>
                    <button className={btnGhost} onClick={() => setActive(a, !a.aktif)}>
                      {a.aktif ? t("ortakPasiflestir") : t("ortakAktiflestir")}
                    </button>
                  </div>
                </Td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <Td colSpan={6}>
                  <EmptyState title={t("demirbasYok")} description={t("demirbasYokAlt")} />
                </Td>
              </tr>
            )}
          </tbody>
          </Tablo>
        </div>
      </div>

      {detail && (
        <motion.div {...panelMotion} className={`space-y-3 ${panelCls}`}>
          <h2 className="text-lg font-medium">
            {t("demirbasZimmetBaslik", { ad: detail.ad })}
          </h2>
          <p className="text-sm">
            {openCheckout ? (
              <span className="text-amber-700">
                {t("demirbasSuAnUzerinde", {
                  kisi: userName(openCheckout.alan_user_id),
                  zaman: formatDateTime(openCheckout.alma_zamani),
                })}
              </span>
            ) : (
              <span className="text-emerald-700">{t("demirbasKimsedeDegil")}</span>
            )}
          </p>
          <p className="text-xs text-metin-muted">
            {t("demirbasPanelNotu")}
          </p>
          <div className="overflow-hidden rounded-lg border kart-kenar">
            <div className="odak-ic overflow-x-auto" tabIndex={0}>
              <Tablo>
              <TabloBasligi>
                  <Th>{t("demirbasAlan")}</Th>
                  <Th>{t("demirbasAlma")}</Th>
                  <Th>{t("demirbasBirakma")}</Th>
                </TabloBasligi>
              <tbody>
                {(history?.items ?? []).map((h) => (
                  <Tr key={h.id}>
                    <Td>{userName(h.alan_user_id)}</Td>
                    <Td className="text-metin-body">{formatDateTime(h.alma_zamani)}</Td>
                    <Td className="text-metin-body">
                      {h.birakma_zamani ? formatDateTime(h.birakma_zamani) : t("demirbasAcik")}
                    </Td>
                  </Tr>
                ))}
                {history && history.items.length === 0 && (
                  <tr>
                    <Td colSpan={3}>
                      <EmptyState title={t("demirbasZimmetYok")} />
                    </Td>
                  </tr>
                )}
              </tbody>
              </Tablo>
            </div>
          </div>
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
    </div>
  );
}
