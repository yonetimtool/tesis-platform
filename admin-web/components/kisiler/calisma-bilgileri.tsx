"use client";

/**
 * (P252 §1) CALISMA BILGILERI — personel ekleme formu ve satir duzenlemesi.
 *
 * Ayni alanlar iki yerde: Kisiler › Personel › Ekle (hesapla AYNI
 * istekte, `POST /users` `calisma`) ve satirdaki "Calisma bilgileri"
 * penceresi (bagli maas kartini okur/yazar). Iki ayri kayit YOK: maas
 * karti TEK kaynak; Finans › Maas kartlari ayni satiri gosterir.
 *
 * Ucret girilirse odeme gunu ZORUNLU — gunu olmayan ucret otomasyona
 * hic girmez ve yonetici bunu ancak ay sonunda fark ederdi.
 */
import { useEffect, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import { IBAN_HATA_METNI } from "@/components/tanimlar/tanimlar";
import { Alan, AlanSarmal, CokSatir, Dugme, Modal, Secim } from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { ISTEMCI_SINIR, SINIR } from "@/lib/girdi-siniri";
import { ibanGiris, ibanHatasi, ibanTemizle } from "@/lib/iban";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { kurusToTLSade, tlToKurus } from "@/lib/money";
import { rolAdi } from "@/lib/roles";
import type { UserDetail, UserRow } from "@/lib/types";

export interface CalismaDegeri {
  giris: string;
  gorev: string;
  ucret: string;
  gun: string;
  kasa: string;
  iban: string;
  not: string;
}

export const BOS_CALISMA: CalismaDegeri = {
  giris: "", gorev: "", ucret: "", gun: "", kasa: "", iban: "", not: "",
};

const GUNLER = Array.from({ length: 31 }, (_, i) => String(i + 1));
const BIRINCIL = "birincil" as const;
const KUCUK = "kucuk" as const;
export const KASALAR_UCU = "/api/tanimlar/kasalar?limit=200";

type Kasa = { id: string; ad: string; aktif?: boolean };
type Kart = {
  id: string;
  giris_tarihi: string | null;
  gorev: string | null;
  maas_kurus: number | null;
  odeme_gunu: number | null;
  kasa_id: string | null;
  iban: string | null;
  notlar: string | null;
};

/** Hepsi bossa `null` (yalniz hesap acilir). Hata varsa sozluk anahtari. */
export function calismaGovdesi(
  d: CalismaDegeri,
): { govde: Record<string, unknown> | null; hata: SozlukAnahtari | null } {
  const dolu = Object.values(d).some((v) => v.trim() !== "");
  if (!dolu) return { govde: null, hata: null };
  let maas: number | null = null;
  if (d.ucret.trim()) {
    maas = tlToKurus(d.ucret);
    if (maas === null) return { govde: null, hata: "calismaUcretGecersiz" };
    if (!d.gun) return { govde: null, hata: "calismaGunGerekli" };
  }
  const iban = ibanTemizle(d.iban);
  if (iban) {
    const kod = ibanHatasi(iban);
    if (kod) return { govde: null, hata: IBAN_HATA_METNI[kod] };
  }
  return {
    govde: {
      giris_tarihi: d.giris || null,
      gorev: d.gorev.trim() || null,
      maas_kurus: maas,
      odeme_gunu: d.gun ? Number(d.gun) : null,
      kasa_id: d.kasa || null,
      iban: iban || null,
      notlar: d.not.trim() || null,
    },
    hata: null,
  };
}

export function karttanDeger(k: Kart | null | undefined): CalismaDegeri {
  if (!k) return BOS_CALISMA;
  return {
    giris: k.giris_tarihi ?? "",
    gorev: k.gorev ?? "",
    ucret: k.maas_kurus != null ? kurusToTLSade(k.maas_kurus) : "",
    gun: k.odeme_gunu != null ? String(k.odeme_gunu) : "",
    kasa: k.kasa_id ?? "",
    iban: k.iban ? ibanGiris(k.iban) : "",
    not: k.notlar ?? "",
  };
}

export function CalismaAlanlari({
  deger,
  onDegis,
  devre = false,
}: {
  deger: CalismaDegeri;
  onDegis: (d: CalismaDegeri) => void;
  devre?: boolean;
}) {
  const t = useT();
  const { data: kasalar } = useSWR<{ items: Kasa[] }>(KASALAR_UCU, jsonFetcher);
  const set = (k: keyof CalismaDegeri) => (v: string) => onDegis({ ...deger, [k]: v });
  return (
    <fieldset className="space-y-3" data-test="calisma-bilgileri">
      <legend className="mb-1 font-semibold" style={{ color: "var(--yz-text)" }}>
        {t("calismaBaslik")}
      </legend>
      <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{t("calismaAlt")}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        <AlanSarmal etiket={t("calismaGiris")}>
          {(b) => (
            <Alan {...b} type="date" disabled={devre} value={deger.giris}
              onChange={(e) => set("giris")(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("calismaGorev")}>
          {(b) => (
            <Alan {...b} maxLength={100} disabled={devre} value={deger.gorev}
              placeholder={t("calismaGorevIpucu")}
              onChange={(e) => set("gorev")(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("calismaUcret")}>
          {(b) => (
            <Alan {...b} inputMode="decimal" maxLength={ISTEMCI_SINIR.SAYI} disabled={devre} value={deger.ucret}
              data-test="calisma-ucret"
              onChange={(e) => set("ucret")(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("calismaOdemeGunu")} ipucu={t("calismaOdemeGunuKurali")}>
          {(b) => (
            <Secim {...b} disabled={devre} value={deger.gun} data-test="calisma-gun"
              onChange={(e) => set("gun")(e.target.value)}>
              <option value="">—</option>
              {GUNLER.map((g) => <option key={g} value={g}>{g}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("calismaKasa")}>
          {(b) => (
            <Secim {...b} disabled={devre} value={deger.kasa} data-test="calisma-kasa"
              onChange={(e) => set("kasa")(e.target.value)}>
              <option value="">{t("calismaKasaVarsayilan")}</option>
              {(kasalar?.items ?? []).filter((k) => k.aktif !== false).map((k) => (
                <option key={k.id} value={k.id}>{k.ad}</option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("calismaIban")}>
          {(b) => (
            <Alan {...b} maxLength={SINIR.IBAN} disabled={devre} value={deger.iban} autoComplete="off"
              onChange={(e) => set("iban")(ibanGiris(e.target.value))} />
          )}
        </AlanSarmal>
      </div>
      <AlanSarmal etiket={t("calismaNot")}>
        {(b) => (
          <CokSatir {...b} rows={2} maxLength={SINIR.NOT} disabled={devre} value={deger.not}
            onChange={(e) => set("not")(e.target.value)} />
        )}
      </AlanSarmal>
    </fieldset>
  );
}

/**
 * Satirdaki "Calisma bilgileri" — bagli maas kartini acar; yoksa olusturur
 * (hesabin adi/e-postasiyla, BAGLI). Kaydet: PATCH ya da POST.
 */
export function CalismaBilgileriPenceresi({
  kullanici,
  acik,
  onKapat,
}: {
  /** Pencere yalniz kimlik, ad, e-posta ve rolu okur (detay sayfasi da acar). */
  kullanici: Pick<UserRow, "id" | "ad" | "email" | "role">;
  acik: boolean;
  onKapat: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const ucu = `/api/tanimlar/personel-kayitlari?app_user_id=${kullanici.id}`;
  const { data, mutate } = useSWR<{ items: Kart[] }>(acik ? ucu : null, jsonFetcher);
  const kart = data?.items[0] ?? null;
  const [deger, setDeger] = useState<CalismaDegeri>(BOS_CALISMA);
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);

  useEffect(() => {
    if (data) setDeger(karttanDeger(kart));
    // `kart` `data`dan turer.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  async function kaydet() {
    const { govde, hata: h } = calismaGovdesi(deger);
    if (h) {
      setHata(t(h));
      return;
    }
    setKaydediyor(true);
    setHata(null);
    try {
      if (kart) {
        await apiSend(`/api/tanimlar/personel-kayitlari/${kart.id}`, "PATCH", govde ?? {
          maas_kurus: null, odeme_gunu: null,
        });
      } else {
        // Kart yok: hesabin adi, e-postasi ve telefonuyla BAGLI kart
        // (P251 davranisi); gorev bos birakildiysa rol adi.
        const ayrinti = await jsonFetcher<UserDetail>(`/api/users/${kullanici.id}`);
        await apiSend("/api/tanimlar/personel-kayitlari", "POST", {
          ad: kullanici.ad,
          email: kullanici.email || null,
          telefon: ayrinti.telefon ?? null,
          app_user_id: kullanici.id,
          ...(govde ?? {}),
          gorev: (govde?.gorev as string | null) ?? rolAdi(t, kullanici.role),
        });
      }
      await mutate();
      toast.success(t("calismaKaydedildi"));
      onKapat();
    } catch (e) {
      setHata(alanliHataMetni(e, t("ortakHataOlustu")));
    } finally {
      setKaydediyor(false);
    }
  }

  return (
    <Modal acik={acik} onKapat={onKapat} baslik={t("calismaPencereBaslik", { ad: kullanici.ad })}>
      {!data ? (
        <p>{t("ortakYukleniyor")}</p>
      ) : (
        <div className="space-y-4">
          <CalismaAlanlari deger={deger} onDegis={setDeger} devre={kaydediyor} />
          {hata ? (
            <p role="alert" style={{ color: "var(--yz-danger)", fontSize: "var(--yz-fs-sm)" }}>{hata}</p>
          ) : null}
          <div className="flex justify-end">
            <Dugme tur={BIRINCIL} disabled={kaydediyor} onClick={() => void kaydet()} data-test="calisma-kaydet">
              {t("ortakKaydet")}
            </Dugme>
          </div>
        </div>
      )}
    </Modal>
  );
}

/** Satir eylemi: "Calisma bilgileri" dugmesi + penceresi. */
export function CalismaEylemi({ kullanici }: { kullanici: UserRow }) {
  const t = useT();
  const [acik, setAcik] = useState(false);
  return (
    <>
      <Dugme boy={KUCUK} onClick={() => setAcik(true)} data-test={`calisma-${kullanici.id}`}>
        {t("calismaDugme")}
      </Dugme>
      {acik ? (
        <CalismaBilgileriPenceresi kullanici={kullanici} acik={acik} onKapat={() => setAcik(false)} />
      ) : null}
    </>
  );
}
