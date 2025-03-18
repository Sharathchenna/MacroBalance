import 'package:macrotracker/main.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  final supabase = Supabase.instance.client;
  final supabaseService = SupabaseService();

  Future<void> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Ensure we wait for the full sync to complete
        await supabaseService.fullSync(response.user!.id);

        // Explicitly fetch food entries from Supabase
        final foodEntryProvider = navigatorKey.currentContext != null
            ? Provider.of<FoodEntryProvider>(navigatorKey.currentContext!,
                listen: false)
            : null;

        if (foodEntryProvider != null) {
          await foodEntryProvider.loadEntriesFromSupabase();
        }
      }
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (error) {
      throw Exception('An unexpected error occurred during sign in: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      throw Exception('Error signing out: $error');
    }
  }

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
