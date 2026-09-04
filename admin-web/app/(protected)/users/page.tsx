"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import useSWR from "swr";

import { useToast } from "@/components/Toast";
import {
  Alan,
  AlanSarmal,
  AramaAlani,
  Dugme,
  HataDurumu,
  Modal,
  Rozet,
  Secim,
  VeriTablosu,
  type Kolon,
  type RozetDurumu,
  type SayfaBoyu,
  type TabloDurumu,
  useOnay,
} from "@/components/ui";
import { alanliHataMetni, apiSend } from "@/lib/client";
import type { UnitList } from "@/lib/types";
import { jsonFetcher } from "@/lib/fetcher";
import { TelefonAlani } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { ROLE_OPTIONS as ROLES, rolAdi } from "@/lib/roles";
import { telefonNormalle } from "@/lib/telefon";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";
import type { UserDetail, UserListResponse, UserRole, UserRow } from "@/lib/types";

/**
 * (P160 / Asama 6) KULLANICILAR — yeni tasarim diline tasindi.
 *
 * =========================================================================
 * NE DEGISTI, NE DEGISMEDI
 * =========================================================================
 * DEGISMEYEN (kilitli kural 2): butun veri mantigi birebir korundu —
 * suzgecler (rol · durum · arama), sunucudan gelen ACILABILIR ROL kumesi,
 * duzenlenen kaydin rolunun listede tutulmasi, denetciye ozel gorev
 * penceresi, telefon normalizasyonu, parolanin opsiyonelligi, gecici kod
 * uyarisi, aktiflestir/pasiflestir ve toplu yukleme bagi.
 *
 * DEGISEN (sunum):
 *   * Form SAYFA USTUNDE ALAN ACMA yerine MODAL'da (brief).
 *   * Tablo `VeriTablosu`: siralama, kolon gorunurlugu ve SAYFA BASINA
 *     KAYIT SECIMI (10/25/50/100) BEDAVA geldi — eskiden sabit 20'ydi.
 *   * Iskelet yukleme durumu (eskiden duz "Yukleniyor..." metniydi).
 *   * Rol ve durum rozetleri: renkli DOLGU yerine kenar+metin.
 *
 * =========================================================================
 * SUNUCU TARAFLI SAYFALAMA
 * =========================================================================
 * Uc `limit`/`offset` + `meta.total` ile calisiyor, yani tablo kendi
 * dilimlemez (`sunucuTarafli`). Aksi halde 5000 kullanicili bir tesiste
 * TUM listeyi cekmek gerekirdi.
 */

/** Sayfa boyu artik kullanici secimli; bu yalniz ILK degerdir. */
const ILK_BOY: SayfaBoyu = 25;

/** Rol -> rozet durumu. Renk SINYALDIR; ad zaten metinde yazili. */
const ROL_DURUMU: Record<string, RozetDurumu> = {
  admin: "kritik",
  yonetici: "uyari",
  denetci: "bilgi",
};

const VARSAYILAN_ROL: UserRole = "security";
const ROL_DENETCI = "denetci";

interface FormState {
  ad: string;
  email: string;
  telefon: string;
  aranabilir: boolean;
  role: UserRole;
  // (P128) Gorev penceresi — YALNIZ `denetci` rolunde gosterilir.
  gorevBaslangic: string;
  gorevBitis: string;
}
const EMPTY: FormState = {
  ad: "",
  email: "",
  telefon: "",
  aranabilir: false,
  role: VARSAYILAN_ROL,
  gorevBaslangic: "",
  gorevBitis: "",
};

// UCLUDE DIZE YAZILMAZ (depo kurali `sabit-metin`).
const DURUM_OLUMLU = "olumlu" as const;
const DURUM_NOTR = "notr" as const;

const ROL_SAKIN = "resident" as const;
// (P185 §4) Daire ROLE BAGLI DEGIL: bir yonetici AYNI ZAMANDA sakin olabilir,
// ona da daire atanabilir. Form daire alanini sakin VE yonetici rolunde gosterir.
const ROL_YONETICI = "yonetici" as const;
const DAIRE_ROLLERI: readonly string[] = [ROL_SAKIN, ROL_YONETICI];
// (P186) Blok-atanmamis daireler icin acilir-liste NObet degeri (bos "" =
// "blok secilmedi"den ayirt edilmeli). Kullaniciya "Blok atanmamis" gorunur.
const BLOKSUZ = "__bloksuz__";

export default function UsersPage() {
  const t = useT();
  // (P162) Yikici onay tema/dil taniyan diyalogdan gecer.
  const { onayla, diyalog } = useOnay();
  // (P162 §6) SAKIN OLUSTURURKEN DAIRE ATAMASI.
  //
  // Mobilde tek adimda yapilabiliyordu, webde YAPILAMIYORDU: once
  // kullanici olusturulup sonra Daireler ekranindan atanmasi gerekiyordu.
  // Iki adim, ikinci adimin unutulmasi demekti — sakin kaydi var, hangi
  // dairede oldugu belirsiz.
  //
  // UC DEGISMEDI: kullanici `POST /users`, atama `POST /units/{id}/
  // residents`. Ikisi ARDISIK cagriliyor; sunucuya birlesik bir uc
  // eklemek sozlesmeyi degistirmek olurdu (kilitli kural).
  const [atanacakDaire, setAtanacakDaire] = useState("");
  // (P186) BLOK -> DAIRE iki asamali secim: cok daireli sitede tek liste
  // kullanissizdir; once blok secilir, daire listesi ona gore filtrelenir.
  const [secilenBlok, setSecilenBlok] = useState("");
  const { data: daireListesi } = useSWR<UnitList>(
    "/api/units?limit=1000&offset=0",
    jsonFetcher,
    { revalidateOnFocus: false },
  );
  // Benzersiz bloklar (blok-atanmamis daireler BLOKSUZ altinda toplanir).
  const bloklar = useMemo(() => {
    const s = new Set<string>();
    for (const u of daireListesi?.items ?? []) s.add(u.blok || BLOKSUZ);
    return Array.from(s).sort();
  }, [daireListesi]);
  // Adlandirilmis blok var mi? Yoksa (tek bina) blok secici gosterilmez.
  const blokSecici = bloklar.some((b) => b !== BLOKSUZ);
  const filtreliDaireler = useMemo(
    () =>
      (daireListesi?.items ?? []).filter(
        (u) => (u.blok || BLOKSUZ) === secilenBlok,
      ),
    [daireListesi, secilenBlok],
  );
  const toast = useToast();

  const [durum, setDurum] = useState<TabloDurumu>({
    sayfa: 1,
    boy: ILK_BOY,
    siraKolon: null,
    siraYonu: "artan",
  });
  const [role, setRole] = useState<string>("");
  const [aktif, setAktif] = useState<string>("");
  const [q, setQ] = useState("");

  const qs = new URLSearchParams({
    limit: String(durum.boy),
    offset: String((durum.sayfa - 1) * durum.boy),
  });
  if (role) qs.set("role", role);
  if (aktif) qs.set("is_active", aktif);
  if (q.trim()) qs.set("q", q.trim());
  const { data, error, isLoading, mutate } = useSWR<UserListResponse>(
    `/api/users?${qs.toString()}`,
    jsonFetcher,
  );

  // (P130) ACILIR LISTE SUNUCUDAN. Eskiden `ROLE_OPTIONS`in tamami
  // cizilirdi: bir site yoneticisi "Platform Admin"i SECEBILIYOR ve
  // kaydedince 403 aliyordu — sunucu dogru davraniyordu, arayuz yanlis soz
  // veriyordu. Liste artik cagiranin GERCEKTEN acabildigi kumedir.
  const { data: acilabilir } = useSWR<{ roller: UserRole[] }>(
    "/api/users/acilabilir-roller",
    jsonFetcher,
  );
  // `undefined` = HENUZ BILINMIYOR (bos kumeyle ayni sey degil): liste
  // gelene kadar secenek cizmek, gelince degisen bir form demek olurdu.
  const acilabilirRoller = acilabilir?.roller;
  const formRolleri = useMemo(
    () => (acilabilirRoller ? ROLES.filter((r) => acilabilirRoller.includes(r.value)) : []),
    [acilabilirRoller],
  );

  const [open, setOpen] = useState(false);
  // (P193 §7) BILDIRIM TESHISI (eksik 5) + ODEME KODLARI (eksik 10).
  const [teshis, setTeshis] = useState<UserDetail | null>(null);
  const [kodAcik, setKodAcik] = useState(false);
  const [kodHata, setKodHata] = useState<string | null>(null);
  const [kodlar, setKodlar] = useState<{
    uretilen: number;
    items: { user_id: string; ad: string; daire_no: string | null; odeme_kodu: string }[];
  } | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  // (P186 §2) Duzenlemede: kayit tamamlandiysa e-posta salt-okunur (giris
  // kimligi). `ilkDaire` acilistaki atamayi tutar; kaydette DEGISTIYSE
  // ata/kaldir yapilir (degismediyse dokunma).
  const [duzenlenenTamam, setDuzenlenenTamam] = useState(false);
  const [ilkDaire, setIlkDaire] = useState("");

  // DUZENLENEN KAYDIN ROLU LISTEDE YOKSA YINE GORUNUR. Aksi halde select
  // sessizce ilk secenege duser ve kaydet, kullanicinin DOKUNMADIGI bir
  // alani degistirmek isterdi (sunucu 403 verirdi ama sebep gorunmezdi).
  const mevcutRol = ROLES.find((r) => r.value === form.role);
  const rolSecenekleri =
    mevcutRol && !formRolleri.some((r) => r.value === form.role)
      ? [mevcutRol, ...formRolleri]
      : formRolleri;

  /** Suzgec degisince ILK SAYFAYA don — 7. sayfada suzmek bos ekran verirdi. */
  function suzgec(next: { role?: string; aktif?: string; q?: string }) {
    if (next.role !== undefined) setRole(next.role);
    if (next.aktif !== undefined) setAktif(next.aktif);
    if (next.q !== undefined) setQ(next.q);
    setDurum((d) => ({ ...d, sayfa: 1 }));
  }

  function openNew() {
    setEditingId(null);
    // Varsayilan rol de acilabilir kumeden secilir; sabit "security"
    // birakmak, o rolu acamayan bir cagirana pesinen gecersiz bir form
    // vermek olurdu.
    setForm({ ...EMPTY, role: formRolleri[0]?.value ?? EMPTY.role });
    setFormErr(null);
    setDuzenlenenTamam(false);
    setAtanacakDaire("");
    setIlkDaire("");
    setSecilenBlok("");
    setOpen(true);
  }

  async function openEdit(u: UserRow) {
    setEditingId(u.id);
    // Numara listede DONMEZ (KVKK); tek-kayit detayindan cekilir.
    setForm({
      ad: u.ad,
      email: u.email,
      telefon: "",
      aranabilir: u.aranabilir ?? false,
      role: (u.role as UserRole) ?? VARSAYILAN_ROL,
      gorevBaslangic: u.gorev_baslangic ?? "",
      gorevBitis: u.gorev_bitis ?? "",
    });
    setFormErr(null);
    // Detay gelene kadar guvenli varsayilan: tamamlanmis KABUL et (e-posta
    // kilitli baslar), atama bilinmiyor.
    setDuzenlenenTamam(true);
    setTeshis(null);
    setAtanacakDaire("");
    setIlkDaire("");
    setSecilenBlok("");
    setOpen(true);
    try {
      const d = await jsonFetcher<UserDetail>(`/api/users/${u.id}`);
      setTeshis(d);
      setForm((f) => ({
        ...f,
        telefon: d.telefon ?? "",
        aranabilir: d.aranabilir ?? false,
      }));
      setDuzenlenenTamam(d.kayit_tamamlandi ?? false);
      setAtanacakDaire(d.daire_id ?? "");
      setIlkDaire(d.daire_id ?? "");
      // Mevcut atamanin blogunu turet ki blok->daire secici on-dolsun.
      const birim = (daireListesi?.items ?? []).find((x) => x.id === d.daire_id);
      setSecilenBlok(birim ? birim.blok || BLOKSUZ : "");
    } catch {
      // Detay cekilemezse form yine acik kalir (telefon bos); kaydetmeye engel yok.
    }
  }

  async function odemeKodlariniAc(): Promise<void> {
    setKodHata(null);
    setKodAcik(true);
    setKodlar(null);
    try {
      // POST cunku uc YAZAR: eksik kodlari uretir (tembel uretim, bkz.
      // `routers/users.py`). Yonetici "kodlari duyuracagim" dedigi anda
      // kodlarin VAR OLMASI gerekir.
      const d = await apiSend<{
        uretilen: number;
        items: { user_id: string; ad: string; daire_no: string | null; odeme_kodu: string }[];
      }>("/api/users/odeme-kodlari", "POST", {});
      setKodlar(d);
    } catch (e) {
      setKodHata(e instanceof Error ? e.message : t("ortakHataOlustu"));
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        // (P186-ek2) PAROLA YOK: yonetici bir kullanicinin parolasini
        // degistiremez. Kullanici kendi parolasini kendi degistirir.
        const body: Record<string, unknown> = {
          ad: form.ad,
          email: form.email || null,
          telefon: telefonNormalle(form.telefon) || null,
          aranabilir: form.aranabilir,
          role: form.role,
          // BOS = "pencere yok" (acik null); alani hic gondermemek
          // "degistirme" demek olurdu ve gorev IPTALI yapilamazdi.
          gorev_baslangic: form.gorevBaslangic || null,
          gorev_bitis: form.gorevBitis || null,
        };
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
        // (P186 §2.1) DAIRE ATAMASI DUZENLEMEDE: yalniz daire-tutan rolde
        // (sakin/yonetici) ve secim DEGISTIYSE ata/kaldir. Rol daire-tutan
        // kumeden CIKTIYSA backend bagi zaten kaldirdi — burada dokunma.
        if (DAIRE_ROLLERI.includes(form.role) && atanacakDaire !== ilkDaire) {
          try {
            if (ilkDaire) {
              await apiSend(
                `/api/units/${ilkDaire}/residents/${editingId}`,
                "DELETE",
              );
            }
            if (atanacakDaire) {
              await apiSend(`/api/units/${atanacakDaire}/residents`, "POST", {
                user_id: editingId,
              });
            }
          } catch {
            toast.error(t("kullaniciDaireAtanamadi"));
          }
        }
      } else {
        // (P185 §3/§4 · P186) E-POSTA ZORUNLU (dogrulama/bildirim + DAVET
        // kanali). Parola YOK: hesap parolasiz acilir, kisi davet (Tesis ID)
        // ile mobilden KENDI kimligini kurar. Yonetici parola atamaz.
        if (!form.email.trim()) {
          setFormErr(t("kullaniciEpostaZorunluHata"));
          setSaving(false);
          return;
        }
        const body: Record<string, unknown> = {
          ad: form.ad,
          // (P212-ek §2) TELEFON ARTIK OPSIYONEL — ve bu coklu tesisin
          // onundeki engeldi. Telefon PLATFORM GENELINDE benzersiz;
          // zorunlu oldugu surece ayni kisi IKINCI bir tesise ancak
          // UYDURMA bir numarayla eklenebiliyordu (olculdu: telefonsuz
          // 422, ayni numarayla 409). Kimlik P197'den beri E-POSTADIR.
          // Bos birakilirsa alan GONDERILMEZ.
          telefon: telefonNormalle(form.telefon) || null,
          aranabilir: form.aranabilir,
          role: form.role,
          email: form.email.trim(),
        };
        if (form.gorevBaslangic) body.gorev_baslangic = form.gorevBaslangic;
        if (form.gorevBitis) body.gorev_bitis = form.gorevBitis;
        const created = await apiSend<{ id?: string }>(
          "/api/users",
          "POST",
          body,
        );
        // DAIRE ATAMASI — kullanici olustuktan SONRA.
        //
        // HATASI KULLANICI KAYDINI GERI ALMAZ ve bu bilincli: hesap
        // acildi, atama basarisiz oldu. Sessizce yutmak "atandi" sanmaya
        // yol acardi; bu yuzden AYRI bir uyari veriliyor ve kullanici
        // atamayi Daireler ekranindan tamamlayabiliyor.
        if (atanacakDaire && created?.id) {
          try {
            await apiSend(`/api/units/${atanacakDaire}/residents`, "POST", {
              user_id: created.id,
            });
          } catch {
            toast.error(t("kullaniciDaireAtanamadi"));
          }
        }
      }
      setOpen(false);
      mutate();
      toast.success(editingId ? t("kullaniciGuncellendi") : t("kullaniciOlusturuldu"));
    } catch (err) {
      const m = err instanceof Error ? err.message : t("ortakKaydedilemedi");
      setFormErr(
        /email|e-posta|telefon|zaten kayitli|conflict/i.test(m)
          ? t("kullaniciZatenKayitli")
          : m,
      );
    } finally {
      setSaving(false);
    }
  }

  /**
   * (P162 §4.3) KULLANICI SILME — WEBDE YOKTU.
   *
   * Uc (`DELETE /users/{id}`) ve BFF rotasi ZATEN VARDI; eksik olan
   * yalnizca dugmeydi. Mobilde silinebilen bir hesap webde silinemiyordu
   * (brief'in web/mobil esitligi maddesi).
   *
   * ONAY METNI SERT SILMEYI ACIKCA SOYLER: sunucu `is_active=false`
   * DEGIL, kaydi GERCEKTEN siliyor. Yumusak silme zaten ayri bir dugme
   * ("Pasiflestir"); ikisini ayni cumleyle anlatmak kullaniciyi geri
   * alinabilir sanip silmeye iterdi.
   */
  async function sil(u: UserRow) {
    const ok = await onayla({
      baslik: t("ortakSilBaslik"),
      mesaj: t("kullaniciSilOnay", { ad: u.ad }),
      onayMetni: t("ortakSil"),
      tehlikeli: true,
    });
    if (!ok) return;
    try {
      // (P189) Backend akilli siler: {deleted:false} => gecmisi oldugu icin
      // ANONIMLESTIRILDI (kayitlar korundu), true => satir tamamen gitti.
      const r = await apiSend<{ deleted?: boolean }>(
        `/api/users/${u.id}`,
        "DELETE",
      );
      mutate();
      toast.success(
        r?.deleted === false
          ? t("kullaniciAnonimlestirildi")
          : t("kullaniciSilindi"),
      );
    } catch (err) {
      toast.error(alanliHataMetni(err, t("ortakSilinemedi")));
    }
  }

  async function setActive(u: UserRow, active: boolean) {
    try {
      await apiSend(`/api/users/${u.id}`, "PATCH", { is_active: active });
      mutate();
      toast.success(active ? t("kullaniciAktiflestirildi") : t("kullaniciPasiflestirildi"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("ortakGuncellenemedi"));
    }
  }

  const kolonlar: Kolon<UserRow>[] = useMemo(
    () => [
      {
        id: "ad", kartRolu: "baslik",
        baslik: t("ortakAd"),
        hucre: (u) => u.ad,
        // Siralama SUNUCU TARAFLI kipte istemcide yapilmaz; uc bugun
        // `sort` parametresi almiyor, bu yuzden kolonlar siralanabilir
        // ISARETLENMEDI. Yanlis calisan bir ok gostermektense hic
        // gostermemek dogru.
        gizlenebilir: false,
      },
      { id: "email", kartRolu: "ozet", baslik: t("girisEposta"), hucre: (u) => u.email },
      {
        id: "aranabilir",
        baslik: t("kullaniciAranabilir"),
        hucre: (u) => (u.aranabilir ? t("ortakEvet") : "—"),
        darEkrandaGizle: true,
      },
      {
        id: "rol", kartRolu: "ozet",
        baslik: t("ortakRol"),
        hucre: (u) => (
          <Rozet durum={ROL_DURUMU[u.role] ?? DURUM_NOTR} nokta>
            {rolAdi(t, u.role)}
          </Rozet>
        ),
      },
      {
        id: "durum", kartRolu: "rozet",
        baslik: t("ortakDurum"),
        hucre: (u) => (
          <Rozet durum={u.is_active ? DURUM_OLUMLU : DURUM_NOTR}>
            {u.is_active ? t("ortakAktif") : t("ortakPasif")}
          </Rozet>
        ),
      },
      {
        id: "eylem", kartRolu: "eylem",
        baslik: "",
        gizlenebilir: false,
        hucre: (u) => (
          <div className="flex justify-end gap-2">
            <Dugme boy="kucuk" onClick={() => void openEdit(u)}>
              {t("ortakDuzenle")}
            </Dugme>
            <Dugme
              boy="kucuk"
              onClick={() => void setActive(u, !u.is_active)}
            >
              {u.is_active ? t("ortakPasiflestir") : t("ortakAktiflestir")}
            </Dugme>
            <Dugme boy="kucuk" tur="tehlike" onClick={() => void sil(u)}>
              {t("ortakSil")}
            </Dugme>
          </div>
        ),
      },
    ],
    // `t` disindaki bagimliliklar kararli; `openEdit`/`setActive` her
    // cizimde yeniden kurulsa da kolon tanimi yalniz metin tasiyor.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t],
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 style={{ fontSize: "var(--yz-fs-h1)", color: "var(--yz-text)" }}>
          {t("kabukKullanicilar")}
        </h1>
        <div className="flex flex-wrap gap-2">
          {/* (P154 / Asama 5) EXCEL ILE TOPLU SAKIN YUKLEME — brief:
              "Asama 8'deki import framework'u kullanacak, AYRI YUKLEME
              KODU YAZMA". Bu yuzden burada bir yukleme formu YOK,
              catiya yonlendirme var. */}
          <Link href="/ice-aktarim?tur=kisi">
            <Dugme boy="kucuk">{t("kullaniciTopluYukle")}</Dugme>
          </Link>
          {/* (P193 §7 / eksik 10) ODEME KODLARI. Banka eslestirmesinin
              kesin calismasi sakinin havale aciklamasina kendi kodunu
              yazmasina bagli; kod sakinin uygulamasinda gorunuyordu ama
              yonetici goremiyor, dolayisiyla DUYURAMIYORDU. */}
          <Dugme boy="kucuk" onClick={() => void odemeKodlariniAc()}>
            {t("kullaniciOdemeKodlari")}
          </Dugme>
          <Dugme tur="birincil" boy="kucuk" onClick={openNew}>
            {t("kullaniciYeni")}
          </Dugme>
        </div>
      </div>

      {/* HATA DURUMU artik TABLONUN ICINDE (`hata` ozelligi). Disarida
          bir dal olsaydi hata cikinca SUZGECLER de kaybolurdu — oysa
          kullanicinin ilk refleksi suzgeci degistirip tekrar denemek. */}
        <VeriTablosu<UserRow>
          kolonlar={kolonlar}
          satirlar={data?.items ?? []}
          satirId={(u) => u.id}
          hata={error ? error.message : null}
          onTekrar={() => void mutate()}
          yukleniyor={isLoading && !data}
          bosBaslik={t("kullaniciYok")}
          bosAciklama={t("kullaniciYokAlt")}
          sunucuTarafli
          toplam={data?.meta?.total ?? 0}
          durum={durum}
          onDurumDegisti={setDurum}
          araclar={
            <div className="flex flex-wrap items-end gap-3">
              <div className="w-44">
                <AlanSarmal etiket={t("ortakRol")}>
                  {(b) => (
                    <Secim
                      {...b}
                      value={role}
                      onChange={(e) => suzgec({ role: e.target.value })}
                    >
                      <option value="">{t("ortakTumu")}</option>
                      {ROLES.map((r) => (
                        <option key={r.value} value={r.value}>
                          {t(r.anahtar)}
                        </option>
                      ))}
                    </Secim>
                  )}
                </AlanSarmal>
              </div>
              <div className="w-44">
                <AlanSarmal etiket={t("ortakDurum")}>
                  {(b) => (
                    <Secim
                      {...b}
                      value={aktif}
                      onChange={(e) => suzgec({ aktif: e.target.value })}
                    >
                      <option value="">{t("ortakTumu")}</option>
                      <option value="true">{t("ortakAktif")}</option>
                      <option value="false">{t("ortakPasif")}</option>
                    </Secim>
                  )}
                </AlanSarmal>
              </div>
              <div className="min-w-[220px] grow">
                <AramaAlani
                  deger={q}
                  onDegisim={(v) => suzgec({ q: v })}
                  etiket={t("kullaniciArama")}
                  yerTutucu={t("kullaniciAramaIpucu")}
                  temizleEtiketi={t("ortakKapat")}
                />
              </div>
            </div>
          }
        />

      {/* FORM ARTIK MODALDA (brief: "sayfa ustunde alan acma deseni
          kaldirilacak"). Odak tuzagi, ESC ve kapanista odagin geri
          donmesi `Modal`da. */}
      <Modal
        acik={open}
        onKapat={() => setOpen(false)}
        baslik={editingId ? t("kullaniciDuzenle") : t("kullaniciYeni")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <>
            <Dugme tur="sessiz" onClick={() => setOpen(false)} disabled={saving}>
              {t("ortakIptal")}
            </Dugme>
            <Dugme tur="birincil" type="submit" form="kullanici-form" yukleniyor={saving}>
              {saving ? t("ortakKaydediliyor") : t("ortakKaydet")}
            </Dugme>
          </>
        }
      >
        {/* `form` ID ile alttaki dugmeye baglandi: eylemler modalin
            SABIT altinda duruyor ve govdeyle birlikte kaymiyor. */}
        <form id="kullanici-form" onSubmit={save} className="grid gap-4 sm:grid-cols-2">
          {/* (P162 §6 · P185 §4 · P186 §2.1) DAIRE ATAMASI — SAKIN VE YONETICIDE.
              Daire ROLE BAGLI DEGIL (yonetici de sakin olabilir); form yalniz
              gosterme kararini rolden verir. SAKINDE ZORUNLU (sakin bir dairede
              oturur), yoneticide istege bagli. DUZENLEMEDE DE gosterilir
              (P186 kabul 4): acilista mevcut atama on-dolar, degisirse
              ata/kaldir. */}
          {DAIRE_ROLLERI.includes(form.role) && blokSecici && (
            <AlanSarmal etiket={t("ortakBlok")} zorunlu={form.role === ROL_SAKIN}>
              {(b) => (
                <Secim
                  {...b}
                  value={secilenBlok}
                  onChange={(e) => {
                    // Blok degisince daire secimi SIFIRLANIR (eski daire yeni
                    // bloga ait olmayabilir).
                    setSecilenBlok(e.target.value);
                    setAtanacakDaire("");
                  }}
                  required={form.role === ROL_SAKIN}
                >
                  <option value="">{t("kullaniciBlokSec")}</option>
                  {bloklar.map((bl) => (
                    <option key={bl} value={bl}>
                      {bl === BLOKSUZ ? t("daireBlokAtanmamis") : bl}
                    </option>
                  ))}
                </Secim>
              )}
            </AlanSarmal>
          )}

          {DAIRE_ROLLERI.includes(form.role) && (
            <AlanSarmal
              etiket={
                form.role === ROL_SAKIN
                  ? t("kullaniciDaire")
                  : t("kullaniciDaireAta")
              }
              zorunlu={form.role === ROL_SAKIN}
            >
              {(b) => (
                <Secim
                  {...b}
                  value={atanacakDaire}
                  onChange={(e) => setAtanacakDaire(e.target.value)}
                  required={form.role === ROL_SAKIN}
                  // Blok secici varken once blok secilmeli (daire ona gore
                  // filtreli). Tek binada (blok yok) tum daireler listelenir.
                  disabled={blokSecici && !secilenBlok}
                >
                  <option value="">{t("kullaniciDaireYok")}</option>
                  {(blokSecici ? filtreliDaireler : daireListesi?.items ?? []).map(
                    (u) => (
                      <option key={u.id} value={u.id}>
                        {u.blok ? `${u.blok}/${u.no}` : u.no}
                      </option>
                    ),
                  )}
                </Secim>
              )}
            </AlanSarmal>
          )}

          <AlanSarmal etiket={t("ortakAd")} zorunlu>
            {(b) => (
              <Alan
                {...b}
                value={form.ad}
                onChange={(e) => setForm({ ...form, ad: e.target.value })}
                required
              />
            )}
          </AlanSarmal>

          {/* (P185 §3/§4 · P186 §2.2) E-POSTA ZORUNLU: dogrulama + bildirim
              kanali. TAMAMLANMIS hesapta SALT-OKUNUR: e-posta giris kimligidir,
              panelden ezmek hesap-ele-gecirme olurdu (backend de 409 verir).
              Tamamlanmamis hesapta degistirilirse davet yeni adrese gider. */}
          <AlanSarmal
            etiket={t("kullaniciEposta")}
            ipucu={
              editingId && duzenlenenTamam
                ? t("kullaniciEpostaKilitli")
                : t("kullaniciEpostaIpucu")
            }
            zorunlu
          >
            {(b) => (
              <Alan
                {...b}
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                required
                readOnly={Boolean(editingId) && duzenlenenTamam}
              />
            )}
          </AlanSarmal>

          {/* (P185 §3) TELEFON YALNIZ ILETISIM — "giris anahtari" DEGIL.
              (P212-ek §2) ARTIK OPSIYONEL: zorunlulugu, ayni kisinin
              ikinci bir tesise eklenmesini imkansiz kiliyordu (telefon
              global benzersiz). */}
          <TelefonAlani
            etiket={t("kullaniciTelefon")}
            ipucu={t("kullaniciTelefonIpucu")}
            deger={form.telefon}
            onDegisti={(v) => setForm({ ...form, telefon: v })}
          />

          <AlanSarmal
            etiket={t("kullaniciAranabilir")}
            ipucu={t("kullaniciAranabilirIpucu")}
          >
            {(b) => (
              <label
                className="flex h-11 items-center gap-2"
                style={{ fontSize: "var(--yz-fs-body)", color: "var(--yz-text)" }}
              >
                <input
                  {...b}
                  type="checkbox"
                  checked={form.aranabilir}
                  onChange={(e) => setForm({ ...form, aranabilir: e.target.checked })}
                />
                {t("kullaniciAranabilirOnay")}
              </label>
            )}
          </AlanSarmal>

          <AlanSarmal etiket={t("ortakRol")}>
            {(b) => (
              <Secim
                {...b}
                value={form.role}
                disabled={acilabilirRoller === undefined}
                onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}
              >
                {rolSecenekleri.map((r) => (
                  <option key={r.value} value={r.value}>
                    {t(r.anahtar)}
                  </option>
                ))}
              </Secim>
            )}
          </AlanSarmal>

          {form.role === ROL_DENETCI ? (
            // (P128) YALNIZ DENETCIDE GORUNUR: gorev penceresi bugun
            // baska bir rolde anlam tasimiyor ve her role gostermek,
            // doldurulunca hicbir sey yapmayan bir alan demekti.
            <>
              <AlanSarmal
                etiket={t("kullaniciGorevBaslangic")}
                ipucu={t("kullaniciGorevIpucu")}
              >
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    value={form.gorevBaslangic}
                    onChange={(e) =>
                      setForm({ ...form, gorevBaslangic: e.target.value })
                    }
                  />
                )}
              </AlanSarmal>
              <AlanSarmal etiket={t("kullaniciGorevBitis")}>
                {(b) => (
                  <Alan
                    {...b}
                    type="date"
                    value={form.gorevBitis}
                    onChange={(e) => setForm({ ...form, gorevBitis: e.target.value })}
                  />
                )}
              </AlanSarmal>
            </>
          ) : null}

          {/* (P186-ek2) PAROLA ALANI TAMAMEN KALDIRILDI. Yonetici bir
              kullanicinin parolasini ne olustururken ne de duzenlerken
              belirleyemez (o parolayla hesaba girebilirdi). Kullanici kendi
              parolasini kurar/degistirir: davet (Tesis ID) ile ilk kayit,
              sonrasinda "sifremi unuttum" (e-posta) ya da kendi parola ayari. */}

          {formErr && (
            <p
              role="alert"
              className="sm:col-span-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formErr}
            </p>
          )}
          {/* (P193 §7 / eksik 5) BILDIRIM TANILAMA — SALT OKUNUR.
              "Sakine bildirim gitmiyor" sikayetinin uc olasi cevabi var:
              kanal tercihi kapali, e-posta dogrulanmamis, ya da kayitli
              cihaz yok. Ucu de burada gorunur. DEGISTIRILEMEZ: tercihi
              baskasi adina degistirmek rizayi anlamsizlastirir. */}
          {editingId && teshis && (
            <div className="sm:col-span-2 space-y-1">
              <h3 style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}>
                {t("kullaniciTanilama")}
              </h3>
              <dl
                className="flex flex-wrap gap-x-5 gap-y-1"
                style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}
              >
                {(
                  [
                    ["kullaniciTanilamaEposta", teshis.bildirim_eposta],
                    ["kullaniciTanilamaSms", teshis.bildirim_sms],
                    ["kullaniciTanilamaMobil", teshis.bildirim_mobil],
                    ["kullaniciTanilamaDogrulandi", teshis.eposta_dogrulandi],
                  ] as [SozlukAnahtari, boolean | null | undefined][]
                ).map(([anahtar, deger]) => (
                  <span key={anahtar}>
                    <dt className="inline">{t(anahtar)}: </dt>
                    <dd className="inline font-semibold">
                      {deger ? t("ortakAcik") : t("ortakKapali")}
                    </dd>
                  </span>
                ))}
                <span>
                  <dt className="inline">{t("kullaniciTanilamaCihaz")}: </dt>
                  <dd className="inline font-semibold tabular-nums">
                    {teshis.mobil_cihaz_sayisi ?? 0}
                  </dd>
                </span>
                {teshis.odeme_kodu && (
                  <span>
                    <dt className="inline">{t("kullaniciOdemeKodu")}: </dt>
                    <dd className="inline font-mono font-semibold">{teshis.odeme_kodu}</dd>
                  </span>
                )}
              </dl>
              {/* Cihaz YOKKEN "mobil bildirim acik" YANILTICIDIR: tercih
                  acik olsa da bildirim gitmez. Sebep acikca yazilir. */}
              {teshis.bildirim_mobil && (teshis.mobil_cihaz_sayisi ?? 0) === 0 && (
                <p style={{ fontSize: "var(--yz-fs-xs)", color: "var(--yz-text-2)" }}>
                  {t("kullaniciTanilamaCihazYok")}
                </p>
              )}
            </div>
          )}
        </form>
      </Modal>

      {/* (P193 §7) ODEME KODLARI LISTESI */}
      <Modal
        acik={kodAcik}
        onKapat={() => setKodAcik(false)}
        baslik={t("kullaniciOdemeKodlari")}
        genislikSinifi="max-w-2xl"
        eylemler={
          <Dugme tur="sessiz" onClick={() => setKodAcik(false)}>
            {t("ortakKapat")}
          </Dugme>
        }
      >
        <div className="space-y-2">
          <p style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text-2)" }}>
            {t("kullaniciOdemeKodlariAciklama")}
          </p>
          {kodHata && (
            <p role="alert" style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}>
              {kodHata}
            </p>
          )}
          {kodlar && (
            <ul className="space-y-1">
              {kodlar.items.map((k) => (
                <li
                  key={k.user_id}
                  className="flex flex-wrap items-center gap-2"
                  style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-text)" }}
                >
                  <span className="font-mono font-semibold">{k.odeme_kodu}</span>
                  <span style={{ color: "var(--yz-text-2)" }}>
                    {k.daire_no ?? "—"} · {k.ad}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </Modal>
      {diyalog}
    </div>
  );
}
