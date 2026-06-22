import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with a timeout so the app never hangs on startup.
  try {
    await Supabase.initialize(
      url: 'https://jjkijnmrtkkukdboajxu.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqa2lqbm1ydGtrdWtkYm9hanh1'
          'Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMTE0NDMsImV4cCI6MjA5NzY4'
          'NzQ0M30.6I2swrTQDDT0phQvRqDkLFFo_BxtmxD3NE9R8lDbDeI',
    ).timeout(const Duration(seconds: 8));

    // Load data in the background — does not block app startup.
    SupabaseService.loadAll();
  } catch (_) {}

  runApp(const FomraHrmsApp());
}
