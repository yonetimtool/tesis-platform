"use client";

import { useState } from "react";
import useSWR from "swr";

import { Field, ErrorBox, Pager, inputCls, btnPrimary, btnGhost } from "@/components/form";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Complaint, ComplaintDurum, ComplaintList } from "@/lib/types";

const LIMIT = 20;

// Durum rozetleri — mobil ile ayni renk kodu: acik=mavi,
// inceleniyor=turuncu, cozuldu=yesil.
const DURUM_META: Record<ComplaintDurum, { label: string; cls: string }> = {
  acik: { label: "Acik", cls: "bg-blue-100 text-blue-700" },
  inceleniyor: { label: "Inceleniyor", cls: "bg-orange-100 text-orange-700" },
  cozuldu: { label: "Cozuldu", cls: "bg-green-100 text-green-700" },
};

const FILTERS: Array<{ value: ComplaintDurum | ""; label: string }> = [
  { value: "", label: "Tumu" },
  { value: "acik", label: "Acik" },
  { value: "inceleniyor", label: "Inceleniyor" },
  { value: "cozuldu", label: "Cozuldu" },
];

function DurumBadge({ durum }: { durum: ComplaintDurum }) {
  const meta = DURUM_META[durum] ?? DURUM_META.acik;
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${meta.cls}`}>
      {meta.label}
    </span>
  );
}

// Sikayet/oneri yonetimi: sakinlerin actigi talepler (backend RBAC: panel
// admin'i tenant'taki TUMUNU gorur), durum degistirme + yonetici yaniti.
// Talep ACMA yalniz mobil sakin tarafindadir; panelde olusturma yoktur.
export default function ComplaintsPage() {
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState<ComplaintDurum | "">("");
  const query = `/api/complaints?limit=${LIMIT}&offset=${offset}${durum ? `&durum=${durum}` : ""}`;
  const { data, error, isLoading, mutate } = useSWR<ComplaintList>(query, jsonFetcher);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Sikayet / Oneri</h1>
        <div className="flex gap-1">
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
      </div>

      <p className="text-sm text-muted">
        Sakinlerin yonetime ilettigi talepler. Durumu guncelleyin ve yanit
        yazin — sakin, yaniti mobil uygulamada kendi talebinde gorur.
      </p>

      {error && <ErrorBox message={error.message} />}
      {isLoading && !data && <p className="text-sm text-muted">Yukleniyor...</p>}

      <ul className="space-y-3">
        {(data?.items ?? []).map((c) => (
          <ComplaintCard key={c.id} complaint={c} onSaved={() => mutate()} />
        ))}
        {data && data.items.length === 0 && (
          <li className="rounded-xl border border-slate-200 bg-white p-6 text-center text-muted">
            {durum ? "Bu durumda talep yok." : "Henuz talep yok."}
          </li>
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
  onSaved,
}: {
  complaint: Complaint;
  onSaved: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [durum, setDurum] = useState<ComplaintDurum>(c.durum);
  const [yanit, setYanit] = useState(c.yonetici_yaniti ?? "");
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    // Degismeyen alanlar gonderilmez: yanit ayni kalirsa damga
    // (yanitlayan/zaman) korunur; bos govde backend'de 422.
    const body: Record<string, unknown> = {};
    if (durum !== c.durum) body.durum = durum;
    const trimmed = yanit.trim();
    if (trimmed && trimmed !== (c.yonetici_yaniti ?? "")) body.yonetici_yaniti = trimmed;
    if (Object.keys(body).length === 0) {
      setErr("Degisiklik yok: durum secin veya yanit yazin.");
      return;
    }
    setSaving(true);
    setErr(null);
    try {
      await apiSend(`/api/complaints/${c.id}`, "PATCH", body);
      setOpen(false);
      onSaved();
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : "Kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <li className="rounded-xl border border-slate-200 bg-white p-5">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <h3 className="font-medium">{c.baslik}</h3>
            <DurumBadge durum={c.durum} />
          </div>
          <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600">{c.mesaj}</p>
          {c.foto_url && (
            // Presigned GET URL kisa omurlu — liste her yenilendiginde taze gelir.
            <a href={c.foto_url} target="_blank" rel="noreferrer" className="mt-2 block w-fit">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={c.foto_url}
                alt={`${c.baslik} gorseli`}
                className="max-h-40 rounded-lg border border-slate-200 object-cover"
              />
            </a>
          )}
          <p className="mt-2 text-xs text-muted">
            {c.acan_ad ?? "Sakin"} · {formatDateTime(c.created_at)}
          </p>
          {c.yonetici_yaniti && (
            <div className="mt-3 rounded-lg bg-green-50 p-3 text-sm">
              <p className="text-xs text-muted">
                Yonetim yaniti
                {c.yanit_zamani && ` · ${formatDateTime(c.yanit_zamani)}`}
              </p>
              <p className="mt-1 whitespace-pre-wrap">{c.yonetici_yaniti}</p>
            </div>
          )}
        </div>
        <button className={btnGhost} onClick={() => setOpen(!open)}>
          {open ? "Kapat" : c.yonetici_yaniti ? "Yaniti duzenle" : "Yanitla"}
        </button>
      </div>

      {open && (
        <form onSubmit={save} className="mt-4 space-y-4 border-t border-slate-100 pt-4">
          <Field label="Durum">
            <select
              className={inputCls}
              value={durum}
              onChange={(e) => setDurum(e.target.value as ComplaintDurum)}
            >
              <option value="acik">Acik</option>
              <option value="inceleniyor">Inceleniyor</option>
              <option value="cozuldu">Cozuldu</option>
            </select>
          </Field>
          <Field label="Yonetim yaniti" hint="En fazla 5000 karakter — sakin mobilde gorur">
            <textarea
              className={`${inputCls} min-h-24`}
              value={yanit}
              onChange={(e) => setYanit(e.target.value)}
              maxLength={5000}
            />
          </Field>
          <ErrorBox message={err} />
          <div className="flex gap-2">
            <button type="submit" className={btnPrimary} disabled={saving}>
              {saving ? "Kaydediliyor..." : "Kaydet"}
            </button>
            <button type="button" className={btnGhost} onClick={() => setOpen(false)}>
              Iptal
            </button>
          </div>
        </form>
      )}
    </li>
  );
}
