"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  EksikVeriUyarisi,
  FiltreCubugu,
  Kart,
  Modal,
  OzetKarti,
  OzetSeridi,
  Rozet,
  SayfaBasligi,
  Secim,
  type Kolon,
  type TabloDurumu,
  VeriTablosu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { kisaKimlik } from "@/lib/kimlik";
import { DEMIRBAS_DURUM, DEMIRBAS_KATEGORI, enumAdi } from "@/lib/enum-adlari";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import { useAcilinca } from "@/lib/kaydir";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type {
  AssetCheckout,
  Asset,
  AssetCheckoutList,
  AssetKategori,
  AssetList,
  UserListResponse,
} from "@/lib/types";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
// NFC bir TEKNIK KIMLIKTIR — cevrilmez, sozluge girmez.
const NFC_BASLIK = "NFC" as const;
const R_OLUMLU = "olumlu" as const;
const R_UYARI = "uyari" as const;
const R_NOTR = "notr" as const;

/** Demirbas durumu -> rozet rengi. */
function durumRengi(d: string) {
  if (d === "musait") return R_OLUMLU;
  if (d === "zimmetli") return R_UYARI;
  return R_NOTR;
}
const NFC_PLACEHOLDER = "04A1B2C3D4";
// UCLUDE/SORGUDA DIZE YAZILMAZ (depo kurali `sabit-metin`).
const D_MUSAIT = "musait" as const;
const D_ZIMMETLI = "zimmetli" as const;
const D_BAKIMDA = "bakimda" as const;

const IKON_KUTU = "M3 8.5 12 4l9 4.5M3 8.5V17l9 4.5M3 8.5l9 4.5m0 0v9m0-9 9-4.5M21 8.5V17l-9 4.5";
const IKON_KISI = "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4 21a8 8 0 0 1 16 0";
const IKON_ANAHTAR = "M14.7 6.3a4 4 0 1 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4M17 7h.01";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}
// METIN DEGIL KIMLIK (modul duzeyinde `t()` yok — README tur 18 dersi).
const KATEGORI: { value: AssetKategori; anahtar: SozlukAnahtari }[] = [
  { value: "ekipman", anahtar: "demirbasEkipman" },
  { value: "arac", anahtar: "demirbasArac" },
  { value: "alet", anahtar: "demirbasAlet" },
  { value: "diger", anahtar: "ortakDiger" },
];
// (P244 §8b) `DURUM_STYLE` SILINDI — OLU KODDU.
//
// Ham tailwind paleti (sabit yesil zemin + metin) tasiyan tek
// sabitti ve HIC KULLANILMIYORDU: rozet rengi yukaridaki `durumRengi`
// uzerinden `Rozet`in kendi token'larindan geliyor. Eski dilin renk
// katmanindan geriye kalan bir kalintiydi.

interface FormState {
  ad: string;
  kategori: string;
  nfc_tag_uid: string;
  aciklama: string;
  aktif: boolean;
}
const EMPTY: FormState = { ad: "", kategori: "", nfc_tag_uid: "", aciklama: "", aktif: true };

export default function AssetsPage() {
  const t = useT();
  const toast = useToast();
  // (P160) SAYFALAMA `VeriTablosu` durumuna gecti.
  const [tabloDurumu, setTabloDurumu] = useState<TabloDurumu>({
    sayfa: 1,
    boy: 25,
    siraKolon: null,
    siraYonu: "artan",
  });
  const offset = (tabloDurumu.sayfa - 1) * tabloDurumu.boy;
  const [kategori, setKategori] = useState("");
  const [durum, setDurum] = useState("");

  const qs = new URLSearchParams({ limit: String(tabloDurumu.boy), offset: String(offset) });
  if (kategori) qs.set("kategori", kategori);
  if (durum) qs.set("durum", durum);
  const { data, error, isLoading, mutate } = useSWR<AssetList>(
    `/api/assets?${qs.toString()}`,
    jsonFetcher,
  );
  // SAYAÇLAR AYRI UÇLARDAN, GORUNEN SAYFADAN DEGIL (`?durum=X&limit=1`
  // -> `meta.total`). Gorunen sayfa hem sayfalanmis hem SUZULMUS olur;
  // ondan saymak, suzgec acikken sayaci da suzerdi.
  const { data: musaitSayi } = useSWR<AssetList>(
    `/api/assets?limit=1&offset=0&durum=${D_MUSAIT}`,
    jsonFetcher,
  );
  const { data: zimmetliSayi } = useSWR<AssetList>(
    `/api/assets?limit=1&offset=0&durum=${D_ZIMMETLI}`,
    jsonFetcher,
  );
  const { data: bakimdaSayi } = useSWR<AssetList>(
    `/api/assets?limit=1&offset=0&durum=${D_BAKIMDA}`,
    jsonFetcher,
  );
  const { data: users, error: usersErr } = useSWR<UserListResponse>("/api/users?limit=200&offset=0", jsonFetcher);

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  // (P162 §7.1) Acilan detay alanina yumusak kaydirma — tek yardimci.
  const { ref: detayRef, kaydir: detayKaydir } = useAcilinca();
  const [detail, setDetail] = useState<Asset | null>(null);

  const { data: history } = useSWR<AssetCheckoutList>(
    detail ? `/api/assets/${detail.id}/history?limit=50&offset=0` : null,
    jsonFetcher,
  );

  function userName(id: string): string {
    return users?.items.find((u) => u.id === id)?.ad ?? kisaKimlik(id);
  }

  function openNew() {
    setEditingId(null);
    setForm(EMPTY);
    setFormErr(null);
    setOpen(true);
  }
  function openEdit(a: Asset) {
    setEditingId(a.id);
    setForm({
      ad: a.ad,
      kategori: a.kategori ?? "",
      nfc_tag_uid: a.nfc_tag_uid ?? "",
      aciklama: a.aciklama ?? "",
      aktif: a.aktif,
    });
    setFormErr(null);
    setOpen(true);
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    const body = {
      ad: form.ad,
      kategori: form.kategori || null,
      nfc_tag_uid: form.nfc_tag_uid.trim() || null,
      aciklama: form.aciklama || null,
      aktif: form.aktif,
    };
    try {
      if (editingId) await apiSend(`/api/assets/${editingId}`, "PATCH", body);
      else await apiSend("/api/assets", "POST", body);
      setOpen(false);
      mutate();
      toast.success(editingId ? t("demirbasGuncellendi") : t("demirbasOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(/nfc/i.test(m) ? t("demirbasEtiketKullanimda") : m);
    } finally {
      setSaving(false);
    }
  }

  async function setActive(a: Asset, active: boolean) {
    try {
      await apiSend(`/api/assets/${a.id}`, "PATCH", { aktif: active });
      mutate();
      toast.success(active ? t("demirbasAktiflestirildi") : t("demirbasPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  const openCheckout = (history?.items ?? []).find((h) => !h.birakma_zamani) ?? null;

  const kolonlar: Kolon<Asset>[] = useMemo(
    () => [
      { id: "ad", kartRolu: "baslik", baslik: t("ortakAd"), gizlenebilir: false, hucre: (a) => a.ad },
      {
        id: "kategori", kartRolu: "ozet",
        baslik: t("gorevKategoriAlan"),
        hucre: (a) => enumAdi(t, DEMIRBAS_KATEGORI, a.kategori),
      },
      {
        id: "nfc",
        baslik: NFC_BASLIK,
        darEkrandaGizle: true,
        hucre: (a) => <span className="font-mono">{a.nfc_tag_uid ?? "—"}</span>,
      },
      {
        id: "durum", kartRolu: "rozet",
        baslik: t("ortakDurum"),
        hucre: (a) => (
          <Rozet durum={durumRengi(a.durum)}>{enumAdi(t, DEMIRBAS_DURUM, a.durum)}</Rozet>
        ),
      },
      {
        id: "aktif",
        baslik: t("ortakAktif"),
        darEkrandaGizle: true,
        hucre: (a) => (a.aktif ? t("ortakEvet2") : t("ortakHayir2")),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (a) => (
          <div className="flex justify-end gap-2">
            <Dugme
              boy="kucuk"
              aria-expanded={detail?.id === a.id}
              onClick={() => { setDetail(detail?.id === a.id ? null : a); detayKaydir(); }}
            >
              {detail?.id === a.id ? t("ortakKapat") : t("demirbasZimmet")}
            </Dugme>
            <Dugme boy="kucuk" onClick={() => openEdit(a)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme boy="kucuk" onClick={() => setActive(a, !a.aktif)}>
              {a.aktif ? t("ortakPasiflestir") : t("ortakAktiflestir")}
            </Dugme>
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, detail],
  );

  const gecmisKolonlari: Kolon<AssetCheckout>[] = useMemo(
    () => [
      {
        id: "alan",
        baslik: t("demirbasAlan"),
        gizlenebilir: false,
        hucre: (h) => userName(h.alan_user_id),
      },
      { id: "alma", baslik: t("demirbasAlma"), hucre: (h) => formatDateTime(h.alma_zamani) },
      {
        id: "birakma",
        baslik: t("demirbasBirakma"),
        hucre: (h) =>
          h.birakma_zamani ? formatDateTime(h.birakma_zamani) : t("demirbasAcik"),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, users],
  );

  return (
    <div>
      <SayfaBasligi
        baslik={t("kabukDemirbas")}
        aciklama={t("demirbasSayfaAlt")}
        eylem={
          <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
            {t("demirbasYeni")}
          </Dugme>
        }
      />

      {/* Sayaclar ayri uclardan gelir: liste hem sayfali hem suzgecli;
          gorunen sayfadan saymak yanlis bir sayi uretirdi. */}
      <OzetSeridi>
        <OzetKarti
          etiket={t("demirbasMusait")}
          deger={String(musaitSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_KUTU} />}
          durum="olumlu"
        />
        <OzetKarti
          etiket={t("demirbasZimmetli")}
          deger={String(zimmetliSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_KISI} />}
          durum="uyari"
          altBilgi={t("demirbasZimmetliAlt")}
        />
        <OzetKarti
          etiket={t("demirbasBakimda")}
          deger={String(bakimdaSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ANAHTAR} />}
          durum="notr"
        />
      </OzetSeridi>

      <EksikVeriUyarisi
        mesaj={usersErr ? t("ortakSecenekYuklenemedi") : null}
      />

      <FiltreCubugu
        aktifSayi={(kategori ? 1 : 0) + (durum ? 1 : 0)}
        onTemizle={() => {
          setKategori("");
          setDurum("");
          setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
        }}
      >
        {/* SECIMLER GORUNMEZ ETIKETLI: serit her kontrolun ustune bir
            etiket satiri koyunca iki kata cikiyordu; ad `aria-label`
            ile KALIR. */}
        <Secim
          aria-label={t("gorevKategoriAlan")}
          value={kategori}
          onChange={(e) => {
            setKategori(e.target.value);
            setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
          }}
          className="w-auto"
        >
          <option value="">{t("demirbasKategoriHepsi")}</option>
          {KATEGORI.map((k) => (
            <option key={k.value} value={k.value}>
              {t(k.anahtar)}
            </option>
          ))}
        </Secim>
        <Secim
          aria-label={t("ortakDurum")}
          value={durum}
          onChange={(e) => {
            setDurum(e.target.value);
            setTabloDurumu((d) => ({ ...d, sayfa: 1 }));
          }}
          className="w-auto"
        >
          <option value="">{t("demirbasDurumHepsi")}</option>
          <option value={D_MUSAIT}>{t("demirbasMusait")}</option>
          <option value={D_ZIMMETLI}>{t("demirbasZimmetli")}</option>
          <option value={D_BAKIMDA}>{t("demirbasBakimda")}</option>
        </Secim>
      </FiltreCubugu>

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("demirbasDuzenle") : t("demirbasYeni")}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="demirbas-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        <form id="demirbas-form" onSubmit={save} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <AlanSarmal etiket={t("ortakAd")}>
  {(b) => (
    <Alan {...b} value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required />
  )}
</AlanSarmal>
            <AlanSarmal etiket={t("demirbasKategoriOpsiyonel")}>
  {(b) => (
    <Secim {...b} value={form.kategori}
                onChange={(e) => setForm({ ...form, kategori: e.target.value })}
              >
                <option value="">{t("ortakYokSecim")}</option>
                {KATEGORI.map((k) => (
                  <option key={k.value} value={k.value}>
                    {t(k.anahtar)}
                  </option>
                ))}</Secim>
  )}
</AlanSarmal>
            <AlanSarmal
              etiket={t("demirbasNfcUidOpsiyonel")}
              ipucu={t("demirbasEtiketIpucu")}
            >
              {(b) => (
                <Alan
                  {...b}
                  className="font-mono uppercase"
                  value={form.nfc_tag_uid}
                  placeholder={NFC_PLACEHOLDER}
                  onChange={(e) =>
                    setForm({ ...form, nfc_tag_uid: e.target.value.toUpperCase() })
                  }
                />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("ortakAciklamaOpsiyonel")}>
  {(b) => (
    <Alan {...b} value={form.aciklama}
                onChange={(e) => setForm({ ...form, aciklama: e.target.value })} />
  )}
</AlanSarmal>
          </div>
          <label
            className="flex items-center gap-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
          >
            <input
              type="checkbox"
              checked={form.aktif}
              onChange={(e) => setForm({ ...form, aktif: e.target.checked })}
            />
            {t("ortakAktif")}
          </label>
          {formErr && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {formErr}
            </p>
          )}
        </form>
      </Modal>

      <VeriTablosu<Asset>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(a) => a.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        bosBaslik={t("demirbasYok")}
        // (E2E 2026-09) "Filtreyi degistirin" YALNIZ suzgec aciksa.
        bosAciklama={kategori || durum ? t("demirbasYokAlt") : t("demirbasYokIlk")}
        sunucuTarafli
        toplam={data?.meta?.total ?? 0}
        durum={tabloDurumu}
        onDurumDegisti={setTabloDurumu}
      />

      <div ref={detayRef} />
      {detail && (
        <Kart className="space-y-3">
          <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
            {t("demirbasZimmetBaslik", { ad: detail.ad })}
          </h2>
          <p style={{ fontSize: "var(--yz-fs-sm)" }}>
            {openCheckout ? (
              <span style={{ color: "var(--yz-warning-ink)" }}>
                {t("demirbasSuAnUzerinde", {
                  kisi: userName(openCheckout.alan_user_id),
                  zaman: formatDateTime(openCheckout.alma_zamani),
                })}
              </span>
            ) : (
              <span style={{ color: "var(--yz-success-ink)" }}>
                {t("demirbasKimsedeDegil")}
              </span>
            )}
          </p>
          <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
            {t("demirbasPanelNotu")}
          </p>
          <VeriTablosu<AssetCheckout>
            kolonlar={gecmisKolonlari}
            satirlar={history?.items ?? []}
            satirId={(h) => h.id}
            bosBaslik={t("demirbasZimmetYok")}
          />
        </Kart>
      )}

    </div>
  );
}
