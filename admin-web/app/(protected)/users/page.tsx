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
  Girinti,
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
import { ParolaAlani } from "@/components/ParolaAlani";
import { alanliHataMetni, apiSend } from "@/lib/client";
import type { UnitList } from "@/lib/types";
import { jsonFetcher } from "@/lib/fetcher";
import { TelefonAlani } from "@/components/TelefonAlani";
import { useT } from "@/lib/i18n/kullan";
import { ROLE_OPTIONS as ROLES, rolAdi } from "@/lib/roles";
import { telefonNormalle } from "@/lib/telefon";
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
  password: string;
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
  password: "",
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
  const { data: daireListesi } = useSWR<UnitList>(
    "/api/units?limit=200&offset=0",
    jsonFetcher,
    { revalidateOnFocus: false },
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
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

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
      password: "",
      gorevBaslangic: u.gorev_baslangic ?? "",
      gorevBitis: u.gorev_bitis ?? "",
    });
    setFormErr(null);
    setOpen(true);
    try {
      const d = await jsonFetcher<UserDetail>(`/api/users/${u.id}`);
      setForm((f) => ({
        ...f,
        telefon: d.telefon ?? "",
        aranabilir: d.aranabilir ?? false,
      }));
    } catch {
      // Detay cekilemezse form yine acik kalir (telefon bos); kaydetmeye engel yok.
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormErr(null);
    try {
      if (editingId) {
        // PATCH: parola yalniz doluysa gonderilir (bossa degismez).
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
        if (form.password) body.password = form.password;
        await apiSend(`/api/users/${editingId}`, "PATCH", body);
      } else {
        // (P185 §3/§4) E-POSTA ZORUNLU (dogrulama/bildirim kanali). TELEFON
        // istege bagli (yalniz iletisim, giris anahtari DEGIL). Parola bossa
        // backend TEK SEFERLIK gecici kod uretir (temp_code).
        if (!form.email.trim()) {
          setFormErr(t("kullaniciEpostaZorunluHata"));
          setSaving(false);
          return;
        }
        const body: Record<string, unknown> = {
          ad: form.ad,
          // (P185 NOT) Telefon şimdilik ZORUNLU kalıyor: backend'de global
          // benzersiz anahtardı; opsiyonele çevirmek bir göç işi (dagitim'de
          // belirtildi). Etiketi "giriş anahtarı"ndan arındırıldı (§5).
          telefon: telefonNormalle(form.telefon),
          aranabilir: form.aranabilir,
          role: form.role,
          email: form.email.trim(),
        };
        if (form.gorevBaslangic) body.gorev_baslangic = form.gorevBaslangic;
        if (form.gorevBitis) body.gorev_bitis = form.gorevBitis;
        if (form.password) body.password = form.password;
        const created = await apiSend<{ temp_code?: string | null; id?: string }>(
          "/api/users",
          "POST",
          body,
        );
        if (created?.temp_code) {
          window.alert(t("kullaniciGeciciKod", { kod: created.temp_code }));
        }
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
      await apiSend(`/api/users/${u.id}`, "DELETE");
      mutate();
      toast.success(t("kullaniciSilindi"));
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
          {/* (P162 §6 · P185 §4) DAIRE ATAMASI — YENI SAKIN VE YENI YONETICIDE.
              Daire ROLE BAGLI DEGIL (yonetici de sakin olabilir); form yalniz
              gosterme kararini rolden verir. SAKINDE ZORUNLU (sakin bir dairede
              oturur), yoneticide istege bagli. Duzenlemede gosterilmiyor:
              mevcut daire Daireler ekranindan yonetiliyor. */}
          {!editingId && DAIRE_ROLLERI.includes(form.role) && (
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
                >
                  <option value="">{t("kullaniciDaireYok")}</option>
                  {(daireListesi?.items ?? []).map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.blok ? `${u.blok}/${u.no}` : u.no}
                    </option>
                  ))}
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

          {/* (P185 §3/§4) E-POSTA ZORUNLU: dogrulama + bildirim kanali (giris
              anahtari DEGIL ama artik zorunlu). */}
          <AlanSarmal
            etiket={t("kullaniciEposta")}
            ipucu={t("kullaniciEpostaIpucu")}
            zorunlu
          >
            {(b) => (
              <Alan
                {...b}
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                required
              />
            )}
          </AlanSarmal>

          {/* (P185 §3) TELEFON YALNIZ ILETISIM — "giris anahtari" DEGIL.
              (Simdilik zorunlu; opsiyonele cevirmek backend goc isi.) */}
          <TelefonAlani
            etiket={t("kullaniciTelefon")}
            ipucu={t("kullaniciTelefonIpucu")}
            zorunlu
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

          <AlanSarmal
            etiket={editingId ? t("kullaniciYeniParola") : t("kullaniciParolaOpsiyonel")}
            ipucu={editingId ? t("kullaniciEnAz8") : t("kullaniciParolaBosYeni")}
          >
            {(b) => (
              // `ParolaAlani` ORTAK ILKEL ve `style` KABUL ETMIYOR
              // (bilincli: gorunumu cagirandan almiyor). Yeni yuzeye
              // uydurmak icin GIRINTILI kapsayiciya konuyor; girdi
              // saydam kaliyor. Bilesenin kendisine dokunulmadi —
              // alti sayfa daha onu kullaniyor.
              <Girinti className="flex items-center px-1">
                <ParolaAlani
                  {...b}
                  className="h-11 w-full bg-transparent px-2 outline-none"
                    value={form.password}
                  onChange={(v) => setForm({ ...form, password: v })}
                  minLength={8}
                  placeholder={
                    editingId
                      ? t("kullaniciParolaBosDuzenle")
                      : t("kullaniciParolaBosKisa")
                  }
                />
              </Girinti>
            )}
          </AlanSarmal>

          {formErr && (
            <p
              role="alert"
              className="sm:col-span-2"
              style={{ fontSize: "var(--yz-fs-sm)", color: "var(--yz-danger-ink)" }}
            >
              {formErr}
            </p>
          )}
        </form>
      </Modal>
      {diyalog}
    </div>
  );
}
