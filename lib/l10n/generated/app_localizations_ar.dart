// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get brand => 'مشغل IPTV';

  @override
  String get home => 'الرئيسية';

  @override
  String get favorites => 'المفضلة';

  @override
  String get live => 'البث المباشر';

  @override
  String get movies => 'أفلام';

  @override
  String get series => 'مسلسلات';

  @override
  String get search => 'بحث';

  @override
  String get settings => 'الإعدادات';

  @override
  String get accessibility => 'إمكانية الوصول';

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String get play => 'تشغيل';

  @override
  String get myList => 'قائمتي';

  @override
  String get noSynopsis => 'لا يوجد ملخص متاح.';

  @override
  String get noEpisodes => 'لا توجد حلقات متاحة لهذا المسلسل.';

  @override
  String get addToMyList => 'أضف إلى قائمتي';

  @override
  String get removeFromMyList => 'إزالة من قائمتي';

  @override
  String get favoritesEmptyHint => 'العناصر التي تضيفها إلى قائمتي ستظهر هنا.';

  @override
  String get moreInfo => 'المزيد';

  @override
  String get back => 'رجوع';

  @override
  String get synopsis => 'القصة';

  @override
  String get episodes => 'الحلقات';

  @override
  String get language => 'اللغة';

  @override
  String get highContrast => 'تباين عالٍ';

  @override
  String get reduceMotion => 'تقليل الحركة';

  @override
  String get colorblindSafe => 'ألوان مناسبة لعمى الألوان';

  @override
  String get highLegibilityFont => 'خط سهل القراءة';

  @override
  String get textSize => 'حجم النص';

  @override
  String get sizeDefault => 'افتراضي';

  @override
  String get sizeLarge => 'كبير';

  @override
  String get sizeLarger => 'أكبر';

  @override
  String get captionsLabel => 'الترجمة';

  @override
  String get captionSize => 'حجم الترجمة';

  @override
  String get captionSizeSmall => 'صغير';

  @override
  String get captionSizeMedium => 'متوسط';

  @override
  String get captionBackground => 'الخلفية';

  @override
  String get bgNone => 'بلا';

  @override
  String get bgLight => 'خفيفة';

  @override
  String get bgSolid => 'صلبة';

  @override
  String get captionColor => 'اللون';

  @override
  String get colorWhite => 'أبيض';

  @override
  String get colorYellow => 'أصفر';

  @override
  String get colorCyan => 'سماوي';

  @override
  String get complianceNote =>
      'مشغل IPTV لا يستضيف أي محتوى. تأتي جميع القنوات والوسائط من قوائم التشغيل التي توفّرها.';

  @override
  String get getStarted => 'ابدأ';

  @override
  String get tagline => 'قوائم تشغيلك. محتواك. منظّم بشكل جميل.';

  @override
  String get addPlaylist => 'إضافة قائمة';

  @override
  String get serverUrl => 'رابط الخادم';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get playlistName => 'اسم قائمة التشغيل';

  @override
  String get m3uUrl => 'رابط قائمة التشغيل';

  @override
  String get importAction => 'استيراد';

  @override
  String get tabUpload => 'رفع';

  @override
  String get noResults => 'لا نتائج';

  @override
  String get resultsLabel => 'نتيجة';

  @override
  String get channels => 'قناة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get playbackFailedNetwork =>
      'تعذّر الوصول إلى البث. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get playbackFailedUnavailable => 'لم يعد هذا البث متاحًا لدى المزوّد.';

  @override
  String get playbackFailedRefused =>
      'رفض المزوّد هذا البث. قد لا يشمله اشتراكك، أو أن عدد الأجهزة المتصلة كبير.';

  @override
  String get playbackFailedTimeout => 'لم يستجب البث في الوقت المحدد.';

  @override
  String get playbackFailedUnknown => 'تعذّر تشغيل هذا البث.';

  @override
  String get cast => 'طاقم التمثيل';

  @override
  String get director => 'المخرج';

  @override
  String get genre => 'النوع';

  @override
  String get country => 'البلد';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get recentlyViewed => 'شوهد مؤخرًا';

  @override
  String get allCategory => 'الكل';

  @override
  String get otherCategory => 'أخرى';

  @override
  String get noChannels => 'لا توجد قنوات';

  @override
  String get noContentYet => 'لا يوجد محتوى بعد';

  @override
  String get setUpPlaylist => 'إعداد قائمة تشغيل';

  @override
  String get noItemsFound => 'لا توجد عناصر';

  @override
  String get jumpToLetter => 'الانتقال إلى حرف';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String seasonNumber(int number) {
    return 'الموسم $number';
  }

  @override
  String playEpisode(int number, String title) {
    return 'تشغيل الحلقة $number: $title';
  }

  @override
  String playSeasonEpisode(int season, int episode) {
    return 'تشغيل م$seasonح$episode';
  }

  @override
  String resumeSeasonEpisode(int season, int episode) {
    return 'متابعة م$seasonح$episode';
  }

  @override
  String get skipBackward => 'إرجاع ١٠ ثوانٍ';

  @override
  String get skipForward => 'تقديم ١٠ ثوانٍ';

  @override
  String get audioTrack => 'المسار الصوتي';

  @override
  String get logs => 'السجلات';

  @override
  String get troubleshooting => 'استكشاف الأخطاء';

  @override
  String get viewLogs => 'عرض السجلات';

  @override
  String get importErrorRefused =>
      'تعذّر الوصول إلى الخادم. إذا كان العنوان يبدأ بـ https:// فجرّب http:// — كثير من المزوّدين لا يدعمون HTTPS.';

  @override
  String get importErrorDns => 'تعذّر العثور على هذا الخادم. تحقق من العنوان.';

  @override
  String get importErrorTimeout =>
      'استغرق الخادم وقتًا طويلاً للرد. تحقق من اتصالك وحاول مجددًا.';

  @override
  String get importErrorCredentials =>
      'رفض الخادم اسم المستخدم أو كلمة المرور.';

  @override
  String get importErrorUnknown => 'تعذّر استيراد قائمة التشغيل.';

  @override
  String get importErrorDetails => 'التفاصيل في الإعدادات ← عرض السجلات.';
}
