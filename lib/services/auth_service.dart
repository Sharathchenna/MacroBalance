import 'package:macrotracker/main.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/services/storage_service.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<void> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Restore goals from user_macros first, so the provider reload below
        // picks them up when this device has no nutrition_goals yet.
        Map<String, dynamic>? macroResponse;
        try {
          macroResponse = await supabase
              .from('user_macros')
              .select()
              .eq('id', response.user!.id)
              .maybeSingle();
        } catch (_) {
          // Signed in fine; goals fall back to what this device has.
        }

        if (macroResponse != null && StorageService().get('nutrition_goals') == null) {
          StorageService()
              .put('calories_goal', macroResponse['calories_goal'] ?? 2000.0);
          StorageService()
              .put('protein_goal', macroResponse['protein_goal'] ?? 150.0);
          StorageService()
              .put('carbs_goal', macroResponse['carbs_goal'] ?? 225.0);
          StorageService().put('fat_goal', macroResponse['fat_goal'] ?? 65.0);
        }

        final foodEntryProvider = navigatorKey.currentContext != null
            ? Provider.of<FoodEntryProvider>(navigatorKey.currentContext!,
                listen: false)
            : null;

        if (foodEntryProvider != null) {
          // Loads local entries, then merges in the user's cloud entries.
          await foodEntryProvider.loadEntriesForCurrentUser();
          await foodEntryProvider.loadNutritionGoals();
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
