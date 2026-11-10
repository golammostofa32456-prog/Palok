// হোম ফিডের তৈরির শিট, ফাঁকা ফিড ইত্যাদির অনুবাদ। tf('h_...') দিয়ে ব্যবহার হয়।
// এখানে না পেলে strings_home / strings_profile, তারপর tr() তে খোঁজে।

import 'app_strings.dart';
import 'strings_home.dart';
import 'strings_profile.dart';

String tf(String key, [Map<String, String>? params]) {
  final code = LanguageController.instance.code;
  final found = _lookup(code, key) ?? _lookup('en', key);

  if (found == null) {
    return tr(key, params);
  }

  var text = found;
  if (params != null) {
    params.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
  }
  return text;
}

String? _lookup(String code, String key) {
  return feedStrings[code]?[key] ??
      homeStrings[code]?[key] ??
      profileStrings[code]?[key];
}

const Map<String, Map<String, String>> feedStrings = {
  'en': {
    'h_follow_self': 'You cannot follow your own profile.',
    'h_create_title': 'Create on PALOK',
    'h_record_video': 'Record video',
    'h_record_sub': 'Create a new video with the camera',
    'h_upload_video': 'Upload video',
    'h_upload_sub': 'Choose a video from your gallery',
    'h_add_sound': 'Add sound',
    'h_sound_sub': 'Sound feature will be added later',
    'h_sound_soon': 'Sound feature coming soon',
    'h_pick_failed': 'Could not select the video.',
    'h_following_empty_title': 'Your Following feed is empty',
    'h_following_empty_sub':
        'Videos from creators you follow will appear here.',
    'h_see_for_you': 'Watch For You',
  },
  'bn': {
    'h_follow_self': 'নিজের প্রোফাইল অনুসরণ করা যাবে না।',
    'h_create_title': 'PALOK-এ তৈরি করুন',
    'h_record_video': 'ভিডিও রেকর্ড করুন',
    'h_record_sub': 'ক্যামেরা দিয়ে নতুন ভিডিও তৈরি করুন',
    'h_upload_video': 'ভিডিও আপলোড করুন',
    'h_upload_sub': 'গ্যালারি থেকে ভিডিও বেছে নিন',
    'h_add_sound': 'সাউন্ড যোগ করুন',
    'h_sound_sub': 'সাউন্ড সুবিধা পরে যোগ করা হবে',
    'h_sound_soon': 'সাউন্ড সুবিধা শিগগির আসছে',
    'h_pick_failed': 'ভিডিও বাছাই করা যায়নি।',
    'h_following_empty_title': 'অনুসরণ ফিড এখনো খালি',
    'h_following_empty_sub': 'যাদের অনুসরণ করবেন তাদের ভিডিও এখানে দেখা যাবে।',
    'h_see_for_you': 'আপনার জন্য দেখুন',
  },
  'hi': {
    'h_follow_self': 'आप अपनी प्रोफ़ाइल को फ़ॉलो नहीं कर सकते।',
    'h_create_title': 'PALOK पर बनाएं',
    'h_record_video': 'वीडियो रिकॉर्ड करें',
    'h_record_sub': 'कैमरे से नया वीडियो बनाएं',
    'h_upload_video': 'वीडियो अपलोड करें',
    'h_upload_sub': 'गैलरी से वीडियो चुनें',
    'h_add_sound': 'साउंड जोड़ें',
    'h_sound_sub': 'साउंड सुविधा बाद में जोड़ी जाएगी',
    'h_sound_soon': 'साउंड सुविधा जल्द आ रही है',
    'h_pick_failed': 'वीडियो चुना नहीं जा सका।',
    'h_following_empty_title': 'आपका फ़ॉलोइंग फ़ीड अभी खाली है',
    'h_following_empty_sub':
        'जिन क्रिएटर्स को आप फ़ॉलो करेंगे उनके वीडियो यहां दिखेंगे।',
    'h_see_for_you': 'आपके लिए देखें',
  },
  'ur': {
    'h_follow_self': 'آپ اپنی پروفائل کو فالو نہیں کر سکتے۔',
    'h_create_title': 'PALOK پر بنائیں',
    'h_record_video': 'ویڈیو ریکارڈ کریں',
    'h_record_sub': 'کیمرے سے نئی ویڈیو بنائیں',
    'h_upload_video': 'ویڈیو اپ لوڈ کریں',
    'h_upload_sub': 'گیلری سے ویڈیو منتخب کریں',
    'h_add_sound': 'آواز شامل کریں',
    'h_sound_sub': 'آواز کی سہولت بعد میں شامل کی جائے گی',
    'h_sound_soon': 'آواز کی سہولت جلد آ رہی ہے',
    'h_pick_failed': 'ویڈیو منتخب نہیں ہو سکی۔',
    'h_following_empty_title': 'آپ کی فالونگ فیڈ ابھی خالی ہے',
    'h_following_empty_sub':
        'جن تخلیق کاروں کو آپ فالو کریں گے ان کی ویڈیوز یہاں نظر آئیں گی۔',
    'h_see_for_you': 'آپ کے لیے دیکھیں',
  },
  'ar': {
    'h_follow_self': 'لا يمكنك متابعة ملفك الشخصي.',
    'h_create_title': 'أنشئ على PALOK',
    'h_record_video': 'تسجيل فيديو',
    'h_record_sub': 'أنشئ فيديو جديدًا بالكاميرا',
    'h_upload_video': 'رفع فيديو',
    'h_upload_sub': 'اختر فيديو من المعرض',
    'h_add_sound': 'إضافة صوت',
    'h_sound_sub': 'ستتم إضافة ميزة الصوت لاحقًا',
    'h_sound_soon': 'ميزة الصوت قادمة قريبًا',
    'h_pick_failed': 'تعذر اختيار الفيديو.',
    'h_following_empty_title': 'موجز المتابَعة فارغ حاليًا',
    'h_following_empty_sub':
        'ستظهر هنا مقاطع الفيديو من المبدعين الذين تتابعهم.',
    'h_see_for_you': 'شاهد «لك»',
  },
  'id': {
    'h_follow_self': 'Anda tidak dapat mengikuti profil sendiri.',
    'h_create_title': 'Buat di PALOK',
    'h_record_video': 'Rekam video',
    'h_record_sub': 'Buat video baru dengan kamera',
    'h_upload_video': 'Unggah video',
    'h_upload_sub': 'Pilih video dari galeri',
    'h_add_sound': 'Tambah suara',
    'h_sound_sub': 'Fitur suara akan ditambahkan nanti',
    'h_sound_soon': 'Fitur suara segera hadir',
    'h_pick_failed': 'Gagal memilih video.',
    'h_following_empty_title': 'Feed Mengikuti Anda masih kosong',
    'h_following_empty_sub':
        'Video dari kreator yang Anda ikuti akan muncul di sini.',
    'h_see_for_you': 'Lihat Untuk Anda',
  },
  'ne': {
    'h_follow_self': 'आफ्नै प्रोफाइल फलो गर्न मिल्दैन।',
    'h_create_title': 'PALOK मा बनाउनुहोस्',
    'h_record_video': 'भिडियो रेकर्ड गर्नुहोस्',
    'h_record_sub': 'क्यामेराबाट नयाँ भिडियो बनाउनुहोस्',
    'h_upload_video': 'भिडियो अपलोड गर्नुहोस्',
    'h_upload_sub': 'ग्यालरीबाट भिडियो छान्नुहोस्',
    'h_add_sound': 'साउन्ड थप्नुहोस्',
    'h_sound_sub': 'साउन्ड सुविधा पछि थपिनेछ',
    'h_sound_soon': 'साउन्ड सुविधा छिट्टै आउँदैछ',
    'h_pick_failed': 'भिडियो छान्न सकिएन।',
    'h_following_empty_title': 'तपाईंको फलोइङ फिड अहिले खाली छ',
    'h_following_empty_sub':
        'तपाईंले फलो गरेका क्रिएटरहरूका भिडियो यहाँ देखिनेछन्।',
    'h_see_for_you': 'तपाईंका लागि हेर्नुहोस्',
  },
};
