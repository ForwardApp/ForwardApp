import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class SupabaseService {
  static late final SupabaseClient _client;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    // If already marked as initialized in our service, don't try again
    if (_isInitialized) return;
    
    try {
      // Check if Supabase instance already exists
      try {
        // This will throw an error if not initialized
        final testClient = Supabase.instance.client;
        // If we get here, Supabase is already initialized
        _client = testClient;
        _isInitialized = true;
        debugPrint('Supabase was already initialized, reusing existing instance');
        return;
      } catch (e) {
        // Supabase not initialized yet, continue with normal initialization
      }
      
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Missing Supabase environment variables');
      }

      debugPrint('Initializing Supabase with URL: $supabaseUrl');
      
      // Initialize without retries since we already checked
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: true, // Enable debug logs
      );
      
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('SupabaseService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
      // Don't rethrow, just return and let app continue
    }
  }

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('SupabaseService not initialized');
    }
    return _client;
  }


  static bool get isInitialized => _isInitialized;

  static Future<void> saveRouteLocations({
    required String location1Name,
    required String location2Name, 
    String? location1Address,
    String? location2Address,
    double? location1Lat,
    double? location1Lng,
    double? location2Lat,
    double? location2Lng,
    String? startTime,
    String? endTime,
    String? transportMode,
  }) async {
    try {
      // Try to initialize if not already initialized
      if (!_isInitialized) {
        debugPrint('Auto-initializing Supabase before saving data...');
        await initialize();
      }
      
      // Check again if initialization was successful
      if (!_isInitialized) {
        throw Exception('Could not initialize Supabase service');
      }

      await client.from('location_list').insert({
        'first_location_name': location1Name,
        'first_location_address': location1Address ?? '',
        'second_location_name': location2Name,
        'second_location_address': location2Address ?? '',
        'first_location_lat': location1Lat,
        'first_location_lng': location1Lng,
        'second_location_lat': location2Lat,
        'second_location_lng': location2Lng,
        'transport_mode': transportMode ?? 'walk', // Default to walk if not specified
        'start_time': startTime,
        'end_time': endTime,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Route locations saved successfully to location_list table');
    } catch (e) {
      debugPrint('Error saving route locations: $e');
      rethrow;
    }
  }
}