"use client";

import { useState } from "react";
import useSWR from "swr";

import { Alan, AlanSarmal, BosDurum, CokSatir, Dugme, HataDurumu, IskeletMetin, Kart, Modal, Rozet, Secim, Tablo, TabloBasligi, Td, Th, useOnay } from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import { ParolaAlani } from "@/components/ParolaAlani";
import { DiyafonBolumu } from "@/components/diyafon/diyafon-bolumu";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type {
  AuthType,
  HttpMethod,
  Integration,
  IntegrationChannel,
  IntegrationList,
  IntegrationPreset,
  IntegrationTriggerResult,
} from "@/lib/types";

interface FormState {
  ad: string;
  channel_type: IntegrationChannel;
  endpoint_url: string;
  http_method: HttpMethod;
  headers_text: string; // JSON metni (gizli OLMAYAN header'lar)
  auth_type: AuthType;
  auth_secret: string; // write-only; doluysa gonderilir
  payload_template: string;
  aktif: boolean;
}
const EMPTY: FormState = {
  ad: "",
  channel_type: "webhook",
  endpoint_url: "",
  http_method: "POST",
  headers_text: "{}",
  auth_type: "none",
  auth_secret: "",
  payload_template: "",
  aktif: true,
};

/** (P240 §4) Saglik durumu -> sozluk anahtari. */
const SAGLIK_ETIKET: Record<string, SozlukAnahtari> = {
  bilinmiyor: "entegSaglikBilinmiyor",
  bagli: "entegSaglikBagli",
  hata: "entegSaglikHata",
};
const SAGLIK_YEDEK: SozlukAnahtari = "entegSaglikBilinmiyor";
/** JSX ucluda sabit dize yazilamaz (depo kurali `sabit-metin`). */
const SAGLIK_VARSAYILAN = "bilinmiyor";
/** Hata KIMLIGI -> sozluk anahtari (sunucu cumle gondermez). */
const HATA_ETIKET: Record<string, SozlukAnahtari> = {
  entegrasyon_adres_engelli: "entegHataAdresEngelli",
  entegrasyon_adres_cozulemedi: "entegHataAdresCozulemedi",
  entegrasyon_baglanti_yok: "entegHataBaglantiYok",
  entegrasyon_adres_gecersiz: "entegHataAdresGecersiz",
};
const HATA_YEDEK: SozlukAnahtari = "entegHataBaglantiYok";
const IKINCIL = "ikincil" as const;

const CHANNELS: IntegrationChannel[] = ["webhook", "megaphone", "smarthome"];
const METHODS: HttpMethod[] = ["POST", "PUT", "PATCH", "GET"];
const AUTH_TYPES: AuthType[] = ["none", "bearer", "api_key"];

export default function IntegrationsPage() {
  const t = useT();
  // (P161) Yikici onaylar yerel `confirm()` degil, tema/dil taniyan diyalog.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<IntegrationList>(
    "/api/integrations?limit=200",
    jsonFetcher,
  );
  const { data: presets } = useSWR<IntegrationPreset[]>(
    "/api/integrations/presets",
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingSecretSet, setEditingSecretSet] = useState(false);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [testResult, setTestResult] = useState<Record<string, IntegrationTriggerResult>>({});
  const [testing, setTesting] = useState<string | null>(null);
  const [kontrolEdilen, setKontrolEdilen] = useState<string | null>(null);

  /** (P240 §4) Baglanti kontrolu — TETIKLEMEZ, yalniz TCP acar. */
  async function saglikKontrol(it: Integration) {
    setKontrolEdilen(it.id);
    try {
      await apiSend(`/api/integrations/${it.id}/saglik`, "POST", {});
      await mutate();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKontrolEdilen(null);
    }
  }

  function openNew() {
    setEditingId(null);
    setEditingSecretSet(false);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }

  function applyPreset(key: string) {
    const p = presets?.find((x) => x.key === key);
    if (!p) return;
    setForm((f) => ({
      ...f,
      channel_type: p.channel_type,
      http_method: p.http_method,
      headers_text: JSON.stringify(p.headers_json, null, 2),
      payload_template: p.payload_template,
    }));
  }

  async function openEdit(it: Integration) {
    setEditingId(it.id);
    setEditingSecretSet(it.auth_secret_set);
    setForm({
      ad: it.ad,
      channel_type: it.channel_type,
      endpoint_url: it.endpoint_url,
      http_method: it.http_method,
      headers_text: JSON.stringify(it.headers_json ?? {}, null, 2),
      auth_type: it.auth_type,
      auth_secret: "", // sir GET'te gelmez; boş = değiştirme
      payload_template: it.payload_template,
      aktif: it.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    let headers_json: Record<string, string>;
    try {
      headers_json = form.headers_text.trim() ? JSON.parse(form.headers_text) : {};
    } catch {
      setSaving(false);
      setFormErr(t("entegHeaderJson"));
      return;
    }
    try {
      const base: Record<string, unknown> = {
        ad: form.ad,
        channel_type: form.channel_type,
        endpoint_url: form.endpoint_url,
        http_method: form.http_method,
        headers_json,
        auth_type: form.auth_type,
        payload_template: form.payload_template,
        aktif: form.aktif,
      };
      // Sir yalnızca girildiyse gönderilir (write-only; boş = değiştirme).
      if (form.auth_secret) base.auth_secret = form.auth_secret;
      if (editingId) await apiSend(`/api/integrations/${editingId}`, "PATCH", base);
      else await apiSend("/api/integrations", "POST", base);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("entegGuncellendi") : t("entegOlusturuldu"));
    } catch (err) {
      setFormErr(err instanceof Error ? err.message : t("ortakKaydedilemedi"));
    } finally {
      setSaving(false);
    }
  }

  async function remove(it: Integration) {
    if (!(await onayla({ baslik: t("ortakSilBaslik"), mesaj: t("ortakSilOnay", { ad: it.ad }), onayMetni: t("ortakSil"), tehlikeli: true }))) return;
    try {
      await apiSend(`/api/integrations/${it.id}`, "DELETE");
      mutate();
      toast.success(t("entegrasyonSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  async function test(it: Integration) {
    setTesting(it.id);
    try {
      const res = await apiSend<IntegrationTriggerResult>(
        `/api/integrations/${it.id}/trigger`,
        "POST",
        { message: t("entegTestMesaji"), title: "Test" },
      );
      setTestResult((m) => ({ ...m, [it.id]: res }));
    } catch (err) {
      setTestResult((m) => ({
        ...m,
        [it.id]: { ok: false, error: err instanceof Error ? err.message : t("ortakHataOlustu") },
      }));
    } finally {
      setTesting(null);
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kabukEntegrasyonlar")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("entegAciklama")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("entegYeni")}
        </Dugme>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("entegDuzenle") : t("entegYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="enteg-form" tur="birincil" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="enteg-form" onSubmit={save} className="space-y-4">
          {!editingId && presets && presets.length > 0 && (
            <AlanSarmal etiket={t("entegSablon")} ipucu={t("entegSablonIpucu")}>
  {(b) => (
    <Secim {...b} defaultValue=""
                onChange={(e) => e.target.value && applyPreset(e.target.value)}
              >
                <option value="">{t("entegSablonSec")}</option>
                {presets.map((p) => (
                  <option key={p.key} value={p.key}>
                    {p.key}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
          )}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <AlanSarmal etiket={t("ortakAd")}>
  {(b) => (
    <Alan {...b} value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("entegKanalTipi")}>
  {(b) => (
    <Secim {...b} value={form.channel_type}
                onChange={(e) =>
                  setForm({ ...form, channel_type: e.target.value as IntegrationChannel })
                }
              >
                {CHANNELS.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("entegEndpointUrl")} ipucu={t("entegUrlIpucu")}>
  {(b) => (
    <Alan {...b} value={form.endpoint_url}
                onChange={(e) => setForm({ ...form, endpoint_url: e.target.value })}
                placeholder="https://..."
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("entegHttpMetodu")}>
  {(b) => (
    <Secim {...b} value={form.http_method}
                onChange={(e) => setForm({ ...form, http_method: e.target.value as HttpMethod })}
              >
                {METHODS.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("entegKimlikDogrulama")}>
  {(b) => (
    <Secim {...b} value={form.auth_type}
                onChange={(e) => setForm({ ...form, auth_type: e.target.value as AuthType })}
              >
                {AUTH_TYPES.map((a) => (
                  <option key={a} value={a}>
                    {a}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            {/* PAROLA ALANI kendi etiketini `AlanSarmal`dan alir; gorunur
                etiket + ipucu ayni sarmalayicidan gelir. */}
            <AlanSarmal
              etiket={t("entegSir")}
              ipucu={editingSecretSet ? t("entegSirKayitli") : t("entegSirYazmaOzel")}
            >
              {(b) => (
                <ParolaAlani
                  // `AlanSarmal`in urettigi kimlik BAGLANMALI: etiket
                  // `htmlFor` ile bu kimlige isaret ediyor. Baglamazsak
                  // gorunur bir etiket var ama denetimle ILISKISIZ olur.
                  id={b.id}
                  value={form.auth_secret}
                  onChange={(v) => setForm({ ...form, auth_secret: v })}
                  placeholder={editingSecretSet ? t("entegSirBos") : ""}
                  disabled={form.auth_type === "none"}
                />
              )}
            </AlanSarmal>
          </div>
          <AlanSarmal etiket={t("entegHeaderlar")}>
            {(b) => (
              <CokSatir {...b} rows={4}
              value={form.headers_text}
              onChange={(e) => setForm({ ...form, headers_text: e.target.value })} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("entegPayloadSablonu")} ipucu={t("entegYerTutucular")}>
            {(b) => (
              <CokSatir {...b} rows={4}
              value={form.payload_template}
              onChange={(e) => setForm({ ...form, payload_template: e.target.value })} />
            )}
          </AlanSarmal>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />{t("ortakAktif")}</label>
          <HataDurumu mesaj={formErr} />
        </form>
      </Modal>

      <div className="overflow-hidden rounded-kart border kart-kenar bg-white">
        <div className="odak-ic overflow-x-auto" tabIndex={0}>
          <Tablo>
            <TabloBasligi>
                <Th>{t("ortakAd")}</Th>
                <Th>{t("entegKanal")}</Th>
                <Th>{t("entegEndpoint")}</Th>
                <Th>{t("entegKimlik")}</Th>
                <Th>{t("ortakAktif")}</Th>
                {/* (P240 §4) SAGLIK — tek ekrandan hepsi gorunsun. */}
                <Th>{t("entegSaglik")}</Th>
                <Th>{t("entegSonIletisim")}</Th>
                <Th />
              </TabloBasligi>
            <tbody>
            {(data?.items ?? []).map((it) => {
              const tr = testResult[it.id];
              return (
                <tr key={it.id} className={`border-t border-yuzey-divider transition-colors hover:bg-yuzey-bg ${it.aktif ? "" : "bg-yuzey-bg"}`}>
                  <Td>{it.ad}</Td>
                  <Td className="text-metin-body">{it.channel_type}</Td>
                  <Td className="text-metin-body max-w-[280px] truncate">
                    {it.http_method} {it.endpoint_url}
                  </Td>
                  <Td className="text-metin-body">
                    {it.auth_type}
                    {it.auth_secret_set ? " 🔒" : ""}
                  </Td>
                  <Td>{it.aktif ? t("ortakEvet") : "—"}</Td>
                  <Td>
                    <span data-test={`enteg-saglik-${it.id}`}>
                    <Rozet
                      durum={
                        it.saglik === "bagli"
                          ? "olumlu"
                          : it.saglik === "hata"
                            ? "kritik"
                            : "notr"
                      }
                    >
                      {t(SAGLIK_ETIKET[it.saglik ?? SAGLIK_VARSAYILAN] ?? SAGLIK_YEDEK)}
                    </Rozet>
                    </span>
                    {/* HATA SEBEBI ANLASILIR DILDE: sunucu KIMLIK
                        gonderiyor, cumle burada kullanicinin dilinde
                        kuruluyor. Ham ayrinti (istisna tipi, sunucu adi)
                        arayuze HIC gelmiyor. */}
                    {it.son_hata_kod && (
                      <div
                        data-test={`enteg-hata-${it.id}`}
                        style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-danger-ink)" }}
                      >
                        {t(HATA_ETIKET[it.son_hata_kod] ?? HATA_YEDEK)}
                      </div>
                    )}
                  </Td>
                  <Td className="text-metin-body">
                    <span data-test={`enteg-son-iletisim-${it.id}`}>
                    {/* SON BASARILI ILETISIM — "hic" ile "uzun zaman
                        once" ayni sey degil; bos birakmak ikisini
                        birbirine karistirirdi. */}
                    {it.son_basarili_at
                      ? formatDateTime(it.son_basarili_at)
                      : t("entegHicIletisim")}
                    </span>
                  </Td>
                  <Td hizala="end">
                    <div className="flex flex-col items-end gap-1">
                      <div className="flex justify-end gap-2">
                        {/* (P240 §4) IKI AYRI DUGME — ve ayrim yazili.

                            "Kontrol et" YALNIZ BAGLANTIYA bakar (TCP);
                            "Test" ise entegrasyonu GERCEKTEN TETIKLER.
                            Tek dugmeye indirmek, megafon kanalinda
                            "kontrol edeyim" diyen yoneticiye siteye
                            anons YAPTIRIRDI. */}
                        <Dugme
                          boy="kucuk"
                          tur={IKINCIL}
                          data-test={`enteg-saglik-kontrol-${it.id}`}
                          onClick={() => saglikKontrol(it)}
                          disabled={kontrolEdilen === it.id}
                        >
                          {kontrolEdilen === it.id
                            ? t("entegKontrolEdiliyor")
                            : t("entegKontrolEt")}
                        </Dugme>
                        <Dugme
                          boy="kucuk"
                          onClick={() => test(it)}
                          disabled={testing === it.id}
                          title={t("entegTestIpucu")}
                        >
                          {testing === it.id ? t("entegTestEdiliyor") : t("entegTest")}
                        </Dugme>
                        <Dugme boy="kucuk" onClick={() => openEdit(it)}>
                          {t("ortakDuzenle")}
                        </Dugme>
                        <Dugme tur="tehlike" boy="kucuk" onClick={() => remove(it)}>
                          {t("ortakSil")}
                        </Dugme>
                      </div>
                      {tr && (
                        <span
                          className={`text-xs ${tr.ok ? "text-emerald-700" : "text-red-700"}`}
                        >
                          {tr.ok
                            ? t("entegBasarili", { kod: tr.status ?? "—" })
                            : `✗ ${tr.error ?? t("entegBasarisiz")}${tr.status ? ` (${tr.status})` : ""}`}
                        </span>
                      )}
                    </div>
                  </Td>
                </tr>
              );
            })}
            {data && data.items.length === 0 && (
              <tr>
                <Td colSpan={8}>
                  <BosDurum baslik={t("entegYok")} aciklama={t("entegYokAlt")} />
                </Td>
              </tr>
            )}
            </tbody>
          </Tablo>
        </div>
      </div>
      {diyalog}

      {/* (P240 §2) DIYAFON — AYNI EKRANDA.

          Ayri bir menu girisi acmak, yoneticinin "bagli mi" sorusunu
          iki ayri ekranda sormasi demekti; §4'un istegi tek bir
          "Entegrasyonlar" ekrani. */}
      <DiyafonBolumu />
    </div>
  );
}
