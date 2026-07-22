import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/expense_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/contacts_provider.dart';
import 'screens/events_list_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ExpenseProvider()..loadData()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => ContactsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'دنگ چی',
            themeMode: settings.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.vazirmatnTextTheme(),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1F1F1F),
                foregroundColor: Colors.white,
              ),
            ),
            // تنظیمات محلی‌سازی
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fa', 'IR'), // فارسی
            ],
            locale: const Locale('fa', 'IR'),
            home: const EventsListScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
