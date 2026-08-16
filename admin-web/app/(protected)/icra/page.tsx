"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import { Ekler } from "@/components/Ekler";
import {
  Alan,
  AlanSarmal,
  CokSatir,
  Dugme,
  Kart,
  Modal,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type TabloDurumu,
  useOnay,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL } from "@/lib/money";
import { useSorguSecimi } from "@/lib/sorgu-secimi";

/**
 * (P154 / Asama 7.1) ICRA DOSYALARI — brief: "ayri ust sekme".
 *
 * NEDEN YENI BIR SAYFA: uc (`/finans/icra-dosyalari`, GET+POST+PATCH) ve
 * BFF kaydi VARDI, ama HICBIR EKRAN onlari cagirmiyordu — envanterdeki
 * "olu BFF ucu" sinifinin bir uyesi. Brief bu bolumu ayri istedigi icin
 * eksik olan sey sayfaydi, uc degil.
 *
 * NEDEN FINANSIN ICINDE DEGIL: icra HUKUKI bir surectir, para hareketi
 * degil. Borc `dues_assessment`ta durur ve buraya KOPYALANMAZ (P29
 * karari); acik borc her satirda ANLIK okunur. Ikisini ayni sayfada
 * gostermek "icra bir kasa hareketidir" izlenimi verirdi.
 *
 * YAZMA YALNIZ ADMIN: uc `require_role("admin")` ile kapali (yonetici
 * OKUR, yazamaz). Bu yuzden "Yeni dosya" dugmesi yoneticiye ve denetciye
 * CIZILMEZ — basilacak ama 403 alacak bir dugme, P129'un notuyla ayni
 * hatadir ("yetkim var sandim").
 */

interface IcraDosyasi {
  id: string;
  dosya_no: string;
  user_id: string;
  user_ad: string | null;
  veris_tarihi: string | null;
  avukat: string | null;
  durum: string;
  aciklama: string | null;
  acik_borc_kurus: number;
  created_at: string;
}

const DURUMLAR = ["acik", "takipte", "tahsil_edildi", "kapandi"] as const;
type Durum = (typeof DURUMLAR)[number];
/** Suzgec: dort durumdan biri ya da "" (hepsi). */
type DurumSecimi = "" | Durum;

const BOS = { dosya_no: "", user_id: "", veris_tarihi: "", avukat: "", aciklama: "" };

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_UYARI = "uyari" as const;
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;
const DURUM_KRITIK = "kritik" as const;

/** Dosya durumu -> rozet rengi. Kapanmis dosya notr, tahsil olumlu. */
function durumRengi(d: string) {
  if (d === "tahsil_edildi") return DURUM_OLUMLU;
  if (d === "kapandi") return DURUM_NOTR;
  if (d === "takipte") return DURUM_UYARI;
  return DURUM_KRITIK;
}

export default function IcraPage() {
  const t = useT();
  // (P161) Yikici onaylar tema/dil taniyan diyalogdan gecer.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const [durum, setDurum] = useSorguSecimi<DurumSecimi>("durum", DURUMLAR, "");
  const [acik, setAcik] = useState(false);
  const [form, setForm] = useState(BOS);
  const [formHata, setFormHata] = useState<string | null>(null);
  const [kaydediliyor, setKaydediliyor] = useState(false);
  const [secili, setSecili] = useState<IcraDosyasi | null>(null);

  // Rol SUNUCUDAN: istemcide bir rol listesi tutmak, yetkinin ikinci bir
  // dogruluk kaynagi olurdu.
  const { data: ben } = useSWR<{ role?: string }>("/api/me", jsonFetcher);
  const yazabilir = ben?.role === "admin";

  // (P160) BORCLU SECIMI. Form "Borçlu kimliği" adinda bir SERBEST METIN
  // alaniydi ve icine bir UUID yazilmasi bekleniyordu. Hicbir yonetici
  // kullanici kimligini ezbere bilmez; alan pratikte doldurulamazdi ve
  // yanlis yazilan kimlik 422 ile geri donuyordu. Artik kisi listesinden
  // secilir. Liste CEKILEMEZSE alan eski haline (serbest metin) duser —
  // boylece yetenek kaybolmaz.
  const { data: kisiler, error: kisiErr } = useSWR<{
    items: { id: string; ad: string }[];
    meta: { total: number };
  }>(yazabilir ? "/api/users?limit=200&offset=0" : null, jsonFetcher);
  const kisiSecilebilir = !kisiErr && (kisiler?.items.length ?? 0) > 0;

  const suzgec = durum ? `&durum=${durum}` : "";
  const anahtar = `/api/panel/icra-dosyalari?limit=${tabloDurumu.boy}&offset=${offset}${suzgec}`;
  const {
    data,
    error,
    isLoading,
    mutate,
  } = useSWR<{ items: IcraDosyasi[]; meta: { total: number } }>(anahtar, jsonFetcher);

  async function kaydet(e: React.FormEvent) {
    e.preventDefault();
    setFormHata(null);
    setKaydediliyor(true);
    try {
      await apiSend("/api/panel/icra-dosyalari", "POST", {
        dosya_no: form.dosya_no.trim(),
        user_id: form.user_id.trim(),
        veris_tarihi: form.veris_tarihi || null,
        avukat: form.avukat.trim() || null,
        aciklama: form.aciklama.trim() || null,
      });
      setAcik(false);
      setForm(BOS);
      await mutate();
      toast.success(t("icraOlusturuldu"));
    } catch (err) {
      setFormHata(err instanceof Error ? err.message : t("ortakHataOlustu"));
    } finally {
      setKaydediliyor(false);
    }
  }

  async function durumDegistir(d: IcraDosyasi, yeni: Durum) {
    try {
      await apiSend(`/api/panel/icra-dosyalari/${d.id}`, "PATCH", { durum: yeni });
      await mutate();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakHataOlustu"));
    }
  }

  // Secenekler JSX'IN DISINDA kuruluyor: ternary'nin iki dali da kisa
  // kalsin ve `AlanSarmal` ile alan arasina 20 satir girmesin.
  const kisiSecenekleri = (kisiler?.items ?? []).map((k) => (
    <option key={k.id} value={k.id}>
      {k.ad}
    </option>
  ));

  const kolonlar: Kolon<IcraDosyasi>[] = useMemo(
    () => [
      {
        id: "dosya_no",
        baslik: t("icraDosyaNo"),
        gizlenebilir: false,
        hucre: (k) => k.dosya_no,
      },
      { id: "user_ad", baslik: t("icraBorclu"), hucre: (k) => k.user_ad ?? "—" },
      {
        id: "acik_borc_kurus",
        baslik: t("icraAcikBorc"),
        sayisal: true,
        // ANLIK okunur, kopyalanmaz — iki yerde tutulan borc, biri
        // guncellenip digeri unutuldugunda hangi rakamin dogru
        // oldugunu belirsiz birakirdi (P29).
        hucre: (k) => kurusToTL(k.acik_borc_kurus),
      },
      {
        id: "avukat",
        baslik: t("icraAvukat"),
        darEkrandaGizle: true,
        hucre: (k) => k.avukat ?? "—",
      },
      {
        id: "durum",
        baslik: t("icraDurum"),
        hucre: (k) => (
          <Rozet durum={durumRengi(k.durum)}>{t(`icraDurum_${k.durum}` as never)}</Rozet>
        ),
      },
      {
        id: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (k) => (
          <div className="flex flex-wrap justify-end gap-2">
            <Dugme
              boy="kucuk"
              aria-expanded={secili?.id === k.id}
              onClick={() => setSecili(secili?.id === k.id ? null : k)}
            >
              {secili?.id === k.id ? t("ortakKapat") : t("icraDetay")}
            </Dugme>
            {/* DURUM DEGISIMI TEK BIR SECIMDE. Eskiden her satirda uc
                ayri dugme vardi; dar ekranda satiri tasiriyor ve ekran
                okuyucuda "acik / takipte / kapandi" diye baglamsiz
                okunuyordu. Secim ADLIDIR ve ne yaptigini soyler. */}
            {yazabilir && (
              <Secim
                aria-label={t("icraDurumDegistir", { no: k.dosya_no })}
                value=""
                onChange={(e) => {
                  const yeni = e.target.value as Durum;
                  if (yeni) void durumDegistir(k, yeni);
                }}
              >
                <option value="">{t("icraDurumDegistirKisa")}</option>
                {DURUMLAR.filter((d) => d !== k.durum).map((d) => (
                  <option key={d} value={d}>
                    {t(`icraDurum_${d}` as never)}
                  </option>
                ))}
              </Secim>
            )}
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, yazabilir, secili],
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>{t("kabukIcra")}</h1>
        {yazabilir ? (
          <Dugme
            tur="birincil"
            boy="kucuk"
            onClick={() => {
              setForm(BOS);
              setFormHata(null);
              setAcik(true);
            }}
          >
            {t("icraYeni")}
          </Dugme>
        ) : null}
      </div>

      <VeriTablosu<IcraDosyasi>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(k) => k.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("icraKayitYok")}
        sunucuTarafli
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
        araclar={
          <div style={{ maxWidth: 220 }}>
            <AlanSarmal etiket={t("icraDurum")}>
              {(b) => (
                <Secim
                  {...b}
                  value={durum}
                  onChange={(e) => {
                    setDurum(e.target.value as DurumSecimi);
                    setTabloDurumu({ ...tabloDurumu, sayfa: 1 });
                  }}
                >
                  <option value="">{t("icraDurumHepsi")}</option>
                  {DURUMLAR.map((d) => (
                    <option key={d} value={d}>
                      {t(`icraDurum_${d}` as never)}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
          </div>
        }
      />

      {secili && (
        <Kart className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("icraDetayBaslik", { no: secili.dosya_no })}
          </h2>
          {secili.aciklama && (
            <p
              className="whitespace-pre-wrap"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
            >
              {secili.aciklama}
            </p>
          )}
          {/* (P154 / Asama 6.4) Ortak not/ek yuzeyi — icraya OZEL bir ek
              tablosu yazilmadi. Avukat yazismasi ve tebligat belgesi tam
              da buraya iliskin "ek bilgi"dir. */}
          <Ekler varlikTipi="icra_dosyasi" varlikId={secili.id} />
        </Kart>
      )}

      <Modal
        baslik={t("icraYeni")}
        acik={acik}
        onKapat={() => setAcik(false)}
        // Doldurulmus bir form kazara kapanmasin.
        kirliMi={form.dosya_no !== "" || form.user_id !== ""}
        onKirliKapat={() => {
          // `window.confirm` bilincli: depoda zaten bu desen kullaniliyor
          // (blok silme, tesis silme) ve modal icinde modal acmak daha
          // kotu bir odak sorunu uretirdi.
          void onayla({
            baslik: t("modalKirliBaslik"),
            mesaj: t("modalKirliUyari"),
            onayMetni: t("ortakVazgec"),
            tehlikeli: true,
          }).then((o) => {
            if (o) setAcik(false);
          });
        }}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setAcik(false)} disabled={kaydediliyor}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="icra-form" yukleniyor={kaydediliyor}>
              {kaydediliyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="icra-form" onSubmit={kaydet} className="space-y-3">
          {formHata && (
            <p
              role="alert"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formHata}
            </p>
          )}
          <AlanSarmal etiket={t("icraDosyaNo")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.dosya_no}
                onChange={(e) => setForm({ ...form, dosya_no: e.target.value })}
                required
                maxLength={50}
              />
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("icraBorclu")} zorunlu>
            {(b) =>
              kisiSecilebilir ? (
                <Secim
                  {...b}
                  value={form.user_id}
                  onChange={(e) => setForm({ ...form, user_id: e.target.value })}
                  required
                >
                  <option value="">—</option>
                  {kisiSecenekleri}
                </Secim>
              ) : (
                // Liste cekilemedi: eski davranis (serbest kimlik) duruyor
                // ki dosya acmak IMKANSIZ hale gelmesin.
                <Alan
                  {...b}
                  value={form.user_id}
                  onChange={(e) => setForm({ ...form, user_id: e.target.value })}
                  required
                />
              )
            }
          </AlanSarmal>

          <AlanSarmal etiket={t("icraVerisTarihi")}>
            {(b) => (
              <Alan
                {...b}
                type="date"
                value={form.veris_tarihi}
                onChange={(e) => setForm({ ...form, veris_tarihi: e.target.value })}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("icraAvukat")}>
            {(b) => (
              <Alan
                {...b}
                value={form.avukat}
                onChange={(e) => setForm({ ...form, avukat: e.target.value })}
                maxLength={150}
              />
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("icraAciklama")}>
            {(b) => (
              <CokSatir
                {...b}
                rows={3}
                value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })}
                maxLength={1000}
              />
            )}
          </AlanSarmal>
        </form>
      </Modal>
      {diyalog}
    </div>
  );
}
