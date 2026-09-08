"use client";

import { useState } from "react";
import useSWR, { mutate as globalMutate } from "swr";

import {
  BosDurum,
  Dugme,
  HataDurumu,
  IskeletMetin,
  Kart,
  Rozet,
} from "@/components/ui";
import { BILDIRIM_SAYAC_UC } from "@/components/ui/bildirim-merkezi";
import { PushTeshis } from "@/components/PushTeshis";
import { useToast } from "@/components/Toast";
import { apiSend } from "@/lib/client";
import { useGecikmeli } from "@/lib/gecikmeli";
import { useRol } from "@/lib/rol-kullan";
import { BILDIRIM_TIP, enumAdi } from "@/lib/enum-adlari";
import { formatDateTime, jsonFetcher } from "@/lib/fetcher";
import type { AppNotification, NotificationList } from "@/lib/types";
import { useT } from "@/lib/i18n/kullan";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

// (P220 §3) IKI SEKME — "Tumu" KALDIRILDI ve varsayilan OKUNMAMIS.
//
// Onceden uc dugme vardi ve varsayilan "Tumu"ydu. Bildirim listesinin
// yanitlamasi gereken soru "NEYI KACIRDIM"; okunmuslarla karisik bir
// liste o soruyu yanitlamiyor, kullaniciyi her acilista suzmeye
// zorluyordu. "Tumu" gorunumu, arama geldigi icin de gereksiz: bir
// bildirimi metniyle ariyorsan hangi sekmede oldugunu bilmen gerekmez —
// iki sekmede de arama var.
type OkunduFiltre = "true" | "false";
const LIMIT = 20;

// (P53) Harita `lib/enum-adlari.ts`e tasindi: AYNI tip panoda da rozet
// olarak ciziliyor ve iki kopya, birinin guncellenip digerinin unutulmasi
// demekti — P51'de tam olarak bu olmustu.

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const TUR_BIRINCIL = "birincil" as const;
const TUR_IKINCIL = "ikincil" as const;
const TUR_TEHLIKE = "tehlike" as const;
const ROL_ADMIN = "admin" as const;
const ROL_YONETICI = "yonetici" as const;

export default function NotificationsPage() {
  const t = useT();
  const toast = useToast();
  const [okundu, setOkundu] = useState<OkunduFiltre>("false");
  const [offset, setOffset] = useState(0);
  // (P181 Bölüm 6.5) TOPLU İŞLEM seçimi — sayfa içindeki id'ler.
  const [secili, setSecili] = useState<Set<string>>(new Set());
  // (P220 §3) ARAMA — her iki sekmede de calisir.
  const [arama, setArama] = useState("");
  // GECIKMELI: her tusa basista sunucuya gitmek, uzun listede gereksiz
  // yuk ve titreyen bir liste demekti.
  const aramaGecikmeli = useGecikmeli(arama, 300);
  const aramaGecerli = aramaGecikmeli.trim().length >= 2;
  const [topluCalisiyor, setTopluCalisiyor] = useState(false);
  // (P191 §2) PUSH TESHISI YALNIZ YONETIME. Sakin/guvenlik icin cihaz
  // sayilari ve baskalarinin gonderim sonuclari ne isine yarar ne de
  // gormeli; uc zaten 403 doner, kabuk da onu ISTEMEZ.
  const rol = useRol(null);

  // (P220 §3) ARAMA SUNUCUDA. Istemcide filtrelemek yalniz ACIK SAYFAYI
  // suzerdi: "kargo" arayan kullanici 3. sayfadaki kaydi bulamaz ve
  // "yok" sanirdi. Uc, kullanicinin GORDUGU metinde ariyor (baslik +
  // govde + tip) — metin kayitta durmuyor, okuma aninda uretiliyor.
  const key = `/api/notifications?limit=${LIMIT}&offset=${offset}` +
    `&okundu=${okundu}` +
    (aramaGecerli ? `&q=${encodeURIComponent(aramaGecikmeli.trim())}` : "");
  const { data, error, isLoading, mutate } = useSWR<NotificationList>(key, jsonFetcher);

  // HAM `fetch` DEGIL `apiSend`: ham fetch basarisiz yanitta da cozulur,
  // yani 401/500 sonrasi "okundu olarak isaretlendi" BASARI bildirimi
  // cikiyordu — kullanici isaretledigini saniyor, bildirim okunmamis
  // kaliyordu. apiSend hata govdesini APIError mesajina cevirir.
  async function markRead(id: string) {
    try {
      await apiSend(`/api/notifications/${id}`, "PATCH", { okundu: true });
      // (P190 §4) ROZET DE TAZELENIR: ust bardaki sayac ayri bir SWR
      // anahtari kullanir; yalniz `mutate()` cagirmak rozeti 60 sn'lik
      // poll'a kadar bayat birakiyordu.
      void globalMutate(BILDIRIM_SAYAC_UC);
      mutate();
      toast.success(t("bildirimOkunduIsaretlendi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    }
  }

  function setFilter(v: OkunduFiltre) {
    setOkundu(v);
    setOffset(0);
    // SEKME DEGISINCE SECIM TEMIZLENIR: gorunmeyen satirlar uzerinde
    // toplu islem yapmak, kullanicinin gormedigi bir seyi silmesi
    // olurdu.
    setSecili(new Set());
  }

  function setArananMetin(v: string) {
    setArama(v);
    setOffset(0);
    setSecili(new Set());
  }

  const items = data?.items ?? [];
  const total = data?.meta?.total ?? 0;
  const tumuSecili = items.length > 0 && items.every((n) => secili.has(n.id));

  function tekiliDegistir(id: string) {
    setSecili((onceki) => {
      const yeni = new Set(onceki);
      if (yeni.has(id)) yeni.delete(id);
      else yeni.add(id);
      return yeni;
    });
  }

  function tumunuDegistir() {
    setSecili(tumuSecili ? new Set() : new Set(items.map((n) => n.id)));
  }

  // Ortak toplu-işlem sarmalı: çağır, seçimi temizle, listeyi tazele.
  async function topluCalistir(
    url: string,
    govde: unknown,
    basariAnahtari: SozlukAnahtari,
  ) {
    setTopluCalisiyor(true);
    try {
      await apiSend(url, "POST", govde);
      setSecili(new Set());
      // (P190 §4) Toplu okundu / toplu sil / tumunu okundu — HEPSINDE rozet
      // aninda tazelenir (markRead'deki gerekce).
      void globalMutate(BILDIRIM_SAYAC_UC);
      await mutate();
      toast.success(t(basariAnahtari));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakIslemBasarisiz"));
    } finally {
      setTopluCalisiyor(false);
    }
  }

  const seciliListe = () => Array.from(secili);

  // (P220 §3) ARAMA HER IKI SEKMEDE — VE SUNUCUDA
  //
  // Sunucu, kullanicinin GORDUGU metinde ariyor: baslik + govde + tip.
  // Metin kayitta DURMUYOR (okuma aninda, istegin dilinde uretiliyor),
  // bu yuzden SQL `ILIKE` ile aranamiyor.
  //
  // Istemcide filtrelemek de yanlis olurdu: yalniz ACIK SAYFAYI suzer.
  // "kargo" arayan kullanici 3. sayfadaki kaydi bulamaz.
  //
  // (P220 §3) TARAMA TAVANI NEDEN GORUNUR OLMALI
  //
  // Arama SQL'de yapilamiyor: bildirim metni kayitta durmuyor, okuma
  // aninda uretiliyor. Uc bu yuzden TAVANA kadar satir tariyor.
  //
  // Tavan asildiginda bunu SOYLEMEZSEK, kullanici sonucu "hepsi bu"
  // sanar ve arananin var olmadigi sonucuna varir — oysa kayit
  // TARANMAMIS olabilir. `meta.arama_tavani_asildi` o yuzden yanitta ve
  // o yuzden ekranda.

  return (
    <div className="space-y-5">
      <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
        {t("kabukBildirimler")}
      </h1>

      {/* (P191 §2) "Bildirim gelmiyor" sorusunun cevabi listenin USTUNDE:
          kullanici zaten bu sayfaya "bildirimlerim nerede?" diye gelir. */}
      {rol === ROL_ADMIN || rol === ROL_YONETICI ? <PushTeshis /> : null}

      {/* SARILABILIR: uc filtre dugmesi 360 dp + buyuk kok yazi boyunda tek
          satira sigmiyordu (tur 28 surusu: tr +9 px, ru +79 px). Sekme
          degil dugme oldugu icin sarmak dogru cozum — kaydirma gerekmez. */}
      <div className="flex flex-wrap items-center gap-2">
        {([
          ["false", t("bildirimOkunmamis")],
          ["true", t("bildirimOkunmus")],
        ] as [OkunduFiltre, string][]).map(([v, label]) => (
          // (P160) `aria-pressed` EKLENDI: eskiden secili suzgec YALNIZ
          // RENKLE anlatiliyordu ve ekran okuyucu hangisinin acik
          // oldugunu SOYLEYEMIYORDU. Secililik artik hem kabartmayla
          // (gorsel) hem `aria-pressed` ile (isitsel) belli.
          <Dugme
            key={label}
            boy="kucuk"
            tur={okundu === v ? TUR_BIRINCIL : TUR_IKINCIL}
            aria-pressed={okundu === v}
            onClick={() => setFilter(v)}
          >
            {label}
          </Dugme>
        ))}
      </div>

      {/* (P220 §3) ARAMA — her iki sekmede; gerekce yukarida. */}
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="search"
          value={arama}
          onChange={(e) => setArananMetin(e.target.value)}
          placeholder={t("bildirimAraIpucu")}
          aria-label={t("bildirimAra")}
          className="w-full max-w-sm rounded px-3 py-2"
          style={{
            fontSize: "var(--yz-fs-sm)",
            border: "1px solid var(--yz-border)",
            background: "var(--yz-surface-1)",
            color: "var(--yz-text)",
          }}
        />
        {arama.trim().length > 0 && arama.trim().length < 2 && (
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("bildirimAraAsgari")}
          </span>
        )}
        {/* TARAMA TAVANI GORUNUR — gerekce yukarida. */}
        {data?.meta?.arama_tavani_asildi ? (
          <span role="status" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("bildirimAramaTavani")}
          </span>
        ) : null}
      </div>

      {/* (P181 Bölüm 6.5) TOPLU İŞLEM ŞERİDİ: tümünü seç + seçilenlere okundu/sil + tümünü okundu. */}
      {total > 0 && (
        <div className="flex flex-wrap items-center gap-2">
          <label
            className="flex cursor-pointer select-none items-center gap-2"
            style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
          >
            <input
              type="checkbox"
              checked={tumuSecili}
              onChange={tumunuDegistir}
              className="h-4 w-4 rounded"
              style={{ accentColor: "var(--yz-accent)" }}
              aria-label={t("bildirimTumunuSec")}
            />
            {t("bildirimTumunuSec")}
          </label>
          {secili.size > 0 && (
            <>
              <span
                style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}
              >
                {secili.size} {t("bildirimSecili")}
              </span>
              <Dugme
                boy="kucuk"
                disabled={topluCalisiyor}
                onClick={() =>
                  void topluCalistir(
                    "/api/notifications/toplu-okundu",
                    { ids: seciliListe(), okundu: true },
                    "bildirimOkunduIsaretlendi",
                  )
                }
              >
                {t("bildirimSeciliOkundu")}
              </Dugme>
              <Dugme
                boy="kucuk"
                tur={TUR_TEHLIKE}
                disabled={topluCalisiyor}
                onClick={() =>
                  void topluCalistir(
                    "/api/notifications/toplu-sil",
                    { ids: seciliListe() },
                    "bildirimSilindi",
                  )
                }
              >
                {t("bildirimSeciliSil")}
              </Dugme>
            </>
          )}
          <Dugme
            boy="kucuk"
            tur={TUR_IKINCIL}
            disabled={topluCalisiyor}
            onClick={() =>
              void topluCalistir(
                "/api/notifications/tumunu-okundu",
                {},
                "bildirimOkunduIsaretlendi",
              )
            }
          >
            {t("bildirimTumunuOkundu")}
          </Dugme>
        </div>
      )}

      {/* HATA VARSA LISTE HIC CIZILMEZ. Bunu ayri bir dal yapmak sart:
          uc dustugunde `data` undefined kaliyor ve liste dali "0 kayit"
          gorup BOS DURUM ciziyordu — yani "bildirim yok" diyordu, oysa
          bilinen tek sey bildirimlerin OKUNAMADIGI. Kullanici bekledigi
          uyariyi gormedigi icin her sey yolunda saniyordu. */}
      {error ? (
        <HataDurumu mesaj={error.message} onTekrar={() => void mutate()} />
      ) : /* LISTE, TABLO DEGIL — ve bu bilincli: bildirim bir CUMLEDIR,
             sutunlara bolunecek alanlari yok. `VeriTablosu` burada yapiyi
             zorlardi. */
      isLoading && !data ? (
        <Kart>
          <IskeletMetin satir={5} />
        </Kart>
      ) : items.length === 0 ? (
        <Kart>
          <BosDurum baslik={t("bildirimYok")} />
        </Kart>
      ) : (
        <ul className="space-y-2">
          {items.map((n: AppNotification) => (
            <li key={n.id}>
              <Kart className="flex flex-wrap items-start gap-3">
                <input
                  type="checkbox"
                  checked={secili.has(n.id)}
                  onChange={() => tekiliDegistir(n.id)}
                  className="mt-1 h-4 w-4 rounded"
                  style={{ accentColor: "var(--yz-accent)" }}
                  aria-label={t("bildirimSec")}
                />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span
                      style={{
                        fontSize: "var(--yz-fs-xs)",
                        color: "var(--yz-text-2)",
                      }}
                    >
                      {enumAdi(t, BILDIRIM_TIP, n.tip)}
                    </span>
                    {!n.okundu && (
                      <Rozet durum="bilgi" nokta>
                        {t("bildirimYeniRozet")}
                      </Rozet>
                    )}
                  </div>
                  <p
                    className="mt-0.5"
                    style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
                  >
                    {n.mesaj}
                  </p>
                  <span
                    style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-3)" }}
                  >
                    {formatDateTime(n.created_at)}
                  </span>
                </div>
                {!n.okundu && (
                  <Dugme boy="kucuk" onClick={() => void markRead(n.id)}>
                    {t("bildirimOkunduIsaretle")}
                  </Dugme>
                )}
              </Kart>
            </li>
          ))}
        </ul>
      )}

      {/* SAYFALAMA: `VeriTablosu` kullanilmadigi icin (liste, tablo
          degil) serit burada elle ciziliyor — ama dugmeler ve toplam
          ayni ilkelden. */}
      {total > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3">
          <span style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("ortakToplam")}: {total} · {offset + 1}-
            {Math.min(offset + LIMIT, total)}
          </span>
          <div className="flex gap-2">
            <Dugme
              boy="kucuk"
              disabled={offset === 0}
              onClick={() => setOffset(Math.max(0, offset - LIMIT))}
              aria-label={t("listeOncekiSayfa")}
            >
              {t("ortakOnceki")}
            </Dugme>
            <Dugme
              boy="kucuk"
              disabled={offset + LIMIT >= total}
              onClick={() => setOffset(offset + LIMIT)}
              aria-label={t("listeSonrakiSayfa")}
            >
              {t("ortakSonraki")}
            </Dugme>
          </div>
        </div>
      )}
    </div>
  );
}
