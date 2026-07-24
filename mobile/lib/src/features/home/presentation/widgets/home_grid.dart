/// Ana ekran izgara sutun sayisi — referans 4'lu dizilim; cok dar ekranda
/// (<=360dp) 2'ye duser (kompakt kart bile sigmayacagi icin).
int homeGridCols(double maxWidth) => maxWidth <= 360 ? 2 : 4;

/// Sutuna gore hucre orani: 4 sutunda kartlar dikey-dikdortgen. 0.72 dar
/// hucrelerde (dense ModuleCard: chip+baslik+sayac) tasma verdigi icin 0.6'ya
/// dusuruldu (brief WP-A: tasma cikarsa oran kucultulebilir).
double homeGridAspect(int cols) => cols == 4 ? 0.6 : 1.15;
