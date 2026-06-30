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
