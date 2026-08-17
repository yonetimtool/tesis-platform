"use client";

// (P167 §4.5) HESAPLAR ARASI VIRMAN.
//
// Brief modali: Tarih* · Aciklama · Tutar* · Borclandirilacak Hesap Tipi* ·
// Alacaklandirilacak Hesap Tipi* (yan yana).
//
// "HESAP TIPI" = KASA. Uc iki kasa kimligi aliyor (`kaynak_kasa_id`,
// `hedef_kasa_id`) ve tesiste "hesap" dedigimiz sey kasadir; ayri bir
// "hesap tipi" kavrami UYDURULMADI — olmayan bir varliga ekran cizmek,
// kullaniciya doldurulamayan bir alan gostermek olurdu.

import { useState } from "react";

import { useToast } from "@/components/Toast";
import { Alan, AlanSarmal, Dugme, HataDurumu, Modal, Secim } from "@/components/ui";
import { bugun, useKasalar } from "@/components/finans/ortak";
import { HareketSayfasi } from "@/components/finans/hareket-sayfasi";
import { apiSend } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import { tlToKurus } from "@/lib/money";

const TIP = "virman";

export default function VirmanPage() {
  const t = useT();
  const [acik, setAcik] = useState(false);
  const [yenile, setYenile] = useState(0);

  return (
    <HareketSayfasi
      baslikAnahtari="kabukVirman"
      tip={TIP}
      raporKodu="kasa_ekstresi"
      yenile={yenile}
      araclar={
        <Dugme tur="birincil" boy="kucuk" onClick={() => setAcik(true)}>
          {t("finansYeni")}
        </Dugme>
      }
      cocuk={
        <VirmanModal
          acik={acik}
          onKapat={() => setAcik(false)}
          onKaydedildi={() => setYenile((n) => n + 1)}
        />
      }
    />
  );
}

function VirmanModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();

  const [tarih, setTarih] = useState(bugun());
  const [aciklama, setAciklama] = useState("");
  const [tutar, setTutar] = useState("");
  const [kaynak, setKaynak] = useState("");
  const [hedef, setHedef] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  async function kaydet() {
    const kurus = tlToKurus(tutar);
    if (!kurus || kurus <= 0) { setHata(t("finansTutarGerekli")); return; }
    if (!kaynak || !hedef) { setHata(t("finansKasaGerekli")); return; }
    // AYNI KASA KONTROLU ISTEMCIDE DE VAR ve bu bir tekrar DEGIL: uc
    // zaten 422 doner (`VirmanIstek._ayni_kasa_olmaz`) ama kullaniciyi
    // once gondermeye zorlamak, hata yolunu bilgi yolu olarak
    // kullanmakti. Kural SUNUCUDA kaliyor; buradaki yalniz erken uyari.
    if (kaynak === hedef) { setHata(t("finansAyniKasa")); return; }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/finans-virman", "POST", {
        kaynak_kasa_id: kaynak,
        hedef_kasa_id: hedef,
        tutar_kurus: kurus,
        tarih: tarih || null,
        aciklama: aciklama.trim() || null,
      });
      toast.success(t("finansKaydedildi"));
      setTutar(""); setAciklama("");
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
      baslik={t("kabukVirman")}
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
        <AlanSarmal etiket={t("finansAlanAciklama")}>
          {(b) => <Alan {...b} value={aciklama} onChange={(e) => setAciklama(e.target.value)} />}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => <Alan {...b} value={tutar} inputMode="decimal" onChange={(e) => setTutar(e.target.value)} />}
        </AlanSarmal>
        {/* BRIEF: iki hesap YAN YANA. */}
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("finansAlanKaynakKasa")} zorunlu>
            {(b) => (
              <Secim {...b} value={kaynak} onChange={(e) => setKaynak(e.target.value)}>
                <option value="">{t("finansKasaSec")}</option>
                {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansAlanHedefKasa")} zorunlu>
            {(b) => (
              <Secim {...b} value={hedef} onChange={(e) => setHedef(e.target.value)}>
                <option value="">{t("finansKasaSec")}</option>
                {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
              </Secim>
            )}
          </AlanSarmal>
        </div>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
