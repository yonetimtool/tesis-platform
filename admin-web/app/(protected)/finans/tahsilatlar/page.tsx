"use client";

// (P167 §4.2) TAHSILATLAR — IKI AYRI DUGME, iki ayri akis.
//
// Brief: "'+ Yeni' ve '+ Toplu Tahsilat' iki ayri dugme."
//
// NEDEN IKI AKIS BIRLESTIRILMEDI: tekil tahsilat bir MAKBUZ kesme
// islemidir (kisi, yontem, kasa, aciklama — hepsi tek kisi icin);
// toplu tahsilat ise bir GUN SONU girisidir (N satir, tek kasa, tek
// tarih). Tek forma sigdirmak, tek kisi icin makbuz kesen kullaniciya
// bos bir tablo gostermek olurdu.

import { useState } from "react";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  Dugme,
  HataDurumu,
  Modal,
  Secim,
} from "@/components/ui";
import {
  bugun,
  useBorclular,
  useDaireler,
  useKasalar,
  useKisiler,
} from "@/components/finans/ortak";
import { HareketSayfasi } from "@/components/finans/hareket-sayfasi";
import {
  SatirTablosu,
  yeniSatirAnahtari,
  type SatirTabani,
} from "@/components/finans/satir-tablosu";
import { apiSend, genIdempotencyKey } from "@/lib/client";
import { useT } from "@/lib/i18n/kullan";
import { kurusToTL, tlToKurus } from "@/lib/money";

const TIP = "tahsilat";
// TAHSILAT YONTEMI: brief "varsayilan Otomatik" diyor. Uc bugun bir
// `yontem` alani TASIMIYOR; deger `aciklama`ya eklenmez ve UYDURULMAZ —
// alan gorunur ama tek secenegi vardir ve neden oyle oldugu raporda
// yazili. Uc genisletildiginde tek satirla acilir.
const YONTEM_OTOMATIK = "otomatik";

interface Satir extends SatirTabani {
  tarih: string;
  kisiId: string;
  aciklama: string;
}

export default function TahsilatlarPage() {
  const t = useT();
  const [tekil, setTekil] = useState(false);
  const [toplu, setToplu] = useState(false);
  const [yenile, setYenile] = useState(0);

  return (
    <HareketSayfasi
      baslikAnahtari="kabukTahsilatlar"
      tip={TIP}
      raporKodu="makbuz_dokumu"
      yenile={yenile}
      araclar={
        <>
          <Dugme tur="birincil" boy="kucuk" onClick={() => setTekil(true)}>
            {t("finansYeni")}
          </Dugme>
          <Dugme tur="ikincil" boy="kucuk" onClick={() => setToplu(true)}>
            {t("finansTopluTahsilat")}
          </Dugme>
        </>
      }
      cocuk={
        <>
          <TekilModal
            acik={tekil}
            onKapat={() => setTekil(false)}
            onKaydedildi={() => setYenile((n) => n + 1)}
          />
          <TopluModal
            acik={toplu}
            onKapat={() => setToplu(false)}
            onKaydedildi={() => setYenile((n) => n + 1)}
          />
        </>
      }
    />
  );
}

function TekilModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();
  const { kisiler, hata: kisiHatasi } = useKisiler();
  const { borclular, yukleniyor: borcYukleniyor } = useBorclular();
  const daireler = useDaireler();

  // (P206 §2) PESIN ODEME ACIK BIR SECIM.
  //
  // Varsayilan liste BORCLULARDIR: tahsilat penceresinde sorulan soru
  // "kime borcu var"dir ve yuzlerce ad arasindan aramak, kapida bekleyen
  // kisiyle konusurken yapilacak is degildir. Ama P192'de "borc oncesi
  // pesin odeme ALACAKTA BEKLER" senaryosu var — borcu olmayan birinden
  // tahsilat MUMKUN olmali. Iki listeyi birlestirmek yerine ACIK bir
  // anahtar konuldu: kullanici ne yaptigini bilerek gecer.
  const [pesin, setPesin] = useState(false);
  const [ara, setAra] = useState("");

  const [kisiId, setKisiId] = useState("");
  const [daireId, setDaireId] = useState("");
  const [kasaId, setKasaId] = useState("");
  const [tutar, setTutar] = useState("");
  const [tarih, setTarih] = useState(bugun());
  const [aciklama, setAciklama] = useState("");
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  // (P192 §6.2) IDEMPOTENCY ANAHTARI — uc basligi ANLIYOR ama bu ekran
  // GONDERMIYORDU: zaman asimi sonrasi tekrar (kullanici "kaydedilmedi"
  // sanip yeniden basar) kasada IKI hareket olusturabilirdi. Anahtar
  // FORM ORNEGI BASINA uretilir; basarili kayittan sonra yenilenir.
  const [anahtarTekil, setAnahtarTekil] = useState(() => genIdempotencyKey());

  const secKasa = kasaId || kasalar[0]?.id || "";

  // ARAMA HER IKI LISTEDE de calisir. Borclu satirinda DAIRE ve KALAN
  // TUTAR da yazar: yonetici "hangi Ahmet" ve "ne kadar" sorularini
  // secmeden once yanitlayabilmeli.
  const q = ara.trim().toLocaleLowerCase("tr");
  const sucuzBorclular = borclular
    .filter(
      (b) =>
        !q ||
        b.ad.toLocaleLowerCase("tr").includes(q) ||
        b.unitNo.toLocaleLowerCase("tr").includes(q),
    )
    .map((b) => ({
      deger: b.userId,
      etiket: `${b.ad} · ${b.unitNo} · ${kurusToTL(b.kalanKurus)}`,
    }));
  const sucuzKisiler = kisiler
    .filter((k) => !q || k.ad.toLocaleLowerCase("tr").includes(q))
    .map((k) => ({ deger: k.id, etiket: k.ad }));

  async function kaydet() {
    if (!kisiId) { setHata(t("finansKisiGerekli")); return; }
    if (!secKasa) { setHata(t("finansKasaGerekli")); return; }
    const kurus = tlToKurus(tutar);
    if (!kurus || kurus <= 0) { setHata(t("finansTutarGerekli")); return; }
    setHata(null);
    setKaydediyor(true);
    try {
      await apiSend("/api/panel/finans-tahsilat", "POST", {
        user_id: kisiId,
        unit_id: daireId || null,
        kasa_id: secKasa,
        tutar_kurus: kurus,
        tarih: tarih || null,
        aciklama: aciklama.trim() || null,
      }, { "Idempotency-Key": anahtarTekil });
      toast.success(t("finansKaydedildi"));
      setKisiId(""); setDaireId(""); setTutar(""); setAciklama("");
      setAnahtarTekil(genIdempotencyKey());
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
      baslik={t("kabukTahsilatlar")}
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
        {/* (P206 §2) KISI SECICI — BORCLULAR ONCE. */}
        <HataDurumu mesaj={kisiHatasi ? t("finansKisiListesiAlinamadi") : null} />
        <AlanSarmal etiket={t("finansKisiAra")}>
          {(b) => (
            <Alan
              {...b}
              value={ara}
              data-test="tahsilat-kisi-ara"
              onChange={(e) => setAra(e.target.value)}
            />
          )}
        </AlanSarmal>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={pesin}
            data-test="tahsilat-pesin"
            onChange={(e) => {
              setPesin(e.target.checked);
              setKisiId("");
            }}
          />
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("finansPesinOdeme")}
          </span>
        </label>
        <AlanSarmal etiket={t("finansSutunKisi")} zorunlu>
          {(b) => (
            <Secim
              {...b}
              value={kisiId}
              data-test="tahsilat-kisi"
              onChange={(e) => {
                setKisiId(e.target.value);
                // BORCLU SECILINCE DAIRE DE DOLAR: borc daireye
                // baglidir ve daireyi elle secmek, yanlis daireye
                // makbuz kesme riskini bedavaya ekliyordu.
                const b2 = borclular.find((x) => x.userId === e.target.value);
                if (!pesin && b2) setDaireId(b2.unitId);
              }}
            >
              <option value="">{t("finansKisiSec")}</option>
              {(pesin ? sucuzKisiler : sucuzBorclular).map((k) => (
                <option key={k.deger} value={k.deger}>
                  {k.etiket}
                </option>
              ))}
            </Secim>
          )}
        </AlanSarmal>
        {/* BOS LISTE SESSIZ KALMAZ: "kimseyi secemiyorum" diyen
            kullaniciya ekran hicbir sey soylemiyordu. */}
        {!pesin && !borcYukleniyor && borclular.length === 0 && (
          <p
            data-test="tahsilat-borclu-yok"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("finansBorcluYok")}
          </p>
        )}
        {!pesin && borclular.length > 0 && sucuzBorclular.length === 0 && (
          <p
            data-test="tahsilat-arama-bos"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            {t("finansAramaSonucYok")}
          </p>
        )}
        <AlanSarmal etiket={t("finansSutunDaire")}>
          {(b) => (
            <Secim {...b} value={daireId} onChange={(e) => setDaireId(e.target.value)}>
              <option value="">{t("finansDaireSec")}</option>
              {daireler.map((d) => <option key={d.id} value={d.id}>{d.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        {/* TAHSILAT YONTEMI: brief'in "varsayilan Otomatik" alani. Uc
            bugun bir `yontem` alani tasimiyor; secenek UYDURULMADI ve
            deger sunucuya GONDERILMIYOR — alan tek secenekle gorunur ve
            eksigin ne oldugu raporda yazili. */}
        <AlanSarmal etiket={t("finansAlanYontem")}>
          {(b) => (
            <Secim {...b} value={YONTEM_OTOMATIK} disabled>
              <option value={YONTEM_OTOMATIK}>{t("finansYontemOtomatik")}</option>
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansSutunKasa")} zorunlu>
          {(b) => (
            <Secim {...b} value={secKasa} onChange={(e) => setKasaId(e.target.value)}>
              <option value="">{t("finansKasaSec")}</option>
              {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTutar")} zorunlu>
          {(b) => (
            <Alan {...b} value={tutar} inputMode="decimal"
              onChange={(e) => setTutar(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanTarih")} zorunlu>
          {(b) => (
            <Alan {...b} type="date" value={tarih}
              onChange={(e) => setTarih(e.target.value)} />
          )}
        </AlanSarmal>
        <AlanSarmal etiket={t("finansAlanAciklama")}>
          {(b) => (
            <Alan {...b} value={aciklama}
              onChange={(e) => setAciklama(e.target.value)} />
          )}
        </AlanSarmal>
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}

function TopluModal({
  acik, onKapat, onKaydedildi,
}: { acik: boolean; onKapat: () => void; onKaydedildi: () => void }) {
  const t = useT();
  const toast = useToast();
  const kasalar = useKasalar();
  // (P206 §2) Kanca artik {kisiler, hata} donuyor.
  const { kisiler } = useKisiler();

  const bosSatir = (): Satir => ({
    _k: yeniSatirAnahtari(),
    tarih: bugun(),
    kisiId: "",
    tutar: "",
    aciklama: "",
  });

  const [satirlar, setSatirlar] = useState<Satir[]>([bosSatir()]);
  const [kasaId, setKasaId] = useState("");
  const [tarih, setTarih] = useState(bugun());
  const [hata, setHata] = useState<string | null>(null);
  const [kaydediyor, setKaydediyor] = useState(false);
  // (P192 §6.2) IDEMPOTENCY ANAHTARI — uc basligi ANLIYOR ama bu ekran
  // GONDERMIYORDU: zaman asimi sonrasi tekrar (kullanici "kaydedilmedi"
  // sanip yeniden basar) kasada IKI hareket olusturabilirdi. Anahtar
  // FORM ORNEGI BASINA uretilir; basarili kayittan sonra yenilenir.
  const [anahtarToplu, setAnahtarToplu] = useState(() => genIdempotencyKey());

  const secKasa = kasaId || kasalar[0]?.id || "";


  async function kaydet() {
    const dolu = satirlar.filter((s) => (tlToKurus(s.tutar) ?? 0) > 0);
    if (dolu.length === 0) { setHata(t("finansSatirGerekli")); return; }
    if (!secKasa) { setHata(t("finansKasaGerekli")); return; }
    setHata(null);
    setKaydediyor(true);
    try {
      // KASA VE TARIH FIS BASINA, satir basina DEGIL: uc oyle
      // (`TopluTahsilatIstek`) ve gun sonu girisinde ikisi de zaten
      // ortaktir. Satir basina kasa istemek, ayni degeri N kez
      // sectirmek olurdu.
      await apiSend("/api/panel/finans-tahsilat-toplu", "POST", {
        kasa_id: secKasa,
        tarih: tarih || null,
        satirlar: dolu.map((s) => ({
          user_id: s.kisiId || null,
          tutar_kurus: tlToKurus(s.tutar),
          aciklama: s.aciklama.trim() || null,
        })),
      }, { "Idempotency-Key": anahtarToplu });
      toast.success(t("finansKaydedildi"));
      setSatirlar([bosSatir()]);
      setAnahtarToplu(genIdempotencyKey());
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
      baslik={t("finansTopluTahsilat")}
      onKapat={onKapat}
      genislikSinifi="max-w-4xl"
      eylemler={
        <span className="flex gap-2">
          <Dugme tur="ikincil" onClick={onKapat}>{t("ortakIptal")}</Dugme>
          <Dugme tur="birincil" disabled={kaydediyor} onClick={() => void kaydet()}>
            {kaydediyor ? t("ortakKaydediliyor") : t("ortakKaydet")}
          </Dugme>
        </span>
      }
    >
      <div className="space-y-3">
        <div className="grid gap-3 sm:grid-cols-2">
          <AlanSarmal etiket={t("finansSutunKasa")} zorunlu>
            {(b) => (
              <Secim {...b} value={secKasa} onChange={(e) => setKasaId(e.target.value)}>
                <option value="">{t("finansKasaSec")}</option>
                {kasalar.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
              </Secim>
            )}
          </AlanSarmal>
          <AlanSarmal etiket={t("finansAlanTarih")} zorunlu>
            {(b) => (
              <Alan {...b} type="date" value={tarih}
                onChange={(e) => setTarih(e.target.value)} />
            )}
          </AlanSarmal>
        </div>
        <SatirTablosu<Satir>
          satirlar={satirlar}
          onDegisti={setSatirlar}
          bosSatir={bosSatir}
          basliklar={[t("finansSutunKisi"), t("finansSutunAciklama")]}
          hucreler={(s, guncelle) => [
            <Secim
              key="k"
              value={s.kisiId}
              aria-label={t("finansSutunKisi")}
              onChange={(e) => guncelle({ kisiId: e.target.value })}
              className="!h-10 min-w-40"
            >
              <option value="">{t("finansKisiSec")}</option>
              {kisiler.map((k) => <option key={k.id} value={k.id}>{k.ad}</option>)}
            </Secim>,
            <Alan
              key="a"
              value={s.aciklama}
              aria-label={t("finansSutunAciklama")}
              onChange={(e) => guncelle({ aciklama: e.target.value })}
              className="!h-10 min-w-40"
            />,
          ]}
        />
        <HataDurumu mesaj={hata} />
      </div>
    </Modal>
  );
}
