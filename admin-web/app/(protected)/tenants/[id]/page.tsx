"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, btnPrimary, btnGhost, inputCls, cardCls } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";

interface Yonetici {
  id: string;
  ad: string;
  telefon: string | null;
  is_active: boolean;
  password_set: boolean;
}
interface TenantDetail {
  tenant_id: string;
  ad: string;
  kurulum_tamamlandi: boolean;
  created_at: string;
  yonetici: Yonetici | null;
}

function fmtDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString("tr-TR", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export default function TenantDetailPage() {
  const t = useT();
  const toast = useToast();
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data, error, isLoading, mutate } = useSWR<TenantDetail>(
    id ? `/api/tenants/${id}` : null,
    jsonFetcher,
  );

  const [editing, setEditing] = useState(false);
  const [ad, setAd] = useState("");
  const [telefon, setTelefon] = useState("");
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const [confirmAd, setConfirmAd] = useState("");
  const [nameEditing, setNameEditing] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [nameErr, setNameErr] = useState<string | null>(null);
  const [nameSaving, setNameSaving] = useState(false);

  const y = data?.yonetici ?? null;

  function openNameEdit() {
    if (!data) return;
    setNameInput(data.ad);
    setNameErr(null);
    setNameEditing(true);
  }

  async function saveName(e: React.FormEvent) {
    e.preventDefault();
    setNameSaving(true);
    setNameErr(null);
    try {
      await apiSend(`/api/tenants/${id}`, "PATCH", { ad: nameInput.trim() });
      setNameEditing(false);
      mutate();
      toast.success(t("tesisAdiGuncellendi"));
    } catch (err) {
      setNameErr(err instanceof Error ? err.message : "Kaydedilemedi.");
    } finally {
      setNameSaving(false);
    }
  }

  function openEdit() {
    if (!y) return;
    setAd(y.ad);
    setTelefon(y.telefon ?? "");
    setFormErr(null);
    setEditing(true);
  }

  async function saveEdit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      const body: Record<string, unknown> = { ad };
      if (telefon.trim()) body.phone = telefon.trim();
      await apiSend(`/api/tenants/${id}/yonetici`, "PATCH", body);
      setEditing(false);
      mutate();
      toast.success(t("tesisYoneticiGuncellendi"));
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/telefon|zaten kay/i.test(m) ? t("tesisTelefonKayitli") : m);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive() {
    if (!y) return;
    const next = !y.is_active;
    if (!window.confirm(next ? t("tesisYoneticiAktifOnay") : t("tesisYoneticiPasifOnay"))) return;
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}/yonetici`, "PATCH", { is_active: next });
      mutate();
      toast.success(next ? t("tesisYoneticiAktiflestirildi") : t("tesisYoneticiPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    } finally {
      setBusy(false);
    }
  }

  async function resetCredential() {
    if (!window.confirm(t("tesisParolaSifirlaOnay"))) return;
    setBusy(true);
    try {
      const r = await apiSend<{ temp_code: string }>(
        `/api/tenants/${id}/yonetici/reset-credential`,
        "POST",
      );
      window.alert(
        t("tesisGeciciKod", { kod: r.temp_code }),
      );
      mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("tesisSifirlanamadi"));
    } finally {
      setBusy(false);
    }
  }

  async function deleteTenant() {
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}`, "DELETE");
      router.push("/tenants");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Silinemedi.");
      setBusy(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <Link href="/tenants" className={btnGhost}>
          ← Tesisler
        </Link>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">{t("ortakYukleniyor")}</p>}

      {data && (
        <>
          <div className={`${cardCls} p-5`}>
            {!nameEditing && (
              <>
                <div className="flex items-start justify-between">
                  <div>
                    <h1 className="text-2xl font-semibold">{data.ad}</h1>
                    <p className="mt-1 font-mono text-xs text-slate-500">{data.tenant_id}</p>
                  </div>
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      data.kurulum_tamamlandi
                        ? "bg-emerald-100 text-emerald-800"
                        : "bg-amber-100 text-amber-800"
                    }`}
                  >
                    {data.kurulum_tamamlandi ? t("tesisKurulumTamamlandi") : "kurulum bekliyor"}
                  </span>
                </div>
                <div className="mt-2 flex items-center justify-between">
                  <p className="text-sm text-slate-600">
                    {t("tesisOlusturulmaTarihi", { zaman: fmtDate(data.created_at) })}
                  </p>
                  <button className={btnGhost} onClick={openNameEdit}>
                    {t("tesisAdiDuzenle")}
                  </button>
                </div>
              </>
            )}

            {nameEditing && (
              <form onSubmit={saveName} className="space-y-3">
                <Field label={t("ayarTesisAdi")}>
                  <input
                    className={inputCls}
                    value={nameInput}
                    onChange={(e) => setNameInput(e.target.value)}
                    minLength={2}
                    maxLength={120}
                    required
                    autoFocus
                  />
                </Field>
                {nameErr && <ErrorBox message={nameErr} />}
                <div className="flex gap-2">
                  <button type="submit" className={btnPrimary} disabled={nameSaving}>
                    {nameSaving ? t("ortakKaydediliyor") : t("ortakKaydet")}
                  </button>
                  <button
                    type="button"
                    className={btnGhost}
                    onClick={() => setNameEditing(false)}
                    disabled={nameSaving}
                  >
                    {t("ortakVazgec")}
                  </button>
                </div>
              </form>
            )}
          </div>

          <div className={`${cardCls} p-5`}>
            <h2 className="mb-3 font-medium">{t("rolYonetici")}</h2>
            {!y && <p className="text-sm text-muted">{t("tesisYoneticiYok")}</p>}

            {y && !editing && (
              <div className="space-y-3">
                <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                  <dt className="text-slate-500">{t("ortakAd")}</dt>
                  <dd>{y.ad}</dd>
                  <dt className="text-slate-500">{t("tesisTelefonGiris")}</dt>
                  <dd>{y.telefon ?? "—"}</dd>
                  <dt className="text-slate-500">{t("ortakDurum")}</dt>
                  <dd>
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                        y.is_active ? "bg-emerald-100 text-emerald-800" : "bg-slate-200 text-slate-600"
                      }`}
                    >
                      {y.is_active ? "aktif" : "pasif"}
                    </span>
                  </dd>
                  <dt className="text-slate-500">Kimlik</dt>
                  <dd className="text-slate-600">
                    {y.password_set ? "parola belirlendi" : t("tesisGeciciKodAsamasi")}
                  </dd>
                </dl>
                <div className="flex flex-wrap gap-2 pt-1">
                  <button className={btnGhost} onClick={openEdit} disabled={busy}>
                    {t("tesisAdTelefonDuzenle")}
                  </button>
                  <button className={btnGhost} onClick={resetCredential} disabled={busy}>
                    {t("tesisParolaSifirla")}
                  </button>
                  <button className={btnGhost} onClick={toggleActive} disabled={busy}>
                    {y.is_active ? t("ortakPasiflestir") : t("ortakAktiflestir")}
                  </button>
                </div>
              </div>
            )}

            {y && editing && (
              <form onSubmit={saveEdit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <Field label={t("ortakAd")}>
                    <input
                      className={inputCls}
                      value={ad}
                      onChange={(e) => setAd(e.target.value)}
                      required
                      minLength={2}
                    />
                  </Field>
                  <Field label={t("kullaniciTelefon")} hint="Global benzersiz">
                    <input
                      className={inputCls}
                      value={telefon}
                      onChange={(e) => setTelefon(e.target.value)}
                      placeholder={t("kullaniciTelefonOrnek")}
                    />
                  </Field>
                </div>
                <ErrorBox message={formErr} />
                <div className="flex gap-2">
                  <button type="submit" className={btnPrimary} disabled={saving}>
                    {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
                  </button>
                  <button type="button" className={btnGhost} onClick={() => setEditing(false)}>
                    {t("ortakIptal")}
                  </button>
                </div>
              </form>
            )}
          </div>

          <div className="rounded-xl border border-rose-200 bg-rose-50 p-5">
            <h2 className="font-medium text-rose-800">{t("tesisTehlikeliBolge")}</h2>
            <p className="mt-1 text-sm text-rose-700">
              {t("tesisSilUyari", { kelime: t("tesisSilOnayKelimesi") })}
            </p>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <input
                className={`${inputCls} max-w-xs`}
                value={confirmAd}
                onChange={(e) => setConfirmAd(e.target.value)}
                placeholder={t("tesisSilOnayKelimesi")}
              />
              <button
                className="rounded-lg bg-rose-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-rose-700 disabled:opacity-50"
                onClick={deleteTenant}
                disabled={busy || confirmAd.trim().toLocaleUpperCase("tr") !== t("tesisSilOnayKelimesi")}
              >
                {t("tesisKaliciSil")}
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
