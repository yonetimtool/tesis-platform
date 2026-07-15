"use client";

import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, btnPrimary, btnGhost, inputCls } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";

interface TenantRow {
  id: string;
  ad: string;
  kurulum_tamamlandi: boolean;
  created_at: string;
}
interface TenantListResponse {
  items: TenantRow[];
}
interface CreatedOut {
  tenant_id: string;
  yonetici_user_id: string;
  temp_code?: string | null;
}

interface FormState {
  yonetici_ad: string;
  phone: string;
  password: string;
}
const EMPTY: FormState = { yonetici_ad: "", phone: "", password: "" };

function fmtDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString("tr-TR", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export default function TenantsPage() {
  const { data, error, isLoading, mutate } = useSWR<TenantListResponse>(
    "/api/tenants",
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openNew() {
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      // Parola bossa backend TEK SEFERLIK gecici kod uretir (temp_code).
      const body: Record<string, unknown> = {
        yonetici_ad: form.yonetici_ad,
        phone: form.phone,
      };
      if (form.password) body.password = form.password;
      const created = await apiSend<CreatedOut>("/api/tenants", "POST", body);
      if (created?.temp_code) {
        window.alert(
          `Tesis + yönetici oluşturuldu.\nGeçici giriş kodu: ${created.temp_code}\n\n` +
            `Bu kod yalnızca bir kez gösterilir; yöneticiye iletin. Yönetici cep ` +
            `telefonu + bu kod ile girip kalıcı parolasını belirler, sonra ilk ` +
            `girişte tesisini adlandırır.`,
        );
      } else {
        window.alert(
          `Tesis + yönetici oluşturuldu.\nYönetici belirlediğiniz parola ile giriş ` +
            `yapıp ilk girişte tesisini adlandırır.`,
        );
      }
      setOpen(false);
      mutate();
    } catch (err) {
      const m = err instanceof Error ? err.message : "Kaydedilemedi.";
      setFormErr(
        /telefon|zaten kayitli|conflict|zaten kayıtlı/i.test(m)
          ? "Bu telefon zaten kayıtlı."
          : m,
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Tesisler</h1>
          <p className="text-sm text-muted">
            Yeni tesis + yöneticisini burada açarsınız. Yönetici ilk girişte tesisi adlandırır.
          </p>
        </div>
        <button className={btnPrimary} onClick={openNew}>
          Yeni tesis + yönetici
        </button>
      </div>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <form onSubmit={save} className="space-y-4 rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="font-medium">Yeni tesis + yönetici</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Yönetici adı">
              <input
                className={inputCls}
                value={form.yonetici_ad}
                onChange={(e) => setForm({ ...form, yonetici_ad: e.target.value })}
                required
                minLength={2}
              />
            </Field>
            <Field
              label="Cep telefonu (giriş anahtarı)"
              hint="Global benzersiz; yönetici telefonla giriş yapar"
            >
              <input
                className={inputCls}
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="örn. 0532 111 22 03"
                required
              />
            </Field>
            <Field
              label="Parola (opsiyonel)"
              hint="Boş bırakırsanız tek seferlik geçici kod üretilir"
            >
              <input
                type="password"
                className={inputCls}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                minLength={8}
                placeholder="Boş: geçici kod"
              />
            </Field>
          </div>
          <p className="text-xs text-muted">
            Tesis adı burada girilmez — yönetici uygulamaya ilk girişte kendisi belirler.
          </p>
          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Oluşturuluyor..." : "Oluştur"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              İptal
            </button>
          </div>
        </form>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-slate-500">
            <tr>
              <th className="px-3 py-2 font-medium">Tesis adı</th>
              <th className="px-3 py-2 font-medium">Kimlik (ID)</th>
              <th className="px-3 py-2 font-medium">Kurulum</th>
              <th className="px-3 py-2 font-medium">Oluşturulma</th>
              <th className="px-3 py-2 font-medium" />
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((t) => (
              <tr key={t.id} className="border-t border-slate-100 hover:bg-slate-50">
                <td className="px-3 py-2">
                  <Link href={`/tenants/${t.id}`} className="font-medium text-ink hover:underline">
                    {t.ad}
                  </Link>
                </td>
                <td className="px-3 py-2 font-mono text-xs text-slate-500">{t.id}</td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-xs font-medium ${
                      t.kurulum_tamamlandi
                        ? "bg-emerald-100 text-emerald-800"
                        : "bg-amber-100 text-amber-800"
                    }`}
                  >
                    {t.kurulum_tamamlandi ? "tamamlandı" : "bekliyor"}
                  </span>
                </td>
                <td className="px-3 py-2 text-slate-600">{fmtDate(t.created_at)}</td>
                <td className="px-3 py-2 text-right">
                  <Link href={`/tenants/${t.id}`} className={btnGhost}>
                    Yönet
                  </Link>
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td className="px-3 py-6 text-center text-muted" colSpan={5}>
                  Henüz tesis yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
