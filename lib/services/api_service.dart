
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Removed FatSecret credentials and token logic.
  // API calls will now be proxied through the Supabase Edge Function.

  // depending on how the calling code (e.g., searchPage.dart) is updated
  // to use the Supabase Edge Function directly.
}
