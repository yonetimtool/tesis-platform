// /contracts/openapi.yaml semalarinin TypeScript karsiliklari (panel icin gerekenler).

export type PatrolWindowDurum = "bekliyor" | "tamamlandi" | "kacirildi";
export type AlarmTip =
  | "kacirilan_tur"
  | "eksik_checkpoint"
  | "gecikmis_okutma"
  | "acil_durum";

export interface AktifTur {
  patrol_window_id: string;
  patrol_plan_id: string;
  patrol_plan_ad?: string | null;
  pencere_baslangic: string;
  pencere_bitis: string;
  durum: PatrolWindowDurum;
  beklenen_checkpoint_sayisi?: number | null;
  okutulan_checkpoint_sayisi?: number | null;
}

export interface Alarm {
  tip: AlarmTip;
  olusma_zamani: string;
  mesaj: string;
  patrol_window_id?: string | null;
  checkpoint_id?: string | null;
}

export interface DashboardLive {
  generated_at: string;
  aktif_turlar: AktifTur[];
  son_alarmlar: Alarm[];
}

export interface AppNotification {
  id: string;
  tip: string;
  patrol_window_id?: string | null;
  patrol_plan_id?: string | null;
  checkpoint_id?: string | null;
  task_id?: string | null;
  mesaj: string;
  okundu: boolean;
  created_at: string;
}

export interface PageMeta {
  limit: number;
  offset: number;
  total: number;
}

export interface NotificationList {
  meta: PageMeta;
  items: AppNotification[];
}

// Sozlesme hata zarfi: { error: { code, message } }
export interface ApiError {
  error: { code: string; message: string };
}

// ------------------------------- shift ------------------------------------- #
export type GunTipi = "her_gun" | "hafta_ici" | "hafta_sonu" | "resmi_tatil";

export interface Shift {
  id: string;
  ad: string;
  baslangic_saat: string; // "HH:MM"
  bitis_saat: string;
  gun_tipi: string;
  created_at: string;
  updated_at?: string | null;
}

export interface ShiftList {
  meta: PageMeta;
  items: Shift[];
}

// ----------------------------- checkpoint ---------------------------------- #
export interface Checkpoint {
  id: string;
  ad: string;
  nfc_tag_uid: string;
  gps_lat?: number | null;
  gps_lng?: number | null;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}

export interface CheckpointList {
  meta: PageMeta;
  items: Checkpoint[];
}

// ----------------------------- patrol plan --------------------------------- #
export interface PatrolPlan {
  id: string;
  ad: string;
  shift_id?: string | null;
  baslangic_saat: string;
  bitis_saat: string;
  periyot_dakika: number;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}

export interface PatrolPlanList {
  meta: PageMeta;
  items: PatrolPlan[];
}

export interface PatrolPlanCheckpoint {
  checkpoint_id: string;
  sira: number;
  checkpoint?: Checkpoint | null;
}

export interface PatrolPlanDetail extends PatrolPlan {
  checkpoints?: PatrolPlanCheckpoint[];
}

// -------------------------------- aidat ------------------------------------ #
export type ResidentRol = "malik" | "kiraci";
export type DuesYontem = "elden" | "havale" | "kart" | "diger";
export type DuesDurum = "basarili" | "bekliyor" | "iptal";

export interface Unit {
  id: string;
  no: string;
  blok?: string | null;
  metrekare?: number | null;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}
export interface UnitList {
  meta: PageMeta;
  items: Unit[];
}

export interface UnitResident {
  id: string;
  unit_id: string;
  user_id: string;
  rol_tipi?: string | null;
  baslangic?: string | null;
  bitis?: string | null;
  created_at: string;
}

export interface DuesAssessment {
  id: string;
  unit_id: string;
  donem: string;
  tutar_kurus: number;
  son_odeme_tarihi?: string | null;
  aciklama?: string | null;
  created_at: string;
}
export interface DuesAssessmentList {
  meta: PageMeta;
  items: DuesAssessment[];
}
export interface DuesAssessmentResult {
  created: DuesAssessment[];
  atlanan: number;
}

export interface DuesPayment {
  id: string;
  unit_id: string;
  assessment_id?: string | null;
  tutar_kurus: number;
  odeme_zamani: string;
  yontem: string;
  durum: string;
  makbuz_no?: string | null;
  provider?: string | null;
  provider_ref?: string | null;
  kaydeden_user_id: string;
  idempotency_key: string;
  created_at: string;
}
export interface DuesPaymentList {
  meta: PageMeta;
  items: DuesPayment[];
}

export interface UnitDuesStatus {
  unit_id: string;
  no: string;
  toplam_tahakkuk_kurus: number;
  toplam_odenen_kurus: number;
  bakiye_kurus: number;
  assessments?: DuesAssessment[];
  payments?: DuesPayment[];
}

// -------------------------------- users ------------------------------------ #
export type UserRole = "admin" | "security" | "cleaning" | "resident";

// password_hash ASLA gelmez (backend User semasinda yok).
export interface UserRow {
  id: string;
  ad: string;
  email: string;
  telefon?: string | null;
  role: string;
  is_active: boolean;
  created_at: string;
}

export interface UserListResponse {
  meta: PageMeta;
  items: UserRow[];
}
