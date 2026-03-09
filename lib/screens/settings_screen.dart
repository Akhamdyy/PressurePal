import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../config/translations.dart';
import '../services/notification_service.dart';
import '../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay morningTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay afternoonTime = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay eveningTime = const TimeOfDay(hour: 21, minute: 0);
  bool _biometricsEnabled = false;
  
  // --- GUARDIAN MODE VARS ---
  String _emergencyPhone = "";

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
    _loadBiometricPref();
    _loadGuardianSettings(); // <--- Load Phone
  }

  Future<void> _loadBiometricPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    });
  }

  // --- NEW: Load Emergency Contact ---
  Future<void> _loadGuardianSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyPhone = prefs.getString('emergency_phone') ?? "";
    });
  }

  Future<void> _saveGuardianPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_phone', phone);
    setState(() => _emergencyPhone = phone);
  }
  // -----------------------------------

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      morningTime = _getTime(prefs, 'morning', 9);
      afternoonTime = _getTime(prefs, 'afternoon', 15);
      eveningTime = _getTime(prefs, 'evening', 21);
    });
  }

  TimeOfDay _getTime(SharedPreferences prefs, String key, int defaultHour) {
    final h = prefs.getInt('${key}_h') ?? defaultHour;
    final m = prefs.getInt('${key}_m') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _updateTime(String key, int id, TimeOfDay time, String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${key}_h', time.hour);
    await prefs.setInt('${key}_m', time.minute);
    
    if (key == 'morning') setState(() => morningTime = time);
    if (key == 'afternoon') setState(() => afternoonTime = time);
    if (key == 'evening') setState(() => eveningTime = time);

    await NotificationService.scheduleDailyNotification(time.hour, time.minute);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageNotifier.value == 'en' ? "Reminder Updated" : "تم تحديث التنبيه")),
      );
    }
  }

  // --- PHONE INPUT DIALOG ---
  void _showPhoneDialog() {
    final controller = TextEditingController(text: _emergencyPhone);
    bool isArabic = languageNotifier.value == 'ar';
    
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? "رقم الطوارئ" : "Emergency Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isArabic 
              ? "أدخل الرقم مع رمز الدولة (مثال: 2010xxxx+)" 
              : "Enter with Country Code (e.g. +2010xxxx)",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone),
                hintText: "+20...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text(isArabic ? "إلغاء" : "Cancel")
          ),
          ElevatedButton(
            onPressed: () {
              _saveGuardianPhone(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(isArabic ? "حفظ" : "Save"),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = themeNotifier.value == ThemeMode.dark;
    bool isArabic = languageNotifier.value == 'ar';
    String t(String key) => AppTranslations.get(key); 

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? "الإعدادات" : "Settings")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. GENERAL SECTION
          _buildSectionHeader(isArabic ? "عام" : "General"),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.teal),
                  title: Text(isArabic ? "اللغة" : "Language", style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(isArabic ? "العربية" : "English", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  onTap: () {
                     languageNotifier.value = isArabic ? 'en' : 'ar';
                     setState(() {}); 
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(isArabic ? "الوضع الليلي" : "Dark Mode", style: const TextStyle(fontWeight: FontWeight.bold)),
                  secondary: Icon(Icons.dark_mode, color: isDark ? Colors.purple.shade200 : Colors.grey),
                  value: isDark,
                  activeThumbColor: Colors.purple.shade200,
                  onChanged: (val) {
                    setState(() { themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light; });
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // 2. GUARDIAN MODE SECTION (NEW 🛡️) 
          _buildSectionHeader(isArabic ? "وضع الحماية 🛡️" : "Guardian Mode 🛡️"),
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.emergency_share, color: Colors.redAccent),
              title: Text(
                isArabic ? "رقم الطوارئ (طبيب/ابن)" : "Emergency Contact", 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                _emergencyPhone.isEmpty 
                  ? (isArabic ? "اضغط لإضافة رقم للتنبيهات" : "Tap to set alert number")
                  : _emergencyPhone,
                style: TextStyle(
                  color: _emergencyPhone.isEmpty ? Colors.grey : Colors.green,
                  fontWeight: _emergencyPhone.isEmpty ? FontWeight.normal : FontWeight.bold
                ),
              ),
              trailing: const Icon(Icons.edit, color: Colors.grey, size: 20),
              onTap: _showPhoneDialog,
            ),
          ),

          const SizedBox(height: 30),

          // 3. SECURITY SECTION
          _buildSectionHeader(isArabic ? "الأمان" : "Security"),
          _buildCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.face, color: Colors.blueAccent),
              title: Text(
                isArabic ? "قفل التطبيق (بصمة/وجه)" : "App Lock (Biometric)",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isArabic ? "طلب المصادقة عند الفتح" : "Require auth on startup",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: _biometricsEnabled,
              activeThumbColor: Colors.blueAccent,
              onChanged: (val) async {
                if (val) {
                  bool success = await BiometricService.authenticate();
                  if (success) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('biometrics_enabled', true);
                    setState(() => _biometricsEnabled = true);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isArabic ? "فشلت المصادقة" : "Authentication failed"))
                      );
                    }
                  }
                } else {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('biometrics_enabled', false);
                  setState(() => _biometricsEnabled = false);
                }
              },
            ),
          ),

          const SizedBox(height: 30),

          // 4. REMINDERS SECTION
          _buildSectionHeader(isArabic ? "التنبيهات" : "Reminders"),
          _buildCard(
            child: Column(
              children: [
                _buildTimeRow("Morning", "الصباح", morningTime, (picked) => _updateTime('morning', 1, picked, "Good Morning", "Time for your morning BP check!")),
                const Divider(height: 1),
                _buildTimeRow("Afternoon", "الظهر", afternoonTime, (picked) => _updateTime('afternoon', 2, picked, "Good Afternoon", "Don't forget your afternoon reading.")),
                const Divider(height: 1),
                _buildTimeRow("Evening", "المساء", eveningTime, (picked) => _updateTime('evening', 3, picked, "Good Evening", "Please record your evening BP.")),
              ],
            ),
          ),
          
          const SizedBox(height: 30),

          // 5. ACCOUNT SECTION
          _buildSectionHeader(isArabic ? "الحساب" : "Account"),
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(isArabic ? "تسجيل خروج" : "Log Out", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(isArabic ? "تأكيد" : "Confirm"),
                    content: Text(isArabic ? "هل تريد تسجيل الخروج؟" : "Are you sure you want to log out?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isArabic ? "إلغاء" : "Cancel")),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isArabic ? "خروج" : "Log Out", style: const TextStyle(color: Colors.red))),
                    ],
                  )
                );
                if (confirm == true) { Navigator.pop(context); await Supabase.instance.client.auth.signOut(); }
              },
            ),
          ),
          
          const SizedBox(height: 30),

          // 6. ABOUT SECTION
          _buildSectionHeader(isArabic ? "عن التطبيق" : "About"),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: Text(t('version'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Text("3.3.0", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: Colors.orange),
                  title: Text(isArabic ? "تطوير" : "Developed by", style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isArabic ? "علي خالد" : "Ali Khaled", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(width: 5),
                      const Icon(Icons.favorite, color: Colors.red, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
      child: Text(title, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildTimeRow(String enLabel, String arLabel, TimeOfDay time, Function(TimeOfDay) onSelect) {
    final label = languageNotifier.value == 'en' ? enLabel : arLabel;
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
        child: Text(time.format(context), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
      ),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onSelect(picked);
      },
    );
  }
}