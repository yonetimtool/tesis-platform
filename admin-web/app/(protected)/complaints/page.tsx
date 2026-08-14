"use client";

import { useState } from "react";
import useSWR from "swr";

import { Foto } from "@/components/Foto";
import { Pager } from "@/components/form";
import {
  AlanSarmal,
  BosDurum,
  CokSatir,
  Dugme,
  Kart,
  HataDurumu,
  IskeletMetin,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Complaint, ComplaintDurum, ComplaintList, ComplaintStatusHistory } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_TEHLIKE = "tehlike" as const;
const LIMIT = 20;

// Durum rozetleri — mobil ile ayni wire kodu: acik=amber, is_emri=mavi,
// cozuldu=yesil, reddedildi=kirmizi. Renk siniflari globals.css'te koyu-mod
// eslemesi olan accent'ler (bg-*-100 / text-*-700).
// METIN DEGIL KIMLIK (modul duzeyi — README tur 18 dersi).
const DURUM_META: Record<ComplaintDurum, { anahtar: SozlukAnahtari; cls: string }> = {
  acik: { anahtar: "ortakAcik", cls: "bg-amber-100 text-amber-700" },
  is_emri: { anahtar: "talepIsEmri", cls: "bg-blue-100 text-blue-700" },
  cozuldu: { anahtar: "destekCozuldu", cls: "bg-green-100 text-green-700" },
  reddedildi: { anahtar: "talepReddedildi", cls: "bg-red-100 text-red-700" },
};

const FILTERS: Array<{ value: ComplaintDurum | ""; anahtar: SozlukAnahtari }> = [
  { value: "", anahtar: "ortakTumu" },
  { value: "acik", anahtar: "ortakAcik" },
  { value: "is_emri", anahtar: "talepIsEmri" },
  { value: "cozuldu", anahtar: "destekCozuldu" },
  { value: "reddedildi", anahtar: "talepReddedilen" },
];

// Timeline actor rolu -> TR etiket (mobil UserRole.label ile ayni).
const ROLE_ANAHTAR: Record<string, SozlukAnahtari> = {
  admin: "rolPlatformAdmin",
  yonetici: "rolYonetici",
  security: "rolGuvenlik",
  tesis_gorevlisi: "rolTesisGorevlisi",
  resident: "rolSiteSakini",
};

// Bagli is emri (Task) durumu -> TR etiket (mobil _LinkedWorkOrderCard ile ayni):
// 'acik' -> t("talepAtandi"), 'tamamlandi' -> t("talepTamamlandi").
function isEmriAnahtari(durum?: string | null): SozlukAnahtari {
  switch (durum) {
    case "acik":
      return "talepAtandi";
    case "tamamlandi":
      return "talepTamamlandi";
    default:
      return "talepDurumBilinmiyor";
  }
}

function DurumBadge({ durum }: { durum: ComplaintDurum }) {
  const t = useT();
  const meta = DURUM_META[durum] ?? DURUM_META.acik;
  return (
    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${meta.cls}`}>
      {t(meta.anahtar)}
    </span>
  );
}

// Talep/Ariza -> Is Emri kanali: sakinlerin (ve saha rollerinin) actigi talepler.
// Panel admin'i tenant'taki TUMUNU gorur. Is emrine DONUSTURME (atama secimi)
// mobilde kalir; panel bagli is emrini SALT OKUR gosterir + acik talebi coz/reddet.
export default function ComplaintsPage() {
  const t = useT();
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState<ComplaintDurum | "">("");
  const query = `/api/complaints?limit=${LIMIT}&offset=${offset}${durum ? `&durum=${durum}` : ""}`;
  const { data, error, isLoading, mutate } = useSWR<ComplaintList>(query, jsonFetcher);

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("talepBaslik")}
        </h1>
        {/* (P160) `aria-pressed` EKLENDI: secili suzgec eskiden yalniz
            RENKLE anlatiliyordu ve ekran okuyucu hangisinin acik oldugunu
            SOYLEMIYORDU. */}
        <div className="flex flex-wrap gap-1">
          {FILTERS.map((f) => (
            <Dugme
              key={f.value}
              boy="kucuk"
              tur={durum === f.value ? TUR_BIRINCIL : TUR_IKINCIL}
              aria-pressed={durum === f.value}
              onClick={() => {
                setDurum(f.value);
                setOffset(0);
              }}
            >
              {t(f.anahtar)}
            </Dugme>
          ))}
        </div>
      </div>

      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("talepPanelNotu", { coz: t("talepCoz"), reddet: t("talepReddet") })}
      </p>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      <ul className="space-y-3">
        {(data?.items ?? []).map((c) => (
          <ComplaintCard key={c.id} complaint={c} onChanged={() => mutate()} />
        ))}
        {data && data.items.length === 0 && !error && (
          <Kart>
            <BosDurum
              baslik={durum ? t("talepDurumdaYok") : t("talepYok")}
              aciklama={durum ? t("talepFiltreDegistir") : t("talepYokAlt")}
            />
          </Kart>
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
  const t = useT();
  // Acik talepte iki eylem: "coz" (opsiyonel not) / "reddet" (zorunlu sebep).
  const [action, setAction] = useState<"coz" | "reddet" | null>(null);
  const canAct = c.durum === "acik";

  return (
    <li className="">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{c.baslik}</h3>
            <DurumBadge durum={c.durum} />
            <span className="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-metin-body">
              {c.kategori_ad ?? t("ortakDiger")}
            </span>
          </div>
          <p className="mt-1 whitespace-pre-wrap text-sm text-metin-body">{c.mesaj}</p>

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
                    <Foto
                      src={f.foto_url ?? undefined}
                      alt={t("gorselAlt", { baslik: c.baslik })}
                      className="h-24 w-24 rounded-lg border kart-kenar object-cover"
                    />
                  </a>
                ))}
            </div>
          )}

          <p className="mt-2 text-xs text-metin-muted">
            {c.acan_ad ?? t("rolSiteSakini")} · {formatDateTime(c.created_at)}
          </p>

          {c.is_emri_id && (
            <div className="mt-3 flex flex-wrap items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-sm">
              <span className="text-blue-700">{t("talepBagliIsEmri")}</span>
              <span className="ms-auto font-medium text-blue-700">
                {t(isEmriAnahtari(c.is_emri_durum))}
              </span>
            </div>
          )}

          {c.gecmis.length > 0 && (
            <Timeline gecmis={c.gecmis} />
          )}
        </div>

        {canAct && !action && (
          <div className="flex shrink-0 flex-col gap-2">
            <Dugme tur="birincil" onClick={() => setAction("coz")}>{t("talepCoz")}</Dugme>
            <Dugme tur="tehlike" boy="kucuk" onClick={() => setAction("reddet")}>
              {t("talepReddet")}
            </Dugme>
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
  const t = useT();
  return (
    <div className="mt-3 border-t border-yuzey-divider pt-3">
      <p className="mb-2 text-xs font-medium text-metin-muted">{t("talepDurumGecmisi")}</p>
      <ol className="space-y-3">
        {gecmis.map((g, i) => {
          const meta = DURUM_META[g.durum as ComplaintDurum];
          return (
            <li key={i} className="flex gap-3 text-sm">
              <span
                className={`mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full ${
                  meta?.cls ?? "bg-slate-100 text-metin-body"
                }`}
              />
              <div className="min-w-0">
                <div className="flex flex-wrap items-baseline gap-x-2">
                  <span style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{meta ? t(meta.anahtar) : g.durum}</span>
                  <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                    {ROLE_ANAHTAR[g.actor_role] ? t(ROLE_ANAHTAR[g.actor_role]) : g.actor_role} ·{" "}
                    {formatDateTime(g.created_at)}
                  </span>
                </div>
                {g.sebep && g.sebep.trim() && (
                  <p className="mt-0.5 whitespace-pre-wrap text-metin-body">{g.sebep}</p>
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
  const t = useT();
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
        toast.success(t("talepReddedildi"));
      } else {
        const notu = text.trim();
        await apiSend(`/api/complaints/${c.id}/resolve`, "POST", {
          cozum_notu: notu || null,
        });
        toast.success(t("talepCozuldu"));
      }
      onDone();
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : t("ortakIslemBasarisiz"));
    } finally {
      setSaving(false);
    }
  }

  return (
    <form
      onSubmit={submit}
      className="mt-4 space-y-4 pt-4"
      style={{ borderTop: "1px solid var(--yz-border)" }}
    >
      <AlanSarmal
        etiket={isReddet ? t("talepRedSebebi") : t("talepCozumNotu")}
        ipucu={isReddet ? t("talepNotZorunlu") : t("talepNotIstege")}
        zorunlu={isReddet}
      >
        {(b) => (
          <CokSatir
            {...b}
            rows={4}
            value={text}
            onChange={(e) => setText(e.target.value)}
            maxLength={5000}
            autoFocus
          />
        )}
      </AlanSarmal>
      {err && (
        <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
          {err}
        </p>
      )}
      <div className="flex gap-2">
        <Dugme
          type="submit"
          tur={isReddet ? TUR_TEHLIKE : TUR_BIRINCIL}
          disabled={submitDisabled}
          yukleniyor={saving}
        >
          {saving ? t("destekGonderiliyor") : isReddet ? t("talepReddet") : t("talepCoz")}
        </Dugme>
        <Dugme type="button" boy="kucuk" onClick={onClose}>
          {t("ortakIptal")}
        </Dugme>
      </div>
    </form>
  );
}
