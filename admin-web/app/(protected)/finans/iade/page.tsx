"use client";

// (P167 §4.6) ODEME IADESI.
//
// Brief modali: Tarih* · Kisi* · Bagimsiz Bolum* · Borclandirma Turu* ·
// Kasa* (varsayilan Nakit) · Tutar* · Aciklama.
//
// UC BASKA BIR SEY ISTIYOR ve dogrusu o: `IadeIstek` bir `hareket_id`
// aliyor — YANI HANGI TAHSILATIN iade edildigi. Kisi/daire/kasa o
// hareketten TURETILIR (`routers/finans.py`: `kasa_id=orijinal.kasa_id`,
// `user_id=orijinal.user_id`).
//
// NEDEN BOYLE DOGRU: iade "birine para vermek" degil "alinmis bir parayi
// geri vermek"tir. Kisiyi ve kasayi elle sectirmek, iadeyi orijinal
// tahsilattan BAGIMSIZ bir hareket yapar ve "hangi tahsilat iade edildi"
// sorusu ancak aciklama metnine bakilarak cevaplanabilirdi. Ustelik
// yanlis kasadan iade, iki kasayi birden bozardi.
//
// Bu yuzden form KISI ILE BASLAR ama kisiden sonra ONUN TAHSILATLARINI
// listeler; secilen tahsilat kisiyi, daireyi ve kasayi kendisi getirir.
// Brief'in istedigi alanlar EKRANDA GORUNUR — yalnizca hangisinin
// yazilabilir hangisinin turetilmis oldugu degisti.

import { useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Modal, Secim } from "@/components/ui";
import { bugun, useKisiler } from "@/components/finans/ortak";
import {
  HareketSayfasi,
  type Hareket,
} from "@/components/finans/hareket-sayfasi";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";

const TIP = "iade";

export default function IadePage() {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const [yenile, setYenile] = useState(0);

  return (
    <HareketSayfasi
      baslikAnahtari="kabukIade"
      tip={TIP}
      raporKodu="finansal_hareketler"
      yenile={yenile}
      araclar={
        <Dugme tur="birincil" boy="kucuk" onClick={() => setAcik(true)}>
          {t("finansYeni")}
        </Dugme>
      }
      cocuk={
        <IadeModal
          acik={acik}
          onKapat={() => setAcik(false)}
          onKaydedildi={() => setYenile((n) => n + 1)}
        />
      }
    />
  );
}

function IadeModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kisiler = useKisiler();

  const [kisiId, setKisiId] = useState("");
  const [hareketId, setHareketId] = useState("");
  const [tutar, setTutar] = useState("");
  const [tarih, setTarih] = useState(bugun());
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  // (P192 §6.2) IDEMPOTENCY ANAHTARI — uc basligi ANLIYOR ama bu ekran
  // GONDERMIYORDU: zaman asimi sonrasi tekrar (kullanici "kaydedilmedi"
  // sanip yeniden basar) kasada IKI hareket olusturabilirdi. Anahtar
  // FORM ORNEGI BASINA uretilir; basarili kayittan sonra yenilenir.
  const [anahtar, setAnahtar] = useState(() => genIdempotencyKey());

  // KISI SECILENE KADAR ISTEK ATILMAZ (`null` anahtar): tum tahsilatlari
  // cekip istemcide suzmek, buyuk bir listeyi tarayiciya tasimak olurdu.
  const { data } = useSWR<{ items: Hareket[] }>(
    acik && kisiId
      ? `/api/panel/finans-hareketler?tip=tahsilat&user_id=${kisiId}&limit=100`
      : null,
    jsonFetcher,
  );
  const tahsilatlar = data?.items ?? [];

  async function kaydet() {
    if (!kisiId) { setHata(t("finansKisiGerekli")); return; }
    if (!hareketId) { setHata(t("finansIadeSecim")); return; }
    const kurus = tlToKurus(tutar);
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/finans-iade", "POST", {
        hareket_id: hareketId,
        // TUTAR BOS BIRAKILABILIR: uc o zaman KALAN tutarin tamamini
        // iade eder. Sifir gondermek 422 olurdu; `null` "hepsi" demek.
        tutar_kurus: kurus && kurus > 0 ? kurus : null,
        tarih: tarih || null,
        aciklama: aciklama.trim() || null,
      }, { "Idempotency-Key": anahtar });
      toast.success(t("finansKaydedildi"));
      setHareketId(""); setTutar(""); setAciklama("");
      setAnahtar(genIdempotencyKey());
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
      baslik={t("kabukIade")}
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
        <AlanSarmal etiket={t("finansSutunKisi")} zorunlu>
          {(b) => (
            <Secim {...b} value={kisiId} onChange={(e) => { setKisiId(e.target.value); setHareketId(""); }}>
              <option value="">{t("finansKisiSec")}</option>
              {kisiler.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        {/* SECILEN TAHSILAT kisiyi, daireyi ve kasayi KENDISI getirir —
            uc onlari orijinal hareketten turetiyor. */}
        <AlanSarmal etiket={t("finansIadeEdilecek")} zorunlu ipucu={t("finansIadeSecim")}>
          {(b) => (
            <Secim {...b} value={hareketId} disabled={!kisiId}
              onChange={(e) => setHareketId(e.target.value)}>
              <option value="">{t("finansIadeSecim")}</option>
              {tahsilatlar.map((h) => (
                <option key={h.id} value={h.id}>
                  {`${h.tarih} · ${h.belge_no ?? ""} · ${kurusToTL(h.tutar_kurus)}`}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")}>
          {(b) => <Alan {...b} value={tutar} inputMode="decimal" onChange={(e) => setTutar(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanAciklama")}>
          {(b) => <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />}
        </AlanSarmal>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
