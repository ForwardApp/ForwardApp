import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

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

  static Future<void> saveSafeZone({
    required String locationName,
    String? locationAddress,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      if (!_isInitialized) {
        debugPrint('Auto-initializing Supabase before saving safe zone...');
        await initialize();
      }
      
      if (!_isInitialized) {
        throw Exception('Could not initialize Supabase service');
      }

      await client.from('safe_zone').insert({
        'location_name': locationName,
        'location_address': locationAddress ?? '',
        'location_lat': locationLat,
        'location_lng': locationLng,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Safe zone saved successfully to safe_zone table');
    } catch (e) {
      debugPrint('Error saving safe zone: $e');
      rethrow;
    }
  }

  static Future<void> saveBoundingBox({
    required double pointALat,
    required double pointALng,
    required double pointBLat,
    required double pointBLng,
    required double pointCLat,
    required double pointCLng,
    required double pointDLat,
    required double pointDLng,
    int? safeZoneId,
    String? locationName,
  }) async {
    try {
      if (!_isInitialized) {
        debugPrint('Auto-initializing Supabase before saving bounding box...');
        await initialize();
      }
      
      if (!_isInitialized) {
        throw Exception('Could not initialize Supabase service');
      }

      // Create the data object for the bounding box
      final boundingBoxData = {
        'point_a_lat': pointALat,
        'point_a_lng': pointALng,
        'point_b_lat': pointBLat,
        'point_b_lng': pointBLng,
        'point_c_lat': pointCLat,
        'point_c_lng': pointCLng,
        'point_d_lat': pointDLat,
        'point_d_lng': pointDLng,
        'safe_zone_id': safeZoneId,
        'location_name': locationName,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if a bounding box already exists for this safe zone
      if (safeZoneId != null) {
        final existingData = await client
            .from('bounding_box')
            .select()
            .eq('safe_zone_id', safeZoneId)
            .maybeSingle();
        
        if (existingData != null) {
          // Update existing record
          await client
              .from('bounding_box')
              .update(boundingBoxData)
              .eq('safe_zone_id', safeZoneId);
          
          debugPrint('Bounding box updated for safe zone ID: $safeZoneId');
          return;
        }
      }

      // If no existing record was found, insert a new one
      boundingBoxData['created_at'] = DateTime.now().toIso8601String();
      await client.from('bounding_box').insert(boundingBoxData);
      
      debugPrint('Bounding box saved successfully to bounding_box table');
    } catch (e) {
      debugPrint('Error saving bounding box: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getBoundingBoxes() async {
    try {
      if (!_isInitialized) {
        debugPrint('Auto-initializing Supabase before fetching bounding boxes...');
        await initialize();
      }
      
      if (!_isInitialized) {
        throw Exception('Could not initialize Supabase service');
      }

      final response = await client
          .from('bounding_box')
          .select()
          .order('created_at', ascending: false);
      
      debugPrint('Fetched ${response.length} bounding boxes from database');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching bounding boxes: $e');
      return [];
    }
  }

  static Future<bool> hasBoundingBoxForSafeZone(int safeZoneId) async {
    try {
      if (!_isInitialized) {
        debugPrint('Auto-initializing Supabase before checking bounding box...');
        await initialize();
      }
      
      if (!_isInitialized) {
        throw Exception('Could not initialize Supabase service');
      }

      final response = await client
          .from('bounding_box')
          .select('id')
          .eq('safe_zone_id', safeZoneId)
          .limit(1)
          .maybeSingle();
      
      // If response is not null, then a bounding box exists for this safe zone
      debugPrint('Checking if bounding box exists for safe zone ID: $safeZoneId - ${response != null ? 'Found' : 'Not found'}');
      return response != null;
    } catch (e) {
      debugPrint('Error checking for bounding box: $e');
      return false;
    }
  }

  // Save task to database with image support
  static Future<void> saveTask({
    required String taskDescription,
    required DateTime taskDate,
    required String repeatOption,
    File? imageFile,
  }) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      String? imageUrl;
      
      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await uploadTaskImage(imageFile);
      }

      await client.from('task_list').insert({
        'task_description': taskDescription,
        'task_date': taskDate.toIso8601String().split('T')[0],
        'repeat_option': repeatOption,
        'checked': false,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Task saved successfully with image: $taskDescription');
    } catch (e) {
      debugPrint('Error saving task: $e');
      throw Exception('Failed to save task: $e');
    }
  }

  // Upload task image to Supabase Storage
  static Future<String?> uploadTaskImage(File imageFile) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'task_$timestamp.$extension';

      // Upload to Supabase Storage
      final String filePath = await client.storage
          .from('task-images')
          .upload(fileName, imageFile);

      // Get public URL
      final String publicUrl = client.storage
          .from('task-images')
          .getPublicUrl(fileName);

      debugPrint('Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Download task image
  static Future<Uint8List?> downloadTaskImage(String imageUrl) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;

      // Download from Supabase Storage
      final Uint8List imageData = await client.storage
          .from('task-images')
          .download(fileName);

      return imageData;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  // Delete task image
  static Future<bool> deleteTaskImage(String imageUrl) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;

      // Delete from Supabase Storage
      await client.storage
          .from('task-images')
          .remove([fileName]);

      debugPrint('Image deleted successfully: $fileName');
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  // Add these methods to handle recurring tasks
  static Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      final dateString = date.toIso8601String().split('T')[0];
      final today = DateTime.now();
      final todayString = today.toIso8601String().split('T')[0];

      // Get direct tasks for this date
      final directTasks = await client
          .from('task_list')
          .select()
          .eq('task_date', dateString)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> allTasks = List<Map<String, dynamic>>.from(directTasks);

      // Get daily recurring tasks created before or on the requested date
      final dailyTasks = await client
          .from('task_list')
          .select()
          .eq('repeat_option', 'Daily')
          .lte('task_date', dateString)
          .order('created_at', ascending: false);

      for (final task in dailyTasks) {
        final taskDate = DateTime.parse(task['task_date']);
        // Only include if the requested date is on or after the task's original date
        if (!date.isBefore(taskDate)) {
          // Create a copy of the task with the requested date
          final recurringTask = Map<String, dynamic>.from(task);
          recurringTask['task_date'] = dateString;
          recurringTask['is_recurring'] = true;
          recurringTask['original_date'] = task['task_date'];
          allTasks.add(recurringTask);
        }
      }

      // Get weekly recurring tasks
      final weeklyTasks = await client
          .from('task_list')
          .select()
          .eq('repeat_option', 'Weekly')
          .lte('task_date', dateString)
          .order('created_at', ascending: false);

      for (final task in weeklyTasks) {
        final taskDate = DateTime.parse(task['task_date']);
        // Check if the requested date falls on the same weekday as the original task
        if (!date.isBefore(taskDate) && date.weekday == taskDate.weekday) {
          // Create a copy of the task with the requested date
          final recurringTask = Map<String, dynamic>.from(task);
          recurringTask['task_date'] = dateString;
          recurringTask['is_recurring'] = true;
          recurringTask['original_date'] = task['task_date'];
          allTasks.add(recurringTask);
        }
      }

      // Remove duplicates based on task description and date
      final uniqueTasks = <String, Map<String, dynamic>>{};
      for (final task in allTasks) {
        final key = '${task['task_description']}_${task['task_date']}_${task['repeat_option']}';
        if (!uniqueTasks.containsKey(key) || 
            (uniqueTasks[key]!['is_recurring'] == true && task['is_recurring'] != true)) {
          uniqueTasks[key] = task;
        }
      }

      final result = uniqueTasks.values.toList();
      debugPrint('Loaded ${result.length} tasks for date: $dateString (${directTasks.length} direct, ${result.length - directTasks.length} recurring)');
      
      return result;
    } catch (e) {
      debugPrint('Error getting tasks for date: $e');
      return [];
    }
  }

  static Future<void> updateTaskStatus(int taskId, bool isChecked, {bool isRecurring = false, String? taskDate}) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      if (isRecurring && taskDate != null) {
        // For recurring tasks, we need to create a separate record for the specific date
        // to track its completion status independently
        final originalTask = await client
            .from('task_list')
            .select()
            .eq('id', taskId)
            .single();

        // Check if we already have a completion record for this date
        final existingRecord = await client
            .from('task_completions')
            .select()
            .eq('original_task_id', taskId)
            .eq('completion_date', taskDate)
            .maybeSingle();

        if (existingRecord != null) {
          // Update existing completion record
          await client
              .from('task_completions')
              .update({
                'completed': isChecked,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingRecord['id']);
        } else {
          // Create new completion record
          await client.from('task_completions').insert({
            'original_task_id': taskId,
            'completion_date': taskDate,
            'completed': isChecked,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // For non-recurring tasks, update directly
        await client
            .from('task_list')
            .update({
              'checked': isChecked,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', taskId);
      }

      debugPrint('Task status updated: $taskId -> $isChecked (recurring: $isRecurring)');
    } catch (e) {
      debugPrint('Error updating task status: $e');
      throw Exception('Failed to update task status: $e');
    }
  }

  // Delete task from database
  static Future<void> deleteTask(int taskId) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // First get the task to check if it has an image
      final task = await client
          .from('task_list')
          .select('image_url')
          .eq('id', taskId)
          .maybeSingle();

      // Delete the image from storage if it exists
      if (task != null && task['image_url'] != null) {
        await deleteTaskImage(task['image_url']);
      }

      // Delete the task from database
      await client
          .from('task_list')
          .delete()
          .eq('id', taskId);

      // Also delete any completion records for recurring tasks
      await client
          .from('task_completions')
          .delete()
          .eq('original_task_id', taskId);

      debugPrint('Task deleted successfully: $taskId');
    } catch (e) {
      debugPrint('Error deleting task: $e');
      throw Exception('Failed to delete task: $e');
    }
  }
}