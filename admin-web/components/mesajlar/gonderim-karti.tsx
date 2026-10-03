"use client";

/**
 * (P253 §B) TOPLU MESAJ GONDERIMI — onizle, kime, ONAY, gonder, sonuc.
 *
 * OLCULEN KUSUR: "Gonderim" sekmesinde gonder dugmesi YOKTU. Onizleme
 * dugmesi vardi ama o da sunucuya yalniz `sablon_id` gonderiyordu; sunucu
 * `govde` istedigi icin her onizleme 422 donuyordu (DOM testi sahte
 * yanitla gectigi icin kimse gormedi). Yani web'den toplu mesaj HIC
 * gonderilemiyordu.
 *
 * AKIS: sablon -> kime -> (istege bagli) onizle -> "Gonder..." -> sunucudan
 * ALICI OZETI (`/mesajlar/alicilar`, hicbir sey gondermez) -> onay
 * penceresi ("247 kisiye e-posta gidecek") -> gonder -> sonuc sayilari.
 * Onay ozetindeki sayilar gonderimle AYNI kuraldan gelir (`_hedefler`).
 */
import { useState } from "react";

import { AlanSarmal, Alan, Dugme, Kart, Modal, Secim } from "@/components/ui";
import { apiSend } from "@/lib/client";
import { ISTEMCI_SINIR } from "@/lib/girdi-siniri";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export interface GonderimSablonu {
  id: string;
  kanal: string;
  ad: string;
  konu: string | null;
  govde: string;
}

interface SmsOlcum {
  karakter: number;
  unicode_mi: boolean;
  parca: number;
  kalan: number;
  zorlayan: string[];
}
interface Onizleme {
  konu: string | null;
  govde: string;
  sms: SmsOlcum | null;
}
export interface AliciOzeti {
  kanal: string;
  toplam: number;
  gonderilecek: number;
  riza_yok: number;
  adres_yok: number;
  kanal_hazir: boolean;
  kota_kalan: number | null;
}
export interface GonderimSonucu {
  gonderildi: number;
  kuyrukta: number;
  gonderilemedi: number;
  riza_yok: number;
  adres_yok: number;
}

type Kime = "tum" | "blok" | "borclu" | "rol";
const KIMELER: readonly Kime[] = ["tum", "blok", "borclu", "rol"];
const KIME_ETIKET: Record<Kime, SozlukAnahtari> = {
  tum: "mesajKimeTum",
  blok: "mesajKimeBlok",
  borclu: "mesajKimeBorclu",
  rol: "mesajKimeRol",
};
const ROLLER = ["security", "tesis_gorevlisi", "guvenlik_amiri", "yonetici"] as const;
const ROL_ETIKET: Record<(typeof ROLLER)[number], SozlukAnahtari> = {
  security: "rolGuvenlik",
  tesis_gorevlisi: "rolTesisGorevlisi",
  guvenlik_amiri: "rolGuvenlikAmiri",
  yonetici: "rolYonetici",
};
const BIRINCIL = "birincil" as const;
const SESSIZ = "sessiz" as const;
const KUCUK = "kucuk" as const;

/** Sunucu govdesi — onizleme, ozet ve gonderim AYNI suzgeci tasir. */
export function aliciGovdesi(sablonId: string, kime: Kime, blok: string, rol: string) {
  return {
    sablon_id: sablonId,
    ...(kime === "blok" ? { blok: blok.trim() } : {}),
    ...(kime === "borclu" ? { borc_durumu: "borclu" } : {}),
    ...(kime === "rol" ? { rol } : {}),
  };
}

function kanalAnahtari(kanal: string): SozlukAnahtari {
  if (kanal === "sms") return "mesajKanal_sms";
  return "mesajKanal_eposta";
}

export function GonderimKarti({ sablonlar }: { sablonlar: GonderimSablonu[] }) {
  const t = useT();
  const [seciliId, setSeciliId] = useState("");
  const [kime, setKime] = useState<Kime>("tum");
  const [blok, setBlok] = useState("");
  const [rol, setRol] = useState<string>(ROLLER[0]);
  const [onizleme, setOnizleme] = useState<Onizleme | null>(null);
  const [ozet, setOzet] = useState<AliciOzeti | null>(null);
  const [sonuc, setSonuc] = useState<GonderimSonucu | null>(null);
  const [hata, setHata] = useState<string | null>(null);
  const [mesgul, setMesgul] = useState(false);

  const sablon = sablonlar.find((s) => s.id === seciliId) ?? null;
  const govde = () => aliciGovdesi(seciliId, kime, blok, rol);
  const eksik = !sablon || (kime === "blok" && !blok.trim());

  // Istek SOZ olarak gelir (`() => apiSend<..>` bicimi sabit-metin
  // taramasinda JSX metni gibi okunuyordu).
  async function calis<T>(is: Promise<T>): Promise<T | null> {
    setHata(null);
    setMesgul(true);
    try {
      return await is;
    } catch (e) {
      setHata(e instanceof Error ? e.message : String(e));
      return null;
    } finally {
      setMesgul(false);
    }
  }

  async function onizle() {
    if (!sablon) return;
    setSonuc(null);
    const veri = await calis(
      apiSend<Onizleme>(`/api/panel/mesaj-onizleme?kanal=${sablon.kanal}`, "POST", {
        govde: sablon.govde,
        konu: sablon.konu,
      }),
    );
    setOnizleme(veri);
  }

  async function ozetAl() {
    setSonuc(null);
    const veri = await calis(apiSend<AliciOzeti>("/api/panel/mesaj-alicilar", "POST", govde()));
    if (veri) setOzet(veri);
    if (veri && !onizleme) void onizle();
  }

  async function gonder() {
    const veri = await calis(apiSend<GonderimSonucu>("/api/panel/mesaj-gonder", "POST", govde()));
    if (veri) {
      setSonuc(veri);
      setOzet(null);
    }
  }

  const kotaAsiyor = !!ozet && ozet.kota_kalan !== null && ozet.gonderilecek > ozet.kota_kalan;
  const gonderilemez = !ozet || ozet.gonderilecek === 0 || !ozet.kanal_hazir || kotaAsiyor;

  return (
    <Kart>
      <h2 className="mb-3 text-sm font-semibold">{t("mesajSekmeGonderim")}</h2>
      <div className="grid gap-3 sm:grid-cols-3">
        <AlanSarmal etiket={t("mesajSablon")}>
          {(b) => (
            <Secim {...b} value={seciliId} data-test="gonderim-sablon"
              onChange={(e) => {
                setSeciliId(e.target.value);
                setOnizleme(null);
                setSonuc(null);
              }}>
              <option value="">—</option>
              {sablonlar.map((s) => (
                <option key={s.id} value={s.id}>{s.ad}</option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("mesajKime")}>
          {(b) => (
            <Secim {...b} value={kime} data-test="gonderim-kime"
              onChange={(e) => setKime(e.target.value as Kime)}>
              {KIMELER.map((k) => (
                <option key={k} value={k}>{t(KIME_ETIKET[k])}</option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        {kime === "blok" ? (
          <AlanSarmal etiket={t("ortakBlok")}>
            {(b) => (
              <Alan {...b} maxLength={ISTEMCI_SINIR.SAYI} value={blok} data-test="gonderim-blok"
                onChange={(e) => setBlok(e.target.value)} />
            )}
          </AlanSarmal>
        ) : null}
        {kime === "rol" ? (
          <AlanSarmal etiket={t("ortakRol")}>
            {(b) => (
              <Secim {...b} value={rol} onChange={(e) => setRol(e.target.value)}>
                {ROLLER.map((r) => (
                  <option key={r} value={r}>{t(ROL_ETIKET[r])}</option>
                ))}
              </Secim>
            )}
          </AlanSarmal>
        ) : null}
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <Dugme boy={KUCUK} disabled={mesgul || !sablon} onClick={() => void onizle()}>
          {t("mesajOnizle")}
        </Dugme>
        <Dugme tur={BIRINCIL} boy={KUCUK} disabled={mesgul || eksik} data-test="gonderim-gonder"
          onClick={() => void ozetAl()}>
          {t("mesajGonderDugme")}
        </Dugme>
      </div>
      {hata ? (
        <p role="alert" className="mt-2" style={{ color: "var(--yz-danger)", fontSize: "var(--yz-fs-sm)" }}>{hata}</p>
      ) : null}
      {onizleme ? <OnizlemeKutusu onizleme={onizleme} /> : null}
      {sonuc ? (
        <div className="mt-3 space-y-1" data-test="gonderim-sonuc" style={{ fontSize: "var(--yz-fs-sm)" }}>
          <h3 className="font-semibold">{t("mesajSonucBaslik")}</h3>
          <p>{t("mesajSonucGonderildi")}: <b className="tabular-nums">{sonuc.gonderildi}</b></p>
          <p>{t("mesajSonucKuyrukta")}: <b className="tabular-nums">{sonuc.kuyrukta}</b></p>
          <p>{t("mesajSonucGonderilemedi")}: <b className="tabular-nums">{sonuc.gonderilemedi}</b></p>
          <p style={{ color: "var(--yz-text-2)" }}>
            {t("mesajSonucRizaYok")}: {sonuc.riza_yok} · {t("mesajSonucAdresYok")}: {sonuc.adres_yok}
          </p>
        </div>
      ) : null}

      <Modal
        acik={!!ozet}
        onKapat={() => setOzet(null)}
        baslik={t("mesajOnayBaslik")}
        eylemler={
          <>
            <Dugme tur={SESSIZ} onClick={() => setOzet(null)} disabled={mesgul}>{t("ortakIptal")}</Dugme>
            <Dugme tur={BIRINCIL} disabled={mesgul || gonderilemez} data-test="gonderim-onayla"
              onClick={() => void gonder()}>
              {t("mesajOnayGonder")}
            </Dugme>
          </>
        }
      >
        {ozet ? (
          <div className="space-y-3" data-test="gonderim-onay" style={{ fontSize: "var(--yz-fs-sm)" }}>
            {ozet.gonderilecek > 0 ? (
              <p className="font-semibold" style={{ fontSize: "var(--yz-fs-h3)" }}>
                {t("mesajOnayCumle", { sayi: ozet.gonderilecek, kanal: t(kanalAnahtari(ozet.kanal)) })}
              </p>
            ) : (
              <p className="font-semibold">{t("mesajOnayHicKimse")}</p>
            )}
            {ozet.riza_yok + ozet.adres_yok > 0 ? (
              <p style={{ color: "var(--yz-text-2)" }}>
                {t("mesajOnayAtlanan", { riza: ozet.riza_yok, adres: ozet.adres_yok })}
              </p>
            ) : null}
            {!ozet.kanal_hazir ? (
              <p role="alert" style={{ color: "var(--yz-danger)" }}>{t("mesajOnayKanalYok")}</p>
            ) : null}
            {kotaAsiyor ? (
              <p role="alert" style={{ color: "var(--yz-danger)" }}>
                {t("mesajOnayKota", { kalan: ozet.kota_kalan ?? 0 })}
              </p>
            ) : null}
            {onizleme ? <OnizlemeKutusu onizleme={onizleme} /> : null}
          </div>
        ) : null}
      </Modal>
    </Kart>
  );
}

function OnizlemeKutusu({ onizleme }: { onizleme: Onizleme }) {
  const t = useT();
  return (
    <div className="mt-3 space-y-2" data-test="gonderim-onizleme">
      {onizleme.konu ? <p className="font-semibold">{onizleme.konu}</p> : null}
      <pre className="whitespace-pre-wrap rounded p-3 text-xs"
        style={{ background: "var(--yz-surface-sunken)", color: "var(--yz-text)" }}>
        {onizleme.govde}
      </pre>
      {onizleme.sms ? (
        <div className="text-xs" style={{ color: "var(--yz-text-2)" }}>
          {t("mesajSayacKarakter")}: <b className="tabular-nums">{onizleme.sms.karakter}</b> ·{" "}
          {t("mesajSayacParca")}: <b className="tabular-nums">{onizleme.sms.parca}</b> ·{" "}
          {t("mesajSayacKalan")}: <b className="tabular-nums">{onizleme.sms.kalan}</b>
          {onizleme.sms.unicode_mi ? (
            <span className="ms-2" style={{ color: "var(--yz-warning-ink)" }}>
              {t("mesajUnicodeUyari")} <b>{onizleme.sms.zorlayan.join(" ")}</b>
            </span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
