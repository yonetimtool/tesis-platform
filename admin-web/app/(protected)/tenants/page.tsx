"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { Field, ErrorBox, PageHeader, btnPrimary, btnGhost, btnDanger, inputCls, panelCls, panelMotion } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import type { TenantAdminCreate, TenantAdminCreatedOut } from "@/lib/types";

interface TenantRow {
  id: string;
  ad: string;
  kurulum_tamamlandi: boolean;
  created_at: string;
}
interface TenantListResponse {
  items: TenantRow[];
}

// Formdaki tek yonetici satiri. Parola bos string = "verilmedi" (govdeye hic
// konmaz) -> backend tek seferlik gecici kod uretir.
interface YoneticiForm {
  ad: string;
  phone: string;
  password: string;
}
interface FormState {
  ad: string;
  yonetim_email: string;
  yoneticiler: YoneticiForm[];
}
const BOS_YONETICI: YoneticiForm = { ad: "", phone: "", password: "" };
// Ilk satir HER ZAMAN vardir ve BIRINCIL'dir (kaldirilamaz) — backend en az bir
// yonetici bekler ve listenin ilkini birincil isaretler.
const EMPTY: FormState = { ad: "", yonetim_email: "", yoneticiler: [{ ...BOS_YONETICI }] };

function fmtDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString("tr-TR", { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export default function TenantsPage() {
  const toast = useToast();
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

  async function removeTenant(t: TenantRow) {
    // Tesisi + TUM verisini kalici siler (geri alinamaz). Tek adimli net onay
    // (yeni tesisin adi "(Kurulum bekliyor)" yer tutucu oldugundan ad-yazdirma
    // pratik degil).
    const ok = window.confirm(
      `"${t.ad}" tesisini ve TÜM verisini (yönetici, duyuru, daire, sakin...) ` +
        `kalıcı olarak silmek üzeresiniz.\n\nBu işlem GERİ ALINAMAZ. Silinsin mi?`,
    );
    if (!ok) return;
    try {
      await apiSend(`/api/tenants/${t.id}`, "DELETE");
      mutate();
      toast.success("Tesis silindi.");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Silinemedi.");
    }
  }

  function setYonetici(i: number, patch: Partial<YoneticiForm>) {
    setForm({
      ...form,
      yoneticiler: form.yoneticiler.map((y, j) => (j === i ? { ...y, ...patch } : y)),
    });
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      const body: TenantAdminCreate = {
        yoneticiler: form.yoneticiler.map((y) => ({
          ad: y.ad,
          phone: y.phone,
          ...(y.password ? { password: y.password } : {}),
        })),
      };
      if (form.ad.trim()) body.ad = form.ad.trim();
      if (form.yonetim_email.trim()) body.yonetim_email = form.yonetim_email.trim();

      const created = await apiSend<TenantAdminCreatedOut>("/api/tenants", "POST", body);

      // Gecici kod YALNIZ parolasiz acilan yonetici icin ve BIR KEZ doner —
      // her kod kendi yoneticisinin adiyla listelenir ki yanlis kisiye gitmesin.
      const kodlar = (created?.yoneticiler ?? []).filter((y) => y.temp_code);
      if (kodlar.length) {
        window.alert(
          "Tesis + yöneticiler oluşturuldu.\n\nGeçici giriş kodları:\n" +
            kodlar
              .map((y) => `• ${y.ad}${y.birincil ? " (birincil)" : ""}: ${y.temp_code}`)
              .join("\n") +
            "\n\nHer yönetici telefonu + kendi kodu ile girip kalıcı parolasını belirler.",
        );
      } else {
        window.alert(
          "Tesis + yöneticiler oluşturuldu.\nYöneticiler belirlediğiniz parola ile giriş yapar.",
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
      <PageHeader
        title="Tesisler"
        subtitle="Yeni tesis + yöneticisini burada açarsınız. Yönetici ilk girişte tesisi adlandırır."
        action={
          <button className={btnPrimary} onClick={openNew}>
            Yeni tesis + yönetici
          </button>
        }
      />

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      {open && (
        <motion.form {...panelMotion} onSubmit={save} className={`space-y-4 ${panelCls}`}>
          <h2 className="font-medium">Yeni tesis + yönetici</h2>
          <div className="grid grid-cols-2 gap-4">
            <Field
              label="Tesis adı (opsiyonel)"
              hint="Boş bırakırsanız yönetici ilk girişte kendisi belirler."
            >
              <input
                className={inputCls}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                minLength={2}
                placeholder="örn. Acme Plaza"
              />
            </Field>
            <Field
              label="Yönetim maili (opsiyonel)"
              hint="Yönetici iletişim kartında herkese görünür."
            >
              <input
                type="email"
                className={inputCls}
                value={form.yonetim_email}
                onChange={(e) => setForm({ ...form, yonetim_email: e.target.value })}
                placeholder="örn. yonetim@acme.com"
              />
            </Field>
          </div>

          <div className="space-y-4">
            {form.yoneticiler.map((y, i) => (
              <div key={i} className="rounded-lg border border-slate-200 p-4">
                <div className="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-medium">
                      {i === 0 ? "Birincil yönetici" : `Yönetici ${i + 1}`}
                    </h3>
                    {i === 0 && (
                      <p className="text-xs text-muted">Tesisi ilk girişte adlandırır.</p>
                    )}
                  </div>
                  {i > 0 && (
                    <button
                      type="button"
                      className="rounded-lg px-3 py-1.5 text-sm font-medium text-rose-700 transition hover:bg-rose-50"
                      onClick={() =>
                        setForm({
                          ...form,
                          yoneticiler: form.yoneticiler.filter((_, j) => j !== i),
                        })
                      }
                    >
                      Kaldır
                    </button>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <Field label="Ad soyad">
                    <input
                      className={inputCls}
                      value={y.ad}
                      onChange={(e) => setYonetici(i, { ad: e.target.value })}
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
                      value={y.phone}
                      onChange={(e) => setYonetici(i, { phone: e.target.value })}
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
                      value={y.password}
                      onChange={(e) => setYonetici(i, { password: e.target.value })}
                      minLength={8}
                      placeholder="Boş: geçici kod"
                    />
                  </Field>
                </div>
              </div>
            ))}
            <button
              type="button"
              className={btnGhost}
              onClick={() =>
                setForm({ ...form, yoneticiler: [...form.yoneticiler, { ...BOS_YONETICI }] })
              }
            >
              + Yönetici ekle
            </button>
          </div>

          <ErrorBox message={formErr} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Oluşturuluyor..." : "Oluştur"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              İptal
            </button>
          </div>
        </motion.form>
      )}

      <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-slate-500">
              <tr>
                <th className="px-4 py-2.5 font-medium">Tesis adı</th>
                <th className="px-4 py-2.5 font-medium">Kimlik (ID)</th>
                <th className="px-4 py-2.5 font-medium">Kurulum</th>
                <th className="px-4 py-2.5 font-medium">Oluşturulma</th>
                <th className="px-4 py-2.5 font-medium" />
              </tr>
            </thead>
            <tbody>
              {(data?.items ?? []).map((t) => (
                <tr key={t.id} className="border-t border-slate-100 transition-colors hover:bg-slate-50">
                  <td className="px-4 py-2.5">
                    <Link href={`/tenants/${t.id}`} className="font-medium text-ink hover:underline">
                      {t.ad}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 font-mono text-xs text-slate-500">{t.id}</td>
                  <td className="px-4 py-2.5">
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
                  <td className="px-4 py-2.5 text-slate-600">{fmtDate(t.created_at)}</td>
                  <td className="px-4 py-2.5 text-right">
                    <div className="flex justify-end gap-2">
                      <Link href={`/tenants/${t.id}`} className={btnGhost}>
                        Yönet
                      </Link>
                      <button className={btnDanger} onClick={() => removeTenant(t)}>
                        Sil
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {data && data.items.length === 0 && (
                <tr>
                  <td colSpan={5}>
                    <EmptyState title="Henüz tesis yok" description="İlk tesisi ve yöneticisini oluşturarak başlayın." />
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
