import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888, // using notificationId instead of notificationTitle
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // DartPluginRegistrant.ensureInitialized(); // not needed for your setup

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  // Listen for location updates and send to notification
  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  ).listen((Position position) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Location Tracking",
        content: "Lat: ${position.latitude}, Long: ${position.longitude}",
      );
    }
    // You can also save to local storage or send to server here
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Background Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Location & BLE Tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _locationInfo = "No location data";
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  // Bluetooth related variables
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  Map<String, BluetoothDevice> _connectedDevices = {};

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _adapterState = state;
      });
    });
    // listen for disconnects and update UI
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (event.connectionState == BluetoothConnectionState.disconnected) {
        setState(() {
          _connectedDevices.remove(event.device.id.id);
        });
      }
    });
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable them.')));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied')));
      return false;
    }
    return true;
  }

  void _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;

    setState(() {
      _isTracking = true;
      _locationInfo = "Getting location...";
    });

    print("Location tracking started...");

    // Start background service
    FlutterBackgroundService().startService();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _locationInfo =
              'Latitude: ${position.latitude}\n'
              'Longitude: ${position.longitude}';
        });

        print("Location update: Lat: ${position.latitude}, Long: ${position.longitude}");
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _locationInfo = "Error getting location: $e";
        });
        print("Location error: $e");
      }
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isTracking = false;
      _locationInfo = "Location tracking stopped";
    });
    print("Location tracking stopped");
    FlutterBackgroundService().invoke('stopService');
  }

  // Bluetooth scanning methods
  Future<void> _startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth is not enabled')),
      );
      return;
    }

    // Request runtime permissions for Android 12+
    var bluetoothScanPermission = await Permission.bluetoothScan.request();
    var bluetoothConnectPermission = await Permission.bluetoothConnect.request();
    var locationPermission = await Permission.location.request();

    if (bluetoothScanPermission != PermissionStatus.granted ||
        locationPermission != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth and location permissions are required')),
      );
      return;
    }

    setState(() {
      _scanResults = [];
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.stopScan();

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          setState(() {
            _scanResults = results;
          });
        },
        onError: (e) {
          print("Scan error: $e");
          _stopScan();
        }
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      print("Error starting scan: $e");
      setState(() {
        _isScanning = false;
      });
    }

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _isScanning) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      if (_connectedDevices.containsKey(device.id.id)) {
        await device.disconnect();
        setState(() {
          _connectedDevices.remove(device.id.id);
        });
      } else {
        await device.connect();
        setState(() {
          _connectedDevices[device.id.id] = device;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Location section
              Text(
                'Location Data:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(
                  _locationInfo,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isTracking ? null : _getCurrentLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: const Icon(Icons.location_off),
                    label: const Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),
              
              // Bluetooth section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bluetooth Devices:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    _adapterState == BluetoothAdapterState.on ? "Bluetooth ON" : "Bluetooth OFF",
                    style: TextStyle(
                      color: _adapterState == BluetoothAdapterState.on ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startScan,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan for Devices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScan : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _isScanning 
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox(),
              const SizedBox(height: 10),
              
              // Display scan results
              ..._scanResults
                .where((result) => result.device.name == "WioTerminal")
                .map(
                  (result) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(result.device.name),
                      subtitle: Text(result.device.id.id),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _connectToDevice(result.device);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _connectedDevices.containsKey(result.device.id.id)
                                  ? Colors.green
                                  : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: const Size(60, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _connectedDevices.containsKey(result.device.id.id)
                                  ? "Connected"
                                  : "Connect",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text("${result.rssi} dBm", style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () async {
                        if (_connectedDevices.containsKey(result.device.id.id)) {
                          String blePayload = "";
                          try {
                            List<BluetoothService> services = await result.device.discoverServices();
                            final service = services.firstWhere(
                              (s) => s.uuid.toString().toLowerCase() == "12345678-1234-5678-1234-56789abcdef0",
                              orElse: () => services.first,
                            );
                            final characteristic = service.characteristics.firstWhere(
                              (c) => c.uuid.toString().toLowerCase() == "abcdefab-cdef-1234-5678-1234567890ab",
                              orElse: () => service.characteristics.first,
                            );
                            var value = await characteristic.read();
                            blePayload = String.fromCharCodes(value);
                          } catch (e) {
                            blePayload = "Error reading BLE payload: $e";
                          }
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Message: $blePayload",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  )
                ).toList(),
              
              if (_scanResults.isEmpty && !_isScanning)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text("No devices found"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}