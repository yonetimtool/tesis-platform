"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, btnPrimary, btnGhost, inputCls } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";

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

  const y = data?.yonetici ?? null;

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
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(/telefon|zaten kay/i.test(m) ? "Bu telefon zaten kayıtlı." : m);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive() {
    if (!y) return;
    const next = !y.is_active;
    if (!window.confirm(next ? "Yönetici hesabı aktifleştirilsin mi?" : "Yönetici hesabı pasifleştirilsin mi? (giriş engellenir)")) return;
    setBusy(true);
    try {
      await apiSend(`/api/tenants/${id}/yonetici`, "PATCH", { is_active: next });
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Güncellenemedi.");
    } finally {
      setBusy(false);
    }
  }

  async function resetCredential() {
    if (!window.confirm("Yöneticinin parolası sıfırlanıp yeni geçici kod üretilsin mi?")) return;
    setBusy(true);
    try {
      const r = await apiSend<{ temp_code: string }>(
        `/api/tenants/${id}/yonetici/reset-credential`,
        "POST",
      );
      window.alert(
        `Geçici giriş kodu: ${r.temp_code}\n\nBu kod yalnızca bir kez gösterilir; ` +
          `yöneticiye iletin. Yönetici cep telefonu + bu kod ile girip yeni parolasını belirler.`,
      );
      mutate();
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Sıfırlanamadı.");
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
      window.alert(err instanceof Error ? err.message : "Silinemedi.");
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
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {data && (
        <>
          <div className="rounded-xl border border-slate-200 bg-white p-5">
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
                {data.kurulum_tamamlandi ? "kurulum tamamlandı" : "kurulum bekliyor"}
              </span>
            </div>
            <p className="mt-2 text-sm text-slate-600">
              Oluşturulma: {fmtDate(data.created_at)}
            </p>
          </div>

          <div className="rounded-xl border border-slate-200 bg-white p-5">
            <h2 className="mb-3 font-medium">Yönetici</h2>
            {!y && <p className="text-sm text-muted">Bu tesiste yönetici yok.</p>}

            {y && !editing && (
              <div className="space-y-3">
                <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                  <dt className="text-slate-500">Ad</dt>
                  <dd>{y.ad}</dd>
                  <dt className="text-slate-500">Telefon (giriş)</dt>
                  <dd>{y.telefon ?? "—"}</dd>
                  <dt className="text-slate-500">Durum</dt>
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
                    {y.password_set ? "parola belirlendi" : "geçici kod aşamasında"}
                  </dd>
                </dl>
                <div className="flex flex-wrap gap-2 pt-1">
                  <button className={btnGhost} onClick={openEdit} disabled={busy}>
                    Ad / telefon düzenle
                  </button>
                  <button className={btnGhost} onClick={resetCredential} disabled={busy}>
                    Parola sıfırla / geçici kod üret
                  </button>
                  <button className={btnGhost} onClick={toggleActive} disabled={busy}>
                    {y.is_active ? "Pasifleştir" : "Aktifleştir"}
                  </button>
                </div>
              </div>
            )}

            {y && editing && (
              <form onSubmit={saveEdit} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <Field label="Ad">
                    <input
                      className={inputCls}
                      value={ad}
                      onChange={(e) => setAd(e.target.value)}
                      required
                      minLength={2}
                    />
                  </Field>
                  <Field label="Cep telefonu (giriş anahtarı)" hint="Global benzersiz">
                    <input
                      className={inputCls}
                      value={telefon}
                      onChange={(e) => setTelefon(e.target.value)}
                      placeholder="örn. 0532 111 22 03"
                    />
                  </Field>
                </div>
                <ErrorBox message={formErr} />
                <div className="flex gap-2">
                  <button type="submit" className={btnPrimary} disabled={saving}>
                    {saving ? "Kaydediliyor..." : "Kaydet"}
                  </button>
                  <button type="button" className={btnGhost} onClick={() => setEditing(false)}>
                    İptal
                  </button>
                </div>
              </form>
            )}
          </div>

          <div className="rounded-xl border border-rose-200 bg-rose-50 p-5">
            <h2 className="font-medium text-rose-800">Tehlikeli bölge</h2>
            <p className="mt-1 text-sm text-rose-700">
              Tesisi silmek yöneticiyi, duyuruları, daireleri, sakinleri ve tüm site
              verisini kalıcı olarak siler. Bu işlem geri alınamaz. Onaylamak için
              aşağıya <span className="font-semibold">SİL</span> yazın.
            </p>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <input
                className={`${inputCls} max-w-xs`}
                value={confirmAd}
                onChange={(e) => setConfirmAd(e.target.value)}
                placeholder="SİL"
              />
              <button
                className="rounded-lg bg-rose-600 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-rose-700 disabled:opacity-50"
                onClick={deleteTenant}
                disabled={busy || confirmAd.trim().toLocaleUpperCase("tr") !== "SİL"}
              >
                Tesisi kalıcı olarak sil
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
