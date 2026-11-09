import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_profile.dart';

// ============================================================
// ভাষার তালিকা
// নতুন ভাষা যোগ করতে: এখানে একটা লাইন, আর নিচে _xx ম্যাপ বানিয়ে _strings এ বসান
// ============================================================

class AppLanguage {
  final String code;
  final String nativeName;
  final bool rtl;

  const AppLanguage(this.code, this.nativeName, {this.rtl = false});

  static const List<AppLanguage> all = [
    AppLanguage('en', 'English'),
    AppLanguage('bn', 'বাংলা'),
    AppLanguage('hi', 'हिन्दी'),
    AppLanguage('ur', 'اردو', rtl: true),
    AppLanguage('ar', 'العربية', rtl: true),
    AppLanguage('id', 'Bahasa Indonesia'),
    AppLanguage('ne', 'नेपाली'),
  ];

  static bool isSupported(String code) => all.any((l) => l.code == code);

  static AppLanguage byCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => all.first);
}

// ============================================================
// ভাষা সেভ ও বদলানো
// ============================================================

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();
  static const String _prefKey = 'palok_language';

  String _code = 'en';

  String get code => _code;
  Locale get locale => Locale(_code);
  AppLanguage get current => AppLanguage.byCode(_code);

  /// অ্যাপ চালুর সময় একবার ডাকতে হবে (main.dart এ করা আছে)
  Future<void> load() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_prefKey);
    } catch (_) {}

    if (saved != null && AppLanguage.isSupported(saved)) {
      _code = saved;
      return;
    }

    // আগে কখনো বাছা না হলে ফোনের ভাষা, সমর্থিত না হলে English
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _code = AppLanguage.isSupported(device) ? device : 'en';
  }

  Future<void> setLanguage(String code) async {
    if (!AppLanguage.isSupported(code) || code == _code) return;

    _code = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }
}

/// স্ক্রিনের ভেতরে ভাষা বদলালে সাথে সাথে নতুন করে আঁকার জন্য
class LanguageBuilder extends StatelessWidget {
  final WidgetBuilder builder;

  const LanguageBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, _) => builder(context),
    );
  }
}

/// অনুবাদ আনার ফাংশন। উদাহরণ: tr('logout') বা tr('reset_body', {'email': x})
String tr(String key, [Map<String, String>? params]) {
  final code = LanguageController.instance.code;
  var text = _find(code, key) ?? _find('en', key) ?? key;

  if (params != null) {
    params.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
  }
  return text;
}

String? _find(String code, String key) {
  return _strings[code]?[key] ?? profileStrings[code]?[key];
}

// ============================================================
// অনুবাদ
// ============================================================

const Map<String, Map<String, String>> _strings = {
  'en': _en,
  'bn': _bn,
  'hi': _hi,
  'ur': _ur,
  'ar': _ar,
  'id': _id,
  'ne': _ne,
};

const Map<String, String> _en = {
  'settings_title': 'Settings and privacy',
  'section_account': 'Account',
  'section_activity': 'Activity',
  'section_language': 'Language',
  'section_help': 'Support',
  'section_login': 'Login',
  'edit_profile': 'Edit profile',
  'email': 'Email',
  'no_email': 'No email',
  'change_password': 'Change password',
  'activity_center': 'Activity center',
  'about_palok': 'About PALOK',
  'about_body': 'PALOK is a short video sharing platform.',
  'logout': 'Log out',
  'logout_confirm': 'Do you want to log out?',
  'logout_failed': 'Could not log out.',
  'delete_account': 'Delete account',
  'yes': 'Yes',
  'no': 'No',
  'cancel': 'Cancel',
  'confirm': 'Confirm',
  'send': 'Send',
  'enter_password': 'Enter your password',
  'current_password_hint': 'Your current password',
  'no_email_on_account': 'This account has no email.',
  'reset_body': 'A password reset link will be sent to {email}.',
  'reset_sent': 'Reset link sent. Check your email (including spam).',
  'reset_failed': 'Could not send: {error}',
  'reset_failed_generic': 'Could not send.',
  'delete_title': 'Delete account?',
  'delete_body':
      'Your profile, videos, follows and notifications will be permanently deleted. This cannot be undone.',
  'delete_confirm_btn': 'Delete',
  'wrong_password': 'Wrong password. Try again.',
  'relogin_required': 'For security, log out, log in again, and retry.',
  'delete_failed': 'Could not delete account: {error}',
  'delete_failed_generic':
      'Could not delete account. Check your internet connection and try again.',
  'choose_language': 'Choose language',
};

const Map<String, String> _bn = {
  'settings_title': 'সেটিংস এবং গোপনীয়তা',
  'section_account': 'অ্যাকাউন্ট',
  'section_activity': 'কার্যকলাপ',
  'section_language': 'ভাষা',
  'section_help': 'সহায়তা',
  'section_login': 'লগইন',
  'edit_profile': 'প্রোফাইল এডিট করুন',
  'email': 'ইমেইল',
  'no_email': 'ইমেইল নেই',
  'change_password': 'পাসওয়ার্ড বদলান',
  'activity_center': 'কার্যকলাপ কেন্দ্র',
  'about_palok': 'PALOK সম্পর্কে',
  'about_body': 'PALOK একটি ছোট ভিডিও শেয়ারিং প্ল্যাটফর্ম।',
  'logout': 'লগ আউট',
  'logout_confirm': 'আপনি কি লগ আউট করতে চান?',
  'logout_failed': 'লগ আউট করা যায়নি।',
  'delete_account': 'অ্যাকাউন্ট মুছুন',
  'yes': 'হ্যাঁ',
  'no': 'না',
  'cancel': 'বাতিল',
  'confirm': 'নিশ্চিত করুন',
  'send': 'পাঠান',
  'enter_password': 'পাসওয়ার্ড দিন',
  'current_password_hint': 'আপনার বর্তমান পাসওয়ার্ড',
  'no_email_on_account': 'এই অ্যাকাউন্টে ইমেইল নেই।',
  'reset_body': '{email} ঠিকানায় পাসওয়ার্ড রিসেটের লিংক পাঠানো হবে।',
  'reset_sent': 'রিসেট লিংক পাঠানো হয়েছে। ইমেইল (স্প্যামসহ) দেখুন।',
  'reset_failed': 'পাঠানো যায়নি: {error}',
  'reset_failed_generic': 'পাঠানো যায়নি।',
  'delete_title': 'অ্যাকাউন্ট মুছবেন?',
  'delete_body':
      'আপনার প্রোফাইল, ভিডিও, ফলো ও নোটিফিকেশন স্থায়ীভাবে মুছে যাবে। এটা আর ফেরানো যাবে না।',
  'delete_confirm_btn': 'মুছে ফেলুন',
  'wrong_password': 'পাসওয়ার্ড ভুল। আবার চেষ্টা করুন।',
  'relogin_required':
      'নিরাপত্তার জন্য লগ আউট করে আবার লগ ইন করে চেষ্টা করুন।',
  'delete_failed': 'অ্যাকাউন্ট মোছা যায়নি: {error}',
  'delete_failed_generic':
      'অ্যাকাউন্ট মোছা যায়নি। ইন্টারনেট পরীক্ষা করে আবার চেষ্টা করুন।',
  'choose_language': 'ভাষা বাছাই করুন',
};

const Map<String, String> _hi = {
  'settings_title': 'सेटिंग्स और गोपनीयता',
  'section_account': 'खाता',
  'section_activity': 'गतिविधि',
  'section_language': 'भाषा',
  'section_help': 'सहायता',
  'section_login': 'लॉगिन',
  'edit_profile': 'प्रोफ़ाइल संपादित करें',
  'email': 'ईमेल',
  'no_email': 'कोई ईमेल नहीं',
  'change_password': 'पासवर्ड बदलें',
  'activity_center': 'गतिविधि केंद्र',
  'about_palok': 'PALOK के बारे में',
  'about_body': 'PALOK एक शॉर्ट वीडियो शेयरिंग प्लेटफ़ॉर्म है।',
  'logout': 'लॉग आउट',
  'logout_confirm': 'क्या आप लॉग आउट करना चाहते हैं?',
  'logout_failed': 'लॉग आउट नहीं हो सका।',
  'delete_account': 'खाता हटाएं',
  'yes': 'हाँ',
  'no': 'नहीं',
  'cancel': 'रद्द करें',
  'confirm': 'पुष्टि करें',
  'send': 'भेजें',
  'enter_password': 'अपना पासवर्ड दर्ज करें',
  'current_password_hint': 'आपका वर्तमान पासवर्ड',
  'no_email_on_account': 'इस खाते में कोई ईमेल नहीं है।',
  'reset_body': '{email} पर पासवर्ड रीसेट लिंक भेजा जाएगा।',
  'reset_sent': 'रीसेट लिंक भेज दिया गया है। अपना ईमेल (स्पैम सहित) देखें।',
  'reset_failed': 'भेजा नहीं जा सका: {error}',
  'reset_failed_generic': 'भेजा नहीं जा सका।',
  'delete_title': 'खाता हटाएं?',
  'delete_body':
      'आपकी प्रोफ़ाइल, वीडियो, फ़ॉलो और सूचनाएं स्थायी रूप से हटा दी जाएंगी। इसे वापस नहीं किया जा सकता।',
  'delete_confirm_btn': 'हटाएं',
  'wrong_password': 'गलत पासवर्ड। फिर से कोशिश करें।',
  'relogin_required':
      'सुरक्षा के लिए लॉग आउट करें, फिर से लॉग इन करें और दोबारा कोशिश करें।',
  'delete_failed': 'खाता हटाया नहीं जा सका: {error}',
  'delete_failed_generic':
      'खाता हटाया नहीं जा सका। इंटरनेट जांचें और फिर से कोशिश करें।',
  'choose_language': 'भाषा चुनें',
};

const Map<String, String> _ur = {
  'settings_title': 'ترتیبات اور رازداری',
  'section_account': 'اکاؤنٹ',
  'section_activity': 'سرگرمی',
  'section_language': 'زبان',
  'section_help': 'مدد',
  'section_login': 'لاگ ان',
  'edit_profile': 'پروفائل میں ترمیم کریں',
  'email': 'ای میل',
  'no_email': 'کوئی ای میل نہیں',
  'change_password': 'پاس ورڈ تبدیل کریں',
  'activity_center': 'سرگرمی مرکز',
  'about_palok': 'PALOK کے بارے میں',
  'about_body': 'PALOK ایک مختصر ویڈیو شیئرنگ پلیٹ فارم ہے۔',
  'logout': 'لاگ آؤٹ',
  'logout_confirm': 'کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟',
  'logout_failed': 'لاگ آؤٹ نہیں ہو سکا۔',
  'delete_account': 'اکاؤنٹ حذف کریں',
  'yes': 'ہاں',
  'no': 'نہیں',
  'cancel': 'منسوخ کریں',
  'confirm': 'تصدیق کریں',
  'send': 'بھیجیں',
  'enter_password': 'اپنا پاس ورڈ درج کریں',
  'current_password_hint': 'آپ کا موجودہ پاس ورڈ',
  'no_email_on_account': 'اس اکاؤنٹ میں کوئی ای میل نہیں ہے۔',
  'reset_body': '{email} پر پاس ورڈ ری سیٹ لنک بھیجا جائے گا۔',
  'reset_sent':
      'ری سیٹ لنک بھیج دیا گیا ہے۔ اپنی ای میل (اسپام سمیت) چیک کریں۔',
  'reset_failed': 'بھیجا نہیں جا سکا: {error}',
  'reset_failed_generic': 'بھیجا نہیں جا سکا۔',
  'delete_title': 'اکاؤنٹ حذف کریں؟',
  'delete_body':
      'آپ کی پروفائل، ویڈیوز، فالوز اور اطلاعات ہمیشہ کے لیے حذف ہو جائیں گی۔ اسے واپس نہیں کیا جا سکتا۔',
  'delete_confirm_btn': 'حذف کریں',
  'wrong_password': 'غلط پاس ورڈ۔ دوبارہ کوشش کریں۔',
  'relogin_required':
      'سیکیورٹی کے لیے لاگ آؤٹ کریں، دوبارہ لاگ ان کریں اور پھر کوشش کریں۔',
  'delete_failed': 'اکاؤنٹ حذف نہیں ہو سکا: {error}',
  'delete_failed_generic':
      'اکاؤنٹ حذف نہیں ہو سکا۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
  'choose_language': 'زبان منتخب کریں',
};

const Map<String, String> _ar = {
  'settings_title': 'الإعدادات والخصوصية',
  'section_account': 'الحساب',
  'section_activity': 'النشاط',
  'section_language': 'اللغة',
  'section_help': 'المساعدة',
  'section_login': 'تسجيل الدخول',
  'edit_profile': 'تعديل الملف الشخصي',
  'email': 'البريد الإلكتروني',
  'no_email': 'لا يوجد بريد إلكتروني',
  'change_password': 'تغيير كلمة المرور',
  'activity_center': 'مركز النشاط',
  'about_palok': 'حول PALOK',
  'about_body': 'PALOK منصة لمشاركة مقاطع الفيديو القصيرة.',
  'logout': 'تسجيل الخروج',
  'logout_confirm': 'هل تريد تسجيل الخروج؟',
  'logout_failed': 'تعذر تسجيل الخروج.',
  'delete_account': 'حذف الحساب',
  'yes': 'نعم',
  'no': 'لا',
  'cancel': 'إلغاء',
  'confirm': 'تأكيد',
  'send': 'إرسال',
  'enter_password': 'أدخل كلمة المرور',
  'current_password_hint': 'كلمة المرور الحالية',
  'no_email_on_account': 'لا يوجد بريد إلكتروني لهذا الحساب.',
  'reset_body': 'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى {email}.',
  'reset_sent':
      'تم إرسال رابط إعادة التعيين. تحقق من بريدك (بما في ذلك الرسائل غير المرغوبة).',
  'reset_failed': 'تعذر الإرسال: {error}',
  'reset_failed_generic': 'تعذر الإرسال.',
  'delete_title': 'هل تريد حذف الحساب؟',
  'delete_body':
      'سيتم حذف ملفك الشخصي ومقاطع الفيديو والمتابعات والإشعارات نهائيًا. لا يمكن التراجع عن ذلك.',
  'delete_confirm_btn': 'حذف',
  'wrong_password': 'كلمة المرور خاطئة. حاول مرة أخرى.',
  'relogin_required':
      'لأسباب أمنية، سجّل الخروج ثم الدخول مرة أخرى وأعد المحاولة.',
  'delete_failed': 'تعذر حذف الحساب: {error}',
  'delete_failed_generic':
      'تعذر حذف الحساب. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
  'choose_language': 'اختر اللغة',
};

const Map<String, String> _id = {
  'settings_title': 'Pengaturan dan privasi',
  'section_account': 'Akun',
  'section_activity': 'Aktivitas',
  'section_language': 'Bahasa',
  'section_help': 'Bantuan',
  'section_login': 'Masuk',
  'edit_profile': 'Edit profil',
  'email': 'Email',
  'no_email': 'Tidak ada email',
  'change_password': 'Ubah kata sandi',
  'activity_center': 'Pusat aktivitas',
  'about_palok': 'Tentang PALOK',
  'about_body': 'PALOK adalah platform berbagi video pendek.',
  'logout': 'Keluar',
  'logout_confirm': 'Apakah Anda ingin keluar?',
  'logout_failed': 'Gagal keluar.',
  'delete_account': 'Hapus akun',
  'yes': 'Ya',
  'no': 'Tidak',
  'cancel': 'Batal',
  'confirm': 'Konfirmasi',
  'send': 'Kirim',
  'enter_password': 'Masukkan kata sandi Anda',
  'current_password_hint': 'Kata sandi Anda saat ini',
  'no_email_on_account': 'Akun ini tidak memiliki email.',
  'reset_body': 'Tautan pengaturan ulang kata sandi akan dikirim ke {email}.',
  'reset_sent': 'Tautan dikirim. Periksa email Anda (termasuk spam).',
  'reset_failed': 'Gagal mengirim: {error}',
  'reset_failed_generic': 'Gagal mengirim.',
  'delete_title': 'Hapus akun?',
  'delete_body':
      'Profil, video, pengikut, dan notifikasi Anda akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
  'delete_confirm_btn': 'Hapus',
  'wrong_password': 'Kata sandi salah. Coba lagi.',
  'relogin_required':
      'Demi keamanan, keluar, masuk lagi, lalu coba kembali.',
  'delete_failed': 'Gagal menghapus akun: {error}',
  'delete_failed_generic':
      'Gagal menghapus akun. Periksa koneksi internet dan coba lagi.',
  'choose_language': 'Pilih bahasa',
};

const Map<String, String> _ne = {
  'settings_title': 'सेटिङ र गोपनीयता',
  'section_account': 'खाता',
  'section_activity': 'गतिविधि',
  'section_language': 'भाषा',
  'section_help': 'सहायता',
  'section_login': 'लगइन',
  'edit_profile': 'प्रोफाइल सम्पादन गर्नुहोस्',
  'email': 'इमेल',
  'no_email': 'इमेल छैन',
  'change_password': 'पासवर्ड परिवर्तन गर्नुहोस्',
  'activity_center': 'गतिविधि केन्द्र',
  'about_palok': 'PALOK बारे',
  'about_body': 'PALOK छोटा भिडियो साझा गर्ने प्लेटफर्म हो।',
  'logout': 'लगआउट',
  'logout_confirm': 'के तपाईं लगआउट गर्न चाहनुहुन्छ?',
  'logout_failed': 'लगआउट गर्न सकिएन।',
  'delete_account': 'खाता मेटाउनुहोस्',
  'yes': 'हो',
  'no': 'होइन',
  'cancel': 'रद्द गर्नुहोस्',
  'confirm': 'पुष्टि गर्नुहोस्',
  'send': 'पठाउनुहोस्',
  'enter_password': 'आफ्नो पासवर्ड हाल्नुहोस्',
  'current_password_hint': 'तपाईंको हालको पासवर्ड',
  'no_email_on_account': 'यो खातामा इमेल छैन।',
  'reset_body': '{email} मा पासवर्ड रिसेट लिङ्क पठाइनेछ।',
  'reset_sent':
      'रिसेट लिङ्क पठाइयो। आफ्नो इमेल (स्प्याम सहित) हेर्नुहोस्।',
  'reset_failed': 'पठाउन सकिएन: {error}',
  'reset_failed_generic': 'पठाउन सकिएन।',
  'delete_title': 'खाता मेटाउने?',
  'delete_body':
      'तपाईंको प्रोफाइल, भिडियो, फलो र सूचनाहरू स्थायी रूपमा मेटिनेछन्। यो फिर्ता गर्न सकिँदैन।',
  'delete_confirm_btn': 'मेटाउनुहोस्',
  'wrong_password': 'गलत पासवर्ड। फेरि प्रयास गर्नुहोस्।',
  'relogin_required':
      'सुरक्षाका लागि लगआउट गरी फेरि लगइन गर्नुहोस् र पुनः प्रयास गर्नुहोस्।',
  'delete_failed': 'खाता मेटाउन सकिएन: {error}',
  'delete_failed_generic':
      'खाता मेटाउन सकिएन। इन्टरनेट जाँच गरी फेरि प्रयास गर्नुहोस्।',
  'choose_language': 'भाषा छान्नुहोस्',
};
