package com.app.yonetiyor

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * (P249 §1c) FCM MESAJ SERVISI — SOS'u YEREL alarm olarak kurar.
 *
 * Eklentinin servisini (`FlutterFirebaseMessagingService`) GENISLETIR ve
 * manifest'te onun yerine kaydedilir (`tools:node="remove"`). Eklentinin
 * kendi isi (jeton yenileme, Flutter'a iletim) aynen surer: jeton
 * `onNewToken`da, mesajlar eklentinin alicisinda (`...Receiver`) islenir.
 *
 * NEDEN FLUTTER ARKA PLAN IZOLASYONUNDA DEGIL: o yol, bildirimi kurmak
 * icin once Flutter motorunu baslatmak zorunda. Motor acilisi saniyeler
 * surer ve bazi ureticilerin pil yoneticisi onu yarida oldurur. Alarm
 * gecikemez; burada motor BEKLENMEZ.
 *
 * Yalniz `yerel_alarm=1` tasiyan mesajlar islenir; oteki her mesaj eski
 * yoldan gider (sunucu onlara `notification` govdesi yollar).
 */
class SosMesajServisi : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        val veri = remoteMessage.data
        if (veri["yerel_alarm"] == "1") {
            AlarmBildirimi.goster(applicationContext, veri)
        }
    }
}
