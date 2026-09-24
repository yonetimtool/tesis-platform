"""(P247 §6) TESIS-ICI NESNE SAHIPLIGI (IDOR) TARAMASI — kalici.

===========================================================================
NEDEN
===========================================================================
E2E 2026-09 turu TESISLER ARASI sizintiyi olctu (0 bulgu; RLS kapatiyor).
Tesis ICI sahiplik hic olculmemisti: ayni tesiste ayni rolden IKI kisi
varken B, A'nin kaydina id ile ulasabiliyor mu? RLS burada YARDIM ETMEZ —
iki kisi de ayni tenant'tadir; kural her ucun GOVDESINDE yazilidir ve her
uc onu kendisi hatirlamak zorundadir.

P247 §6 olcumu uc gercek kacak buldu (hepsi rol kapisindan gecip kayit
kapsamini unutan uclar):
  * `/ekler` — sakin B, sakin A'nin talebine yazilan notlari; guvenlik
    gorevlisi baskasina atanmis gorevin notlarini; amir ekibi DISINDAKI
    kisilerin (sakin dahil) kisi notlarini okuyup yazabiliyordu.
  * `/tasks/{id}` yazma + adim uclari — amir tesis gorevlisine atanmis
    gorevi okuyup degistirebiliyor, adim ekleyip silebiliyordu (P231 §3
    atama kurali yalniz YENI atamayi daraltiyordu).
  * `/cameras` — izleyici rollere `stream_kullanici` duz donuyordu.

===========================================================================
YAPI — YENI SATIR KENDILIGINDEN OLCULUR
===========================================================================
`tests/yetki/uc-guvenlik.tsv` kilidinde `sahiplik` sutunu `kendi`, `atama`
ya da `hedef` olan HER satir burada bir VAKA'ya (ya da gerekceli bir
ISTISNA'ya) sahip olmak ZORUNDADIR (`test_HER_SAHIPLIK_BEYANININ_VAKASI_VAR`).
Yeni bir kisi-kapsamli uc eklenip beyan edildiginde bu test kirmizi olur ve
vakasi yazilmadan gecmez; beyan `rol`e cevrilirse artik vaka da kirmizi
olur (beyan ile olcum ayrisamaz).

Her vaka `Deneme` listesi dondurur:
  red  -> 403 ya da 404 beklenir (404 tercih: varlik sizmaz)
  izin -> sahibi/hedefi ULASIR (401/403/404 degil) — kontrol deneyi:
          reddin "id yanlis" yuzunden gelmedigini kanitlar.
"""
from __future__ import annotations

import datetime as dt
import itertools
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import pytest

KILIT = Path(__file__).resolve().parent / "yetki" / "uc-guvenlik.tsv"
BEYANLI = {"kendi", "atama", "hedef"}
PW = "IdorPass1!"

#: Olculemeyen/anlamsiz satirlar — GEREKCE ZORUNLU.
ISTISNALAR: dict[tuple[str, str], str] = {
    ("DELETE", "/auth/oauth/baglantilarim/{saglayici}"): (
        "yol parametresi kayit kimligi DEGIL saglayici adidir; satir token "
        "kullanicisindan secilir, baskasinin kaydina isaret edilemez"
    ),
}


# --------------------------------------------------------------------------- #
# Kilit
# --------------------------------------------------------------------------- #
def _beyanlar() -> dict[tuple[str, str], str]:
    out = {}
    for satir in KILIT.read_text(encoding="utf-8").splitlines():
        if not satir.strip() or satir.startswith("#") or satir.startswith("metot\t"):
            continue
        p = satir.split("\t")
        out[(p[0], p[1])] = p[4]
    return out


# --------------------------------------------------------------------------- #
# Dunya: ayni tesiste her rolden IKI kisi
# --------------------------------------------------------------------------- #
@dataclass
class Deneme:
    aktor: str
    yol: str
    beklenen: str  # "red" | "izin"
    govde: dict | None = None
    baslik: dict = field(default_factory=dict)


class Dunya:
    def __init__(self, client, world, owner_conn):
        from app.security import hash_password

        self.c = client
        self.w = world
        self.conn = owner_conn
        self.tid = world["a"]
        self._onbellek: dict[str, object] = {}
        ek = uuid.uuid4().hex[:8]
        h = hash_password(PW)
        with owner_conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
                (self.tid, world["resident_a"]["email"]),
            )
            self.uid = {"sakin_a": cur.fetchone()[0]}
            for anahtar, kaynak in (("guard_a", "guard_a"), ("gorevli_a", "gorevli_a"),
                                    ("amir", "amir_a"), ("yonetici", "yonetici_a")):
                cur.execute(
                    "SELECT id FROM app_user WHERE tenant_id=%s AND email=%s",
                    (self.tid, world[kaynak]["email"]),
                )
                self.uid[anahtar] = cur.fetchone()[0]
            self.eposta = {}
            for anahtar, rol in (("sakin_b", "resident"), ("guard_b", "security"),
                                 ("gorevli_b", "tesis_gorevlisi")):
                e = f"idor-{anahtar}-{ek}@ornek.com"
                cur.execute(
                    "INSERT INTO app_user (tenant_id, ad, email, password_hash, "
                    "password_set, role) VALUES (%s,%s,%s,%s,true,%s::user_role) "
                    "RETURNING id",
                    (self.tid, f"Idor {anahtar}", e, h, rol),
                )
                self.uid[anahtar] = cur.fetchone()[0]
                self.eposta[anahtar] = e
            self.unit = {}
            for anahtar in ("a", "b"):
                cur.execute(
                    "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,'I') "
                    "RETURNING id",
                    (self.tid, f"I-{anahtar}-{ek}"),
                )
                self.unit[anahtar] = cur.fetchone()[0]
            cur.execute(
                "INSERT INTO unit_resident (tenant_id, unit_id, user_id) "
                "VALUES (%s,%s,%s),(%s,%s,%s)",
                (self.tid, self.unit["a"], self.uid["sakin_a"],
                 self.tid, self.unit["b"], self.uid["sakin_b"]),
            )
        self._hdr: dict[str, dict] = {}
        self._rez_sayac = itertools.count()

    # --- kimlik -------------------------------------------------------------
    def h(self, aktor: str) -> dict:
        if aktor not in self._hdr:
            kaynak = {"sakin_a": "resident_a", "guard_a": "guard_a",
                      "gorevli_a": "gorevli_a", "amir": "amir_a",
                      "yonetici": "yonetici_a"}.get(aktor)
            if kaynak:
                email, pw = self.w[kaynak]["email"], self.w[kaynak]["password"]
            else:
                email, pw = self.eposta[aktor], PW
            r = self.c.post("/auth/login", json={
                "tenant_slug": self.w["slug_a"], "email": email, "password": pw})
            assert r.status_code == 200, (aktor, r.text)
            self._hdr[aktor] = {"Authorization": f"Bearer {r.json()['access_token']}"}
        return self._hdr[aktor]

    def istek(self, metot: str, aktor: str, yol: str, govde=None, baslik=None):
        kw = {"headers": {**self.h(aktor), **(baslik or {})}}
        if govde is not None or metot in ("POST", "PATCH", "PUT"):
            kw["json"] = govde if govde is not None else {}
        return self.c.request(metot, yol, **kw)

    def olustur(self, aktor: str, yol: str, govde: dict) -> dict:
        r = self.istek("POST", aktor, yol, govde)
        assert r.status_code in (200, 201), (yol, r.status_code, r.text)
        return r.json()

    def tek(self, ad: str, uret: Callable[[], object]):
        """Bozmayan (salt okuma/red) denemelerde paylasilan nesne."""
        if ad not in self._onbellek:
            self._onbellek[ad] = uret()
        return self._onbellek[ad]

    # --- nesneler -----------------------------------------------------------
    def gorev(self, atanan: str) -> str:
        return self.olustur("yonetici", "/tasks", {
            "ad": f"idor {uuid.uuid4().hex[:6]}", "atanan_user_id": str(self.uid[atanan])})["id"]

    def adim(self, task_id: str) -> str:
        return self.olustur("yonetici", f"/tasks/{task_id}/adimlar", {"ad": "adim"})["id"]

    def gorev_s(self) -> str:
        return self.tek("gorev_s", lambda: self.gorev("guard_a"))

    def gorev_g(self) -> str:
        return self.tek("gorev_g", lambda: self.gorev("gorevli_a"))

    def adim_s(self) -> str:
        return self.tek("adim_s", lambda: self.adim(self.gorev_s()))

    def adim_g(self) -> str:
        return self.tek("adim_g", lambda: self.adim(self.gorev_g()))

    def sikayet(self, aktor: str = "sakin_a") -> str:
        return self.olustur(aktor, "/complaints", {"baslik": "idor", "mesaj": "x"})["id"]

    def panik(self) -> str:
        return self.tek("panik", lambda: self.olustur("sakin_a", "/panik", {"tip": "sakin"})["id"])

    def rezervasyon(self) -> str:
        alan = self.tek("alan", lambda: self.olustur("yonetici", "/common-areas", {
            "ad": f"Alan {uuid.uuid4().hex[:6]}", "acilis": "00:00",
            "kapanis": "23:59", "slot_dakika": 60})["id"])
        # Zaman kurallari (24 saat, gunde bir) bu testin konusu DEGIL —
        # satir dogrudan yazilir, yalniz SAHIPLIK olculur.
        with self.conn.cursor() as cur:
            cur.execute(
                "INSERT INTO rezervasyon (tenant_id, alan_id, unit_id, "
                "talep_eden_user_id, tarih, baslangic, bitis, kisi_sayisi) "
                "VALUES (%s,%s,%s,%s,%s,'10:00','11:00',1) RETURNING id",
                (self.tid, alan, self.unit["a"], self.uid["sakin_a"],
                 dt.date.today() + dt.timedelta(days=5 + next(self._rez_sayac))),
            )
            return str(cur.fetchone()[0])

    def bildirim(self) -> str:
        with self.conn.cursor() as cur:
            cur.execute(
                "INSERT INTO notification (tenant_id, tip, mesaj, user_id) "
                "VALUES (%s,'kargo','idor',%s) RETURNING id",
                (self.tid, self.uid["sakin_a"]),
            )
            return str(cur.fetchone()[0])

    def cihaz(self) -> str:
        def _uret():
            kopru = self.olustur("yonetici", "/akilli-ev/koprular", {
                "ad": f"K {uuid.uuid4().hex[:6]}", "tur": "home_assistant",
                "host": "10.0.0.9"})["id"]
            return self.olustur("yonetici", "/akilli-ev/cihazlar", {
                "kopru_id": kopru, "ad": "Lamba", "tip": "isik",
                "dis_kimlik": f"light.{uuid.uuid4().hex[:6]}",
                "unit_id": str(self.unit["a"])})["id"]
        return self.tek("cihaz", _uret)

    def fcm(self) -> tuple[str, str]:
        tok = f"idor-{uuid.uuid4().hex}"
        j = self.olustur("sakin_a", "/devices", {"fcm_token": tok, "platform": "android"})
        return tok, j["id"]


# --------------------------------------------------------------------------- #
# Vakalar
# --------------------------------------------------------------------------- #
VAKALAR: dict[tuple[str, str], Callable[[Dunya], list[Deneme]]] = {}


def vaka(*anahtarlar: tuple[str, str]):
    def kaydet(fn):
        for a in anahtarlar:
            assert a not in VAKALAR, a
            VAKALAR[a] = fn
        return fn
    return kaydet


# ---- gorevler (atama) ------------------------------------------------------ #
@vaka(("GET", "/tasks/{task_id}"), ("GET", "/tasks/{task_id}/adimlar"),
      ("GET", "/tasks/{task_id}/completions"))
def _gorev_oku(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s, g = d.gorev_s(), d.gorev_g()
    t = lambda tid: yol.replace("{task_id}", tid)  # noqa: E731
    return [
        Deneme("guard_b", t(s), "red"), Deneme("gorevli_a", t(s), "red"),
        Deneme("gorevli_b", t(g), "red"), Deneme("amir", t(g), "red"),
        Deneme("guard_a", t(s), "izin"), Deneme("amir", t(s), "izin"),
    ]


@vaka(("PATCH", "/tasks/{task_id}"))
def _gorev_duzenle(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    return [Deneme("amir", f"/tasks/{d.gorev_g()}", "red", {"aciklama": "x"}),
            Deneme("amir", f"/tasks/{d.gorev_s()}", "izin", {"aciklama": "x"})]


@vaka(("DELETE", "/tasks/{task_id}"))
def _gorev_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    return [Deneme("amir", f"/tasks/{d.gorev_g()}", "red"),
            Deneme("amir", f"/tasks/{d.gorev('guard_a')}", "izin")]


@vaka(("POST", "/tasks/{task_id}/adimlar"))
def _adim_ekle(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    return [Deneme("amir", f"/tasks/{d.gorev_g()}/adimlar", "red", {"ad": "x"}),
            Deneme("amir", f"/tasks/{d.gorev_s()}/adimlar", "izin", {"ad": "x"})]


@vaka(("PATCH", "/tasks/{task_id}/adimlar/{step_id}"))
def _adim_duzenle(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    return [
        Deneme("amir", f"/tasks/{d.gorev_g()}/adimlar/{d.adim_g()}", "red", {"ad": "x"}),
        Deneme("amir", f"/tasks/{d.gorev_s()}/adimlar/{d.adim_s()}", "izin", {"ad": "x"}),
    ]


@vaka(("DELETE", "/tasks/{task_id}/adimlar/{step_id}"))
def _adim_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s = d.gorev_s()
    return [Deneme("amir", f"/tasks/{d.gorev_g()}/adimlar/{d.adim_g()}", "red"),
            Deneme("amir", f"/tasks/{s}/adimlar/{d.adim(s)}", "izin")]


@vaka(("POST", "/tasks/{task_id}/adimlar/{step_id}/geri-al"))
def _adim_geri_al(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    return [
        Deneme("amir", f"/tasks/{d.gorev_g()}/adimlar/{d.adim_g()}/geri-al", "red"),
        Deneme("amir", f"/tasks/{d.gorev_s()}/adimlar/{d.adim_s()}/geri-al", "izin"),
    ]


@vaka(("POST", "/tasks/{task_id}/adimlar/{step_id}/tamamla"))
def _adim_tamamla(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s = d.gorev_s()
    a = d.adim(s)
    return [Deneme("guard_b", f"/tasks/{s}/adimlar/{a}/tamamla", "red", {}),
            Deneme("gorevli_a", f"/tasks/{s}/adimlar/{a}/tamamla", "red", {}),
            Deneme("guard_a", f"/tasks/{s}/adimlar/{a}/tamamla", "izin", {})]


@vaka(("POST", "/tasks/{task_id}/basla"))
def _gorev_basla(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s = d.gorev("guard_a")
    return [Deneme("guard_b", f"/tasks/{s}/basla", "red"),
            Deneme("gorevli_a", f"/tasks/{s}/basla", "red"),
            Deneme("guard_a", f"/tasks/{s}/basla", "izin")]


@vaka(("POST", "/tasks/{task_id}/completions"))
def _gorev_tamamla(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s = d.gorev("guard_a")
    govde = {"tamamlanma_zamani": dt.datetime.now(dt.timezone.utc).isoformat()}
    ik = lambda: {"Idempotency-Key": uuid.uuid4().hex}  # noqa: E731
    return [Deneme("guard_b", f"/tasks/{s}/completions", "red", govde, ik()),
            Deneme("gorevli_a", f"/tasks/{s}/completions", "red", govde, ik()),
            Deneme("guard_a", f"/tasks/{s}/completions", "izin", govde, ik())]


# ---- talepler / rezervasyon / sikayet (kendi) ------------------------------ #
@vaka(("GET", "/complaints/{complaint_id}"))
def _talep_oku(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    c = d.tek("talep_a", lambda: d.sikayet("sakin_a"))
    cg = d.tek("talep_g", lambda: d.sikayet("guard_a"))
    return [Deneme("sakin_b", f"/complaints/{c}", "red"),
            Deneme("guard_b", f"/complaints/{cg}", "red"),
            Deneme("gorevli_a", f"/complaints/{cg}", "red"),
            Deneme("amir", f"/complaints/{c}", "red"),
            Deneme("sakin_a", f"/complaints/{c}", "izin")]


@vaka(("POST", "/complaints/{complaint_id}/withdraw"))
def _talep_geri_cek(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    c = d.sikayet("sakin_a")
    return [Deneme("sakin_b", f"/complaints/{c}/withdraw", "red"),
            Deneme("sakin_a", f"/complaints/{c}/withdraw", "izin")]


@vaka(("GET", "/reservations/{reservation_id}"))
def _rez_oku(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    r = d.tek("rez", d.rezervasyon)
    return [Deneme("sakin_b", f"/reservations/{r}", "red"),
            Deneme("sakin_a", f"/reservations/{r}", "izin")]


@vaka(("POST", "/reservations/{reservation_id}/cancel"))
def _rez_iptal(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    r = d.rezervasyon()
    return [Deneme("sakin_b", f"/reservations/{r}/cancel", "red"),
            Deneme("sakin_a", f"/reservations/{r}/cancel", "izin")]


@vaka(("POST", "/unit-complaints/{complaint_id}/withdraw"))
def _daire_sikayet_geri(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    s = d.olustur("sakin_a", "/unit-complaints", {
        "target_unit_id": str(d.unit["b"]), "kategori": "gurultu"})["id"]
    return [Deneme("sakin_b", f"/unit-complaints/{s}/withdraw", "red"),
            Deneme("sakin_a", f"/unit-complaints/{s}/withdraw", "izin")]


@vaka(("POST", "/akilli-ev/cihazlar/{cihaz_id}/komut"))
def _cihaz_komut(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    c = d.cihaz()
    g = {"eylem": "ac"}
    # Sahibin komutu bolum kapaliysa 409 doner — "izin" 401/403/404 DISI
    # demektir, yani kapi gecildi.
    return [Deneme("sakin_b", f"/akilli-ev/cihazlar/{c}/komut", "red", g),
            Deneme("guard_a", f"/akilli-ev/cihazlar/{c}/komut", "red", g),
            Deneme("gorevli_a", f"/akilli-ev/cihazlar/{c}/komut", "red", g),
            Deneme("sakin_a", f"/akilli-ev/cihazlar/{c}/komut", "izin", g)]


@vaka(("DELETE", "/vardiya-izin/{izin_id}"))
def _izin_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    gun = (dt.date.today() + dt.timedelta(days=20)).isoformat()
    i = d.olustur("guard_a", "/vardiya-izin", {
        "user_id": str(d.uid["guard_a"]), "tur": "yillik",
        "baslangic": gun, "bitis": gun})["id"]
    return [Deneme("guard_b", f"/vardiya-izin/{i}", "red"),
            Deneme("gorevli_a", f"/vardiya-izin/{i}", "red"),
            Deneme("guard_a", f"/vardiya-izin/{i}", "izin")]


@vaka(("PATCH", "/unit-access-request/{request_id}"))
def _erisim_karar(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    t = d.olustur("yonetici", "/unit-access-request", {"unit_id": str(d.unit["a"])})["id"]
    return [Deneme("sakin_b", f"/unit-access-request/{t}", "red", {"durum": "onaylandi"}),
            Deneme("sakin_a", f"/unit-access-request/{t}", "izin", {"durum": "reddedildi"})]


@vaka(("DELETE", "/ekler/{ek_id}"))
def _ek_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    def ek(aktor, task_id):
        return d.olustur(aktor, "/ekler", {"varlik_tipi": "task", "varlik_id": task_id,
                                          "tur": "not", "metin": "idor"})["id"]
    return [Deneme("amir", f"/ekler/{ek('yonetici', d.gorev_g())}", "red"),
            Deneme("amir", f"/ekler/{ek('yonetici', d.gorev_s())}", "izin")]


@vaka(("DELETE", "/devices/{fcm_token}"))
def _fcm_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    tok, _ = d.fcm()
    return [Deneme("sakin_b", f"/devices/{tok}", "red"),
            Deneme("sakin_a", f"/devices/{tok}", "izin")]


@vaka(("DELETE", "/me/cihazlar/{cihaz_id}"))
def _me_cihaz_sil(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    _, cid = d.fcm()
    return [Deneme("sakin_b", f"/me/cihazlar/{cid}", "red"),
            Deneme("sakin_a", f"/me/cihazlar/{cid}", "izin")]


# ---- hedefli kayitlar (hedef) --------------------------------------------- #
@vaka(("GET", "/kargo/{kargo_id}"), ("PATCH", "/kargo/{kargo_id}"))
def _kargo(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    k = d.olustur("guard_a", "/kargo", {"unit_id": str(d.unit["a"]), "firma": "Idor Kargo"})["id"]
    g = {"durum": "teslim_alindi"} if metot == "PATCH" else None
    return [Deneme("sakin_b", f"/kargo/{k}", "red", g),
            Deneme("sakin_a", f"/kargo/{k}", "izin", g)]


@vaka(("GET", "/visitors/{visitor_id}"))
def _ziyaretci(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    v = d.olustur("guard_a", "/visitors", {
        "unit_id": str(d.unit["a"]), "ziyaretci_ad": "Idor Z",
        "target_resident_user_id": str(d.uid["sakin_a"])})["id"]
    return [Deneme("sakin_b", f"/visitors/{v}", "red"),
            Deneme("sakin_a", f"/visitors/{v}", "izin")]


@vaka(("GET", "/panik/{alarm_id}"), ("POST", "/panik/{alarm_id}/gordum"),
      ("POST", "/panik/{alarm_id}/iptal"), ("POST", "/panik/{alarm_id}/kapat"),
      ("POST", "/panik/{alarm_id}/mudahale"))
def _panik(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    p = d.panik()
    son = yol.rsplit("/", 1)[-1]
    if son == "{alarm_id}":
        return [Deneme("sakin_b", f"/panik/{p}", "red"),
                Deneme("gorevli_a", f"/panik/{p}", "red"),
                Deneme("sakin_a", f"/panik/{p}", "izin")]
    govde = {"kapanis_notu": "idor"} if son == "kapat" else {}
    out = [Deneme("sakin_b", f"/panik/{p}/{son}", "red", govde)]
    if son == "iptal":
        out.append(Deneme("guard_b", f"/panik/{p}/iptal", "red", govde))
    return out


@vaka(("PATCH", "/notifications/{notification_id}"))
def _bildirim(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    n = d.bildirim()
    return [Deneme("sakin_b", f"/notifications/{n}", "red", {"okundu": True}),
            Deneme("guard_a", f"/notifications/{n}", "red", {"okundu": True}),
            Deneme("sakin_a", f"/notifications/{n}", "izin", {"okundu": True})]


@vaka(("POST", "/anketler/{anket_id}/oy"))
def _anket_oy(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    a = d.olustur("yonetici", "/anketler", {
        "baslik": "idor", "secenekler": [{"metin": "a"}, {"metin": "b"}],
        "hedef_roller": ["security"]})
    g = {"secenek_id": a["secenekler"][0]["id"]}
    return [Deneme("sakin_a", f"/anketler/{a['id']}/oy", "red", g),
            Deneme("gorevli_a", f"/anketler/{a['id']}/oy", "red", g),
            Deneme("guard_a", f"/anketler/{a['id']}/oy", "izin", g)]


@vaka(("GET", "/announcements/{announcement_id}"))
def _duyuru(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    a = d.olustur("yonetici", "/announcements", {
        "baslik": "idor", "govde": "x", "hedef_roller": ["security"]})["id"]
    return [Deneme("sakin_a", f"/announcements/{a}", "red"),
            Deneme("gorevli_a", f"/announcements/{a}", "red"),
            Deneme("guard_a", f"/announcements/{a}", "izin")]


@vaka(("GET", "/call-target/{user_id}"))
def _arama(d: Dunya, metot: str, yol: str) -> list[Deneme]:
    for k in ("guard_a", "sakin_a"):
        r = d.istek("PATCH", "yonetici", f"/users/{d.uid[k]}/contact", {"aranabilir": True})
        assert r.status_code == 200, r.text
    return [Deneme("sakin_b", f"/call-target/{d.uid['sakin_a']}", "red"),
            Deneme("guard_b", f"/call-target/{d.uid['guard_a']}", "red"),
            Deneme("sakin_b", f"/call-target/{d.uid['guard_a']}", "izin")]


# --------------------------------------------------------------------------- #
# Testler
# --------------------------------------------------------------------------- #
def test_HER_SAHIPLIK_BEYANININ_VAKASI_VAR():
    beyan = _beyanlar()
    kisi = {k for k, v in beyan.items() if v in BEYANLI}
    eksik = sorted(kisi - set(VAKALAR) - set(ISTISNALAR))
    assert not eksik, (
        f"`kendi/atama/hedef` beyanli ama IDOR vakasi olmayan uc(lar): {eksik} — "
        "test_p247_idor.py'ye vaka ekle (ya da gerekceli ISTISNA)"
    )
    bayat = sorted(k for k in set(VAKALAR) | set(ISTISNALAR) if beyan.get(k) not in BEYANLI)
    assert not bayat, (
        f"vakasi olan ama kilitte artik kisi-kapsamli OLMAYAN uc(lar): {bayat} — "
        "beyan degistiyse vaka da kaldirilmali (ya da beyan yanlis)"
    )


def test_IDOR_TARAMASI(client, world, owner_conn):
    d = Dunya(client, world, owner_conn)
    kusurlar = []
    olculen = 0
    goruldu: set = set()
    for (metot, yol), fn in VAKALAR.items():
        # Ayni fonksiyon birden cok satiri kapsayabilir; metot farkli ise
        # denemeler o metotla kosar.
        for dn in fn(d, metot, yol):
            anahtar = (metot, dn.aktor, dn.yol, dn.beklenen)
            if dn.beklenen == "izin" and anahtar in goruldu:
                continue
            goruldu.add(anahtar)
            r = d.istek(metot, dn.aktor, dn.yol, dn.govde, dn.baslik)
            olculen += 1
            if dn.beklenen == "red" and r.status_code not in (403, 404):
                kusurlar.append(f"IDOR {metot} {yol} aktor={dn.aktor} -> {r.status_code} {r.text[:120]}")
            if dn.beklenen == "izin" and (r.status_code in (401, 403, 404) or r.status_code >= 500):
                kusurlar.append(f"KONTROL {metot} {yol} aktor={dn.aktor} -> {r.status_code} {r.text[:120]}")
    assert olculen > 50, olculen
    assert not kusurlar, "\n".join(kusurlar)


def test_EKLER_UST_KAYIT_KAPSAMI(client, world, owner_conn):
    """`/ekler?varlik_tipi=&varlik_id=` — sorgu parametresindeki kimlik de
    IDOR'dur: rol kapisi yetmez, ust kaydi GOREBILMEK gerekir."""
    d = Dunya(client, world, owner_conn)
    talep = d.sikayet("sakin_a")
    talep_g = d.sikayet("guard_a")
    for tip, vid in (("complaint", talep), ("complaint", talep_g),
                     ("task", d.gorev_s()), ("task", d.gorev_g()),
                     ("app_user", str(d.uid["sakin_a"])),
                     ("app_user", str(d.uid["gorevli_a"]))):
        d.olustur("yonetici", "/ekler", {"varlik_tipi": tip, "varlik_id": vid,
                                        "tur": "not", "metin": "yonetim notu"})

    def oku(aktor, tip, vid):
        return d.c.get("/ekler", headers=d.h(aktor),
                       params={"varlik_tipi": tip, "varlik_id": vid}).status_code

    red = [("sakin_b", "complaint", talep), ("guard_b", "complaint", talep_g),
           ("amir", "complaint", talep), ("guard_b", "task", d.gorev_s()),
           ("gorevli_a", "task", d.gorev_s()), ("amir", "task", d.gorev_g()),
           ("amir", "app_user", str(d.uid["sakin_a"])),
           ("amir", "app_user", str(d.uid["gorevli_a"]))]
    kusur = [(a, t, oku(a, t, v)) for a, t, v in red if oku(a, t, v) not in (403, 404)]
    assert not kusur, f"ust kaydi goremeyen ekleri okuyor: {kusur}"
    for a, t, v in (("sakin_a", "complaint", talep), ("guard_a", "task", d.gorev_s()),
                    ("amir", "task", d.gorev_s()), ("amir", "app_user", str(d.uid["guard_a"]))):
        assert oku(a, t, v) == 200, (a, t)
    # Yazma da ayni kapsamdan gecer.
    r = d.istek("POST", "amir", "/ekler", {"varlik_tipi": "task", "varlik_id": d.gorev_g(),
                                          "tur": "not", "metin": "x"})
    assert r.status_code == 404, r.text
    r = d.istek("POST", "amir", "/ekler", {"varlik_tipi": "app_user",
                                          "varlik_id": str(d.uid["sakin_a"]),
                                          "tur": "not", "metin": "x"})
    assert r.status_code == 404, r.text


def test_AMIR_GOREV_LISTESI_EKIP_KAPSAMINDA(client, world, owner_conn):
    d = Dunya(client, world, owner_conn)
    s, g = d.gorev_s(), d.gorev_g()
    r = d.c.get("/tasks", headers=d.h("amir"), params={"limit": 200})
    assert r.status_code == 200, r.text
    ids = {t["id"] for t in r.json()["items"]}
    assert s in ids and g not in ids


def test_KAMERA_KIMLIGI_IZLEYICIYE_DONMEZ(client, world, owner_conn):
    d = Dunya(client, world, owner_conn)
    kam = d.olustur("yonetici", "/cameras", {
        "ad": f"Idor {uuid.uuid4().hex[:6]}", "stream_url": "rtsp://10.9.9.8/x",
        "tur": "rtsp", "sakin_gorebilir": True, "stream_kullanici": "kamkul",
        "stream_parola": "kamsir", "kayit_aktif": True, "kayit_saglayici": "hikvision",
        "kayit_adres": "http://10.9.9.7:80", "kayit_kullanici": "nvrkul",
        "kayit_parola": "nvrsir", "kayit_kanal": "1"})
    for aktor in ("sakin_a", "gorevli_a", "guard_a", "amir"):
        r = d.c.get("/cameras", headers=d.h(aktor), params={"limit": 200})
        assert r.status_code == 200, (aktor, r.text)
        k = next(x for x in r.json()["items"] if x["id"] == kam["id"])
        for alan in ("stream_kullanici", "kayit_kullanici", "kayit_adres"):
            assert not k.get(alan), (aktor, alan, k.get(alan))
        assert "kamsir" not in r.text and "nvrsir" not in r.text
    r = d.c.get("/cameras", headers=d.h("yonetici"), params={"limit": 200})
    k = next(x for x in r.json()["items"] if x["id"] == kam["id"])
    assert k["stream_kullanici"] == "kamkul" and k["kayit_kullanici"] == "nvrkul"
