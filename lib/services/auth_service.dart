import 'package:macrotracker/main.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:macrotracker/services/storage_service.dart';

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
        // First, ensure we wait for the full sync to complete
        await supabaseService.fullSync(response.user!.id);

        // Then, explicitly fetch and update local storage
        final foodEntryProvider = navigatorKey.currentContext != null
            ? Provider.of<FoodEntryProvider>(navigatorKey.currentContext!,
                listen: false)
            : null;

        if (foodEntryProvider != null) {
          // Load entries from Supabase and update local storage
          await foodEntryProvider.loadEntriesFromSupabase();

          // Force a refresh of the provider's state
          await foodEntryProvider.forceSyncAndDiagnose();
        }

        // Ensure we have the latest data in local storage
        final macroResponse = await supabase
            .from('user_macros')
            .select()
            .eq('id', response.user!.id)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (macroResponse != null) {
          // Update local storage with the latest macro goals
          StorageService()
              .put('calories_goal', macroResponse['calories_goal'] ?? 2000.0);
          StorageService()
              .put('protein_goal', macroResponse['protein_goal'] ?? 150.0);
          StorageService()
              .put('carbs_goal', macroResponse['carbs_goal'] ?? 225.0);
          StorageService().put('fat_goal', macroResponse['fat_goal'] ?? 65.0);
        }
      }
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (error) {
      throw Exception('An unexpected error occurred during sign in: $error');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.macrotracker://reset-callback/',
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (error) {
      throw Exception(
          'An unexpected error occurred during password reset: $error');
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
