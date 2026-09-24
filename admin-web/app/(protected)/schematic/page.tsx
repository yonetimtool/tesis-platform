"use client";

import { useMemo, useState } from "react";
import useSWR from "swr";

import {
  BosDurum,
  HataDurumu,
  IskeletMetin,
  Kart,
  OzetKarti,
  OzetSeridi,
  SayfaBasligi,
  Secim,
  Sekmeler,
} from "@/components/ui";
import { PlanHaritasiYukleyici } from "@/components/harita/harita-yukleyici";
import type { PlanBlogu, PlanHucresi } from "@/components/harita/plan-haritasi";
import { jsonFetcher } from "@/lib/fetcher";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import { tarihBicimi } from "@/lib/tarih";
import type {
  BuildingMap,
  BuildingMapUnit,
  DensityRenk,
  UnitComplaint,
  UnitComplaintList,
} from "@/lib/types";

// Renk API'den gelir (P24 DORT KADEME: yesil 0 / sari 1-2 / kirmizi 3-4 /
// mor 5+ — backend `_ESIKLER`); panel ESIK HESAPLAMAZ.
//
// (P160) ZEMIN RENGI BIRAKILDI, KENAR RENGI ALINDI. Eskiden hucre KOYU
// RENKLE doluydu ve uzerinde BEYAZ metin vardi; bu duzen 4.5 kontrast
// istiyor ve her iki temada ayri ayri olculmesi gerekiyordu (tur 30 axe
// denetimi -500 tonlarini tam bu yuzden dusurmustu). Yeni dilde hucre
// KABARTILMIS METAL yuzeydir: metin normal metin renginde (zaten AA) ve
// yogunluk KENAR + NOKTA ile anlatilir. Anlamli grafik esigi 3.0'dir ve
// `--yz-*-edge` tonlari tam bunun icin olculdu (WCAG 1.4.11).
//
// RENK TEK TASIYICI DEGIL: sayi zaten hucrede yaziyor.
const RENK_TOKEN: Record<DensityRenk, string> = {
  yesil: "var(--yz-success-edge)",
  sari: "var(--yz-warning-edge)",
  kirmizi: "var(--yz-danger-edge)",
  // (E2E 2026-09) TESIS-20: "mor" yoktu -> 5+ daire YESIL ciziliyordu.
  // NFC isaretci tonu: mor aile, 1.4.11 esigiyle olculmus (tasarim-sistemi.css).
  mor: "var(--yz-nfc-edge)",
};
const NOTR_TOKEN = "var(--yz-border)";
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const GORUNUM_SEMA = "sema" as const;
const GORUNUM_HARITA = "harita" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`) — CSS olcusu de dize.
const KENAR_SECILI = "3px" as const;
const KENAR_NORMAL = "2px" as const;

/** Yogunluk rengi -> kenar/nokta tonu. null (yapi gorunumu) -> notr. */
function renkTonu(renk: DensityRenk | null | undefined): string {
  return renk ? (RENK_TOKEN[renk] ?? RENK_TOKEN.yesil) : NOTR_TOKEN;
}

// METIN DEGIL KIMLIK: modul duzeyinde `t()` cagrilamaz (bilesen disi) ve
// cagrilabilse bile metin dil degisiminde donmus kalirdi. Harita ANAHTAR
// tutar, cozum cizim aninda yapilir.
const KATEGORI_ANAHTAR: Record<string, SozlukAnahtari> = {
  gurultu: "kategoriGurultu",
  kapi_onu_ayakkabi: "kategoriKapiOnu",
  zarar_verme: "kategoriZararVerme",
  // (E2E 2026-09) TESIS-20: eksikti, ham anahtar yaziliyordu.
  goruntu_kirliligi: "kategoriGoruntuKirliligi",
  diger: "ortakDiger",
};
// Tur secicisinin sirasi (backend `UnitComplaintKategori` ile ayni kume).
const KATEGORI_SIRASI = [
  "gurultu",
  "kapi_onu_ayakkabi",
  "zarar_verme",
  "goruntu_kirliligi",
  "diger",
] as const;

const fmtDate = tarihBicimi;

function UnitCell({
  unit,
  onSelect,
  selected,
}: {
  unit: BuildingMapUnit;
  onSelect: (u: BuildingMapUnit) => void;
  selected: boolean;
}) {
  const t = useT();
  const ton = renkTonu(unit.color);
  return (
    <button
      onClick={() => onSelect(unit)}
      // (P160) SECILILIK eskiden yalniz HALKA ile belliydi; ekran okuyucu
      // hangi dairenin acik oldugunu soylemiyordu.
      aria-pressed={selected}
      title={t("haritaKartBaslik", { daire: unit.unit_no, sayi: unit.complaint_count ?? 0 })}
      className={`odak-ic yz-raised flex h-16 w-20 flex-col items-center justify-center gap-0.5 ${
        selected ? "" : "yz-lift"
      }`}
      style={{
        borderRadius: "var(--yz-radius-btn)",
        // Secili hucre KALIN kenar: renk zaten yogunlugu tasiyor, kalinlik
        // secimi tasir — ikisi ayri kanal.
        border: `${selected ? KENAR_SECILI : KENAR_NORMAL} solid ${ton}`,
        color: "var(--yz-text)",
        background: "var(--yz-metal-1)",
      }}
    >
      <span style={{ fontSize: "var(--yz-fs-sm)", fontWeight: 600 }}>{unit.unit_no}</span>
      <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {unit.complaint_count ?? 0}
      </span>
    </button>
  );
}

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const RENK_KIRMIZI = "kirmizi" as const;
const RENK_MOR = "mor" as const;

const IKON_UYARI = "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_BINA = "M3 21h18M5 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16M9 7h2M9 11h2M9 15h2M15 21v-8h2a2 2 0 0 1 2 2v6";
const IKON_IZGARA = "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

function Legend() {
  const t = useT();
  const item = (renk: DensityRenk, label: string) => (
    <span className="flex items-center gap-1.5">
      <span
        className="inline-block h-3.5 w-3.5"
        style={{ borderRadius: "var(--yz-radius-sm)", background: renkTonu(renk) }}
      />
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>{label}</span>
    </span>
  );
  return (
    <Kart className="flex flex-wrap items-center gap-4 !p-3">
      <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
        {t("haritaYogunluk")}
      </span>
      {item("yesil", t("haritaYesil"))}
      {item("sari", t("haritaSari"))}
      {item("kirmizi", t("haritaKirmizi"))}
      {item("mor", t("haritaMor"))}
    </Kart>
  );
}

function DetailPanel({ unit }: { unit: BuildingMapUnit }) {
  const t = useT();
  // Sikayet listesi (durum=acik — sayimla tutarli). Rev-1: yonetim gorunumunde
  // notlar + complainant (sikayet eden) DOLU gelir (denetim; backend zorlar).
  const { data, error, isLoading } = useSWR<UnitComplaintList>(
    `/api/unit-complaints?target_unit_id=${unit.unit_id}&durum=acik`,
    jsonFetcher,
  );
  const ton = renkTonu(unit.color);
  const items: UnitComplaint[] = data?.items ?? [];

  return (
    <Kart className="space-y-3">
      <div className="flex items-center gap-2">
        <span
          className="inline-block h-4 w-4"
          style={{ borderRadius: "var(--yz-radius-sm)", background: ton }}
        />
        <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
          {t("haritaDaireNo", { no: unit.unit_no })}
        </h2>
        {/* SAYI metin renginde: renkli metin 4.5 ister ve iki temada ayri
            olcum demekti; nokta zaten rengi tasiyor. */}
        <span className="ms-auto" style={{ fontWeight: 600, color: "var(--yz-text)" }}>
          {t("haritaAcikSikayetSayisi", { n: unit.complaint_count ?? 0 })}
        </span>
      </div>
      {unit.blok != null && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("haritaBlokKatSira", { blok: unit.blok })}
          {unit.kat != null ? ` · ${t("haritaKat", { kat: unit.kat })}` : ""}
          {unit.sira != null ? ` · ${t("haritaSira", { sira: unit.sira })}` : ""}
        </p>
      )}
      {error && <HataDurumu mesaj={t("haritaYuklenemedi")} />}
      {isLoading && <IskeletMetin satir={3} />}
      {/* (P61) `!error` SART. Eski kosul yalniz `!isLoading`e bakiyordu:
          istek dustugunde "Harita yuklenemedi" ile "Acik sikayet yok" YAN
          YANA cikiyordu — ustelik basliktaki sayac haritadan gelip "3 acik
          sikayet" yazarken. "Yuklenemedi" bir durumdur, "yok" bir
          IDDIADIR. */}
      {!isLoading && !error && items.length === 0 && (
        <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
          {t("haritaAcikSikayetYok")}
        </p>
      )}
      <ul className="space-y-1">
        {items.map((it) => (
          <li
            key={it.id}
            className="px-3 py-2"
            style={{
              borderRadius: "var(--yz-radius-sm)",
              border: "1px solid var(--yz-border)",
              fontSize: "var(--yz-fs-sm)",
              color: "var(--yz-text)",
            }}
          >
            <div className="flex justify-between">
              <span style={{ fontWeight: 600 }}>
                {KATEGORI_ANAHTAR[it.kategori]
                  ? t(KATEGORI_ANAHTAR[it.kategori])
                  : it.kategori}
              </span>
              <span style={{ color: "var(--yz-text-3)" }}>{fmtDate(it.created_at)}</span>
            </div>
            {/* Rev-1: sikayet eden kimligi YALNIZ yonetime (denetim). */}
            {it.complainant_ad && (
              <p
                className="mt-0.5"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {t("haritaSikayetEden", { kisi: it.complainant_ad })}
              </p>
            )}
            {it.notlar && (
              <p className="mt-1" style={{ color: "var(--yz-text-2)" }}>
                {it.notlar}
              </p>
            )}
          </li>
        ))}
      </ul>
      <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
        {t("haritaKimlikNotu")}
      </p>
    </Kart>
  );
}

export default function SchematicPage() {
  const t = useT();
  // (E2E 2026-09) TESIS-17: TUR SECICISI — bos = tum turler. Sayim ve
  // renk sunucuda o ture gore hesaplanir (`?kategori=`).
  const [kategori, setKategori] = useState<string>("");
  const { data, error, isLoading } = useSWR<BuildingMap>(
    kategori ? `/api/building-map?kategori=${encodeURIComponent(kategori)}` : "/api/building-map",
    jsonFetcher,
  );
  const [selected, setSelected] = useState<BuildingMapUnit | null>(null);
  const [gorunum, setGorunum] = useState<string>(GORUNUM_SEMA);

  /**
   * (P160) PLAN HARITASININ GIRDISI — `blok`/`kat`/`sira` GERCEK VERI.
   *
   * Duzlem su sekilde kuruluyor: her blok yatayda kendi seridini alir,
   * blok icinde `sira` sutunu, `kat` ise dikey ekseni verir. Uydurulan
   * hicbir sey yok; kat/sira girilmemis daire zaten `unplaced` kovasinda
   * ve haritaya HIC girmiyor (asagida ayrica yaziyor).
   */
  const { hucreler, planBloklari, yerlesimsiz } = useMemo(() => {
    const h: PlanHucresi[] = [];
    const b: PlanBlogu[] = [];
    let x = 0;
    for (const blok of data?.bloklar ?? []) {
      let genislik = 1;
      for (const kat of blok.katlar) {
        for (const u of kat.units) {
          // `sira` yoksa hucre cizilemez: uydurma bir sutun, daireyi
          // olmadigi yere koymakti.
          if (u.sira == null || u.kat == null) continue;
          genislik = Math.max(genislik, u.sira);
          h.push({
            id: u.unit_id,
            etiket: u.unit_no,
            x: x + (u.sira - 1),
            y: u.kat,
            ton: renkTonu(u.color),
            ipucu: t("haritaKartBaslik", {
              daire: u.unit_no,
              sayi: u.complaint_count ?? 0,
            }),
            secili: selected?.unit_id === u.unit_id,
          });
        }
      }
      b.push({ ad: blok.blok, x, genislik });
      x += genislik + 1; // bloklar arasinda bir birim bosluk
    }
    // Kat/sira girilmemis daireler haritada YOK — sayisi yaziliyor ki
    // "haritada gormedigim daire yok" sanilmasin.
    const eksik =
      (data?.bloklar ?? []).reduce(
        (n, blok) =>
          n +
          blok.katlar.reduce(
            (m, kat) => m + kat.units.filter((u) => u.sira == null || u.kat == null).length,
            0,
          ),
        0,
      ) + (data?.unplaced?.length ?? 0);
    return { hucreler: h, planBloklari: b, yerlesimsiz: eksik };
  }, [data, selected, t]);

  /**
   * (P244 §8c) OZET SAYILARI — BURADA ISTEMCIDE HESAPLANIR ve bu
   * BILINCLI bir istisna.
   *
   * Diger ekranlarda sayaclar ayri uclardan (`?limit=1` ->
   * `meta.total`) okunuyor, cunku oralarda liste SAYFALI: gorunen
   * sayfadan saymak yanlis sayi uretir. Burada veri sayfali DEGIL —
   * `building-map` binanin TAMAMINI tek yanitta veriyor (harita zaten
   * ancak boyle cizilebilir). Elimizdeki agac listenin tamami oldugu
   * icin sayim dogrudur ve uce ucuncu bir istek atmak gereksizdi.
   */
  const sayaclar = useMemo(() => {
    let acikSikayet = 0;
    let yogunDaire = 0;
    for (const blok of data?.bloklar ?? []) {
      for (const kat of blok.katlar) {
        for (const u of kat.units) {
          acikSikayet += u.complaint_count ?? 0;
          // (E2E 2026-09) TESIS-20: dort kademede "yogun" = kirmizi + mor.
          if (u.color === RENK_KIRMIZI || u.color === RENK_MOR) yogunDaire += 1;
        }
      }
    }
    return { acikSikayet, yogunDaire };
  }, [data]);

  return (
    <div>
      <SayfaBasligi baslik={t("kabukSikayetHaritasi")} aciklama={t("haritaSayfaAlt")} />

      <OzetSeridi>
        <OzetKarti
          etiket={t("haritaOzetAcikSikayet")}
          deger={String(sayaclar.acikSikayet)}
          ikon={<Ikon yol={IKON_UYARI} />}
          durum="uyari"
        />
        <OzetKarti
          etiket={t("haritaOzetYogunDaire")}
          deger={String(sayaclar.yogunDaire)}
          ikon={<Ikon yol={IKON_BINA} />}
          durum="kritik"
          altBilgi={t("haritaYogunEsik")}
        />
        {/* HARITADAKI daire = CIZILEBILEN daire (`hucreler`), tum
            kayitli daireler degil: kat/sira girilmemis daire haritada
            YOKTUR ve onu bu sayiya katmak, kartin etiketini yalan
            yapardi. Kac tanesinin eksik oldugu haritanin ALTINDA zaten
            yaziyor — ayni cumleyi kartta da tekrarlamak, ekranda iki
            kez okunan tek bir bilgi olurdu (kilit bunu yakaladi). */}
        <OzetKarti
          etiket={t("haritaOzetDaire")}
          deger={String(hucreler.length)}
          ikon={<Ikon yol={IKON_IZGARA} />}
          durum="notr"
        />
      </OzetSeridi>

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Legend />
        <label className="flex items-center gap-2">
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("haritaTurSuzgeci")}
          </span>
          <span className="inline-block w-auto">
          <Secim
            data-test="harita-tur-suzgeci"
            value={kategori}
            onChange={(e) => {
              setKategori(e.target.value);
              setSelected(null);
            }}
          >
            <option value="">{t("ortakTumu")}</option>
            {KATEGORI_SIRASI.map((k) => (
              <option key={k} value={k}>
                {t(KATEGORI_ANAHTAR[k])}
              </option>
            ))}
          </Secim>
          </span>
        </label>
      </div>

      {error && <HataDurumu mesaj={error.message} />}
      {isLoading && !data && (
        <Kart>
          <IskeletMetin satir={4} />
        </Kart>
      )}

      <div className="grid gap-5 lg:grid-cols-[1fr_360px]">
        <Sekmeler
          aktifId={gorunum}
          onDegis={setGorunum}
          sekmeler={[
            {
              id: GORUNUM_SEMA,
              baslik: t("haritaGorunumSema"),
              // SEMA ERISILEBILIR YUZEYDIR ve VARSAYILANDIR: her hucre
              // gercek bir dugmedir, klavyeyle gezilir ve ekran okuyucu
              // adini okur. Harita onun yerine GECMEZ, yanina gelir.
              // Sema: blok -> kat (ust kat yukarida) -> renkli hucreler.
              icerik: (
                <div className="space-y-4">
          {(data?.bloklar ?? []).map((blok) => (
            <Kart key={blok.blok} className="space-y-3">
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("blokEtiketi", { ad: blok.blok })}
              </h2>
              {/* building-map kat'i ARTAN doner; kat plani icin AZALAN goster */}
              {[...blok.katlar].reverse().map((kat) => (
                <div key={kat.kat} className="flex items-start gap-3">
                  <span
                    className="w-14 shrink-0 pt-5"
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
                  >
                    {t("haritaKat", { kat: kat.kat })}
                  </span>
                  <div className="flex flex-wrap gap-2">
                    {kat.units.map((u) => (
                      <UnitCell
                        key={u.unit_id}
                        unit={u}
                        selected={selected?.unit_id === u.unit_id}
                        onSelect={setSelected}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </Kart>
          ))}

          {/* Yerlesimi girilmemis daireler — ayni renk + tiklama */}
          {(data?.unplaced?.length ?? 0) > 0 && (
            <Kart
              className="space-y-3"
              style={{ borderColor: "var(--yz-warning-edge)" }}
            >
              <h2 style={{ fontSize: "var(--yz-fs-h3)", color: "var(--yz-text)" }}>
                {t("haritaYerlesimYok")}
              </h2>
              <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                {t("haritaYerlesimNotu")}
              </p>
              <div className="flex flex-wrap gap-2">
                {(data?.unplaced ?? []).map((u) => (
                  <UnitCell
                    key={u.unit_id}
                    unit={u}
                    selected={selected?.unit_id === u.unit_id}
                    onSelect={setSelected}
                  />
                ))}
              </div>
            </Kart>
          )}

          {data && data.bloklar.length === 0 && (data.unplaced?.length ?? 0) === 0 && (
            <Kart>
              <BosDurum baslik={t("haritaDaireYok")} aciklama={t("haritaDaireYokAlt")} />
            </Kart>
          )}
        </div>
              ),
            },
            {
              id: GORUNUM_HARITA,
              baslik: t("haritaGorunumHarita"),
              // HARITA: buyuk sitelerde pan/zoom kazandirir. Tuval
              // uzerindeki dikdortgen ekran okuyucuya bir sey soylemez —
              // bu yuzden ALTERNATIF gorunum, tek gorunum degil.
              icerik: (
                <div className="space-y-2">
                  <PlanHaritasiYukleyici
                    hucreler={hucreler}
                    bloklar={planBloklari}
                    onSec={(id) => {
                      const bulunan = (data?.bloklar ?? [])
                        .flatMap((b) => b.katlar.flatMap((k) => k.units))
                        .find((u) => u.unit_id === id);
                      if (bulunan) setSelected(bulunan);
                    }}
                  />
                  {/* HARITANIN NE OLMADIGINI YAZAR. */}
                  <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}>
                    {t("haritaPlanNotu")}
                  </p>
                  {/* SESSIZ EKSIK YOK: haritada olmayan daireler sayilir. */}
                  {yerlesimsiz > 0 && (
                    <p
                      role="status"
                      style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-warning-ink)" }}
                    >
                      {t("haritaPlanEksik", { sayi: yerlesimsiz })}
                    </p>
                  )}
                </div>
              ),
            },
          ]}
        />

        {/* Detay paneli — secili daire */}
        <div>
          {selected ? (
            <DetailPanel unit={selected} />
          ) : (
            <div
              className="p-8 text-center"
              style={{
                borderRadius: "var(--yz-radius-card)",
                border: "1px dashed var(--yz-border)",
                fontSize: "var(--yz-fs-sm)",
                color: "var(--yz-text-2)",
              }}
            >
              {t("haritaDaireSecin")}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
