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
  donem?: string | null; // 'YYYY-MM'; serbest odemede null olabilir
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

// ---------------------------- announcements -------------------------------- #
export interface Announcement {
  id: string;
  baslik: string;
  govde: string;
  foto_key?: string | null;
  // Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
  foto_url?: string | null;
  olusturan_user_id: string;
  olusturan_ad?: string | null;
  created_at: string;
  updated_at: string;
}

// `POST /uploads/presign` yaniti — foto yukleme bileti.
export interface PresignTicket {
  foto_key: string;
  upload_url: string;
  method: string;
  expires_in: number;
}

export interface AnnouncementList {
  meta: PageMeta;
  items: Announcement[];
}

// ----------------------------- complaints ---------------------------------- #
export type ComplaintDurum = "acik" | "inceleniyor" | "cozuldu";

export interface Complaint {
  id: string;
  acan_user_id: string;
  acan_ad?: string | null;
  baslik: string;
  mesaj: string;
  foto_key?: string | null;
  // Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
  foto_url?: string | null;
  durum: ComplaintDurum;
  yonetici_yaniti?: string | null;
  yanitlayan_user_id?: string | null;
  yanit_zamani?: string | null;
  created_at: string;
  updated_at: string;
}

export interface ComplaintList {
  meta: PageMeta;
  items: Complaint[];
}

// -------------------------------- users ------------------------------------ #
export type UserRole = "admin" | "yonetici" | "security" | "tesis_gorevlisi" | "resident";

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

// ------------------------------- assets ------------------------------------ #
export type AssetKategori = "ekipman" | "arac" | "alet" | "diger";
export type AssetDurum = "musait" | "zimmetli" | "bakimda";

export interface Asset {
  id: string;
  ad: string;
  kategori?: string | null;
  nfc_tag_uid?: string | null;
  durum: string;
  aciklama?: string | null;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}
export interface AssetList {
  meta: PageMeta;
  items: Asset[];
}

export interface AssetCheckout {
  id: string;
  asset_id: string;
  alan_user_id: string;
  alma_zamani: string;
  birakma_zamani?: string | null;
  notlar?: string | null;
  created_at: string;
}
export interface AssetCheckoutList {
  meta: PageMeta;
  items: AssetCheckout[];
}

// --------------------------- patrol windows (gecmis) ----------------------- #
export interface PatrolWindowRow {
  id: string;
  patrol_plan_id: string;
  plan_adi?: string | null;
  pencere_baslangic: string;
  pencere_bitis: string;
  durum: string;
  okutulan_checkpoint_sayisi: number;
  beklenen_checkpoint_sayisi: number;
}
export interface PatrolWindowOzet {
  toplam: number;
  tamamlandi: number;
  kacirildi: number;
  bekliyor: number;
}
export interface PatrolWindowListResponse {
  meta: PageMeta;
  ozet: PatrolWindowOzet;
  items: PatrolWindowRow[];
}

// -------------------------------- tasks ------------------------------------ #
export type TaskTip = "temizlik" | "kontrol" | "ilaclama" | "bakim" | "peyzaj" | "diger";

export interface Task {
  id: string;
  tip: string;
  ad: string;
  aciklama?: string | null;
  atanan_user_id?: string | null;
  checkpoint_id?: string | null;
  periyot_dakika?: number | null;
  sonraki_planlanan?: string | null;
  foto_zorunlu: boolean;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}
export interface TaskList {
  meta: PageMeta;
  items: Task[];
}

export interface TaskCompletion {
  id: string;
  task_id: string;
  tamamlayan_user_id: string;
  tamamlanma_zamani: string;
  nfc_tag_uid?: string | null;
  foto_key?: string | null;
  foto_url?: string | null;
  notlar?: string | null;
  created_at: string;
}
export interface TaskCompletionList {
  meta: PageMeta;
  items: TaskCompletion[];
}

// ------------------------------ emergency ---------------------------------- #
export type EmergencyDurum = "acik" | "cozuldu";

export interface EmergencyAlert {
  id: string;
  tetikleyen_user_id: string;
  tetiklenme_zamani: string;
  gps_lat?: number | null;
  gps_lng?: number | null;
  durum: string;
  cozen_user_id?: string | null;
  cozulme_zamani?: string | null;
  notlar?: string | null;
  created_at: string;
}
export interface EmergencyList {
  meta: PageMeta;
  items: EmergencyAlert[];
}

// --------------------- task completions (gecmis) --------------------------- #
export interface TaskCompletionRow {
  id: string;
  task_id: string;
  task_adi?: string | null;
  tip: string;
  tamamlayan_user_id: string;
  tamamlanma_zamani: string;
  foto_var: boolean;
  nfc_dogrulandi: boolean;
  notlar?: string | null;
}
export interface TaskCompletionOzet {
  toplam: number;
  temizlik: number;
  kontrol: number;
  ilaclama: number;
  peyzaj: number;
}
export interface TaskCompletionHistoryResponse {
  meta: PageMeta;
  ozet: TaskCompletionOzet;
  items: TaskCompletionRow[];
}

// --------------------------- tenant settings ------------------------------- #
export interface TenantSettings {
  tenant_id: string;
  ad: string;
  slug: string;
  timezone: string;
  acil_durum_telefon?: string | null;
}
