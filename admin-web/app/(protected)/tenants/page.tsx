"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const R_OLUMLU = "olumlu" as const;
const R_UYARI = "uyari" as const;

import {
  Modal,
  Rozet,
  VeriTablosu,
  type Kolon,
  Kart,
  Alan,
  AlanSarmal,
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  useOnay,
} from "@/components/ui";
import { KopyaKod } from "@/components/KopyaKod";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher } from "@/lib/fetcher";
import { useGecikmeli } from "@/lib/gecikmeli";
import type { TenantAdminCreate, TenantAdminCreatedOut } from "@/lib/types";
import { ParolaAlani } from "@/components/ParolaAlani";
import { TelefonAlani } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { ApiHatasi } from "@/lib/client";
import { tarihSaatUzun } from "@/lib/tarih";
import { telefonNormalle } from "@/lib/telefon";

/** (P226) Acilir liste secenek stili — DUZ renk, gradyan DEGIL. */
const SECENEK_STILI = {
  background: "var(--yz-surface-1)",
  color: "var(--yz-text)",
} as const;

interface TenantRow {
  id: string;
  ad: string;
  kayit_kodu: string | null;
  kurulum_tamamlandi: boolean;
  created_at: string;
  /** (P225) Platform admini barindiriyor mu — Sil dugmesi CIZILMEZ. */
  platform_admini_var?: boolean;
}
interface TenantListResponse {
  items: TenantRow[];
}

// Formdaki tek yonetici satiri. Parola bos string = "verilmedi" (govdeye hic
// konmaz) -> backend tek seferlik gecici kod uretir.
interface YoneticiForm {
  /** (P68) KARARLI ANAHTAR. Liste `key={i}` kullaniyordu ve ORTADAN satir
   *  SILINEBILIYOR: React o durumda DOM dugumlerini yeniden kullanir ve
   *  imlec/odak, tarayicinin otomatik doldurmasi, parola yoneticisinin
   *  bagi BIR ALT satira kayar. Satirda PAROLA alani var — yanlis satira
   *  baglanan bir parola yoneticisi ciddi bir kusurdur. */
  anahtar: string;
  ad: string;
  phone: string;
  /** (P197) ZORUNLU — davetin gidecegi TEK kanal. */
  email: string;
  password: string;
}
let _sayac = 0;
function bosYonetici(): YoneticiForm {
  _sayac += 1;
  return { anahtar: `y${_sayac}`, ad: "", phone: "", email: "", password: "" };
}
interface FormState {
  ad: string;
  yonetim_email: string;
  yoneticiler: YoneticiForm[];
}
// Ilk satir HER ZAMAN vardir ve BIRINCIL'dir (kaldirilamaz) — backend en az bir
// yonetici bekler ve listenin ilkini birincil isaretler.
const bosForm = (): FormState => ({
  ad: "",
  yonetim_email: "",
  yoneticiler: [bosYonetici()],
});

function fmtDate(iso: string): string {
  try {
    return tarihSaatUzun(iso);
  } catch {
    return iso;
  }
}

export default function TenantsPage() {
  const t = useT();
  // (P161) Yikici onaylar tema/dil taniyan diyalogdan gecer.
  const { onayla, diyalog } = useOnay();
  const toast = useToast();
  // (P225) ARAMA SUNUCUDA. Bugun 8 tesis var ve istemcide suzmek de
  // calisirdi; sunucu secildi cunku (a) sayfalama eklendigi gun arama
  // TASINMAK ZORUNDA KALMAZ — istemcide suzen liste ilk sayfalamada
  // "yalniz bu sayfada ara" haline duser ve bu SESSIZ bir gerilemedir,
  // (b) TURKCE HARF KATLAMASI TEK KURAL olmali: sunucu `slug` uzerinden
  // katliyor (Dukkan aramasiyla ayni), istemcide ikinci bir katlama
  // yazmak iki farkli "cekmekoy" tanimi demekti.
  const [arama, setArama] = useState("");
  const [kurulumSuzgec, setKurulumSuzgec] = useState<"" | "bekliyor" | "tamam">("");
  // Her tusta istek atmamak icin gecikme (P220'de yazilan ortak kanca).
  const gecikmeliArama = useGecikmeli(arama, 300);
  // BOS DURUM MESAJI icin: suzgec acik mi? Gecikmeli degeri kullaniyoruz —
  // kullanici yazarken mesaj titremesin.
  const aramaAktif = Boolean(gecikmeliArama.trim() || kurulumSuzgec);

  const sorgu = new URLSearchParams();
  if (gecikmeliArama.trim()) sorgu.set("q", gecikmeliArama.trim());
  if (kurulumSuzgec) sorgu.set("kurulum", String(kurulumSuzgec === "tamam"));
  const { data, error, isLoading, mutate } = useSWR<TenantListResponse>(
    `/api/tenants${sorgu.toString() ? `?${sorgu}` : ""}`,
    jsonFetcher,
  );

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(bosForm);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openNew() {
    setForm(bosForm());
    setFormErr(null);
    setOpen(true);
  }

  async function removeTenant(tesis: TenantRow) {
    // (P225) ONAY ARTIK TESISIN ADI.
    //
    // Eskiden sabit bir kelime yazdiriliyordu ve o kelime HER TESISTE
    // AYNIYDI: kas hafizasi olusuyor, yanlis tesiste de ayni refleksle
    // yaziliyordu. Prod'da bir tesis boyle silindi ve platform admin
    // hesabi CASCADE ile gitti.
    //
    // Eski yorum "yeni tesisin adi yer tutucu oldugu icin ad-yazdirma
    // pratik degil" diyordu; dogru cozum ad-yazdirmaktan vazgecmek
    // DEGIL, ne yazilacagini SUNUCUNUN soylemesiydi — liste zaten
    // gercek adi tasiyor.
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("tesisSilOnayMetni", { ad: tesis.ad }),
      onayMetni: tesis.ad,
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      // ONAY SUNUCUYA DA GIDER: panelin tek basina zorlamasi, ucu
      // dogrudan cagiran her seyi korumasiz birakirdi.
      await apiSend(
        `/api/tenants/${tesis.id}?onay=${encodeURIComponent(tesis.ad)}`,
        "DELETE",
      );
      mutate();
      toast.success(t("tesisSilindi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakSilinemedi"));
    }
  }

  function setYonetici(i: number, patch: Partial<YoneticiForm>) {
    setForm({
      ...form,
      yoneticiler: form.yoneticiler.map((y, j) => (j === i ? { ...y, ...patch } : y)),
    });
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      const body: TenantAdminCreate = {
        yoneticiler: form.yoneticiler.map((y) => ({
          ad: y.ad,
          // Sunucuya NORMALLESTIRILMIS gider (telefon GLOBAL BENZERSIZ).
          phone: telefonNormalle(y.phone),
          // (P197) E-POSTA ZORUNLU: sunucu e-postasiz yonetici KABUL ETMEZ
          // (422). Davet bu adrese gider; adres yoksa hesap acilir ama
          // sahiplenilemez.
          email: y.email.trim(),
          ...(y.password ? { password: y.password } : {}),
        })),
      };
      if (form.ad.trim()) body.ad = form.ad.trim();
      if (form.yonetim_email.trim()) body.yonetim_email = form.yonetim_email.trim();

      const created = await apiSend<TenantAdminCreatedOut>("/api/tenants", "POST", body);

      // Gecici kod YALNIZ parolasiz acilan yonetici icin ve BIR KEZ doner —
      // her kod kendi yoneticisinin adiyla listelenir ki yanlis kisiye gitmesin.
      const kodlar = (created?.yoneticiler ?? []).filter((y) => y.temp_code);
      if (kodlar.length) {
        window.alert(
          t("tesisKodlarBaslik") +
            kodlar
              .map((y) => `• ${y.ad}${y.birincil ? t("tesisYoneticiBirincilEki") : ""}: ${y.temp_code}`)
              .join("\n") +
            t("tesisKodlarNot"),
        );
      } else {
        window.alert(
          t("tesisParolaIleGiris"),
        );
      }
      setOpen(false);
      mutate();
    } catch (err) {
      // KOD ile karar (tur 22): sunucu metni artik 7 dilde geldigi icin
      // metinde arama yapmak Turkce disi her dilde sessizce bozulurdu.
      const cakisma =
        err instanceof ApiHatasi &&
        (err.code === "conflict" || err.status === 409);
      setFormErr(
        cakisma
          ? t("tesisTelefonKayitli")
          : err instanceof Error
            ? err.message
            : t("ortakHataOlustu"),
      );
    } finally {
      setSaving(false);
    }
  }

  const kolonlar: Kolon<TenantRow>[] = useMemo(
    () => [
      {
        id: "ad", kartRolu: "baslik",
        baslik: t("ayarTesisAdi"),
        gizlenebilir: false,
        deger: (x) => x.ad,
        hucre: (x) => (
          <Link
            href={`/tenants/${x.id}`}
            className="odak-ic underline"
            style={{ fontWeight: 600, color: "var(--yz-accent-ink)" }}
          >
            {x.ad}
          </Link>
        ),
      },
      {
        // (P155 §6) Yoneticinin ILETECEGI kod birincil; teknik UUID
        // `title` icinde erisilebilir kalir.
        id: "kod", kartRolu: "ozet",
        baslik: t("tesisKayitKodu"),
        hucre: (x) =>
          x.kayit_kodu ? (
            <KopyaKod deger={x.kayit_kodu} etiket={t("tesisKayitKodu")} />
          ) : (
            <span
              style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              title={x.id}
            >
              —
            </span>
          ),
      },
      {
        id: "kurulum",
        baslik: t("tesisKurulum"),
        hucre: (x) => (
          <Rozet durum={x.kurulum_tamamlandi ? R_OLUMLU : R_UYARI}>
            {x.kurulum_tamamlandi ? t("tesisTamamlandi") : t("tesisBekliyor")}
          </Rozet>
        ),
      },
      {
        id: "olusturma", kartRolu: "ozet",
        baslik: t("tesisOlusturulma"),
        darEkrandaGizle: true,
        hucre: (x) => fmtDate(x.created_at),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (x) => (
          <div className="flex justify-end gap-2">
            <Link
              href={`/tenants/${x.id}`}
              className="odak-ic yz-lift inline-flex items-center px-3 py-2"
              style={{
                borderRadius: "var(--yz-radius-btn)",
                border: "var(--yz-border-w) solid var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text)",
                background: "var(--yz-metal-1)",
              }}
            >
              {t("tesisYonet")}
            </Link>
            {/* (P225) PLATFORM ADMINI BARINDIRAN TESISTE SIL DUGMESI
                HIC CIZILMEZ. Sunucu ve trigger da reddediyor (uc
                katman); buradaki gizleme, yoneticiyi anlamsiz bir
                409'a surmemek ve yanlis tikla o an bir sey
                olabilecegi izlenimini vermemek icin.
                Ekran goruntusunde gorulen kusur tam buydu: platform
                tesisinin satirinda Sil dugmesi otekilerle AYNIYDI. */}
            {x.platform_admini_var ? (
              <span
                data-test="tesis-sil-korumali"
                title={t("tesisSilAdminVar")}
                className="inline-flex items-center px-3 py-2"
                style={{
                  fontSize: "var(--yz-fs-sm)",
                  color: "var(--yz-text-3)",
                }}
              >
                {t("tesisKorumali")}
              </span>
            ) : (
              <Dugme tur="tehlike" boy="kucuk" onClick={() => void removeTenant(x)}>
                {t("ortakSil")}
              </Dugme>
            )}
          </div>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
            {t("kabukTesisler")}
          </h1>
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("tesisListeAciklama")}
          </p>
        </div>
        <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
          {t("tesisYeni")}
        </Dugme>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && <IskeletMetin satir={3} />}

      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={t("tesisYeni")}
        // Doldurulmus form kazara kapanmasin.
        kirliMi={form.ad !== "" || form.yonetim_email !== ""}
        onKirliKapat={() => {
          void onayla({
            baslik: t("modalKirliBaslik"),
            mesaj: t("modalKirliUyari"),
            onayMetni: t("ortakVazgec"),
            tehlikeli: true,
          }).then((o) => {
            if (o) setOpen(false);
          });
        }}
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme type="submit" form="tesis-form" tur="birincil" yukleniyor={saving}>
              {saving ? t("tesisOlusturuluyor") : t("tesisOlustur")}
            </Dugme>
          </>
        }
      >
        <form id="tesis-form" onSubmit={save} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <AlanSarmal etiket={t("tesisAdiOpsiyonel")} ipucu={t("tesisAdiBosIpucu")}>
              {(b) => (
                <Alan {...b}
                                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                minLength={2}
                placeholder={t("tesisAdiOrnek")}
              />
              )}
            </AlanSarmal>
            <AlanSarmal etiket={t("tesisYonetimMaili")} ipucu={t("tesisYonetimMailiIpucu")}>
              {(b) => (
                <Alan {...b}
                type="email"
                                value={form.yonetim_email}
                onChange={(e) => setForm({ ...form, yonetim_email: e.target.value })}
                placeholder={t("tesisYonetimMailiOrnek")}
              />
              )}
            </AlanSarmal>
          </div>

          <div className="space-y-4">
            {form.yoneticiler.map((y, i) => (
              <div key={y.anahtar} className="rounded-lg border kart-kenar p-4">
                <div className="mb-3 flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-medium">
                      {i === 0
                        ? t("tesisBirincilYonetici")
                        : t("tesisYoneticiSira", { n: i + 1 })}
                    </h3>
                    {i === 0 && (
                      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>{t("tesisIlkGirisAdlandirir")}</p>
                    )}
                  </div>
                  {i > 0 && (
                    <button
                      type="button"
                      className="rounded-lg px-3 py-1.5 text-sm font-medium text-rose-700 transition hover:bg-rose-50"
                      onClick={() =>
                        setForm({
                          ...form,
                          yoneticiler: form.yoneticiler.filter((_, j) => j !== i),
                        })
                      }
                    >
                      {t("tesisKaldir")}
                    </button>
                  )}
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <AlanSarmal etiket={t("tesisAdSoyad")}>
  {(b) => (
    <Alan {...b} value={y.ad}
                      onChange={(e) => setYonetici(i, { ad: e.target.value })}
                      required
                      minLength={2} />
  )}
</AlanSarmal>
                  <TelefonAlani
                    etiket={t("kullaniciTelefon")}
                    ipucu={t("tesisTelefonIpucu")}
                    zorunlu
                    deger={y.phone}
                    onDegisti={(v) => setYonetici(i, { phone: v })}
                  />
                  {/* (P197) E-POSTA ZORUNLU. Davet YALNIZ buradan gider
                      (SMS urun genelinde kapali); adressiz acilan hesap
                      Tesis ID'yi HIC ogrenemez ve giris yapamaz. Sunucu
                      da e-postasiz govdeyi 422 ile reddeder. */}
                  <AlanSarmal
                    etiket={t("kullaniciEposta")}
                    ipucu={t("tesisYoneticiEpostaIpucu")}
                  >
                    {(b) => (
                      <Alan
                        {...b}
                        type="email"
                        value={y.email}
                        onChange={(e) => setYonetici(i, { email: e.target.value })}
                        required
                      />
                    )}
                  </AlanSarmal>
                  <AlanSarmal
                    etiket={t("tesisParolaOpsiyonel")}
                    ipucu={t("kullaniciParolaBosYeni")}
                  >
                    {(b) => (
                      <ParolaAlani
                        // Etiket kimligi BAGLANMALI: `AlanSarmal` `htmlFor`
                        // ile bu kimlige isaret ediyor.
                        id={b.id}
                        value={y.password}
                        onChange={(v) => setYonetici(i, { password: v })}
                        minLength={8}
                        placeholder={t("kullaniciParolaBosKisa")}
                      />
                    )}
                  </AlanSarmal>
                </div>
              </div>
            ))}
            <Dugme
              type="button"
              boy="kucuk"
              onClick={() =>
                setForm({ ...form, yoneticiler: [...form.yoneticiler, bosYonetici()] })
              }
            >
              {t("tesisYoneticiEkle")}
            </Dugme>
          </div>

          <HataDurumu mesaj={formErr} />
        </form>
      </Modal>

      <VeriTablosu<TenantRow>
        kolonlar={kolonlar}
        satirlar={data?.items ?? []}
        satirId={(x) => x.id}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        yukleniyor={isLoading && !data}
        // (P225) SONUC YOKSA BOS TABLO BIRAKILMAZ ve mesaj ARAMAYA GORE
        // degisir: "hic tesis yok" ile "aramana eslesen yok" ayri
        // durumlardir; ayni cumle, suzgeci acik biraktigini fark etmeyen
        // kullaniciya "tesisler silinmis" dedirtirdi.
        bosBaslik={aramaAktif ? t("tesisAramaSonucYok") : t("tesisYok")}
        bosAciklama={aramaAktif ? t("tesisAramaSonucYokAlt") : t("tesisYokAlt")}
        // Satirlar 1'den numaralanir; numara SAYFA BASINA degil LISTENIN
        // TAMAMINA gore (gerekce `VeriTablosu.numarali`).
        numarali
        araclar={
          <div className="flex flex-wrap items-center gap-2">
            <Alan
              aria-label={t("tesisAraEtiketi")}
              placeholder={t("tesisAraIpucu")}
              value={arama}
              onChange={(e) => setArama(e.target.value)}
              className="w-64"
              data-test="tesis-ara"
            />
            <select
              aria-label={t("tesisKurulumSuzgec")}
              value={kurulumSuzgec}
              onChange={(e) =>
                setKurulumSuzgec(e.target.value as "" | "bekliyor" | "tamam")
              }
              data-test="tesis-kurulum-suzgec"
              className="rounded border px-3 py-2"
              // (P226) ARKA PLAN DUZ RENK — GRADYAN DEGIL.
              //
              // Once `background: var(--yz-metal-1)` yazmistim; o token bir
              // `linear-gradient`. `<option>` satirlari select'in arka
              // planini devralir ama native acilir listede gradyan
              // uygulanamaz: tarayici geri duser, `color` ise
              // `--yz-text` olarak kalir. Koyu temada acik metin acik
              // zeminde kaliyor ve SECENEKLER GORUNMEZ oluyordu —
              // kullanicinin gordugu "listede yalniz ilk satir var"
              // tam olarak buydu.
              //
              // `--yz-surface-1` DUZ renktir (#ffffff / #3b4650) ve her iki
              // temada da `--yz-text` ile okunur kontrast verir.
              style={{
                fontSize: "var(--yz-fs-sm)",
                borderColor: "var(--yz-border)",
                background: "var(--yz-surface-1)",
                color: "var(--yz-text)",
              }}
            >
              {/* Secenekler de ACIKCA boyanir: bazi tarayicilar option
                  arka planini select'ten DEVRALMAZ ve sistem varsayilanina
                  duser. */}
              <option value="" style={SECENEK_STILI}>
                {t("tesisKurulumHepsi")}
              </option>
              <option value="bekliyor" style={SECENEK_STILI}>
                {t("tesisKurulumBekleyen")}
              </option>
              <option value="tamam" style={SECENEK_STILI}>
                {t("tesisKurulumTamamlanan")}
              </option>
            </select>
          </div>
        }
      />
      {diyalog}
    </div>
  );
}
