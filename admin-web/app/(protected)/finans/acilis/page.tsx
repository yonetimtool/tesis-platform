"use client";

// (P167 §4.7) ACILIS FISLERI.
//
// Brief modali: Tarih* · Tipi* · Tutar* · ( ) Borc / ( ) Alacak radyo grubu.
//
// "TIPI" = KASA. Acilis fisi bir kasanin ya da bir kisinin devreden
// bakiyesidir; uc ikisini de destekliyor (`kasa_id` zorunlu, `user_id`
// opsiyonel). Ayri bir "tip" listesi UYDURULMADI.
//
// RADYO GRUBU BILINCLI, acilir liste degil: iki secenekli bir alanda
// acilir liste kullanmak, kullaniciya iki tiklama yaptirir ve secenegin
// ne oldugunu ancak actiktan sonra gosterir. Radyo ikisini de bir
// bakista okutur.

import { useState } from "react";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Modal, Secim } from "@/components/ui";
import { bugun, useKasalar, useKisiler } from "@/components/finans/ortak";
import { HareketSayfasi } from "@/components/finans/hareket-sayfasi";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import { tlToKurus } from "@/lib/money";

const TIP = "acilis";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const YON_GIRIS = "giris";
const YON_CIKIS = "cikis";

export default function AcilisPage() {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const [yenile, setYenile] = useState(0);

  return (
    <HareketSayfasi
      baslikAnahtari="kabukAcilisFisleri"
      tip={TIP}
      raporKodu="kasa_ekstresi"
      yenile={yenile}
      araclar={
        <Dugme tur="birincil" boy="kucuk" onClick={() => setAcik(true)}>
          {t("finansYeni")}
        </Dugme>
      }
      cocuk={
        <AcilisModal
          acik={acik}
          onKapat={() => setAcik(false)}
          onKaydedildi={() => setYenile((n) => n + 1)}
        />
      }
    />
  );
}

function AcilisModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();
  const kisiler = useKisiler();

  const [tarih, setTarih] = useState(bugun());
  const [kasaId, setKasaId] = useState("");
  const [kisiId, setKisiId] = useState("");
  const [tutar, setTutar] = useState("");
  const [yon, setYon] = useState(YON_GIRIS);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  const secKasa = kasaId || kasalar[0]?.id || "";

  async function kaydet() {
    if (!secKasa) { setHata(t("finansKasaGerekli")); return; }
    const kurus = tlToKurus(tutar);
    if (!kurus || kurus <= 0) { setHata(t("finansTutarGerekli")); return; }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/finans-acilis", "POST", {
        kasa_id: secKasa,
        user_id: kisiId || null,
        yon,
        tutar_kurus: kurus,
        tarih: tarih || null,
      });
      toast.success(t("finansKaydedildi"));
      setTutar(""); setKisiId("");
      onKaydedildi();
      onKapat();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Modal
      acik={acik}
      baslik={t("kabukAcilisFisleri")}
      onKapat={onKapat}
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="grid gap-3">
        <AlanSarmal etiket={t("finansAlanTarih")} zorunlu>
          {(b) => <Alan {...b} type="date" value={tarih} onChange={(e) => setTarih(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansSutunKasa")} zorunlu>
          {(b) => (
            <Secim {...b} value={secKasa} onChange={(e) => setKasaId(e.target.value)}>
              <option value="">{t("finansKasaSec")}</option>
              {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        {/* KISI OPSIYONEL: bos birakilirsa KASA acilis bakiyesi, doluysa
            KISI bazli devreden borc/alacak (uc ikisini de destekliyor). */}
        <AlanSarmal etiket={t("finansSutunKisi")}>
          {(b) => (
            <Secim {...b} value={kisiId} onChange={(e) => setKisiId(e.target.value)}>
              <option value="">{t("finansKisiSec")}</option>
              {kisiler.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => <Alan {...b} value={tutar} inputMode="decimal" onChange={(e) => setTutar(e.target.value)} />}
        </AlanSarmal>

        {/* RADYO GRUBU — `fieldset`/`legend` bilincli: ekran okuyucu her
            secenegi "Yon: Borc" diye okur. Ayri `label`larla sarilmis iki
            girdi, grubun ADINI kaybederdi. */}
        <fieldset className="border-0 p-0">
          <legend
            className="mb-1"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          >
            {t("finansAlanYon")}
          </legend>
          <div className="flex gap-4">
            {[
              { id: YON_CIKIS, etiket: t("finansYonBorc") },
              { id: YON_GIRIS, etiket: t("finansYonAlacak") },
            ].map((s) => (
              <label key={s.id} className="flex items-center gap-2 text-sm">
                <input
                  type="radio"
                  name="acilis-yon"
                  value={s.id}
                  checked={yon === s.id}
                  onChange={() => setYon(s.id)}
                />
                {s.etiket}
              </label>
            ))}
          </div>
        </fieldset>

        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
