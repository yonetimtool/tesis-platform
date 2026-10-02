"use client";

// (P250 §6) HIZLI ISLEMLER KARTI — kullanici ozellestirir, role gore.
//
// P250 oncesi kart SABIT dort islem cizerdi. Simdi:
//   * hangi islemlerin gorunecegi ve SIRASI kullanicinin secimi,
//   * secenekler ROLE gore SUNUCUDAN gelir (yetkisi olmayan islem listede
//     cikmaz; yazilmaya calisilirsa sunucu 422 verir),
//   * secim HESAPTA (P182 pano tercihi), mobil ayni listeyi gorur,
//   * "Varsayilana don".
// Ikinci bir ozellestirme sistemi YOK: kayit P182'nin `pano_tercihi`
// kaydinda, kendi ucundan (`/me/hizli-islemler`) birlestirilerek yazilir.
import { useEffect, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { Dugme, DugmeBaglantisi, Kart, Modal } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import {
  HIZLI_ISLEM_KATALOGU,
  HIZLI_UST_SINIR,
  type HizliIslemler,
  sirayiTasi,
} from "@/lib/hizli-islemler";
import { useT } from "@/lib/i18n/kullan";

const UC = "/api/me/hizli-islemler";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

export function HizliIslemlerKarti({ baslik }: { baslik: React.ReactNode }) {
  const t = useT();
  const { data, mutate } = useSWR<HizliIslemler>(UC, jsonFetcher);
  const [acik, setAcik] = useState(false);
  // Katalogda olmayan (istemcinin tanimadigi) kimlik CIZILMEZ.
  const gorunen = (data?.secili ?? []).filter((k) => HIZLI_ISLEM_KATALOGU[k]);

  return (
    <Kart className="space-y-3">
      <div className="flex items-center justify-between gap-2">
        {baslik}
        <Dugme
          tur="sessiz"
          boy="kucuk"
          data-test="hizli-ozellestir"
          onClick={() => setAcik(true)}
          disabled={!data}
        >
          {t("panoHizliOzellestir")}
        </Dugme>
      </div>
      {data && gorunen.length === 0 ? (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("panoHizliBos")}
        </p>
      ) : (
        <div className="grid grid-cols-2 gap-2" data-test="hizli-islemler">
          {gorunen.map((k) => {
            const h = HIZLI_ISLEM_KATALOGU[k];
            return (
              <DugmeBaglantisi key={k} href={h.rota} className="justify-start" data-test={`hizli-${k}`}>
                <Ikon yol={h.ikon} />
                {t(h.anahtar)}
              </DugmeBaglantisi>
            );
          })}
        </div>
      )}
      {acik && data && (
        <OzellestirPenceresi
          veri={data}
          onKapat={() => setAcik(false)}
          onKaydedildi={(yeni) => void mutate(yeni, { revalidate: false })}
        />
      )}
    </Kart>
  );
}

function OzellestirPenceresi({
  veri,
  onKapat,
  onKaydedildi,
}: {
  veri: HizliIslemler;
  onKapat: () => void;
  onKaydedildi: (yeni: HizliIslemler) => void;
}) {
  const t = useT();
  const toast = useToast();
  const secenekler = veri.secenekler.filter((k) => HIZLI_ISLEM_KATALOGU[k]);
  const [secim, setSecim] = useState<string[]>(veri.secili);
  const [kaydediyor, setKaydediyor] = useState(false);
  useEffect(() => setSecim(veri.secili), [veri.secili]);

  // Secilenler SECIM SIRASIYLA ustte, secilmeyenler katalog sirasiyla altta.
  const liste = [...secim, ...secenekler.filter((k) => !secim.includes(k))];
  const dolu = secim.length >= HIZLI_UST_SINIR;

  function degistir(k: string, acikMi: boolean) {
    setSecim(acikMi ? [...secim, k] : secim.filter((x) => x !== k));
  }

  async function yaz(govde: { secili: string[] | null }) {
    setKaydediyor(true);
    try {
      const yeni = await apiSend<HizliIslemler>(UC, "PUT", govde);
      onKaydedildi(yeni);
      toast.success(t("panoHizliKaydedildi"));
      onKapat();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : t("ortakHataOlustu"));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Modal
      acik
      onKapat={onKapat}
      baslik={t("panoHizliIslemler")}
      eylemler={
        <>
          <Dugme tur="sessiz" data-test="hizli-varsayilan" onClick={() => void yaz({ secili: null })} disabled={kaydediyor}>
            {t("panoHizliVarsayilan")}
          </Dugme>
          <Dugme tur="birincil" data-test="hizli-kaydet" onClick={() => void yaz({ secili: secim })} disabled={kaydediyor}>
            {t("ortakKaydet")}
          </Dugme>
        </>
      }
    >
      <p className="mb-3" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
        {t("panoHizliOzellestirAciklama")}
      </p>
      {dolu && (
        <p role="status" className="mb-2" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}>
          {t("panoHizliUstSinir")}
        </p>
      )}
      <ul className="space-y-1" data-test="hizli-secenekler">
        {liste.map((k) => {
          const ad = t(HIZLI_ISLEM_KATALOGU[k].anahtar);
          const secili = secim.includes(k);
          const i = secim.indexOf(k);
          return (
            <li key={k} className="flex items-center gap-2" data-test={`hizli-secenek-${k}`}>
              <label className="flex flex-1 items-center gap-2" style={{ fontSize: "var(--yz-fs-sm)" }}>
                <input
                  type="checkbox"
                  checked={secili}
                  disabled={!secili && dolu}
                  onChange={(e) => degistir(k, e.target.checked)}
                />
                {ad}
              </label>
              {secili && (
                <>
                  <Dugme
                    tur="sessiz"
                    boy="kucuk"
                    aria-label={t("panoHizliYukari", { ad })}
                    disabled={i === 0}
                    onClick={() => setSecim(sirayiTasi(secim, k, -1))}
                  >
                    ↑
                  </Dugme>
                  <Dugme
                    tur="sessiz"
                    boy="kucuk"
                    aria-label={t("panoHizliAsagi", { ad })}
                    disabled={i === secim.length - 1}
                    onClick={() => setSecim(sirayiTasi(secim, k, 1))}
                  >
                    ↓
                  </Dugme>
                </>
              )}
            </li>
          );
        })}
      </ul>
    </Modal>
  );
}
