package com.app.yonetiyor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/**
 * (P249 §1c) SOS ALARM BILDIRIMI — uygulamanin KENDISI kurar.
 *
 * ==========================================================================
 * NEDEN SISTEMIN CIZDIGI BILDIRIM YETMEDI
 * ==========================================================================
 * `notification` govdeli FCM mesajini uygulama kapaliyken isletim sistemi
 * cizer. O bildirim:
 *   * tam ekran ACAMAZ (kilit ekraninda yalniz bir satir),
 *   * sesi DONGUYE alamaz (bir kez calar, cebindeki telefonu duymayan
 *     kisi alarmi kacirir),
 *   * "Gordum"/"Guvendeyim" denince SUSMAZ.
 * Sunucu yeni surumlere SOS'u data-only gonderir (`yerel_alarm=1`);
 * `SosMesajServisi` bu nesneyi cagirir.
 *
 * ==========================================================================
 * SESSIZ MOD VE RAHATSIZ ETMEYIN — NE MUMKUN, NE DEGIL
 * ==========================================================================
 * * Kanalin ses turu `USAGE_ALARM` + bildirim kategorisi `ALARM`: Android
 *   alarm sesini ZIL MODUNDAN BAGIMSIZ calar (sessiz/titresimde de) ve
 *   Rahatsiz Etmeyin'in VARSAYILAN ayari ("alarmlara izin ver") onu
 *   gecirir.
 * * KULLANICI alarm ses seviyesini sifira cektiyse ya da Rahatsiz
 *   Etmeyin'de "alarmlar"i da kapattiysa CALMAZ. Bunu asan bir API
 *   yok — ve olmamali.
 * * `setBypassDnd(true)` ancak uygulamaya "Rahatsiz Etmeyin erisimi"
 *   verildiyse etkilidir; verilmediyse sistem sessizce yok sayar. Uygulama
 *   ayarlar ekraninda bunu gosterir ve kullaniciyi sisteme yonlendirir.
 * * TAM EKRAN (Android 14+): `USE_FULL_SCREEN_INTENT` yalniz arama ve
 *   alarm uygulamalarina otomatik verilir; digerlerinde kullanici
 *   ayarlardan acmalidir. Izin yoksa bildirim YINE gelir, yalniz tam
 *   ekran yerine ust bildirim olarak.
 */
object AlarmBildirimi {
    // SUNUCUYLA AYNI (backend/app/push_kanal.py:KANAL_ALARM).
    const val KANAL_ALARM = "yonetio_alarm_v1"

    /** Acilis niyetinde alarm kimligini tasiyan ek. */
    const val EK_PANIK_ID = "sos_panik_id"

    /** Tum SOS bildirimleri ayni kimlik + FARKLI etiketle: etiket alarm
     *  basina (`acil:<panik_id>`) — ayni alarmin tekrar duyurusu eskisinin
     *  YERINI alir, iki ayri alarm iki ayri bildirim olur. */
    const val BILDIRIM_ID = 7249

    fun kanalKur(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return
        val ses = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val ozellik = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val kanal = NotificationChannel(
            KANAL_ALARM,
            context.getString(R.string.kanal_alarm_ad),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.kanal_alarm_aciklama)
            setSound(ses, ozellik)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            // Yalniz Rahatsiz Etmeyin erisimi verilmisse etkili (ust not).
            setBypassDnd(true)
        }
        mgr.createNotificationChannel(kanal)
    }

    /** FCM `data` alanlarindan alarm bildirimini kurar ve gosterir. */
    fun goster(context: Context, veri: Map<String, String>) {
        kanalKur(context)
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return
        val panikId = veri["panik_id"] ?: ""
        val etiket = veri["etiket"] ?: "acil:$panikId"
        val baslik = veri["baslik"] ?: ""
        val govde = veri["govde"] ?: ""

        val acilis = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EK_PANIK_ID, panikId)
        }
        val pi = PendingIntent.getActivity(
            context,
            etiket.hashCode(),
            acilis,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, KANAL_ALARM)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_MAX)
        }
        b.setSmallIcon(R.drawable.ic_stat_yonetio)
            .setContentTitle(baslik)
            .setContentText(govde)
            // Uzun talimat kesilmesin: bildirim acildiginda TAMAMI okunur.
            .setStyle(Notification.BigTextStyle().bigText(govde))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(pi)
            .setFullScreenIntent(pi, true)
            .setAutoCancel(true)
            .setShowWhen(true)
        val bildirim = b.build()
        // DONGULU SES: kullanici bildirime dokunana, onu kaldirana ya da
        // uygulamada "Gordum"/"Guvendeyim" diyene kadar calar
        // (`MainActivity` -> `sustur`).
        bildirim.flags = bildirim.flags or Notification.FLAG_INSISTENT
        mgr.notify(etiket, BILDIRIM_ID, bildirim)
    }

    /** "Gordum"/"Guvendeyim" -> alarmi sustur (bildirimi kaldir). */
    fun sustur(context: Context, panikId: String) {
        val mgr = context.getSystemService(NotificationManager::class.java) ?: return
        mgr.cancel("acil:$panikId", BILDIRIM_ID)
    }
}
