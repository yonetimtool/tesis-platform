"use client";

/**
 * (P253 §D) RESMI KIMLIK ACMA — PLATFORM PANELI.
 *
 * Sikayet edenin kimligi HICBIR site rolune gosterilmez (yonetici dahil).
 * Resmi bir talep (mahkeme, kolluk, KVKK basvurusu) halinde YALNIZ
 * platform yoneticisi buradan acar: gerekce en az 20 karakter ve HER
 * goruntuleme o tesisin denetim kaydina yazilir (sunucu zorlar).
 *
 * Kimlik ekranda yalniz bu oturumda durur; sayfa yenilenince gider —
 * ikinci bakis ikinci bir denetim kaydi demektir.
 */
import { useState } from "react";

import { Alan, AlanSarmal, CokSatir, Dugme, Kart, SayfaBasligi } from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { formatDateTime } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SikayetKimlik } from "@/lib/types";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const GEREKCE_ASGARI = 20;

export default function SikayetKimlikSayfasi() {
  const t = useT();
  const [tesis, setTesis] = useState("");
  const [sikayet, setSikayet] = useState("");
  const [gerekce, setGerekce] = useState("");
  const [mesgul, setMesgul] = useState(false);
  const [hata, setHata] = useState<string | null>(null);
  const [sonuc, setSonuc] = useState<SikayetKimlik | null>(null);

  const tesisGecerli = UUID.test(tesis.trim());
  const sikayetGecerli = UUID.test(sikayet.trim());
  const hazir = tesisGecerli && sikayetGecerli && gerekce.trim().length >= GEREKCE_ASGARI;

  const goster = async () => {
    setMesgul(true);
    setHata(null);
    setSonuc(null);
    try {
      setSonuc(
        await apiSend<SikayetKimlik>("/api/platform/sikayet-kimlik", "POST", {
          tenant_id: tesis.trim(),
          sikayet_id: sikayet.trim(),
          gerekce: gerekce.trim(),
        }),
      );
    } catch (e) {
      setHata(alanliHataMetni(e, t("sikayetIslemHatasi")));
    } finally {
      setMesgul(false);
    }
  };

  const satir = (etiket: string, deger: string | null) => (
    <div className="flex justify-between gap-4 py-1" style={{ fontSize: "var(--yz-fs-sm)" }}>
      <span style={{ color: "var(--yz-text-2)" }}>{etiket}</span>
      <span style={{ color: "var(--yz-text)", fontWeight: 600 }}>{deger ?? "-"}</span>
    </div>
  );

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <SayfaBasligi baslik={t("sikayetKimlikBaslik")} />
      <Kart className="space-y-3">
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("sikayetKimlikAciklama")}
        </p>
        <AlanSarmal
          etiket={t("sikayetKimlikTesis")}
          zorunlu
          hata={tesis && !tesisGecerli ? t("sikayetKimlikGecersizId") : null}
        >
          {(b) => (
            <Alan {...b} maxLength={36} value={tesis} onChange={(e) => setTesis(e.target.value)}
              data-test="kimlik-tesis" />
          )}
        </AlanSarmal>
        <AlanSarmal
          etiket={t("sikayetKimlikSikayetNo")}
          zorunlu
          hata={sikayet && !sikayetGecerli ? t("sikayetKimlikGecersizId") : null}
        >
          {(b) => (
            <Alan {...b} maxLength={36} value={sikayet} onChange={(e) => setSikayet(e.target.value)}
              data-test="kimlik-sikayet" />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("sikayetKimlikGerekce")} zorunlu hata={hata}>
          {(b) => (
            <CokSatir {...b} rows={3} maxLength={1000} value={gerekce}
              onChange={(e) => setGerekce(e.target.value)} data-test="kimlik-gerekce" />
          )}
        </AlanSarmal>
        <Dugme tur="tehlike" disabled={!hazir || mesgul} onClick={goster} data-test="kimlik-goster">
          {t("sikayetKimlikGoster")}
        </Dugme>
      </Kart>
      {sonuc && (
        <Kart className="space-y-1" data-test="kimlik-sonuc">
          {satir(t("sikayetKimlikSonuc"), sonuc.sikayet_eden_ad)}
          {satir(t("sikayetKimlikTelefon"), sonuc.sikayet_eden_telefon)}
          {satir(t("sikayetKimlikEposta"), sonuc.sikayet_eden_eposta)}
          {satir(t("sikayetKimlikKaynak"), sonuc.kaynak_daire)}
          {satir(t("sikayetKimlikHedef"), sonuc.hedef_daire)}
          {satir(t("sikayetKimlikTarih"), formatDateTime(sonuc.created_at))}
          <p className="pt-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
            {t("sikayetKimlikDenetimNotu")}
          </p>
        </Kart>
      )}
    </div>
  );
}
