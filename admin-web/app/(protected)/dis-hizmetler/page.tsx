"use client";

// (P126.5) DIŞ HİZMETLER — güvenilir esnaf rehberi.
//
// OKUMA tüm rollere açıktır (sunucu: "güvenilir esnafı herkes görür/
// arayabilir"), YAZMA admin+yönetici. Ekran ikisini de tek sayfada tutar;
// yazma formunu role göre gizlemiyoruz çünkü `app.*`ta bu sayfa yönetici
// menüsündedir — sunucu zaten reddeder ve gizlemek yetkilendirme değildir.
//
// TELEFON P123 MASKESİNDEN GEÇER: rehberdeki numara aranmak içindir;
// gruplanmamış 11 hane okunmaz ve yanlış tuşlanır.
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
  Rozet,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { TelefonAlani, telefonHataMetni } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { telefonGiris, telefonHatasi, telefonNormalle } from "@/lib/telefon";

type Hizmet = {
  id: string;
  tur: string;
  ad: string;
  soyad: string;
  telefon: string;
  aciklama: string | null;
};
/** Liste yaniti bir de BOLUM NOTU tasir (yoneticinin serbest metni). */
type Liste = { note: string | null; items: Hizmet[] };

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const ROZET_NOTR = "notr" as const;

export default function DisHizmetlerPage() {
  const t = useT();
  const toast = useToast();
  const { data, error, isLoading, mutate } = useSWR<Liste>(
    "/api/external-services",
    jsonFetcher,
  );

  const [tur, setTur] = useState("");
  const [ad, setAd] = useState("");
  const [soyad, setSoyad] = useState("");
  const [telefon, setTelefon] = useState("");
  /** (P166 §9) Telefonun ALAN BAZINDA hatasi — sayfa hata kutusundan AYRI. */
  const [telefonHatasiMetni, setTelefonHatasiMetni] = useState<string | null>(null);
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [gonderiyor, setGonderiyor] = useState(false);
  const [modalAcik, setModalAcik] = useState(false);
  // (P162 §5) DIS HIZMET DUZENLEME + SILME — webde YOKTU.
  //
  // Uclar (`PATCH/DELETE /external-services/{id}`) ve rol kapisi
  // (`_WRITER` = admin + yonetici) zaten vardi; mobilde kullaniliyordu,
  // webde vekil ve dugme eksikti. Rehberdeki bir numara degistiginde
  // kaydi silip yeniden yazmak, kaydin kimligini (ve ona bagli izleri)
  // gereksizce degistirmekti.
  //
  // AYNI MODAL: yeni kayit ile duzenleme tek formu paylasir.
  const [duzenlenen, setDuzenlenen] = useState<{ id: string } | null>(null);
  const { onayla, diyalog } = useOnay();

  const kayitlar = data?.items ?? [];

  async function ekle() {
    // SOYAD DA ZORUNLU: sunucu `DisHizmetCreate.soyad` icin min_length=1
    // istiyor. Bos gondermek 422 uretirdi — kural sunucudan OKUNDU.
    if (!tur.trim() || !ad.trim() || !soyad.trim()) {
      setHata(t("disHizmetAlanZorunlu"));
      return;
    }
    // (P166 §9) HATA ALANIN YANINDA — sayfa kutusunda DEGIL. Ikisi
    // birden cizilirse kullanici ayni cumleyi iki yerde okur.
    const telHata = telefonHataMetni(telefon, true, t);
    if (telHata) {
      setTelefonHatasiMetni(telHata);
      return;
    }
    setTelefonHatasiMetni(null);
    setHata(null);
    setGonderiyor(true);
    try {
      const govde = {
        tur: tur.trim(),
        ad: ad.trim(),
        soyad: soyad.trim(),
        // Sunucuya NORMALLESTIRILMIS gider (P123).
        telefon: telefonNormalle(telefon),
        aciklama: aciklama.trim() || null,
      };
      if (duzenlenen) {
        await apiSend(`/api/external-services/${duzenlenen.id}`, "PATCH", govde);
      } else {
        await apiSend("/api/external-services", "POST", govde);
      }
      setTur("");
      setAd("");
      setSoyad("");
      setTelefon("");
      setAciklama("");
      setDuzenlenen(null);
      setModalAcik(false);
      toast.success(t("disHizmetEklendi"));
      void mutate();
    } catch (e) {
      setHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setGonderiyor(false);
    }
  }

  async function sil(h: { id: string; ad: string; soyad: string }) {
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("ortakSilOnay", { ad: `${h.ad} ${h.soyad}` }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      await apiSend(`/api/external-services/${h.id}`, "DELETE");
      toast.success(t("ortakSilindi"));
      void mutate();
    } catch (e) {
      toast.error(alanliHataMetni(e, t("ortakSilinemedi")));
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("disHizmetBaslik")}
      </h1>
        <Dugme
          tur="birincil"
          boy="kucuk"
          onClick={() => {
            // YENI KAYIT: duzenleme durumu ve alanlar temizlenir; aksi
            // halde "yeni" dugmesi son duzenlenenin uzerine yazardi.
            setDuzenlenen(null);
            setTur("");
            setAd("");
            setSoyad("");
            setTelefon("");
            setAciklama("");
            setHata(null);
            setModalAcik(true);
          }}
        >
          {t("disHizmetYeni")}
        </Dugme>
      </div>

      {data?.note ? (
        <Kart>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>{data.note}</p>
        </Kart>
      ) : null}

      <Modal
        acik={modalAcik}
        onKapat={() => setModalAcik(false)}
        baslik={t("disHizmetYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setModalAcik(false)} disabled={gonderiyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" disabled={gonderiyor} yukleniyor={gonderiyor} onClick={() => void ekle()}>
            {gonderiyor ? t("ortakKaydediliyor") : t("ortakEkle")}
          </Dugme>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
          <AlanSarmal etiket={t("disHizmetTur")} zorunlu>
            {(b) => (
              <Alan {...b} value={tur} onChange={(e) => setTur(e.target.value)} maxLength={60} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("disHizmetAd")} zorunlu>
            {(b) => (
              <Alan {...b} value={ad} onChange={(e) => setAd(e.target.value)} maxLength={80} />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("disHizmetSoyad")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={soyad}
                onChange={(e) => setSoyad(e.target.value)}
                maxLength={80}
              />
            )}
          </AlanSarmal>
          <TelefonAlani
            etiket={t("kullaniciTelefon")}
            zorunlu
            deger={telefon}
            hata={telefonHatasiMetni}
            onDegisti={(v) => {
              setTelefon(v);
              setTelefonHatasiMetni(null);
            }}
          />
          <AlanSarmal etiket={t("disHizmetAciklama")}>
            {(b) => (
              <Alan
                {...b}
                value={aciklama}
                onChange={(e) => setAciklama(e.target.value)}
                maxLength={500}
              />
            )}
          </AlanSarmal>
        </div>
        {hata && (
          <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
            {hata}
          </p>
        )}
        </div>
      </Modal>

      <section className="space-y-3">
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("disHizmetListe")}
        </h2>
        {/* HATA VARSA LISTE DALI HIC CALISMAZ: `kayitlar` bos gelir ve
            "kayitli esnaf yok" yazmak, rehberin BOS oldugunu soylemek
            olurdu — oysa bilinen tek sey okunamadigi. */}
        {error ? (
          <HataDurumu mesaj={t("ortakHataOlustu")} onTekrar={() => void mutate()} />
        ) : isLoading ? (
          <Kart>
            <IskeletMetin satir={3} />
          </Kart>
        ) : kayitlar.length === 0 ? (
          <Kart>
            <BosDurum baslik={t("disHizmetYok")} />
          </Kart>
        ) : (
          kayitlar.map((h) => (
            <Kart key={h.id} className="space-y-1">
              <div className="flex flex-wrap items-baseline justify-between gap-2">
                <h3 style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}>
                  {h.ad} {h.soyad}
                </h3>
                <Rozet durum={ROZET_NOTR}>{h.tur}</Rozet>
              </div>
              {/* `tel:` baglantisi: rehberdeki numara ARANMAK icindir. */}
              <a
                className="underline"
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-accent-ink)" }}
                href={`tel:${h.telefon}`}
              >
                {telefonGiris(h.telefon)}
              </a>
              {h.aciklama ? (
                <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
                  {h.aciklama}
                </p>
              ) : null}
              <div className="flex flex-wrap gap-2 pt-1">
                <Dugme
                  boy="kucuk"
                  onClick={() => {
                    setDuzenlenen({ id: h.id });
                    setTur(h.tur);
                    setAd(h.ad);
                    setSoyad(h.soyad);
                    setTelefon(telefonGiris(h.telefon));
                    setAciklama(h.aciklama ?? "");
                    setHata(null);
                    setModalAcik(true);
                  }}
                >
                  {t("ortakDuzenle")}
                </Dugme>
                <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(h)}>
                  {t("ortakSil")}
                </Dugme>
              </div>
            </Kart>
          ))
        )}
      </section>
      {diyalog}
    </div>
  );
}
