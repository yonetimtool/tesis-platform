"use client";

import { useState } from "react";
import useSWR from "swr";

import { Foto } from "@/components/Foto";
import {
  AlanSarmal,
  CekmeceSatiri,
  CokSatir,
  DetayCekmecesi,
  Dugme,
  FiltreCubugu,
  type Kolon,
  Modal,
  Rozet,
  type RozetDurumu,
  OzetKarti,
  OzetSeridi,
  Pager,
  SayfaBasligi,
  VeriTablosu,
} from "@/components/ui";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { jsonFetcher, formatDateTime } from "@/lib/fetcher";
import type { Complaint, ComplaintDurum, ComplaintList, ComplaintStatusHistory } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_TEHLIKE = "tehlike" as const;
const TUR_SESSIZ = "sessiz" as const;
const LIMIT = 20;
const DURUM_ACIK = "acik" as const;
const DURUM_IS_EMRI = "is_emri" as const;
const DURUM_COZULDU = "cozuldu" as const;

const IKON_UYARI = "M12 9v4m0 4h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z";
const IKON_ANAHTAR = "M14.7 6.3a4 4 0 1 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4M17 7h.01";
const IKON_ONAY = "M20 6 9 17l-5-5";

function Ikon({ yol }: { yol: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor"
      strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={yol} />
    </svg>
  );
}

/**
 * Durum -> etiket + ROZET DURUMU.
 *
 * METIN DEGIL KIMLIK (modul duzeyi — README tur 18 dersi): ham `durum`
 * degerini ekrana yazmak kullaniciya veritabani sabiti gostermekti.
 *
 * (P244 §8b) HAM TAILWIND PALETI -> `Rozet` DURUMU.
 *
 * Renkler DOGRUDAN palet siniflariydi (sabit sari zemin + sari metin):
 * eski tasarim dilinin renk katmani. Asama 4 modul sinirini kapatmisti
 * ama renk katmanini degil — bu dosya `@/components/ui`den ithal ettigi
 * icin `p244-tek-tasarim-dili` kilidi onu HAKLI OLARAK gecmisti; kilit
 * ithalati olcer, sinif adlarini degil.
 *
 * Anlam korundu: acik=uyari, is_emri=bilgi, cozuldu=olumlu,
 * reddedildi=kritik. Mobildeki wire kodlariyla ayni esleme.
 */
const DURUM_META: Record<ComplaintDurum, { anahtar: SozlukAnahtari; rozet: RozetDurumu }> = {
  acik: { anahtar: "ortakAcik", rozet: "uyari" },
  is_emri: { anahtar: "talepIsEmri", rozet: "bilgi" },
  cozuldu: { anahtar: "destekCozuldu", rozet: "olumlu" },
  reddedildi: { anahtar: "talepReddedildi", rozet: "kritik" },
};

const FILTERS: Array<{ value: ComplaintDurum | ""; anahtar: SozlukAnahtari }> = [
  { value: "", anahtar: "ortakTumu" },
  { value: "acik", anahtar: "ortakAcik" },
  { value: "is_emri", anahtar: "talepIsEmri" },
  { value: "cozuldu", anahtar: "destekCozuldu" },
  { value: "reddedildi", anahtar: "talepReddedilen" },
];

// Timeline actor rolu -> TR etiket (mobil UserRole.label ile ayni).
const ROLE_ANAHTAR: Record<string, SozlukAnahtari> = {
  admin: "rolPlatformAdmin",
  yonetici: "rolYonetici",
  security: "rolGuvenlik",
  tesis_gorevlisi: "rolTesisGorevlisi",
  resident: "rolSiteSakini",
};

// Bagli is emri (Task) durumu -> TR etiket (mobil _LinkedWorkOrderCard ile ayni):
// 'acik' -> t("talepAtandi"), 'tamamlandi' -> t("talepTamamlandi").
function isEmriAnahtari(durum?: string | null): SozlukAnahtari {
  switch (durum) {
    case "acik":
      return "talepAtandi";
    case "tamamlandi":
      return "talepTamamlandi";
    default:
      return "talepDurumBilinmiyor";
  }
}

function DurumBadge({ durum }: { durum: ComplaintDurum }) {
  const t = useT();
  const meta = DURUM_META[durum] ?? DURUM_META.acik;
  return <Rozet durum={meta.rozet}>{t(meta.anahtar)}</Rozet>;
}

// Talep/Ariza -> Is Emri kanali: sakinlerin (ve saha rollerinin) actigi talepler.
// Panel admin'i tenant'taki TUMUNU gorur. Is emrine DONUSTURME (atama secimi)
// mobilde kalir; panel bagli is emrini SALT OKUR gosterir + acik talebi coz/reddet.
export default function ComplaintsPage() {
  const t = useT();
  const [offset, setOffset] = useState(0);
  const [durum, setDurum] = useState<ComplaintDurum | "">("");
  const [secili, setSecili] = useState<Complaint | null>(null);
  const [eylem, setEylem] = useState<{ c: Complaint; tur: "coz" | "reddet" } | null>(null);
  const query = `/api/complaints?limit=${LIMIT}&offset=${offset}${durum ? `&durum=${durum}` : ""}`;
  const { data, error, isLoading, mutate } = useSWR<ComplaintList>(query, jsonFetcher);

  // SAYAÇLAR AYRI UÇLARDAN, GORUNEN SAYFADAN DEGIL.
  //
  // Liste 20'lik sayfalar halinde geliyor. Gorunen sayfayi saymak "3
  // acik talep var" gibi YANLIS bir sayi uretirdi; ustelik suzgec
  // acikken sayac da suzulmus olurdu. `?durum=X&limit=1` -> `meta.total`
  // deseni araç geçişleri ve kargo ekranlarinda da kullanilan desen.
  const { data: acikSayi } = useSWR<ComplaintList>(
    `/api/complaints?limit=1&offset=0&durum=${DURUM_ACIK}`,
    jsonFetcher,
  );
  const { data: isEmriSayi } = useSWR<ComplaintList>(
    `/api/complaints?limit=1&offset=0&durum=${DURUM_IS_EMRI}`,
    jsonFetcher,
  );
  const { data: cozulduSayi } = useSWR<ComplaintList>(
    `/api/complaints?limit=1&offset=0&durum=${DURUM_COZULDU}`,
    jsonFetcher,
  );

  const kayitlar = data?.items ?? [];

  const kolonlar: Kolon<Complaint>[] = [
    {
      id: "baslik",
      baslik: t("talepKolonKonu"),
      hucre: (c) => <span className="font-medium">{c.baslik}</span>,
      deger: (c) => c.baslik,
      kartRolu: "baslik",
    },
    {
      id: "kategori",
      baslik: t("talepKolonKategori"),
      hucre: (c) => c.kategori_ad ?? t("ortakDiger"),
      deger: (c) => c.kategori_ad ?? "",
      kartRolu: "ozet",
    },
    {
      id: "acan",
      baslik: t("talepKolonAcan"),
      hucre: (c) => c.acan_ad ?? t("rolSiteSakini"),
      deger: (c) => c.acan_ad ?? "",
      darEkrandaGizle: true,
    },
    {
      id: "tarih",
      baslik: t("talepKolonTarih"),
      hucre: (c) => formatDateTime(c.created_at),
      deger: (c) => c.created_at,
      kartRolu: "ozet",
    },
    {
      id: "durum",
      baslik: t("talepKolonDurum"),
      hucre: (c) => <DurumBadge durum={c.durum} />,
      deger: (c) => c.durum,
      kartRolu: "rozet",
    },
    {
      id: "eylem",
      baslik: t("listeIslemler"),
      // EYLEMLER SATIRDA KALDI, CEKMECEYE TASINMADI.
      //
      // Bu ekranin isi TRIYAJ: yonetici listeyi tarar ve karar verir.
      // "Coz"u cekmecenin icine koymak her karara bir acma-kapama adimi
      // eklerdi. Cekmeceye tasinan sey AGIR OLAN: tam mesaj, fotograflar,
      // durum gecmisi ve bagli is emri — bunlar listede her kaydi bir
      // duvara cevirmisti.
      hucre: (c) => (
        <div className="flex flex-wrap gap-2">
          <Dugme boy="kucuk" tur={TUR_SESSIZ} onClick={() => setSecili(c)}>
            {t("ortakDetay")}
          </Dugme>
          {c.durum === DURUM_ACIK ? (
            <>
              <Dugme boy="kucuk" tur={TUR_BIRINCIL} onClick={() => setEylem({ c, tur: "coz" })}>
                {t("talepCoz")}
              </Dugme>
              <Dugme boy="kucuk" tur={TUR_TEHLIKE} onClick={() => setEylem({ c, tur: "reddet" })}>
                {t("talepReddet")}
              </Dugme>
            </>
          ) : null}
        </div>
      ),
      gizlenebilir: false,
      kartRolu: "eylem",
    },
  ];

  return (
    <div>
      <SayfaBasligi
        baslik={t("talepBaslik")}
        aciklama={t("talepPanelNotu", { coz: t("talepCoz"), reddet: t("talepReddet") })}
      />

      <OzetSeridi>
        <OzetKarti
          etiket={t("talepOzetAcik")}
          deger={String(acikSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_UYARI} />}
          durum="uyari"
          altBilgi={t("talepOzetAcikAlt")}
        />
        <OzetKarti
          etiket={t("talepOzetIsEmri")}
          deger={String(isEmriSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ANAHTAR} />}
          durum="bilgi"
        />
        <OzetKarti
          etiket={t("talepOzetCozuldu")}
          deger={String(cozulduSayi?.meta?.total ?? 0)}
          ikon={<Ikon yol={IKON_ONAY} />}
          durum="olumlu"
        />
      </OzetSeridi>

      <FiltreCubugu aktifSayi={durum ? 1 : 0} onTemizle={() => { setDurum(""); setOffset(0); }}>
        {/* (P160) `aria-pressed` KORUNDU: secili suzgec eskiden yalniz
            RENKLE anlatiliyordu ve ekran okuyucu hangisinin acik
            oldugunu SOYLEMIYORDU. Dugmeler bir acilir listeye
            cevrilmedi — dort secenek icin segment seridi tek dokunusla
            gecis verir ve secili olan GORUNUR kalir. */}
        <div className="flex flex-wrap gap-1">
          {FILTERS.map((f) => (
            <Dugme
              key={f.value}
              boy="kucuk"
              tur={durum === f.value ? TUR_BIRINCIL : TUR_IKINCIL}
              aria-pressed={durum === f.value}
              onClick={() => {
                setDurum(f.value);
                setOffset(0);
              }}
            >
              {t(f.anahtar)}
            </Dugme>
          ))}
        </div>
      </FiltreCubugu>

      {/* (P61) HATA TABLOYA VERILIR: istek dustugunde "talep yok" yazmak,
          talebin OLMADIGINI soylemek olurdu. */}
      <VeriTablosu
        kolonlar={kolonlar}
        satirlar={kayitlar}
        satirId={(c) => c.id}
        yukleniyor={isLoading && !data}
        hata={error ? error.message : null}
        onTekrar={() => void mutate()}
        bosBaslik={durum ? t("talepDurumdaYok") : t("talepYok")}
        bosAciklama={durum ? t("talepFiltreDegistir") : t("talepYokAlt")}
      />

      {data && (
        <Pager
          offset={offset}
          limit={LIMIT}
          total={data.meta.total}
          onPrev={() => setOffset(Math.max(0, offset - LIMIT))}
          onNext={() => setOffset(offset + LIMIT)}
        />
      )}

      <TalepCekmecesi talep={secili} onKapat={() => setSecili(null)} />

      {eylem && (
        <ActionForm
          complaint={eylem.c}
          action={eylem.tur}
          onClose={() => setEylem(null)}
          onDone={() => {
            setEylem(null);
            void mutate();
          }}
        />
      )}
    </div>
  );
}

/**
 * DETAY CEKMECESI — listede duvar yapan her sey burada.
 *
 * Eskiden her talep, tam mesaji + tum fotograflari + tum durum gecmisi
 * ile listede ACIK duruyordu. Yirmi talep = yirmi duvar; yonetici
 * "hangisi acik" sorusunu kaydirarak yanitliyordu.
 */
function TalepCekmecesi({ talep: c, onKapat }: { talep: Complaint | null; onKapat: () => void }) {
  const t = useT();
  if (!c) return null;
  return (
    <DetayCekmecesi
      acik
      onKapat={onKapat}
      baslik={c.baslik}
      altBaslik={`${c.acan_ad ?? t("rolSiteSakini")} · ${formatDateTime(c.created_at)}`}
      genislik="genis"
    >
      <dl className="mb-4">
        <CekmeceSatiri etiket={t("talepKolonDurum")}>
          <DurumBadge durum={c.durum} />
        </CekmeceSatiri>
        <CekmeceSatiri etiket={t("talepKolonKategori")}>
          {c.kategori_ad ?? t("ortakDiger")}
        </CekmeceSatiri>
        {c.is_emri_id ? (
          <CekmeceSatiri etiket={t("talepBagliIsEmri")}>
            {t(isEmriAnahtari(c.is_emri_durum))}
          </CekmeceSatiri>
        ) : null}
      </dl>

      <p
        className="whitespace-pre-wrap"
        style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
      >
        {c.mesaj}
      </p>

      {c.fotograflar.length > 0 && (
        <div className="mt-4 flex flex-wrap gap-2">
          {c.fotograflar
            .filter((f) => f.foto_url)
            .map((f) => (
              // Presigned GET URL kisa omurlu — liste her yenilendiginde
              // taze gelir. Tiklayinca tam boy yeni sekmede acilir.
              <a
                key={f.id}
                href={f.foto_url ?? undefined}
                target="_blank"
                rel="noreferrer"
                className="block w-fit rounded-lg border"
                style={{ borderColor: "var(--yz-border)" }}
              >
                <Foto
                  src={f.foto_url ?? undefined}
                  alt={t("gorselAlt", { baslik: c.baslik })}
                  className="h-24 w-24 rounded-lg object-cover"
                />
              </a>
            ))}
        </div>
      )}

      {c.gecmis.length > 0 && <Timeline gecmis={c.gecmis} />}
    </DetayCekmecesi>
  );
}

/**
 * DURUM GECMISI.
 *
 * (P244 §8b) Nokta rengi eskiden rozetin TAILWIND SINIFINDAN geliyordu
 * (ayni sinif hem zemin hem nokta). Rozetin kendisi artik token
 * tabanli oldugu icin o sinif kalmadi; nokta `Rozet`in kendi `nokta`
 * kipine devredildi — renk TEK YERDE tanimli kalir.
 */
function Timeline({ gecmis }: { gecmis: ComplaintStatusHistory[] }) {
  const t = useT();
  return (
    <div
      className="mt-4 border-t pt-4"
      style={{ borderColor: "var(--yz-border)", borderTopWidth: "var(--yz-border-w)" }}
    >
      <p className="mb-2 font-medium" style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
        {t("talepDurumGecmisi")}
      </p>
      <ol className="space-y-3">
        {gecmis.map((g, i) => {
          const meta = DURUM_META[g.durum as ComplaintDurum];
          return (
            <li key={i} className="space-y-0.5">
              <div className="flex flex-wrap items-center gap-x-2">
                {meta ? (
                  <Rozet durum={meta.rozet} nokta>
                    {t(meta.anahtar)}
                  </Rozet>
                ) : (
                  // BILINMEYEN DURUMDA HAM DEGER YAZILMAZ.
                  //
                  // Eski kod `{meta ? t(...) : g.durum}` idi ve tek
                  // satirda oldugu icin `ham-enum` taramasindan
                  // gecmisti; ayri satira duserken tarama onu YAKALADI
                  // ve HAKLI: "is_emri" gibi bir veritabani sabitini
                  // ekrana yazmak kullaniciya ic kimlik gostermektir.
                  // Depoda bunun icin zaten bir anahtar var.
                  <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                    {t("talepDurumBilinmiyor")}
                  </span>
                )}
                <span style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {ROLE_ANAHTAR[g.actor_role] ? t(ROLE_ANAHTAR[g.actor_role]) : g.actor_role} ·{" "}
                  {formatDateTime(g.created_at)}
                </span>
              </div>
              {g.sebep && g.sebep.trim() && (
                <p
                  className="whitespace-pre-wrap"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                >
                  {g.sebep}
                </p>
              )}
            </li>
          );
        })}
      </ol>
    </div>
  );
}

function ActionForm({
  complaint: c,
  action,
  onClose,
  onDone,
}: {
  complaint: Complaint;
  action: "coz" | "reddet";
  onClose: () => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [text, setText] = useState("");
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const isReddet = action === "reddet";
  // Reddet: sebep ZORUNLU (backend 422); Coz: cozum notu opsiyonel.
  const submitDisabled = saving || (isReddet && text.trim().length === 0);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setErr(null);
    try {
      if (isReddet) {
        await apiSend(`/api/complaints/${c.id}/decline`, "POST", {
          sebep: text.trim(),
        });
        toast.success(t("talepReddedildi"));
      } else {
        const notu = text.trim();
        await apiSend(`/api/complaints/${c.id}/resolve`, "POST", {
          cozum_notu: notu || null,
        });
        toast.success(t("talepCozuldu"));
      }
      onDone();
    } catch (e2) {
      setErr(e2 instanceof Error ? e2.message : t("ortakIslemBasarisiz"));
    } finally {
      setSaving(false);
    }
  }

  return (
    // (P161) COZ/REDDET ARTIK MODALDA. Bu bir KAYIT DEGISTIRME islemidir
    // (talep kapanir, karar metni kalici olur) — brief'in "istisnasiz"
    // dedigi sinifa girer. Eskiden detayin altinda acilan bolum, uzun
    // listede ekranin disinda kalabiliyordu.
    <Modal
      acik
      onKapat={onClose}
      baslik={isReddet ? t("talepReddet") : t("talepCoz")}
      eylemler={
        <>
          <Dugme tur="sessiz" onClick={onClose} disabled={saving}>
            {t("ortakIptal")}
          </Dugme>
          <Dugme
            type="submit"
            form="talep-karar-form"
            tur={isReddet ? TUR_TEHLIKE : TUR_BIRINCIL}
            disabled={submitDisabled}
            yukleniyor={saving}
          >
            {saving ? t("destekGonderiliyor") : isReddet ? t("talepReddet") : t("talepCoz")}
          </Dugme>
        </>
      }
    >
      <form id="talep-karar-form" onSubmit={submit} className="space-y-4">
        <AlanSarmal
          etiket={isReddet ? t("talepRedSebebi") : t("talepCozumNotu")}
          ipucu={isReddet ? t("talepNotZorunlu") : t("talepNotIstege")}
          zorunlu={isReddet}
        >
          {(b) => (
            <CokSatir
              {...b}
              rows={4}
              value={text}
              onChange={(e) => setText(e.target.value)}
              maxLength={5000}
              autoFocus
            />
          )}
        </AlanSarmal>
        {err && (
          <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
            {err}
          </p>
        )}
      </form>
    </Modal>
  );
}
