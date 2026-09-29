import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads GEMINI_API_KEY (and any other vars) from .env at the project root.
  // If .env is missing, dotenv leaves values unset rather than crashing —
  // GeminiTranscriptionService surfaces a clear error when the key is absent.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env present yet (e.g. fresh checkout before copying .env.example).
    // Continue so the rest of the app still runs; photo transcription will
    // show a "missing API key" message until .env is added.
  }

  runApp(const SubjectNotesApp());
}

class SubjectNotesApp extends StatelessWidget {
  const SubjectNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subject Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B5FEF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F8FC),
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
