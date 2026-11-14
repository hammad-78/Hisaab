import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lightweight English/Urdu localisation. Strings are keyed by their English
/// text; a missing Urdu entry falls back to English. Use `context.tr('...')`.
/// Placeholders are {0}, {1}: `context.trf('Order for {0}', [name])`.

const _storageKey = 'app_locale';
const _storage = FlutterSecureStorage();

const englishLocale = Locale('en');
const urduLocale = Locale('ur');

Future<Locale> loadSavedLocale() async {
  try {
    final v = await _storage.read(key: _storageKey);
    if (v == 'ur') return urduLocale;
  } catch (_) {}
  return englishLocale;
}

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(super.initial);

  Future<void> toggle() async {
    state = state.languageCode == 'ur' ? englishLocale : urduLocale;
    try {
      await _storage.write(key: _storageKey, value: state.languageCode);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(englishLocale),
);

extension L10nContext on BuildContext {
  bool get isUrdu => Localizations.localeOf(this).languageCode == 'ur';

  String tr(String en) => isUrdu ? (_ur[en] ?? en) : en;

  String trf(String en, [List<Object?> args = const []]) {
    var s = tr(en);
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', '${args[i]}');
    }
    return s;
  }

  /// "3 orders" / "1 order".
  String plural(int n, String one, String many) =>
      '$n ${tr(n == 1 ? one : many)}';
}

/// App bar button that flips between English and Urdu.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
      child: Text(context.isUrdu ? 'English' : 'اردو'),
    );
  }
}

const _ur = <String, String>{
  // common
  'Log out': 'لاگ آؤٹ',
  'Cancel': 'منسوخ کریں',
  'Save': 'محفوظ کریں',
  'Delete': 'حذف کریں',
  'Today': 'آج',
  'Today ({0})': 'آج ({0})',
  'Menu': 'مینو',
  'Waiters': 'ویٹرز',
  'Waiter': 'ویٹر',
  'Shops': 'دکانیں',
  'Shop': 'دکان',
  'Reports': 'رپورٹس',
  'Counter': 'کاؤنٹر',
  'Total': 'کل',
  'Price': 'قیمت',
  'Share': 'شیئر کریں',
  'item': 'آئٹم',
  'items': 'آئٹمز',
  'order': 'آرڈر',
  'orders': 'آرڈرز',
  'shop': 'دکان',
  'shops': 'دکانیں',
  'waiter': 'ویٹر',
  'waiters': 'ویٹرز',
  'menu item': 'مینو آئٹم',
  'menu items': 'مینو آئٹمز',
  'sold': 'فروخت',
  'Enter a name': 'نام درج کریں',
  'Enter a valid email': 'درست ای میل درج کریں',
  'At least 6 characters': 'کم از کم 6 حروف',
  'Password': 'پاس ورڈ',
  'Auth error': 'تصدیق کی خرابی',
  'Could not load profile': 'پروفائل لوڈ نہیں ہو سکا',
  'Setting up your account…\nIf this stays, log out and try again.':
      'آپ کا اکاؤنٹ تیار ہو رہا ہے…\nاگر یہ ختم نہ ہو تو لاگ آؤٹ کر کے دوبارہ کوشش کریں۔',

  // login
  'Create an owner account. You can add your cafe, shops and managers next.':
      'مالک کا اکاؤنٹ بنائیں۔ اس کے بعد آپ اپنا کیفے، دکانیں اور مینیجرز شامل کر سکتے ہیں۔',
  'Log in with the email and password you were given.':
      'آپ کو دیے گئے ای میل اور پاس ورڈ سے لاگ اِن کریں۔',
  'Your name': 'آپ کا نام',
  'Enter your name': 'اپنا نام درج کریں',
  'Email': 'ای میل',
  'Hide password': 'پاس ورڈ چھپائیں',
  'Show password': 'پاس ورڈ دکھائیں',
  'Create owner account': 'مالک کا اکاؤنٹ بنائیں',
  'Log in': 'لاگ اِن',
  'Already have an account? Log in': 'پہلے سے اکاؤنٹ ہے؟ لاگ اِن کریں',
  'Cafe owner? Create an account': 'کیفے کے مالک ہیں؟ اکاؤنٹ بنائیں',
  'Something went wrong. Please try again.':
      'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔',
  'Incorrect email or password.': 'ای میل یا پاس ورڈ غلط ہے۔',
  'This email is already registered.': 'یہ ای میل پہلے سے رجسٹرڈ ہے۔',
  'Password must be at least 6 characters.':
      'پاس ورڈ کم از کم 6 حروف کا ہونا چاہیے۔',
  'Enter a valid email address.': 'درست ای میل ایڈریس درج کریں۔',
  'No internet connection.': 'انٹرنیٹ کنکشن نہیں ہے۔',
  'Authentication failed.': 'تصدیق ناکام ہو گئی۔',

  // owner
  'Add shop': 'دکان شامل کریں',
  'Sales today': 'آج کی فروخت',
  '{0} sales today': '{0} کی آج کی فروخت',
  'Shops could not be loaded. {0}': 'دکانیں لوڈ نہیں ہو سکیں۔ {0}',
  'No shops yet. Tap "Add shop" to create one and give its manager a login.':
      'ابھی کوئی دکان نہیں۔ "دکان شامل کریں" دبا کر دکان بنائیں اور اس کے مینیجر کو لاگ اِن دیں۔',
  'Manager': 'مینیجر',
  'None yet. The manager adds the menu.':
      'ابھی کچھ نہیں۔ مینو مینیجر شامل کرتا ہے۔',
  'None yet. The manager adds waiters.':
      'ابھی کوئی نہیں۔ ویٹرز مینیجر شامل کرتا ہے۔',
  '{0}, updates live': '{0}، لائیو اپ ڈیٹ ہوتا ہے',
  'Today {0}': 'آج {0}',
  'Create your cafe': 'اپنا کیفے بنائیں',
  'Cafe name': 'کیفے کا نام',
  'Create cafe': 'کیفے بنائیں',
  'Enter a cafe name': 'کیفے کا نام درج کریں',
  'Could not create cafe: {0}': 'کیفے نہیں بن سکا: {0}',
  'Shop and manager created': 'دکان اور مینیجر بنا دیے گئے',
  'That email is already used by another account.':
      'یہ ای میل کسی اور اکاؤنٹ میں استعمال ہو چکی ہے۔',
  'Could not create manager.': 'مینیجر نہیں بن سکا۔',
  'Could not create shop: {0}': 'دکان نہیں بن سکی: {0}',
  'Shop name': 'دکان کا نام',
  'Enter a shop name': 'دکان کا نام درج کریں',
  'Manager login': 'مینیجر کا لاگ اِن',
  'Manager name': 'مینیجر کا نام',
  'Enter the manager name': 'مینیجر کا نام درج کریں',
  'Manager email': 'مینیجر کی ای میل',
  'Create shop': 'دکان بنائیں',

  'Edit shop': 'دکان میں ترمیم کریں',
  'Edit': 'ترمیم',
  'Could not save: {0}': 'محفوظ نہیں ہو سکا: {0}',
  'New manager password': 'مینیجر کا نیا پاس ورڈ',
  'The current manager will be logged out. Give the new email and this password to the manager.':
      'موجودہ مینیجر لاگ آؤٹ ہو جائے گا۔ نئی ای میل اور یہ پاس ورڈ مینیجر کو دیں۔',
  'Settings': 'سیٹنگز',
  'Appearance': 'ظاہری شکل',
  'Light': 'روشن',
  'Dark': 'گہرا',
  'System': 'سسٹم',
  'Activate': 'فعال کریں',
  'No shops yet.': 'ابھی کوئی دکان نہیں۔',
  'Shop settings': 'دکان کی سیٹنگز',
  'Deactivate shop': 'دکان غیر فعال کریں',
  'Activate shop': 'دکان فعال کریں',
  'Deactivate': 'غیر فعال کریں',
  'Inactive': 'غیر فعال',
  'Deactivate shop {0}?': 'دکان {0} غیر فعال کریں؟',
  'The manager will be logged out and cannot log in until you activate the shop again. All its data is kept.':
      'مینیجر لاگ آؤٹ ہو جائے گا اور دکان دوبارہ فعال کرنے تک لاگ ان نہیں کر سکے گا۔ تمام ڈیٹا محفوظ رہے گا۔',
  'Shop deactivated': 'دکان غیر فعال کر دی گئی',
  'Shop activated': 'دکان فعال کر دی گئی',
  'This login was changed by the owner. Please log in with the new email.':
      'مالک نے یہ لاگ ان تبدیل کر دیا ہے۔ نئی ای میل سے لاگ ان کریں۔',
  'This shop has been deactivated by the owner.':
      'مالک نے اس دکان کو غیر فعال کر دیا ہے۔',

  // reports
  'Yesterday': 'کل',
  'Last 7 days': 'پچھلے 7 دن',
  'This month': 'اس مہینے',
  'Custom': 'اپنی مرضی',
  'All shops': 'تمام دکانیں',
  'Could not load report: {0}': 'رپورٹ لوڈ نہیں ہو سکی: {0}',
  'Total sales': 'کل فروخت',
  'Amount': 'رقم',
  'Qty': 'تعداد',
  'Orders': 'آرڈرز',
  'By shop': 'دکان کے لحاظ سے',
  'By item': 'آئٹم کے لحاظ سے',
  'By waiter': 'ویٹر کے لحاظ سے',
  'View PDF': 'PDF دیکھیں',
  'View Excel': 'Excel دیکھیں',
  'No sales in this period. Pick another date range or shop.':
      'اس مدت میں کوئی فروخت نہیں۔ کوئی اور تاریخ یا دکان منتخب کریں۔',
  'Sales report ({0})': 'فروخت کی رپورٹ ({0})',
  'Downloaded {0}': '{0} ڈاؤن لوڈ ہو گئی',
  'Download failed. Try again. ({0})':
      'ڈاؤن لوڈ ناکام ہو گیا۔ دوبارہ کوشش کریں۔ ({0})',
  'Could not share the file. ({0})': 'فائل شیئر نہیں ہو سکی۔ ({0})',
  'The PDF could not be built. {0}': 'PDF نہیں بن سکی۔ {0}',
  'Download {0}': '{0} ڈاؤن لوڈ کریں',
  'No rows in this sheet.': 'اس شیٹ میں کوئی قطار نہیں۔',

  // manager
  'This login is not linked to a shop. Ask the cafe owner to add you as a shop manager.':
      'یہ لاگ اِن کسی دکان سے منسلک نہیں ہے۔ کیفے کے مالک سے کہیں کہ آپ کو دکان کا مینیجر بنائیں۔',
  'Add item': 'آئٹم شامل کریں',
  'Add waiter': 'ویٹر شامل کریں',
  'Order placed for {0}: {1}': '{0} کا آرڈر درج ہو گیا: {1}',
  'Order not saved. Check your connection and try again. ({0})':
      'آرڈر محفوظ نہیں ہوا۔ انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔ ({0})',
  'No waiters yet. Add waiters': 'ابھی کوئی ویٹر نہیں۔ ویٹر شامل کریں',
  'Find an item': 'آئٹم تلاش کریں',
  'Your menu is empty. Add what this shop sells to start taking orders.':
      'آپ کا مینو خالی ہے۔ آرڈر لینے کے لیے وہ چیزیں شامل کریں جو یہ دکان بیچتی ہے۔',
  'Add menu items': 'مینو آئٹمز شامل کریں',
  '{0}, {1}. Tap to add one.': '{0}، {1}۔ ایک شامل کرنے کے لیے ٹیپ کریں۔',
  '{0} in order': 'آرڈر میں {0}',
  'Edit item': 'آئٹم میں ترمیم کریں',
  'Item name': 'آئٹم کا نام',
  'Enter a valid price': 'درست قیمت درج کریں',
  'The menu could not be loaded. {0}': 'مینو لوڈ نہیں ہو سکا۔ {0}',
  'Your menu is empty.\nTap "Add item" to add what this shop sells.':
      'آپ کا مینو خالی ہے۔\nدکان کی چیزیں شامل کرنے کے لیے "آئٹم شامل کریں" دبائیں۔',
  'Delete {0}': '{0} حذف کریں',
  'Rename waiter': 'ویٹر کا نام بدلیں',
  'Waiter name': 'ویٹر کا نام',
  'Waiters could not be loaded. {0}': 'ویٹرز لوڈ نہیں ہو سکے۔ {0}',
  'No waiters yet.\nTap "Add waiter" to add the people who take orders.':
      'ابھی کوئی ویٹر نہیں۔\nآرڈر لینے والوں کو شامل کرنے کے لیے "ویٹر شامل کریں" دبائیں۔',
  'Delete {0}?': '{0} حذف کریں؟',
  'Past sales and reports are not affected.':
      'پچھلی فروخت اور رپورٹس پر کوئی اثر نہیں پڑے گا۔',
  'Cancel this order?': 'کیا یہ آرڈر منسوخ کرنا ہے؟',
  '{0}, {1}. It will no longer count in today\'s sales or reports. You can revive it later.':
      '{0}، {1}۔ یہ آج کی فروخت یا رپورٹس میں شمار نہیں ہوگا۔ آپ اسے بعد میں بحال کر سکتے ہیں۔',
  'Keep order': 'آرڈر رکھیں',
  'Cancel order': 'آرڈر منسوخ کریں',
  'Order cancelled': 'آرڈر منسوخ ہو گیا',
  'Order revived': 'آرڈر بحال ہو گیا',
  'Revive': 'بحال کریں',
  'Cancelled orders ({0})': 'منسوخ شدہ آرڈرز ({0})',
  'Not counted in the totals above.': 'اوپر کے کل میں شمار نہیں۔',
  'Deleted shop': 'حذف شدہ دکان',
  "Today's orders": 'آج کے آرڈرز',
  "Today's orders could not be loaded. {0}":
      'آج کے آرڈرز لوڈ نہیں ہو سکے۔ {0}',
  '1 order so far': 'اب تک 1 آرڈر',
  '{0} orders so far': 'اب تک {0} آرڈرز',
  'No orders yet today.': 'آج ابھی تک کوئی آرڈر نہیں۔',

  // order slip
  'Tap menu items to start an order.':
      'آرڈر شروع کرنے کے لیے مینو آئٹمز پر ٹیپ کریں۔',
  'Choose a waiter to place this order': 'آرڈر دینے کے لیے ویٹر منتخب کریں',
  'Place order': 'آرڈر دیں',
  'New order': 'نیا آرڈر',
  'Order for {0}': '{0} کے لیے آرڈر',
  'Clear': 'صاف کریں',
  'One less {0}': '{0} ایک کم',
  'One more {0}': '{0} ایک زیادہ',
};
