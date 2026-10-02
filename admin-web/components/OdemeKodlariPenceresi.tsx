"use client";

// (P250 §2) ODEME KODLARI PENCERESI — kopyala, sec, e-postayla gonder.
//
// (P193 §7) yalniz bir liste gosteriyordu. Simdi:
//   * her kodun yaninda KOPYALA (ortak `KopyaKod`),
//   * satir secimi + TUMUNU SEC, secilenlere toplu e-posta,
//   * satir basina tek kisiye e-posta,
//   * son e-postanin TESLIM DURUMU (P234 geri bildirimi): gonderildi /
//     iletildi / geri dondu,
//   * yeni eklenen kisi EN USTTE (sunucu siralar).
//
// Hiz siniri ve "ayni kisiye kisa surede tekrar gonderme" korumasi
// SUNUCUDADIR; bu bilesen atlananlari sayisiyla bildirir.
import { useCallback, useEffect, useMemo, useState } from "react";

import { KopyaKod } from "@/components/KopyaKod";
import { useToast } from "@/components/Toast";
import { Dugme, Modal, Rozet, type RozetDurumu } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export type OdemeKoduSatiri = {
  user_id: string;
  ad: string;
  daire_no: string | null;
  odeme_kodu: string;
  email?: string | null;
  eposta_durumu?: string | null;
  eposta_zamani?: string | null;
  eposta_engeli?: string | null;
};

type Liste = { uretilen: number; items: OdemeKoduSatiri[] };
type Sonuc = {
  gonderilen: number;
  kuyruga_alinan: number;
  atlananlar: { user_id: string; sebep: string }[];
};

const DURUM_METNI: Record<string, SozlukAnahtari> = {
  kuyrukta: "odemeKoduDurumkuyrukta",
  gonderildi: "odemeKoduDurumgonderildi",
  iletildi: "odemeKoduDurumiletildi",
  geri_dondu: "odemeKoduDurumgeri_dondu",
  basarisiz: "odemeKoduDurumbasarisiz",
  yapilandirilmadi: "odemeKoduDurumyapilandirilmadi",
};
const DURUM_TONU: Record<string, RozetDurumu> = {
  kuyrukta: "bilgi",
  gonderildi: "bilgi",
  iletildi: "olumlu",
  geri_dondu: "kritik",
  basarisiz: "kritik",
  yapilandirilmadi: "uyari",
};
const ENGEL_METNI: Record<string, SozlukAnahtari> = {
  eposta_yok: "odemeKoduEngeleposta_yok",
  eposta_kapali: "odemeKoduEngeleposta_kapali",
};
const TON_NOTR: RozetDurumu = "notr";
// Bilinmeyen sunucu degeri icin yedek metinler (JSX icinde dize yazilmaz).
const ENGEL_YEDEK: SozlukAnahtari = "odemeKoduEngeleposta_yok";
const DURUM_YEDEK: SozlukAnahtari = "odemeKoduDurumbasarisiz";
const TON_UYARI: RozetDurumu = "uyari";

export function OdemeKodlariPenceresi({
  acik,
  onKapat,
}: {
  acik: boolean;
  onKapat: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [liste, setListe] = useState<Liste | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [secili, setSecili] = useState<Set<string>>(new Set());
  const [gonderiyor, setGonderiyor] = useState(false);

  const yukle = useCallback(async () => {
    setHata(null);
    try {
      // POST cunku uc YAZAR: eksik kodlari uretir (tembel uretim).
      setListe(await apiSend<Liste>("/api/users/odeme-kodlari", "POST", {}));
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }, [t]);

  useEffect(() => {
    if (!acik) return;
    setListe(null);
    setSecili(new Set());
    void yukle();
  }, [acik, yukle]);

  // Yalniz GONDERILEBILIR satirlar secilebilir: adressiz ya da e-postayi
  // kapatmis kisiyi secip "gonderilmedi" mesaji almak bosuna adimdir.
  const secilebilir = useMemo(
    () => (liste?.items ?? []).filter((k) => !k.eposta_engeli).map((k) => k.user_id),
    [liste],
  );
  const tumuSecili = secilebilir.length > 0 && secilebilir.every((id) => secili.has(id));

  function tumunuSec(acikMi: boolean) {
    setSecili(acikMi ? new Set(secilebilir) : new Set());
  }

  function sec(id: string, acikMi: boolean) {
    const yeni = new Set(secili);
    if (acikMi) yeni.add(id);
    else yeni.delete(id);
    setSecili(yeni);
  }

  async function gonder(idler: string[]) {
    if (idler.length === 0) return;
    setGonderiyor(true);
    try {
      const s = await apiSend<Sonuc>("/api/users/odeme-kodlari/eposta", "POST", {
        user_ids: idler,
      });
      if (s.gonderilen > 0) toast.success(t("odemeKoduGonderildiTek"));
      if (s.kuyruga_alinan > 0) toast.success(t("odemeKoduKuyruga", { n: s.kuyruga_alinan }));
      if (s.atlananlar.length > 0) {
        toast.error(t("odemeKoduAtlandi", { n: s.atlananlar.length }));
      }
      setSecili(new Set());
      await yukle();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  return (
    <Modal
      acik={acik}
      onKapat={onKapat}
      baslik={t("kullaniciOdemeKodlari")}
      genislikSinifi="max-w-3xl"
      eylemler={
        <>
          <Dugme
            tur="birincil"
            data-test="odeme-kodu-toplu-gonder"
            disabled={gonderiyor || secili.size === 0}
            onClick={() => void gonder([...secili])}
          >
            {t("odemeKoduSecilenlereGonder", { n: secili.size })}
          </Dugme>
          <Dugme tur="sessiz" onClick={onKapat}>
            {t("ortakKapat")}
          </Dugme>
        </>
      }
    >
      <div className="space-y-3">
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("kullaniciOdemeKodlariAciklama")}
        </p>
        {hata && (
          <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
            {hata}
          </p>
        )}
        {liste && liste.items.length === 0 && (
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("odemeKoduBos")}
          </p>
        )}
        {liste && liste.items.length > 0 && (
          <>
            <label className="inline-flex items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
              <input
                type="checkbox"
                data-test="odeme-kodu-tumunu-sec"
                checked={tumuSecili}
                disabled={secilebilir.length === 0}
                onChange={(e) => tumunuSec(e.target.checked)}
              />
              {t("odemeKoduTumunuSec")}
            </label>
            <ul className="divide-y" style={{ borderColor: "var(--yz-border)" }}>
              {liste.items.map((k) => {
                const durum = k.eposta_durumu ?? null;
                return (
                  <li
                    key={k.user_id}
                    data-test="odeme-kodu-satiri"
                    className="flex flex-wrap items-center gap-x-3 gap-y-1 py-2"
                    style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                  >
                    <input
                      type="checkbox"
                      data-test="odeme-kodu-sec"
                      aria-label={t("odemeKoduSecimEtiketi", { ad: k.ad })}
                      checked={secili.has(k.user_id)}
                      disabled={Boolean(k.eposta_engeli)}
                      onChange={(e) => sec(k.user_id, e.target.checked)}
                    />
                    <span className="font-semibold">
                      <KopyaKod deger={k.odeme_kodu} etiket={t("kullaniciOdemeKodu")} />
                    </span>
                    <span className="min-w-0 flex-1 break-words" style={{ color: "var(--yz-text-2)" }}>
                      {k.daire_no ?? "—"} · {k.ad}
                      {k.email ? ` · ${k.email}` : ""}
                    </span>
                    {k.eposta_engeli ? (
                      <Rozet durum={TON_UYARI}>
                        {t(ENGEL_METNI[k.eposta_engeli] ?? ENGEL_YEDEK)}
                      </Rozet>
                    ) : durum ? (
                      <Rozet durum={DURUM_TONU[durum] ?? TON_NOTR} nokta>
                        {t(DURUM_METNI[durum] ?? DURUM_YEDEK)}
                      </Rozet>
                    ) : (
                      <Rozet durum={TON_NOTR}>{t("odemeKoduHicGonderilmedi")}</Rozet>
                    )}
                    <Dugme
                      boy="kucuk"
                      tur="sessiz"
                      data-test="odeme-kodu-gonder"
                      aria-label={t("odemeKoduEpostaGonderEtiketi", { ad: k.ad })}
                      disabled={gonderiyor || Boolean(k.eposta_engeli)}
                      onClick={() => void gonder([k.user_id])}
                    >
                      {t("odemeKoduEpostaGonder")}
                    </Dugme>
                  </li>
                );
              })}
            </ul>
          </>
        )}
      </div>
    </Modal>
  );
}
