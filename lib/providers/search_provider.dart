import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/searchPage.dart';

class SearchProvider with ChangeNotifier {
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(hours: 1);

  final Map<String, _CachedSearch> _searchCache = {};
  final Map<String, _CachedSearch> _autoCompleteCache = {};

  bool _isLoading = false;
  bool _isInitialized = false;
  String _lastQuery = '';
  Timer? _debouncer;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get lastQuery => _lastQuery;

  // Supabase Edge Function URL
  final String _fatSecretProxyUrl =
      'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/fatsecret-proxy';
  final _supabase = Supabase.instance.client;

  Future<List<FoodItem>> searchFood(String query,
      {bool useCache = true}) async {
    if (query.isEmpty) return [];

    _lastQuery = query;

    // Check cache first if enabled
    if (useCache) {
      final cached = _searchCache[query.toLowerCase()];
      if (cached != null && !cached.isExpired) {
        return cached.data as List<FoodItem>;
      }
    }

    try {
      _isLoading = true;
      notifyListeners();

      final results = await _performSearch(query);

      // Cache the results
      _cacheSearchResults(query.toLowerCase(), results);

      return results;
    } catch (e) {
      debugPrint('Error searching food: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> getAutoCompleteSuggestions(String query) async {
    if (query.isEmpty) return [];

    // Check cache
    final cached = _autoCompleteCache[query.toLowerCase()];
    if (cached != null && !cached.isExpired) {
      return cached.data as List<String>;
    }

    try {
      final suggestions = await _performAutoComplete(query);

      // Cache the results
      _cacheAutoCompleteResults(query.toLowerCase(), suggestions);

      return suggestions;
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      return [];
    }
  }

  Future<List<FoodItem>> _performSearch(String query) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse(_fatSecretProxyUrl),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'endpoint': 'search',
        'query': query,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final searchData = data['foods_search'];

      if (searchData != null &&
          searchData['results'] != null &&
          searchData['results']['food'] != null) {
        final foods = searchData['results']['food'] as List;
        return foods.map((food) => FoodItem.fromFatSecretJson(food)).toList();
      }
    }

    return [];
  }

  Future<List<String>> _performAutoComplete(String query) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse(_fatSecretProxyUrl),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'endpoint': 'autocomplete',
        'query': query,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> suggestions = [];

      try {
        final suggestionsData = data['suggestions'];
        if (suggestionsData is Map && suggestionsData['suggestion'] is List) {
          suggestions = List<String>.from(
              suggestionsData['suggestion'].map((item) => item.toString()));
        } else if (suggestionsData is List) {
          suggestions =
              List<String>.from(suggestionsData.map((item) => item.toString()));
        }
      } catch (e) {
        debugPrint('Error parsing suggestions: $e');
      }

      return suggestions;
    }

    return [];
  }

  void _cacheSearchResults(String query, List<FoodItem> results) {
    _cleanCache(_searchCache);
    _searchCache[query] = _CachedSearch(
      data: results,
      timestamp: DateTime.now(),
    );
  }

  void _cacheAutoCompleteResults(String query, List<String> results) {
    _cleanCache(_autoCompleteCache);
    _autoCompleteCache[query] = _CachedSearch(
      data: results,
      timestamp: DateTime.now(),
    );
  }

  void _cleanCache(Map<String, _CachedSearch> cache) {
    // Remove expired entries
    cache.removeWhere((_, cached) => cached.isExpired);

    // Remove oldest entries if cache is too large
    if (cache.length > _maxCacheSize) {
      final sortedEntries = cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      final entriesToRemove = sortedEntries.take(cache.length - _maxCacheSize);
      for (var entry in entriesToRemove) {
        cache.remove(entry.key);
      }
    }
  }

  void clearCache() {
    _searchCache.clear();
    _autoCompleteCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    super.dispose();
  }
}

class _CachedSearch {
  final dynamic data;
  final DateTime timestamp;

  _CachedSearch({
    required this.data,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > SearchProvider._cacheExpiry;
}
