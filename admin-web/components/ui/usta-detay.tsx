"use client";

/**
 * (P244 §9) USTA-DETAY DUZENI — solda secim listesi, sagda icerik.
 *
 * =========================================================================
 * OLCULEN KUSUR
 * =========================================================================
 * `/tanimlar` ON BIR kayit defterini sayfanin ustunde SARAN bir dugme
 * siraasi olarak diziyor. On bir dugme iki-uc satira yayiliyor, acik
 * olan yalnizca renkle (ve `aria-pressed` ile) belli oluyor ve icerik
 * her secimde asagi kayiyor. Ayni desen `/users`, `/profil`,
 * `/settings` ve `/tesis-ayarlari`nda da var.
 *
 * Referansta bu ekranlarin hepsi USTA-DETAY: solda dikey bir liste,
 * sagda o secimin icerigi. Dikey liste on bir ogeyi tek sutunda
 * gosterir, secili olan konumunu KORUR ve goz listeyi yukaridan asagi
 * tarar.
 *
 * =========================================================================
 * NEDEN `Sekmeler`IN BIR VARYANTI DEGIL, AYRI BILESEN
 * =========================================================================
 * `Sekmeler` icerigi KENDI tutar (`sekme.icerik`) — on bir defterin
 * hepsini birden kurmak demektir. Burada icerik `children` olarak
 * disaridan gelir: cagiran YALNIZ secili olani cizer. On bir defterin
 * her birinin kendi `useSWR`i oldugu dusunulurse fark, bir istek ile
 * on bir istek arasindaki farktir.
 *
 * =========================================================================
 * IKI ANLAM — VE ARALARINDAKI KURAL
 * =========================================================================
 * (P244 §10) `/tanimlar` `role=tablist`, `/profil` ise `<nav>`
 * kullaniyordu. Ikisi de gecerli ARIA deseni ama AYNI SEKIL icin iki
 * desen bir tutarsizlikti (§9b'de acik madde olarak yazilmisti).
 *
 * Duzen artik TEK bilesende; ayrilan yalnizca ANLAM ve kural su:
 *
 *   `sekme`    — secim AYNI TUR icerigin farkli DILIMINI gosterir.
 *                Ogeler birbirinin ALTERNATIFIDIR. (`/tanimlar`: on bir
 *                defter, hepsi ayni sekil — liste + form.)
 *                Roving `tabIndex`: on bir oge tek Tab duragi.
 *
 *   `gezinme`  — secim FARKLI ISLERE goturur; ogeler birbirinin
 *                alternatifi DEGILDIR. (`/profil`: hesap bilgileri,
 *                sifre degistirme, hesap SILME.) `<nav>` landmark'i
 *                ekran okuyucu kullanicisinin ATLAYABILECEGI bir bolge
 *                verir ve her oge normal bir Tab duragidir — cunku
 *                "sonraki secenege gec" burada ok tusu refleksi
 *                uretmez.
 *
 * ARIA rehberi de boyle ayirir: sekmeler AYNI TUR icerigin alternatif
 * gorunumleridir.
 *
 * =========================================================================
 * TEHLIKELI OGE
 * =========================================================================
 * Yikici bir secim (hesap silme) digerleriyle AYNI gorunemez. `Dugme`
 * ailesindeki `tehlike` turuyle ayni dil: `--yz-danger-ink`.
 */
import { useId, useRef, type ReactNode } from "react";

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const SEFFAF = "transparent";
const GOLGESIZ = "none";
const DIKEY = "vertical" as const;
const SAYFA = "page" as const;
// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`): tarama ucludaki her
// dizgeyi cevrilmemis metin adayi sayar ve HTML etiketi/ARIA rolu ile
// cumleyi ayirt edemez — haklidir.
const ETIKET_DIV = "div" as const;
const ETIKET_NAV = "nav" as const;
const ROL_TABLIST = "tablist" as const;
const ROL_TAB = "tab" as const;
const ROL_TABPANEL = "tabpanel" as const;

export interface UstaSecenek {
  id: string;
  baslik: string;
  /** Sagda gosterilen sayac (orn. defterdeki kayit sayisi). */
  rozet?: number;
  /** Yikici secim — kirmizi cizilir (orn. hesap silme). */
  tehlikeli?: boolean;
}

export function UstaDetayDuzeni({
  secenekler,
  aktifId,
  onDegis,
  listeBasligi,
  anlam = "sekme",
  children,
}: {
  secenekler: UstaSecenek[];
  aktifId: string;
  onDegis: (id: string) => void;
  /** Ekran okuyucu icin listenin adi (gorunmez). */
  listeBasligi: string;
  /** Yukaridaki kurala gore: alternatif gorunum mu, ayri isler mi. */
  anlam?: "sekme" | "gezinme";
  /** SECILI olanin icerigi — cagiran cizer. */
  children: ReactNode;
}) {
  const temelId = useId();
  const seritRef = useRef<HTMLDivElement | null>(null);

  function tus(e: React.KeyboardEvent) {
    // GEZINME kipinde ok tusu SECMEZ: `<nav>` icinde ok tusu bir
    // secim hareketi degildir ve Tab zaten her ogeye ugrar.
    if (anlam !== "sekme") return;
    const i = secenekler.findIndex((s) => s.id === aktifId);
    if (i < 0) return;
    let hedef = i;
    if (e.key === "ArrowDown" || e.key === "ArrowRight") {
      hedef = (i + 1) % secenekler.length;
    } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
      hedef = (i - 1 + secenekler.length) % secenekler.length;
    } else if (e.key === "Home") {
      hedef = 0;
    } else if (e.key === "End") {
      hedef = secenekler.length - 1;
    } else {
      return;
    }
    e.preventDefault();
    onDegis(secenekler[hedef].id);
    // ARIA deseninde ok tusu SECER ve ODAKLAR.
    seritRef.current?.querySelectorAll<HTMLElement>('[role="tab"]')?.[hedef]?.focus();
  }

  const aktif = secenekler.find((s) => s.id === aktifId);
  const sekmeMi = anlam === "sekme";
  const Sarmal = sekmeMi ? ETIKET_DIV : ETIKET_NAV;

  return (
    <div className="grid gap-4 lg:grid-cols-[15rem_minmax(0,1fr)]">
      <Sarmal
        ref={seritRef as never}
        role={sekmeMi ? ROL_TABLIST : undefined}
        aria-orientation={sekmeMi ? DIKEY : undefined}
        aria-label={listeBasligi}
        onKeyDown={tus}
        // DAR EKRANDA YATAY KAYAR, GENISTE DIKEY YIGILIR. Dar ekranda
        // 15rem'lik bir sutun icerige yer birakmazdi.
        className="flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible"
      >
        {secenekler.map((s) => {
          const bu = s.id === aktifId;
          return (
            <button
              key={s.id}
              type="button"
              role={sekmeMi ? ROL_TAB : undefined}
              id={`${temelId}-t-${s.id}`}
              aria-selected={sekmeMi ? bu : undefined}
              aria-current={!sekmeMi && bu ? SAYFA : undefined}
              aria-controls={sekmeMi ? `${temelId}-p` : undefined}
              // SEKMEDE TEK DURAK: yalniz aktif oge Tab ile bulunur;
              // aksi halde klavye kullanicisi on bir kez Tab'a basardi.
              // GEZINMEDE her oge normal bir duraktir.
              tabIndex={sekmeMi && !bu ? -1 : 0}
              onClick={() => onDegis(s.id)}
              className="odak-ic flex shrink-0 items-center justify-between gap-2 px-3 py-2 text-start lg:w-full"
              style={{
                fontSize: "var(--yz-fs-body)",
                borderRadius: "var(--yz-radius-btn)",
                color: s.tehlikeli
                  ? "var(--yz-danger-ink)"
                  : bu
                    ? "var(--yz-text)"
                    : "var(--yz-text-2)",
                background: bu ? "var(--yz-surface-2)" : SEFFAF,
                boxShadow: bu ? "var(--yz-raised)" : GOLGESIZ,
                fontWeight: bu ? 600 : 400,
              }}
            >
              <span className="min-w-0 truncate">{s.baslik}</span>
              {typeof s.rozet === "number" && (
                <span
                  aria-hidden="true"
                  className="shrink-0 px-1.5 tabular-nums"
                  style={{
                    borderRadius: "var(--yz-radius-chip)",
                    background: "var(--yz-surface-sunken)",
                    color: "var(--yz-text-2)",
                    fontSize: "var(--yz-fs-xs)",
                  }}
                >
                  {s.rozet}
                </span>
              )}
            </button>
          );
        })}
      </Sarmal>

      <div
        role={sekmeMi ? ROL_TABPANEL : undefined}
        id={`${temelId}-p`}
        aria-labelledby={aktif ? `${temelId}-t-${aktif.id}` : undefined}
        tabIndex={0}
        className="odak-ic min-w-0"
      >
        {children}
      </div>
    </div>
  );
}
