import '../screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'services/supabase_service.dart';
import 'services/tracking_service.dart';
import 'services/device_location.dart';
import 'services/background_location_service.dart';

void main() async {
  // This needs to be called before any platform channels are accessed
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // First load env variables
    await dotenv.load(fileName: ".env");
    debugPrint('Environment variables loaded');
    
    // Then initialize Mapbox
    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken != null) {
      MapboxOptions.setAccessToken(mapboxToken);
      debugPrint('Mapbox initialized');
    }
    
    // Initialize device info first and wait for it to complete
    debugPrint('Initializing device info...');
    await DeviceLocation.initializeDeviceInfo();
    debugPrint('Device info initialized');
    
    // Initialize background location service
    await BackgroundLocationService.initializeService();
    debugPrint('Background location service initialized');
    
    // Try to initialize Supabase but don't block app launch if it fails
    try {
      await SupabaseService.initialize();
      debugPrint('Supabase initialized successfully');
      
      // Initialize tracking service after Supabase
      await TrackingService().initialize();
      debugPrint('Tracking service initialized');
    } catch (e) {
      // Just log the error but continue app launch
      debugPrint('Supabase initialization failed: $e');
      // We'll retry connecting later when needed
    }
  } catch (e) {
    debugPrint('Error during initialization: $e');
  }
  
  // Always launch the app even if some services failed
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.grey,
          selectionHandleColor: Colors.black,
        ),
      ),
      home: MapScreen(),
    );
  }
}
