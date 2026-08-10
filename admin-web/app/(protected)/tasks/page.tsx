"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import useSWR from "swr";

import { Ekler } from "@/components/Ekler";
import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, Pager, PageHeader, inputCls, btnPrimary, btnGhost, btnDanger, panelCls, panelMotion,
  EksikVeriUyarisi,
} from "@/components/form";
import { BosSatir, Tablo, TabloBasligi, TabloKart, Td, Th, Tr } from "@/components/tablo";
import { useToast } from "@/components/Toast";
import { kisaKimlik } from "@/lib/kimlik";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { SAHA_ROLLERI, rolAdi } from "@/lib/roles";
import { tamsayiCoz } from "@/lib/sayi";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type {
  Task,
  TaskCategoryList,
  TaskCompletionList,
  TaskList,
  TaskTip,
  UserListResponse,
} from "@/lib/types";

const LIMIT = 20;
// METIN DEGIL KIMLIK (modul duzeyi — README tur 18 dersi).
const TIPLER: { value: TaskTip; anahtar: SozlukAnahtari }[] = [
  { value: "temizlik", anahtar: "gorevTipiTemizlik" },
  { value: "kontrol", anahtar: "gorevTipiKontrol" },
  { value: "ilaclama", anahtar: "gorevTipiIlaclama" },
  { value: "bakim", anahtar: "gorevTipiBakim" },
  { value: "peyzaj", anahtar: "gorevTipiPeyzaj" },
  { value: "diger", anahtar: "ortakDiger" },
];
function tipAdi(ceviri: (a: SozlukAnahtari) => string, v: string): string {
  const o = TIPLER.find((x) => x.value === v);
  return o ? ceviri(o.anahtar) : v;
}

function toIso(local: string): string | null {
  if (!local) return null;
  const d = new Date(local);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
function isoToLocalInput(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

interface FormState {
  tip: TaskTip;
  ad: string;
  aciklama: string;
  atanan_user_id: string;
  kategori_id: string;
  periyot_dakika: string;
  sonraki_planlanan: string;
  foto_zorunlu: boolean;
  aktif: boolean;
}
const EMPTY: FormState = {
  tip: "temizlik",
  ad: "",
  aciklama: "",
  atanan_user_id: "",
  kategori_id: "",
  periyot_dakika: "",
  sonraki_planlanan: "",
  foto_zorunlu: false,
  aktif: true,
};

export default function TasksPage() {
  const t = useT();
  const toast = useToast();
  const [offset, setOffset] = useState(0);
  const [tip, setTip] = useState("");
  const [aktif, setAktif] = useState("");
  const [atananFiltre, setAtananFiltre] = useState("");

  const qs = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
  if (tip) qs.set("tip", tip);
  if (aktif) qs.set("aktif", aktif);
  if (atananFiltre) qs.set("atanan_user_id", atananFiltre);
  const { data, error, isLoading, mutate } = useSWR<TaskList>(
    `/api/tasks?${qs.toString()}`,
    jsonFetcher,
  );
  // Atanan picker: saha personeli (security + tesis_gorevlisi — lib/roles SAHA_ROLLERI).
  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);
  // Kategori picker: yonetici-tanimli aktif kategoriler (A6).
  const { data: kategoriler, error: kategorilerErr } = useSWR<TaskCategoryList>("/api/task-categories", jsonFetcher);
  function kategoriAd(id?: string | null): string {
    if (!id) return "—";
    return kategoriler?.items.find((k) => k.id === id)?.ad ?? kisaKimlik(id);
  }
  const personel = (users?.items ?? []).filter(
    (u) => u.is_active && (SAHA_ROLLERI as string[]).includes(u.role),
  );
  function userName(id?: string | null): string {
    if (!id) return "—";
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
  }

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [detail, setDetail] = useState<Task | null>(null);

  const { data: completions } = useSWR<TaskCompletionList>(
    detail ? `/api/tasks/${detail.id}/completions?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(t: Task) {
    setEditingId(t.id);
    setForm({
      tip: (t.tip as TaskTip) ?? "temizlik",
      ad: t.ad,
      aciklama: t.aciklama ?? "",
      atanan_user_id: t.atanan_user_id ?? "",
      kategori_id: t.kategori_id ?? "",
      periyot_dakika: t.periyot_dakika != null ? String(t.periyot_dakika) : "",
      sonraki_planlanan: isoToLocalInput(t.sonraki_planlanan),
      foto_zorunlu: t.foto_zorunlu,
      aktif: t.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    // (P56) `Number(per)` NaN uretebiliyordu ve `JSON.stringify(NaN)`
    // **null**dur: gecersiz periyot sessizce "periyot yok"a donusuyordu.
    const per = tamsayiCoz(form.periyot_dakika);
    if (per.tur === "gecersiz") {
      setFormErr(t("gorevPeriyotGecersiz"));
      return;
    }
    const body = {
      tip: form.tip,
      ad: form.ad,
      aciklama: form.aciklama || null,
      atanan_user_id: form.atanan_user_id || null,
      kategori_id: form.kategori_id || null,
      periyot_dakika: per.tur === "sayi" ? per.deger : null,
      sonraki_planlanan: toIso(form.sonraki_planlanan),
      foto_zorunlu: form.foto_zorunlu,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/tasks/${editingId}`, "PATCH", body);
      else await apiSend("/api/tasks", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("gorevGuncellendi") : t("gorevOlusturuldu"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(gorev: Task) {
    if (!window.confirm(t("gorevSilOnay", { ad: gorev.ad }))) return;
    try {
      await apiSend(`/api/tasks/${gorev.id}`, "DELETE");
      if (detail?.id === gorev.id) setDetail(null);
      mutate();
      toast.success(t("gorevSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("kabukGorevler")}
        action={
          <button className={btnPrimary} onClick={openNew}>{t("gorevYeni")}</button>
        }
      />

      <EksikVeriUyarisi
        mesaj={usersErr || kategorilerErr ? t("ortakSecenekYuklenemedi") : null}
      />

      <div className="flex flex-wrap items-end gap-3">
        <div className="w-44">
          <Field label={t("raporTabloTip")}>
            <select
              className={inputCls}
              value={tip}
              onChange={(e) => {
                setTip(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              {TIPLER.map((o) => (
                <option key={o.value} value={o.value}>
                  {t(o.anahtar)}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="w-44">
          <Field label={t("ortakDurum")}>
            <select
              className={inputCls}
              value={aktif}
              onChange={(e) => {
                setAktif(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              <option value="true">{t("ortakAktif")}</option>
              <option value="false">{t("ortakPasif")}</option>
            </select>
          </Field>
        </div>
        <div className="w-56">
          <Field label={t("gorevAtanan")}>
            <select
              className={inputCls}
              value={atananFiltre}
              onChange={(e) => {
                setAtananFiltre(e.target.value);
                setOffset(0);
              }}
            >
              <option value="">{t("ortakTumu")}</option>
              {personel.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.ad} ({rolAdi(t, u.role)})
                </option>
              ))}
            </select>
          </Field>
        </div>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-metin-muted">{t("ortakYukleniyor")}</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">{editingId ? t("gorevDuzenle") : t("gorevYeni")}</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("raporTabloTip")}>
              <select
                className={inputCls}
                value={form.tip}
                onChange={(e) => setForm({ ...form, tip: e.target.value as TaskTip })}
              >
                {TIPLER.map((o) => (
                  <option key={o.value} value={o.value}>
                    {t(o.anahtar)}
                  </option>
                ))}
              </select>
            </Field>
            <Field label={t("ortakBaslik")}>
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            </Field>
            <Field label={t("ortakAciklamaOpsiyonel")}>
              <input
                className={inputCls}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
              />
            </Field>
            <Field label={t("gorevAtananOpsiyonel")}>
              <select
                className={inputCls}
                value={form.atanan_user_id}
                onChange={(e) => setForm({ ...form, atanan_user_id: e.target.value })}
              >
                <option value="">{t("ortakSecimYok")}</option>
                {personel.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.ad} ({rolAdi(t, u.role)})
                  </option>
                ))}
              </select>
            </Field>
            <Field label={t("demirbasKategoriOpsiyonel")} hint={t("gorevKategoriIpucu")}>
              <select
                className={inputCls}
                value={form.kategori_id}
                onChange={(e) => setForm({ ...form, kategori_id: e.target.value })}
              >
                <option value="">{t("ortakSecimYok")}</option>
                {(kategoriler?.items ?? []).map((k) => (
                  <option key={k.id} value={k.id}>
                    {k.ad}
                  </option>
                ))}
              </select>
            </Field>
            <Field label={t("gorevPeriyotDakikaOpsiyonel")} hint={t("gorevPeriyodikIpucu")}>
              <input
                type="number"
                min={1}
                className={inputCls}
                value={form.periyot_dakika}
                onChange={(e) => setForm({ ...form, periyot_dakika: e.target.value })}
              />
            </Field>
            <Field label={t("gorevSonrakiPlanlananOpsiyonel")} hint={t("gorevPeriyodikSaatIpucu")}>
              <input
                type="datetime-local"
                className={inputCls}
                value={form.sonraki_planlanan}
                onChange={(e) => setForm({ ...form, sonraki_planlanan: e.target.value })}
              />
            </Field>
          </div>
          <div className="flex gap-6">
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.foto_zorunlu}
                onChange={(e) => setForm({ ...form, foto_zorunlu: e.target.checked })}
              />
              {t("gorevFotoZorunlu")}
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.aktif}
                onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
              />{t("ortakAktif")}</label>
          </div>
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
              <Th>{t("ortakBaslik")}</Th>
              <Th>{t("raporTabloTip")}</Th>
              <Th>{t("gorevKategoriAlan")}</Th>
              <Th>{t("gorevAtanan")}</Th>
              <Th>{t("gorevSonraki")}</Th>
              <Th>{t("ortakAktif")}</Th>
              <Th />
            </TabloBasligi>
          <tbody>
            {(data?.items ?? []).map((gorev) => (
              <tr key={gorev.id} className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${gorev.aktif ? "" : "bg-yuzey-bg"}`}>
                <Td>
                  {gorev.ad}
                  {gorev.foto_zorunlu && (
                    <span className="ms-2 rounded-full bg-sky-100 px-2 py-0.5 text-xs text-sky-800">
                      {t("gorevFotoZorunluRozet")}
                    </span>
                  )}
                </Td>
                <Td className="text-metin-body">{tipAdi(t, gorev.tip)}</Td>
                <Td className="text-metin-body">{kategoriAd(gorev.kategori_id)}</Td>
                <Td className="text-metin-body">{userName(gorev.atanan_user_id)}</Td>
                <Td className="text-metin-body">
                  {gorev.sonraki_planlanan ? formatDateTime(gorev.sonraki_planlanan) : "—"}
                </Td>
                <Td className="text-metin-body">{gorev.aktif ? t("ortakEvet2") : t("ortakHayir2")}</Td>
                <Td hizala="end">
                  <div className="flex justify-end gap-2">
                    <button
                      className={btnGhost}
                      onClick={() => setDetail(detail?.id === gorev.id ? null : gorev)}
                    >
                      {detail?.id === gorev.id ? t("ortakKapat") : t("gorevKayitlar")}
                    </button>
                    <button className={btnGhost} onClick={() => openEdit(gorev)}>
                      {t("ortakDuzenle")}
                    </button>
                    <button className={btnDanger} onClick={() => remove(gorev)}>{t("ortakSil")}</button>
                  </div>
                </Td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <Td colSpan={7}>
                  <EmptyState title={t("gorevYok")} description={t("gorevYokAlt")} />
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
            {t("gorevTamamlamaKayitlari", { ad: detail.ad })}
          </h2>
          <div className="overflow-hidden rounded-lg border kart-kenar">
            <div className="odak-ic overflow-x-auto" tabIndex={0}>
              <Tablo>
              <TabloBasligi>
                  <Th>{t("raporTabloZaman")}</Th>
                  <Th>{t("raporTabloTamamlayan")}</Th>
                  <Th>{t("raporTabloFoto")}</Th>
                  <Th>{t("raporNot")}</Th>
                </TabloBasligi>
              <tbody>
                {(completions?.items ?? []).map((c) => (
                  <Tr key={c.id}>
                    <Td className="text-metin-body">{formatDateTime(c.tamamlanma_zamani)}</Td>
                    <Td>{userName(c.tamamlayan_user_id)}</Td>
                    <Td>
                      {c.foto_url ? (
                        // (P131) FOTOGRAFIN KENDISI GOSTERILIR.
                        // Eskiden yalnizca "foto var" rozeti cizilirdi ve
                        // kanita ULASMANIN YOLU YOKTU — cunku sunucu
                        // `foto_url`i hic doldurmuyordu (olculdu: alan
                        // semada vardi, deger null geliyordu). Rozet o
                        // eksigi gizliyordu.
                        <a href={c.foto_url} target="_blank" rel="noreferrer">
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          <img
                            src={c.foto_url}
                            alt={t("gorevFotoVarRozet")}
                            className="h-12 w-16 rounded object-cover"
                          />
                        </a>
                      ) : c.foto_key ? (
                        // Anahtar var ama adres yok: presign uretilememis.
                        // Rozet BURADA dogru — "kanit var, gosterilemiyor".
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-800">
                          {t("gorevFotoVarRozet")}
                        </span>
                      ) : (
                        <span className="text-metin-muted">{t("raporYok")}</span>
                      )}
                    </Td>
                    <Td className="text-metin-body">{c.notlar ?? "—"}</Td>
                  </Tr>
                ))}
                {completions && completions.items.length === 0 && (
                  <tr>
                    <Td colSpan={4}>
                      <EmptyState title={t("denetimKayitYok")} />
                    </Td>
                  </tr>
                )}
              </tbody>
              </Tablo>
            </div>
          </div>

          {/* (P154 / Asama 6.4) Ortak not/ek yuzeyi. Goreve ozel bir ek
              tablosu ve yukleme akisi YAZILMADI: `Ekler` bileseni
              `varlikTipi` alir ve sekiz varlikta ayni sekilde calisir. */}
          <Ekler varlikTipi="task" varlikId={detail.id} />
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
