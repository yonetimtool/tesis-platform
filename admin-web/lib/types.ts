// /contracts/openapi.yaml semalarinin TypeScript karsiliklari (panel icin gerekenler).

export type PatrolWindowDurum = "bekliyor" | "tamamlandi" | "kacirildi";
export type AlarmTip =
  | "kacirilan_tur"
  | "eksik_checkpoint"
  | "gecikmis_okutma";

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
  // Fiziksel yerlesim (bina semasi) — nullable; yerlesimi girilmemis daire
  // sonraki turdaki haritada "yerlesimsiz" kovaya duser.
  kat?: number | null;
  sira?: number | null;
  metrekare?: number | null;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}
export interface UnitList {
  meta: PageMeta;
  items: Unit[];
}

// Bina blogu (D-viz Rev-2 gorsel editor) — `GET/POST/PATCH/DELETE /blocks`.
// Etiket (`ad`) daire.blok ile zayif eslesir; `unit_sayisi` o etiketi tasiyan
// daire sayisi (silme guvenligi: >0 ise DELETE 409 doner).
export interface Block {
  id: string;
  ad: string;
  kat_sayisi?: number | null;
  unit_sayisi: number;
  created_at: string;
  updated_at?: string | null;
}
export interface BlockList {
  items: Block[];
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
// Talep/Ariza -> Is Emri (bkz. contracts/openapi.yaml Complaint semasi).
export type ComplaintDurum = "acik" | "is_emri" | "cozuldu" | "reddedildi";
export type ComplaintOncelik = "dusuk" | "orta" | "yuksek";

export interface ComplaintPhoto {
  id: string;
  foto_key: string;
  sira: number;
  // Goruntuleme icin kisa omurlu presigned GET URL.
  foto_url?: string | null;
}

// Durum gecis timeline'i satiri — user_id ASLA tutulmaz, YALNIZ actor_role.
export interface ComplaintStatusHistory {
  durum: string;
  actor_role: string;
  sebep?: string | null;
  created_at: string;
}

export interface Complaint {
  id: string;
  acan_user_id: string;
  acan_ad?: string | null;
  baslik: string;
  mesaj: string;
  // Talep kategorisi = yonetici-tanimli gorev kategorisi (task_category); null = belirtilmemis.
  kategori_id?: string | null;
  kategori_ad?: string | null;
  durum: ComplaintDurum;
  fotograflar: ComplaintPhoto[];
  gecmis: ComplaintStatusHistory[];
  // Bagli is emri (Task) — talep donusturulmusse dolu.
  is_emri_id?: string | null;
  is_emri_durum?: string | null;
  created_at: string;
  updated_at: string;
}

export interface ComplaintList {
  meta: PageMeta;
  items: Complaint[];
}

// POST /complaints/{id}/convert govdesi (admin + yonetici).
export interface ComplaintConvertRequest {
  kategori_id?: string | null;
  oncelik?: ComplaintOncelik;
  atanan_user_id: string;
  not?: string | null;
}

// POST /complaints/{id}/resolve govdesi (admin + yonetici).
export interface ComplaintResolveRequest {
  cozum_notu?: string | null;
}

// POST /complaints/{id}/decline govdesi (admin + yonetici) — sebep ZORUNLU.
export interface ComplaintDeclineRequest {
  sebep: string;
}

// -------------------------------- users ------------------------------------ #
export type UserRole = "admin" | "yonetici" | "security" | "tesis_gorevlisi" | "resident";

// password_hash ASLA gelmez (backend User semasinda yok).
// Liste ogesi — telefon YOK (KVKK: numaralar toplu listelenmez). aranabilir
// (riza bayragi) yonetim gorunurlugu icin doner.
export interface UserRow {
  id: string;
  ad: string;
  email: string;
  aranabilir?: boolean;
  role: string;
  is_active: boolean;
  created_at: string;
}

// Tek-kayit yonetim gorunumu (GET /users/{id}) — telefon + aranabilir burada.
export interface UserDetail extends UserRow {
  telefon?: string | null;
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
  kategori_id?: string | null;
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

export interface TaskCategory {
  id: string;
  ad: string;
  aktif: boolean;
  created_at: string;
  updated_at?: string | null;
}
export interface TaskCategoryList {
  meta: PageMeta;
  items: TaskCategory[];
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
  // false ise tesisi BIRINCIL yonetici ilk giriste adlandirir (mobil kapisi).
  kurulum_tamamlandi: boolean;
  // Tesis yonetim maili (tenant seviyesi) — yonetici iletisim kartinda gorunur.
  yonetim_email?: string | null;
}

// ------------------------ tenant olusturma (admin) ------------------------- #
/** `POST /tenants` govdesindeki tek yonetici satiri. Telefon = giris anahtari
 *  (global benzersiz). Parola bos ise backend tek seferlik gecici kod uretir. */
export type YoneticiCreate = { ad: string; phone: string; password?: string };

/** ILK yonetici BIRINCIL'dir (tesisi ilk giriste adlandirir). `ad` verilmezse
 *  backend yer tutucu ad + rastgele slug atar. */
export type TenantAdminCreate = {
  ad?: string;
  yonetim_email?: string;
  yoneticiler: YoneticiCreate[];
};

export type YoneticiCreatedOut = {
  user_id: string;
  ad: string;
  birincil: boolean;
  /** YALNIZ parolasiz acilan yonetici icin ve BIR KEZ doner. */
  temp_code: string | null;
};

export type TenantAdminCreatedOut = {
  tenant_id: string;
  yoneticiler: YoneticiCreatedOut[];
};

// --------------------------- integrations (C1b) ---------------------------- #
export type IntegrationChannel = "webhook" | "megaphone" | "smarthome";
export type HttpMethod = "GET" | "POST" | "PUT" | "PATCH";
export type AuthType = "none" | "bearer" | "api_key";

export interface Integration {
  id: string;
  ad: string;
  channel_type: IntegrationChannel;
  endpoint_url: string;
  http_method: HttpMethod;
  headers_json: Record<string, string>;
  auth_type: AuthType;
  auth_secret_set: boolean; // sir kendisi ASLA donmez (write-only)
  payload_template: string;
  aktif: boolean;
  created_at: string;
}
export interface IntegrationList {
  meta: PageMeta;
  items: Integration[];
}
export interface IntegrationPreset {
  key: string;
  channel_type: IntegrationChannel;
  http_method: HttpMethod;
  headers_json: Record<string, string>;
  payload_template: string;
}
export interface IntegrationTriggerResult {
  ok: boolean;
  status?: number | null;
  error?: string | null;
}

// ---------------- bina semasi / sikayet haritasi (D-viz-2) ---------------- #
// GET /unit-complaints/building-map — renk API'den gelir (yesil/sari/kirmizi =
// 0-2/3-4/5+); istemci ESIK HESAPLAMAZ.
export type DensityRenk = "yesil" | "sari" | "kirmizi";

export interface BuildingMapUnit {
  unit_id: string;
  unit_no: string;
  blok?: string | null;
  kat?: number | null;
  sira?: number | null;
  // ROL-FARKINDA (Rev-1): YALNIZ yonetim (shows_density) icin dolu; digerinde null.
  complaint_count?: number | null;
  color?: DensityRenk | null;
}
export interface BuildingMapKat {
  kat: number;
  units: BuildingMapUnit[];
}
export interface BuildingMapBlok {
  blok: string;
  katlar: BuildingMapKat[];
}
export interface BuildingMap {
  // ROL-FARKINDA: yonetimde true (sayim+renk dolu); digerinde false (yapi).
  shows_density: boolean;
  bloklar: BuildingMapBlok[];
  unplaced: BuildingMapUnit[];
}

// GET /unit-complaints?target_unit_id= — YALNIZ yonetim (Rev-1). complainant +
// notlar admin/yonetici icin dolu (denetim).
export interface UnitComplaint {
  id: string;
  target_unit_id: string;
  unit_no?: string | null;
  kategori: string;
  notlar?: string | null;
  durum: string;
  created_at: string;
  complainant_user_id?: string | null;
  complainant_ad?: string | null;
}
export interface UnitComplaintList {
  meta: PageMeta;
  items: UnitComplaint[];
}

// ------------------------------ denetim (audit) ---------------------------- #
export interface AuditLog {
  id: string;
  ts: string;
  tenant_id: string | null;
  actor_user_id: string | null;
  actor_rol: string | null;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  meta: Record<string, unknown>;
}

export interface AuditLogList {
  meta: { limit: number; offset: number; total: number };
  items: AuditLog[];
}

// --------------------------- şeffaflık panosu ------------------------------ #
export interface TransparencyKategori {
  ad: string;
  toplam_kurus: number;
  yuzde: number;
}

export interface TransparencyAidat {
  tahakkuk_kurus: number;
  tahsilat_kurus: number;
  tutar_orani_yuzde: number | null;
  toplam_daire: number;
  odeyen_daire: number;
  daire_orani_yuzde: number | null;
  geciken_daire_sayisi: number;
}

export interface TransparencyBoard {
  ay: string;
  yayinlandi: boolean;
  toplam_gelir_kurus: number;
  toplam_gider_kurus: number;
  net_kurus: number;
  gider_dagilimi: TransparencyKategori[];
  aidat: TransparencyAidat;
  onceki_ay_net_kurus: number | null;
}

export interface TransparencyAyOzet {
  ay: string;
  yayinlandi: boolean;
  net_kurus: number | null;
}

export interface TransparencyList {
  items: TransparencyAyOzet[];
}
