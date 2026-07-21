"use client";

import { useState } from "react";
import useSWR from "swr";

import { EmptyState } from "@/components/EmptyState";
import { ErrorBox, Pager, PageHeader, btnPrimary, btnGhost, btnDanger, cardCls, inputCls, Field } from "@/components/form";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Complaint, ComplaintDurum, ComplaintList, ComplaintStatusHistory } from "@/lib/types";

const LIMIT = 20;

// Durum rozetleri — mobil ile ayni wire kodu: acik=amber, is_emri=mavi,
// cozuldu=yesil, reddedildi=kirmizi. Renk siniflari globals.css'te koyu-mod
// eslemesi olan accent'ler (bg-*-100 / text-*-700).
const DURUM_META: Record<ComplaintDurum, { label: string; cls: string }> = {
  acik: { label: "Açık", cls: "bg-amber-100 text-amber-700" },
  is_emri: { label: "İş Emri", cls: "bg-blue-100 text-blue-700" },
  cozuldu: { label: "Çözüldü", cls: "bg-green-100 text-green-700" },
  reddedildi: { label: "Reddedildi", cls: "bg-red-100 text-red-700" },
};

const FILTERS: Array<{ value: ComplaintDurum | ""; label: string }> = [
  { value: "", label: "Tümü" },
  { value: "acik", label: "Açık" },
  { value: "is_emri", label: "İş Emri" },
  { value: "cozuldu", label: "Çözüldü" },
  { value: "reddedildi", label: "Reddedilen" },
];

// Timeline actor rolu -> TR etiket (mobil UserRole.label ile ayni).
const ROLE_LABEL: Record<string, string> = {
  admin: "Platform Admin",
  yonetici: "Yönetici",
  security: "Güvenlik",
  tesis_gorevlisi: "Tesis Görevlisi",
  resident: "Site Sakini",
};

// Bagli is emri (Task) durumu -> TR etiket (mobil _LinkedWorkOrderCard ile ayni):
// 'acik' -> "Atandı", 'tamamlandi' -> "Tamamlandı".
function isEmriLabel(durum?: string | null): string {
  switch (durum) {
    case "acik":
      return "Atandı";
    case "tamamlandi":
      return "Tamamlandı";
    default:
      return "Durum bilinmiyor";
  }
}

function DurumBadge({ durum }: { durum: ComplaintDurum }) {
  const meta = DURUM_META[durum] ?? DURUM_META.acik;
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${meta.cls}`}>
      {meta.label}
    </span>
  );
}

// Talep/Ariza -> Is Emri kanali: sakinlerin (ve saha rollerinin) actigi talepler.
// Panel admin'i tenant'taki TUMUNU gorur. Is emrine DONUSTURME (atama secimi)
// mobilde kalir; panel bagli is emrini SALT OKUR gosterir + acik talebi coz/reddet.
export default function ComplaintsPage() {
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState<ComplaintDurum | "">("");
  const query = `/api/complaints?limit=${LIMIT}&offset=${offset}${durum ? `&durum=${durum}` : ""}`;
  const { data, error, isLoading, mutate } = useSWR<ComplaintList>(query, jsonFetcher);

  return (
    <div className="space-y-5">
      <PageHeader
        title="Talep / Arıza"
        action={
          <div className="flex flex-wrap gap-1">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                className={`rounded-lg px-3 py-1.5 text-sm transition ${
                  durum === f.value
                    ? "bg-ink text-white"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
                onClick={() => {
                  setDurum(f.value);
                  setOffset(0);
                }}
              >
                {f.label}
              </button>
            ))}
          </div>
        }
      />

      <p className="text-sm text-muted">
        Sakinlerin ve saha ekibinin ilettiği talep/arızalar. Açık talebi
        <strong> Çöz</strong> ya da <strong>Reddet</strong> ile
        sonuçlandırın; iş emrine dönüştürme (atama) mobil uygulamadan yapılır.
      </p>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yükleniyor...</p>}

      <ul className="space-y-3">
        {(data?.items ?? []).map((c) => (
          <ComplaintCard key={c.id} complaint={c} onChanged={() => mutate()} />
        ))}
        {data && data.items.length === 0 && (
          <EmptyState
            title={durum ? "Bu durumda talep yok." : "Henüz talep yok."}
            description={
              durum
                ? "Filtreyi değiştirerek diğer talepleri görebilirsiniz."
                : "Sakinler/saha ekibi mobil uygulamadan talep açtığında burada listelenir."
            }
          />
        )}
      </ul>

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

function ComplaintCard({
  complaint: c,
  onChanged,
}: {
  complaint: Complaint;
  onChanged: () => void;
}) {
  // Acik talepte iki eylem: "coz" (opsiyonel not) / "reddet" (zorunlu sebep).
  const [action, setAction] = useState<"coz" | "reddet" | null>(null);
  const canAct = c.durum === "acik";

  return (
    <li className={`${cardCls} p-5`}>
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-medium">{c.baslik}</h3>
            <DurumBadge durum={c.durum} />
            <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
              {c.kategori_ad ?? "Diğer"}
            </span>
          </div>
          <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600">{c.mesaj}</p>

          {c.fotograflar.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-2">
              {c.fotograflar
                .filter((f) => f.foto_url)
                .map((f) => (
                  // Presigned GET URL kisa omurlu — liste her yenilendiginde taze
                  // gelir. Tiklayinca tam boy yeni sekmede acilir.
                  <a
                    key={f.id}
                    href={f.foto_url ?? undefined}
                    target="_blank"
                    rel="noreferrer"
                    className="block w-fit"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={f.foto_url ?? undefined}
                      alt={`${c.baslik} görseli`}
                      className="h-24 w-24 rounded-lg border border-slate-200 object-cover"
                    />
                  </a>
                ))}
            </div>
          )}

          <p className="mt-2 text-xs text-muted">
            {c.acan_ad ?? "Sakin"} · {formatDateTime(c.created_at)}
          </p>

          {c.is_emri_id && (
            <div className="mt-3 flex items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-sm">
              <span className="text-blue-700">Bağlı İş Emri</span>
              <span className="ml-auto font-medium text-blue-700">
                {isEmriLabel(c.is_emri_durum)}
              </span>
            </div>
          )}

          {c.gecmis.length > 0 && (
            <Timeline gecmis={c.gecmis} />
          )}
        </div>

        {canAct && !action && (
          <div className="flex shrink-0 flex-col gap-2">
            <button className={btnPrimary} onClick={() => setAction("coz")}>
              Çöz
            </button>
            <button className={btnDanger} onClick={() => setAction("reddet")}>
              Reddet
            </button>
          </div>
        )}
      </div>

      {action && (
        <ActionForm
          complaint={c}
          action={action}
          onClose={() => setAction(null)}
          onDone={() => {
            setAction(null);
            onChanged();
          }}
        />
      )}
    </li>
  );
}

function Timeline({ gecmis }: { gecmis: ComplaintStatusHistory[] }) {
  return (
    <div className="mt-3 border-t border-slate-100 pt-3">
      <p className="mb-2 text-xs font-medium text-muted">Durum geçmişi</p>
      <ol className="space-y-3">
        {gecmis.map((g, i) => {
          const meta = DURUM_META[g.durum as ComplaintDurum];
          return (
            <li key={i} className="flex gap-3 text-sm">
              <span
                className={`mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full ${
                  meta?.cls ?? "bg-slate-100 text-slate-600"
                }`}
              />
              <div className="min-w-0">
                <div className="flex flex-wrap items-baseline gap-x-2">
                  <span className="font-medium">{meta?.label ?? g.durum}</span>
                  <span className="text-xs text-muted">
                    {ROLE_LABEL[g.actor_role] ?? g.actor_role} ·{" "}
                    {formatDateTime(g.created_at)}
                  </span>
                </div>
                {g.sebep && g.sebep.trim() && (
                  <p className="mt-0.5 whitespace-pre-wrap text-slate-600">{g.sebep}</p>
                )}
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}

function ActionForm({
  complaint: c,
  action,
  onClose,
  onDone,
}: {
  complaint: Complaint;
  action: "coz" | "reddet";
  onClose: () => void;
  onDone: () => void;
}) {
  const toast = useToast();
  const [text, setText] = useState("");
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const isReddet = action === "reddet";
  // Reddet: sebep ZORUNLU (backend 422); Coz: cozum notu opsiyonel.
  const submitDisabled = saving || (isReddet && text.trim().length === 0);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setErr(null);
    try {
      if (isReddet) {
        await apiSend(`/api/complaints/${c.id}/decline`, "POST", {
          sebep: text.trim(),
        });
        toast.success("Talep reddedildi.");
      } else {
        const notu = text.trim();
        await apiSend(`/api/complaints/${c.id}/resolve`, "POST", {
          cozum_notu: notu || null,
        });
        toast.success("Talep çözüldü.");
      }
      onDone();
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : "İşlem başarısız.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={submit} className="mt-4 space-y-4 border-t border-slate-100 pt-4">
      <Field
        label={isReddet ? "Red sebebi" : "Çözüm notu"}
        hint={
          isReddet
            ? "Zorunlu — sakin mobilde bu sebebi görür."
            : "İsteğe bağlı — sakin mobilde görür."
        }
      >
        <textarea
          className={`${inputCls} min-h-24`}
          value={text}
          onChange={(e) => setText(e.target.value)}
          maxLength={5000}
          autoFocus
        />
      </Field>
      <ErrorBox message={err} />
      <div className="flex gap-2">
        <button
          type="submit"
          className={`${isReddet ? btnDanger : btnPrimary} disabled:opacity-60`}
          disabled={submitDisabled}
        >
          {saving ? "Gönderiliyor..." : isReddet ? "Reddet" : "Çöz"}
        </button>
        <button type="button" className={btnGhost} onClick={onClose}>
          İptal
        </button>
      </div>
    </form>
  );
}
