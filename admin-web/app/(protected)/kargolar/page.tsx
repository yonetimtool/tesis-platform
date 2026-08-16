"use client";

// (P126.4) KARGOLAR — kapı teslimatı + sakinin teslim alması.
//
// Kargo kapıda TESLİM ALINIR, sonra sakine TESLİM EDİLİR: iki ayrı an ve
// iki ayrı durum (`bekliyor` → `teslim_alindi`).
//
// (P162 §5) İKİNCİ AN DA BURADA. Ölçüldü: mobilde sakin kargosunu
// "teslim aldım" diye işaretleyebiliyordu, webde işaretleyemiyordu.
//
// AYRI SAYFA AÇILMADI ve bu bilinçli: `GET /kargo` zaten ROL KAPSAMLI —
// `resident` yalnızca KENDİ dairelerinin kargolarını görür
// (`_aktif_daire_ids`). Yani sakin bu sayfayı açtığında zaten kendi
// listesini görüyordu; eksik olan tek şey düğmeydi. İkinci bir sayfa,
// aynı listeyi iki yerde tutmak olurdu.
//
// DÜĞME ROL FARKINDA ama YETKİ KARARI SUNUCUDA: `PATCH /kargo/{id}`
// yalnız o dairenin aktif sakinine açık (başkasına 404 — varlık
// sızdırılmaz). İstemcideki kontrol yalnızca GÖRÜNÜRLÜK içindir;
// güvenliğe basacağı 404 üreten bir düğme göstermemek için.
import { useState } from "react";
import useSWR from "swr";

import {
  Modal,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihSaatUzun } from "@/lib/tarih";

type Kargo = {
  id: string;
  unit_no: string | null;
  firma: string | null;
  notlar: string | null;
  durum: string;
  created_at: string;
};

// METIN DEGIL KIMLIK (modul duzeyi — tur 18 dersi).
const DURUM_ANAHTARI: Record<string, SozlukAnahtari> = {
  bekliyor: "kargoBekliyor",
  teslim_alindi: "kargoTeslimAlindi",
};

function durumAnahtari(durum: string): SozlukAnahtari {
  const a = DURUM_ANAHTARI[durum];
  if (a) return a;
  // `??` tek satirda yazilirsa sabit-metin taramasi bunu bir uclu sayar.
  return "kargoDurumBilinmiyor";
}

// UCLUDE/GOVDEDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ROL_SAKIN = "resident" as const;
const KARGO_BEKLIYOR = "bekliyor" as const;
const KARGO_TESLIM = "teslim_alindi" as const;

export default function KargolarPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<{ items: Kargo[] }>(
    "/api/kargo?limit=50&offset=0",
    jsonFetcher,
  );

  const [daireNo, setDaireNo] = useState("");
  const [firma, setFirma] = useState("");
  const [notlar, setNotlar] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // Rol: teslim düğmesinin GÖRÜNÜRLÜĞÜ için (yetki sunucuda).
  const { data: ben } = useSWR<{ role?: string }>("/api/me", jsonFetcher);
  const sakinMi = ben?.role === ROL_SAKIN;

  async function teslimAl(id: string) {
    try {
      // Sunucu ATOMİK yapar: `durum='bekliyor'` koşullu UPDATE. Eşler
      // aynı anda bassa bile ikincisi 409 alır ve KİMİN teslim aldığı
      // değişmez.
      await apiSend(`/api/kargo/${id}`, "PATCH", { durum: KARGO_TESLIM });
      toast.success(t("kargoTeslimAlindiBildirim"));
      void mutate();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakHataOlustu")));
    }
  }

  const kayitlar = data?.items ?? [];

  async function kaydet() {
    if (!daireNo.trim()) {
      setHata(t("kargoDaireZorunlu"));
      return;
    }
    setHata(null);
    setGonderiyor(true);
    try {
      // DAIRE NO ile: kapidaki gorevli daire NUMARASINI bilir (ziyaretci
      // ekraniyla ayni gerekce). Sunucu numarayi cozer.
      await apiSend("/api/kargo", "POST", {
        unit_no: daireNo.trim(),
        firma: firma.trim() || null,
        notlar: notlar.trim() || null,
      });
      setDaireNo("");
      setFirma("");
      setNotlar("");
      toast.success(t("kargoKaydedildi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kargoBaslik")}
      </h1>
        <Dugme tur="birincil" boy="kucuk" onClick={() => {
          // (P163 §2) ACILISTA ESKI HATA TEMIZLENIR: modal yeniden acildiginda
          // onceki denemenin mesaji ekranda duruyordu ve kullanici hic
          // denemeden hata gormus oluyordu.
          setHata(null);
          setModalAcik(true);
        }}>
          {t("kargoYeni")}
        </Dugme>
      </div>

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("kargoYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme
            tur="birincil"
            disabled={gonderiyor}
            onClick={() => void kaydet()}
          >
            {gonderiyor ? t("ortakKaydediliyor") : t("kargoTeslimAl")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("kargoDaire")}>
  {(b) => (
    <Alan {...b} value={daireNo}
              onChange={(e) => setDaireNo(e.target.value)}
              maxLength={30} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("kargoFirma")}>
  {(b) => (
    <Alan {...b} value={firma}
              onChange={(e) => setFirma(e.target.value)}
              maxLength={80} />
  )}
</AlanSarmal>
          <AlanSarmal etiket={t("kargoNot")}>
  {(b) => (
    <Alan {...b} value={notlar}
              onChange={(e) => setNotlar(e.target.value)}
              maxLength={500} />
  )}
</AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
        </div>
      </Modal>

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{t("kargoListe")}</h2>
        {error ? <HataDurumu mesaj={t("ortakHataOlustu")} /> : null}
        {isLoading ? (
          <IskeletMetin satir={3} />
        ) : null}
        {!isLoading && !error && kayitlar.length === 0 ? (
          <BosDurum baslik={t("kargoYok")} />
        ) : null}
        {kayitlar.map((k) => (
          <Kart key={k.id} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>{k.unit_no ?? "—"}</h3>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs">
                {t(durumAnahtari(k.durum))}
              </span>
            </div>
            <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
              {tarihSaatUzun(k.created_at)}
              {k.firma ? ` · ${k.firma}` : ""}
            </p>
            {k.notlar ? <p className="text-sm">{k.notlar}</p> : null}
            {/* TESLIM ALDIM — yalniz SAKIN ve yalniz BEKLEYEN kargoda.
                Teslim alinmis bir kargoyu tekrar isaretlemek, geri
                donusu olmayan bir damgayi ikinci kez basmakti (sunucu da
                409 doner). Guvenlikte dugme HIC cizilmez: sunucu ona 404
                verir ve basilacak bir dugme gostermek "yetkim var
                sandim" demektir. */}
            {sakinMi && k.durum === KARGO_BEKLIYOR ? (
              <div className="pt-1">
                <Dugme boy="kucuk" tur="birincil" onClick={() => void teslimAl(k.id)}>
                  {t("kargoTeslimAldim")}
                </Dugme>
              </div>
            ) : null}
          </Kart>
        ))}
      </section>
    </div>
  );
}
