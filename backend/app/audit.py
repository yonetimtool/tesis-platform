"""KVKK denetim kaydi yardimcisi (WP1).

Kullanim (router icinde, tenant-baglamli `db` oturumu ile — AYNI transaction):
    from ..audit import audit_user, Action
    await audit_user(db, user, Action.RESIDENT_CREATE,
                     resource_type="app_user", resource_id=new_id)

Neden ayni-transaction dogrudan INSERT? (1) atomiklik — denetim satiri islem
COMMIT olursa yazilir, ROLLBACK olursa yazilmaz (yaniltici iz olmaz); (2) ucuz —
ekstra baglanti/round-trip yok; (3) app_rw INSERT hakki + set edilmis tenant
baglami sayesinde RLS WITH CHECK gecer. app_rw UPDATE/DELETE ALAMAZ (append-only,
setup_app_role.py REVOKE). Platform/sistem (tenant-siz) olaylar retention task'i
tarafindan owner ile yazilir (RLS bypass).

`meta`: YALNIZ id'ler ve alan ADLARI. ASLA kisisel veri DEGERI konmaz (ad, telefon,
e-posta, parola vb. degerleri denetim kaydina GIRMEZ).
"""
from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from .models import AppUser, AuditLog


class Action:
    """action serbest-metin degerleri (enum degil; merkezi sabitler)."""

    # --- kimlik / oturum ---
    LOGIN_OK = "login_ok"
    LOGIN_FAIL = "login_fail"
    PASSWORD_SET = "password_set"          # ilk giris kalici parola belirleme
    PASSWORD_CHANGE = "password_change"    # oturumlu parola degistirme
    PASSWORD_RESET = "password_reset"      # (P181) e-posta koduyla parola sifirlama
    TOKEN_REUSE = "token_reuse"            # refresh yeniden-kullanim (guvenlik)

    # --- kisisel veri kaynaklari (yazma) ---
    RESIDENT_CREATE = "resident_create"
    RESIDENT_UPDATE = "resident_update"
    RESIDENT_DELETE = "resident_delete"    # tam silme (ledger referansi yoksa)
    RESIDENT_ERASURE = "resident_erasure"  # anonimlestirme (ledger korunur)
    RESIDENT_RESET_PASSWORD = "resident_reset_password"
    #: (P112) Kullanicinin KENDI hesabini silmesi — App Store 5.1.1(v).
    #: `resident_delete`ten AYRI tutulur: "kim sildi" sorusunun cevabi
    #: farklidir (kullanicinin kendisi mi, yonetim mi) ve bu ayrim
    #: KVKK acisindan anlamlidir.
    ACCOUNT_SELF_DELETE = "account_self_delete"
    KAYIT_SELF = "kayit_self"
    KAYIT_ONAY = "kayit_onay"
    KAYIT_RED = "kayit_red"
    USER_CREATE = "user_create"
    USER_UPDATE = "user_update"
    USER_RESET_PASSWORD = "user_reset_password"
    USER_CONTACT_UPDATE = "user_contact_update"   # telefon/aranabilir (riza)
    # (P154 / Asama 5) Kullanici SILME. Sert silme; yumusak silme zaten
    # `is_active` ile yapiliyor ve iki dugmenin ayni isi yapmasi
    # kullaniciyi yaniltirdi.
    USER_DELETE = "user_delete"
    AVATAR_UPDATE = "avatar_update"               # profil fotografi (yukle/kaldir)
    # (P167 §1.7) "Guvenlik ve giris" ekranindan yapilan self-servis islemler.
    # Denetime YAZILIRLAR cunku ikisi de bir GUVENLIK olayidir: cihazin
    # kaldirilmasi bildirim akisini keser, tercih degisimi ise "bu bildirimi
    # neden almadim" sorusunun tek kanitidir.
    DEVICE_REMOVE = "device_remove"               # kendi cihazini pasiflestirdi
    NOTIFICATION_PREFS_UPDATE = "notification_prefs_update"
    # (P181 Bölüm 6.5) Bildirim YUMUŞAK silme (toplu). Denetime yazilir:
    # "bu bildirim neden kayboldu" sorusunun kaniti.
    NOTIFICATION_DELETE = "notification_delete"
    # (P167 Asama 2) Kisisel takvim notu. KISISEL bir kayit ama denetime
    # YAZILIR: "Kendi hesap etkinligim" ekrani (§1.7) kullaniciya kendi
    # yaptiklarinin listesini gosteriyor ve silinen bir hatirlatmanin
    # oradan da yok olmasi, kullaniciyi "ben mi sildim?" sorusuyla
    # birakirdi. Satir yalniz KIMLIK tutar, notun METNINI degil.
    HATIRLATMA_CREATE = "hatirlatma_create"
    HATIRLATMA_UPDATE = "hatirlatma_update"
    HATIRLATMA_DELETE = "hatirlatma_delete"
    SHIFT_ASSIGN = "shift_assign"                 # vardiya personel atamasi (tam-liste)
    CAMERA_CREATE = "camera_create"
    CAMERA_UPDATE = "camera_update"
    CAMERA_DELETE = "camera_delete"
    # (P213 §6) GECMIS KAYIT IZLEME — KVKK acisindan en agir kamera islemi.
    # Canli izleme anliktir; gecmis kayit GERIYE DONUK GOZETIMDIR. Kim,
    # hangi kamerayi, HANGI ZAMAN ARALIGI icin actigi yazilmazsa sonradan
    # hesabi sorulamaz. Denetim kaydini sonradan eklemek imkansiza yakin:
    # gecmise donuk uretilemez.
    CAMERA_KAYIT_ARAMA = "camera_kayit_arama"
    CAMERA_KAYIT_IZLEME = "camera_kayit_izleme"
    KARAR_UPSERT = "karar_upsert"
    KARAR_SIL = "karar_sil"
    DOKUMAN_EKLE = "dokuman_ekle"
    DOKUMAN_SIL = "dokuman_sil"
    SITE_AKTAR = "site_aktar"
    MESAJ_SABLON_UPSERT = "mesaj_sablon_upsert"
    MESAJ_SABLON_SIL = "mesaj_sablon_sil"
    MESAJ_GONDER = "mesaj_gonder"
    FINANS_HAREKET_CREATE = "finans_hareket_create"
    # (P192 §2.3) Harcama onay akisi. CREATE'ten AYRI bir eylem: "kim
    # girdi" ile "kim onayladi" ayni kayitta toplanirsa, onayi verenin
    # kim oldugu sorusu denetimde cevapsiz kalirdi.
    FINANS_HAREKET_ONAY = "finans_hareket_onay"
    FINANS_HAREKET_RED = "finans_hareket_red"
    ICRA_DOSYA_CREATE = "icra_dosya_create"
    ICRA_DOSYA_UPDATE = "icra_dosya_update"
    MUHASEBE_TANIM_CREATE = "muhasebe_tanim_create"
    MUHASEBE_TANIM_UPDATE = "muhasebe_tanim_update"
    MUHASEBE_TANIM_DELETE = "muhasebe_tanim_delete"
    MUHASEBE_AYAR_UPDATE = "muhasebe_ayar_update"
    #: (P202) Platform geneli ayar (surum politikasi). Tenant-disi bir
    #: kaydi denetime yazmak SART: zorunlu guncelleme TUM kullanicilari
    #: etkiler ve "bunu kim, ne zaman acti" sorusu yanitlanabilmeli.
    PLATFORM_AYAR_UPDATE = "platform_ayar_update"
    #: (P203 §2) Kullanici tesis DEGISTIRDI. Gecis parola sormaz (kimlik
    #: e-postadir); bu yuzden "kim, ne zaman, nereden nereye" sorusunun
    #: yanitlanabilir olmasi SART.
    TESIS_DEGISTIR = "tesis_degistir"
    #: (P203 §4.3) Vardiya plani degisikligi. Gun ici degisiklikler
    #: (hastalik/izin/acil) denetime YAZILMALI: kimin yerine kimin
    #: konuldugu, bir olay sonrasi sorulacak ILK sorudur.
    VARDIYA_PLAN_UPDATE = "vardiya_plan_update"
    #: (P203 §5) Fazla mesai GIDERE yazildi. Para ureten bir hesabin
    #: kimin tarafindan, hangi saat ve katsayiyla islendigi kayit
    #: altinda olmali — onay kuyruguna dusen tutar sonradan sorulur.
    MESAI_GIDERE_YAZ = "mesai_gidere_yaz"
    UNIT_TIP_CREATE = "unit_tip_create"
    UNIT_TIP_UPDATE = "unit_tip_update"
    UNIT_TIP_DELETE = "unit_tip_delete"
    UNIT_GRUP_CREATE = "unit_grup_create"
    UNIT_GRUP_UPDATE = "unit_grup_update"
    UNIT_GRUP_DELETE = "unit_grup_delete"
    RESIDENT_ASSIGN = "resident_assign"
    RESIDENT_UNASSIGN = "resident_unassign"
    VISITOR_CREATE = "visitor_create"
    VISITOR_UPDATE = "visitor_update"
    VISITOR_CHECKOUT = "visitor_checkout"         # ziyaretci cikis damgasi (G3)
    VEHICLE_PASS_CREATE = "vehicle_pass_create"   # arac girisi (G1)
    # --- ANPR (P16) ---
    # Olay ALIMI audit'e YAZILMAZ: `anpr_event` tablosunun kendisi bir
    # defterdir ve saniyede onlarca olay gelebilir — audit_log'u bogardi.
    # Yalniz INSAN kararlari ve ANAHTAR yasam donusu yazilir.
    ANPR_ONAY = "anpr_onay"                       # dusuk guvenli okuma karari
    ANPR_KEY_CREATE = "anpr_key_create"
    ANPR_KEY_REVOKE = "anpr_key_revoke"
    VEHICLE_PASS_CHECKOUT = "vehicle_pass_checkout"
    VIOLATION_CREATE = "violation_create"         # ihlal kaydi (G2)
    VIOLATION_UPDATE = "violation_update"         # ihlal durum gecisi
    KARGO_CREATE = "kargo_create"
    KARGO_RECEIVE = "kargo_receive"
    KARGO_PHOTO_VIEW = "kargo_photo_view"         # foto presign-GET (ifsa)
    UNIT_ACCESS_REQUEST = "unit_access_request"
    UNIT_ACCESS_DECIDE = "unit_access_decide"
    COMPLAINT_CREATE = "complaint_create"
    GUVENLIK_MODU = "guvenlik_modu"
    UYARI_MANUEL = "uyari_manuel"
    PORTAL_YAYIN = "portal_yayin"
    ANKET_OLUSTUR = "anket_olustur"
    KVKK_YAYIN = "kvkk_yayin"
    KVKK_ONAY = "kvkk_onay"
    PAZARLAMA_RIZA = "pazarlama_riza"
    COMPLAINT_UPDATE = "complaint_update"
    COMPLAINT_CONVERT = "complaint_convert"
    COMPLAINT_RESOLVE = "complaint_resolve"
    COMPLAINT_DECLINE = "complaint_decline"
    COMPLAINT_WITHDRAW = "complaint_withdraw"
    UNIT_COMPLAINT_FILE = "unit_complaint_file"
    UNIT_COMPLAINT_CLOSE = "unit_complaint_close"
    UNIT_COMPLAINT_WITHDRAW = "unit_complaint_withdraw"
    DUES_ASSESSMENT_CREATE = "dues_assessment_create"
    DUES_PAYMENT_RECORD = "dues_payment_record"
    BLOCK_CREATE = "block_create"
    BLOCK_UPDATE = "block_update"
    BLOCK_DELETE = "block_delete"
    UNIT_CREATE = "unit_create"
    UNIT_UPDATE = "unit_update"
    UNIT_DELETE = "unit_delete"

    # --- KVKK-kritik: telefon ifsasi + arama ---
    PHONE_REVEAL = "phone_reveal"
    CALL_INITIATE = "call_initiate"

    # --- seffaflik panosu (yayin kontrolu) ---
    TRANSPARENCY_PUBLISH = "transparency_publish"
    TRANSPARENCY_UNPUBLISH = "transparency_unpublish"

    # --- sistem ---
    EXPORT = "export"
    ERASURE_RUN = "erasure_run"            # retention/imha calismasi (sayilar)


async def record_audit(
    session: AsyncSession,
    *,
    action: str,
    tenant_id: uuid.UUID | str | None = None,
    actor_user_id: uuid.UUID | str | None = None,
    actor_rol: str | None = None,
    resource_type: str | None = None,
    resource_id: uuid.UUID | str | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Denetim satirini AYNI transaction'a ekler (commit ile yazilir)."""
    session.add(
        AuditLog(
            tenant_id=tenant_id,
            actor_user_id=actor_user_id,
            actor_rol=actor_rol,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id) if resource_id is not None else None,
            meta=meta or {},
        )
    )


async def audit_user(
    session: AsyncSession,
    user: AppUser,
    action: str,
    *,
    resource_type: str | None = None,
    resource_id: uuid.UUID | str | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Kimlikli aktorden denetim — tenant_id/actor_user_id/actor_rol otomatik."""
    await record_audit(
        session,
        action=action,
        tenant_id=user.tenant_id,
        actor_user_id=user.id,
        actor_rol=user.role,
        resource_type=resource_type,
        resource_id=resource_id,
        meta=meta,
    )
