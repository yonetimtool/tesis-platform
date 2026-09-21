"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  FiltreCubugu,
  Rozet,
  SayfaBasligi,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
} from "@/components/ui";
import { rolAdi } from "@/lib/roles";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AuditLog, AuditLogList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`). "platform" bir
// KAPSAM KIMLIGIDIR (tenant'i olmayan kayit), cumle degil.
const PLATFORM = "platform" as const;
// Yer tutucu bir ORNEK DEGER (kaynak tipi), cevrilecek bir cumle degil.
const KAYNAK_IPUCU = "app_user";
const ROZET_NOTR = "notr" as const;

/** Denetim satiri — `AuditLog` sozlesmesi. */
type DenetimSatiri = AuditLog;

// Yaygin action'lar (serbest-metin; liste yalniz kolaylik). Bos = tumu.
const ACTIONS = [
  "", "login_ok", "login_fail", "password_change", "password_set",
  "resident_create", "resident_update", "resident_delete", "resident_erasure",
  "user_create", "user_update", "user_contact_update",
  "phone_reveal", "call_initiate", "kargo_photo_view",
  "visitor_create", "kargo_create", "kargo_receive",
  "unit_access_request", "unit_access_decide",
  "complaint_create", "complaint_resolve", "complaint_decline",
  "dues_assessment_create", "dues_payment_record",
  "block_create", "block_delete", "unit_create", "unit_delete",
  "erasure_run",
];

/** Islem suzgeci secenekleri — bos deger "tumu". */
function ISLEM_SECENEKLERI(t: (a: "ortakTumu") => string) {
  return ACTIONS.map((a) => (
    <option key={a} value={a}>
      {a === "" ? t("ortakTumu") : a}
    </option>
  ));
}

export default function AuditPage() {
  const t = useT();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 50,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const [action, setAction] = useState("");
  const [resourceType, setResourceType] = useState("");
  const [tenantId, setTenantId] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const qs = new URLSearchParams({ limit: String(tabloDurumu.boy), offset: String(offset) });
  if (action) qs.set("action", action);
  if (resourceType) qs.set("resource_type", resourceType);
  if (tenantId) qs.set("tenant_id", tenantId);
  if (from) qs.set("from", from);
  if (to) qs.set("to", to);

  const { data, error, isLoading, mutate } = useSWR<AuditLogList>(
    `/api/audit?${qs.toString()}`,
    jsonFetcher,
  );

  function reset(setter: (v: string) => void) {
    return (v: string) => {
      setter(v);
      setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
    };
  }

  const rows: AuditLog[] = data?.items ?? [];

  const kolonlar: Kolon<DenetimSatiri>[] = useMemo(
    () => [
      {
        id: "ts",
        baslik: t("denetimZaman"),
        gizlenebilir: false,
        hucre: (r) => <span className="whitespace-nowrap">{formatDateTime(r.ts)}</span>,
      },
      {
        id: "action",
        baslik: t("denetimIslem"),
        // Islem kodu TEKNIK KIMLIKTIR (`user.create`), cevrilmez.
        hucre: (r) => <Rozet durum={ROZET_NOTR}>{r.action}</Rozet>,
      },
      {
        // (P66) HAM TEL DEGERI DEGIL: denetim kaydinda rol
        // `admin`/`yonetici` diye ciziliyordu, oysa panelin geri kalani
        // `rolAdi` ile cevirir. Denetim kaydi "kim ne yapti"nin
        // kanitidir; orada kullanicinin taniyamadigi bir jeton
        // gostermek, kaydi okunamaz kilar.
        id: "rol",
        baslik: t("ortakRol"),
        hucre: (r) => (r.actor_rol ? rolAdi(t, r.actor_rol) : "—"),
      },
      {
        id: "kaynak",
        baslik: t("denetimKaynak"),
        hucre: (r) =>
          r.resource_type ? (
            <span className="font-mono" style={{ fontSize: "var(--yz-fs-xs)" }}>
              {r.resource_type}
              {r.resource_id ? `:${r.resource_id.slice(0, 8)}…` : ""}
            </span>
          ) : (
            "—"
          ),
      },
      {
        id: "tenant",
        baslik: t("ortakTesis"),
        darEkrandaGizle: true,
        hucre: (r) => (
          <span className="font-mono" style={{ fontSize: "var(--yz-fs-xs)" }}>
            {r.tenant_id ? `${r.tenant_id.slice(0, 8)}…` : PLATFORM}
          </span>
        ),
      },
      {
        id: "meta",
        baslik: t("denetimMeta"),
        darEkrandaGizle: true,
        hucre: (r) => (
          <code
            className="block max-w-xs truncate"
            style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
          >
            {Object.keys(r.meta ?? {}).length ? JSON.stringify(r.meta) : "—"}
          </code>
        ),
      },
    ],
    [t],
  );

  return (
    <div>
      <SayfaBasligi baslik={t("kabukDenetimKaydi")} aciklama={t("denetimAciklama")} />

      {/* (P244 §9c) SUZGECLER TABLONUN DISINDA.
          `araclar` yuvasindayken, liste hata alinca tablo "tekrar dene"
          cizer ve SUZGECLER DE ONUNLA KAYBOLURDU — oysa kullanicinin
          ilk refleksi suzgeci degistirip tekrar denemektir. Ayni kusur
          §9b'de /users'ta olculmustu; bu tur geri kalan dort ekrani
          kapatiyor. */}
      <FiltreCubugu
        aktifSayi={
          (action ? 1 : 0) +
          (resourceType.trim() ? 1 : 0) +
          (tenantId.trim() ? 1 : 0) +
          (from ? 1 : 0) +
          (to ? 1 : 0)
        }
        onTemizle={() => {
          reset(setAction)("");
          reset(setResourceType)("");
          reset(setTenantId)("");
          reset(setFrom)("");
          reset(setTo)("");
        }}
      >
        {/* GORUNMEZ ETIKET: serit her kontrolun ustune bir etiket satiri
            koyunca iki kata cikiyordu; ad `aria-label` ile KALIR. */}
        <Secim
          aria-label={t("denetimIslem")}
          value={action}
          onChange={(e) => reset(setAction)(e.target.value)}
          className="w-auto"
        >
          {ISLEM_SECENEKLERI(t)}
        </Secim>
        <Alan
          aria-label={t("denetimKaynakTipi")}
          value={resourceType}
          onChange={(e) => reset(setResourceType)(e.target.value)}
          placeholder={KAYNAK_IPUCU}
          className="w-40"
        />
        <Alan
          aria-label={t("ayarTenantId")}
          value={tenantId}
          onChange={(e) => reset(setTenantId)(e.target.value)}
          placeholder={t("denetimTumu")}
          className="w-40"
        />
        <Alan
          aria-label={t("ortakBaslangic")}
          type="date"
          value={from}
          onChange={(e) => reset(setFrom)(e.target.value)}
          className="w-auto"
        />
        <Alan
          aria-label={t("ortakBitis")}
          type="date"
          value={to}
          onChange={(e) => reset(setTo)(e.target.value)}
          className="w-auto"
        />
      </FiltreCubugu>

      <VeriTablosu<DenetimSatiri>
        kolonlar={kolonlar}
        satirlar={rows}
        satirId={(r) => r.id}
        hata={error ? t("denetimYuklenemedi") : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("denetimKayitYok")}
        bosAciklama={t("denetimKayitYokAlt")}
        sunucuTarafli
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />
    </div>
  );
}
