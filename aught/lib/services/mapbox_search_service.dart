import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;

class MapboxSearchResult {
  final String placeName;
  final String address;
  final double longitude;
  final double latitude;
  final String? category;
  final String? properties;
  final String source;
  double relevanceScore = 0.0; // Add relevance score

  MapboxSearchResult({
    required this.placeName,
    required this.address,
    required this.longitude,
    required this.latitude,
    this.category,
    this.properties,
    this.source = 'mapbox',
  });

  factory MapboxSearchResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final coordinates = geometry['coordinates'] as List;

    final properties = json['properties'] as Map<String, dynamic>?;
    final category = properties?['category'] as String?;
    
    // Extract proper address from place_name or use address field
    String address = '';
    final placeName = json['place_name'] ?? '';
    final context = json['context'] as List?;
    
    // Try to get address from properties first
    if (properties?['address'] != null) {
      address = properties!['address'];
    }
    // If no direct address, extract from place_name (everything after first comma)
    else if (placeName.contains(',')) {
      final parts = placeName.split(',');
      if (parts.length > 1) {
        address = parts.sublist(1).join(',').trim();
      }
    }
    // Try to build address from context
    else if (context != null && context.isNotEmpty) {
      final addressParts = <String>[];
      for (final item in context) {
        if (item is Map<String, dynamic> && item['text'] != null) {
          addressParts.add(item['text']);
        }
      }
      address = addressParts.join(', ');
    }

    return MapboxSearchResult(
      placeName: _extractMainName(placeName),
      address: address.isNotEmpty ? address : placeName,
      longitude: coordinates[0].toDouble(),
      latitude: coordinates[1].toDouble(),
      category: category,
      properties: properties?.toString(),
      source: 'mapbox',
    );
  }

  // Helper method to extract main name from place_name
  static String _extractMainName(String placeName) {
    if (placeName.contains(',')) {
      return placeName.split(',').first.trim();
    }
    return placeName;
  }

  factory MapboxSearchResult.fromGooglePlaces(Map<String, dynamic> json) {
    final geometry = json['geometry']['location'];
    final name = json['name'] ?? '';
    final vicinity = json['vicinity'] ?? '';
    final formattedAddress = json['formatted_address'] ?? '';
    
    // Use formatted_address if available, otherwise use vicinity
    String address = formattedAddress.isNotEmpty ? formattedAddress : vicinity;
    
    // Remove the name from the address if it's at the beginning
    if (address.startsWith(name) && address.length > name.length) {
      address = address.substring(name.length).replaceFirst(RegExp(r'^,\s*'), '');
    }

    return MapboxSearchResult(
      placeName: name,
      address: address,
      longitude: geometry['lng'].toDouble(),
      latitude: geometry['lat'].toDouble(),
      category: json['types']?.first,
      properties: json['types']?.join(', '),
      source: 'google',
    );
  }
}

class MapboxSearchService {
  static const String _mapboxBaseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static const String _googlePlacesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';

  // Enhanced comprehensive search with intelligent ranking
  static Future<List<MapboxSearchResult>> comprehensiveSearch(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final List<MapboxSearchResult> allResults = [];
      final Set<String> seenPlaces = {};
      if (allResults.isEmpty && [].contains(seenPlaces)) {}// Does nothing, just a placeholder to avoid unused variable warning

      // Get results from both sources concurrently
      final results = await Future.wait([
        _searchMapbox(query),
        _searchGooglePlaces(query),
      ]);

      final mapboxResults = results[0];
      final googleResults = results[1];

      // Combine all results first
      final combinedResults = <MapboxSearchResult>[];
      combinedResults.addAll(mapboxResults);
      combinedResults.addAll(googleResults);

      // Calculate relevance scores for all results
      for (final result in combinedResults) {
        result.relevanceScore = _calculateRelevanceScore(query, result);
      }

      // Remove duplicates while keeping the highest scoring version
      final Map<String, MapboxSearchResult> uniqueResults = {};

      for (final result in combinedResults) {
        final placeKey =
            '${result.placeName.toLowerCase().trim()}_${result.longitude.toStringAsFixed(4)}_${result.latitude.toStringAsFixed(4)}';

        // Check for near-duplicate based on name similarity and proximity
        String? duplicateKey;
        for (final existingKey in uniqueResults.keys) {
          final existingResult = uniqueResults[existingKey]!;
          final distance = _calculateDistance(
            result.latitude,
            result.longitude,
            existingResult.latitude,
            existingResult.longitude,
          );

          // Consider it a duplicate if within 100 meters and similar name
          if (distance < 100 &&
              _isSimilarName(result.placeName, existingResult.placeName)) {
            duplicateKey = existingKey;
            break;
          }
        }

        if (duplicateKey != null) {
          // Keep the result with higher relevance score
          final existingResult = uniqueResults[duplicateKey]!;
          if (result.relevanceScore > existingResult.relevanceScore) {
            uniqueResults[duplicateKey] = result;
          }
        } else if (!uniqueResults.containsKey(placeKey)) {
          uniqueResults[placeKey] = result;
        }
      }

      // Convert back to list and sort by relevance score (highest first)
      allResults.addAll(uniqueResults.values);
      allResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return allResults.take(25).toList();
    } catch (e) {
      print('Error in comprehensive search: $e');
      // Fallback to Mapbox only if Google fails
      return await _searchMapbox(query);
    }
  }

  // Calculate relevance score based on multiple factors
  static double _calculateRelevanceScore(
    String query,
    MapboxSearchResult result,
  ) {
    final queryLower = query.toLowerCase().trim();
    final placeNameLower = result.placeName.toLowerCase().trim();
    final addressLower = result.address.toLowerCase().trim();

    double score = 0.0;

    // 1. Exact match gets highest score (100 points)
    if (placeNameLower == queryLower) {
      score += 100.0;
    }
    // 2. Place name starts with query (80 points)
    else if (placeNameLower.startsWith(queryLower)) {
      score += 80.0;
    }
    // 3. Place name contains query (60 points)
    else if (placeNameLower.contains(queryLower)) {
      score += 60.0;
    }
    // 4. Address contains query (30 points)
    else if (addressLower.contains(queryLower)) {
      score += 30.0;
    }

    // 5. Bonus for word-by-word matching
    final queryWords = queryLower
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final placeWords = placeNameLower
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    int matchingWords = 0;
    for (final queryWord in queryWords) {
      for (final placeWord in placeWords) {
        if (placeWord.startsWith(queryWord) || placeWord.contains(queryWord)) {
          matchingWords++;
          break;
        }
      }
    }

    if (queryWords.isNotEmpty) {
      double wordMatchPercentage = matchingWords / queryWords.length;
      score += wordMatchPercentage * 40.0; // Up to 40 bonus points
    }

    // 6. Length similarity bonus (shorter names are often more relevant)
    final lengthDifference = (placeNameLower.length - queryLower.length).abs();
    final maxLength = math.max(placeNameLower.length, queryLower.length);
    if (maxLength > 0) {
      double lengthSimilarity = 1.0 - (lengthDifference / maxLength);
      score += lengthSimilarity * 10.0; // Up to 10 bonus points
    }

    // 7. Edit distance bonus (Levenshtein distance)
    final editDistance = _calculateEditDistance(queryLower, placeNameLower);
    final maxEditLength = math.max(queryLower.length, placeNameLower.length);
    if (maxEditLength > 0) {
      double editSimilarity = 1.0 - (editDistance / maxEditLength);
      score += editSimilarity * 15.0; // Up to 15 bonus points
    }

    // 8. Source preference (small bonus for Google since it often has better business data)
    if (result.source == 'google') {
      score += 2.0;
    } else {
      score += 1.0; // Small bonus for Mapbox
    }

    // 9. Category bonus (POIs and businesses get slight preference)
    if (result.category != null && result.category!.isNotEmpty) {
      score += 3.0;
    }

    return score;
  }

  // Calculate Levenshtein distance (edit distance) between two strings
  static int _calculateEditDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[a.length][b.length];
  }

  // Mapbox search method
  static Future<List<MapboxSearchResult>> _searchMapbox(String query) async {
    try {
      final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (accessToken == null) {
        throw Exception('Mapbox access token not found');
      }

      final encodedQuery = Uri.encodeComponent(query);
      final List<MapboxSearchResult> allResults = [];
      final Set<String> seenPlaces = {};

      final urls = [
        '$_mapboxBaseUrl/$encodedQuery.json?access_token=$accessToken&limit=8&autocomplete=true&fuzzyMatch=true&language=en&types=country,region,postcode,district,place,locality,neighborhood,address,poi&routing=true&worldview=us',
        '$_mapboxBaseUrl/$encodedQuery.json?access_token=$accessToken&limit=10&autocomplete=true&fuzzyMatch=true&types=poi&category=restaurant,food,shop,retail,accommodation,entertainment,health,automotive,finance,education,sports,tourism&language=en',
        '$_mapboxBaseUrl/$encodedQuery.json?access_token=$accessToken&limit=6&autocomplete=true&types=address&language=en',
        '$_mapboxBaseUrl/$encodedQuery.json?access_token=$accessToken&limit=6&autocomplete=true&types=place,locality,neighborhood&language=en',
      ];

      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url))),
      );

      for (final response in responses) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List;

          for (final feature in features) {
            final result = MapboxSearchResult.fromJson(feature);
            final placeKey =
                '${result.placeName.toLowerCase()}_${result.longitude.toStringAsFixed(6)}_${result.latitude.toStringAsFixed(6)}';

            if (!seenPlaces.contains(placeKey)) {
              seenPlaces.add(placeKey);
              allResults.add(result);
            }
          }
        }
      }

      return allResults;
    } catch (e) {
      print('Error in Mapbox search: $e');
      return [];
    }
  }

  // Google Places search method
  static Future<List<MapboxSearchResult>> _searchGooglePlaces(
    String query,
  ) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
      if (apiKey == null) {
        throw Exception('Google Places API key not found');
      }

      final encodedQuery = Uri.encodeComponent(query);

      final url =
          '$_googlePlacesBaseUrl/textsearch/json?'
          'query=$encodedQuery&'
          'key=$apiKey&'
          'type=establishment&'
          'language=en';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((result) => MapboxSearchResult.fromGooglePlaces(result))
              .toList();
        } else {
          print('Google Places API error: ${data['status']}');
          return [];
        }
      } else {
        throw Exception(
          'Failed to search Google Places: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in Google Places search: $e');
      return [];
    }
  }

  // Helper method to calculate distance between two points
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;

    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Helper method to check if two place names are similar 
  static bool _isSimilarName(String name1, String name2) {
    final clean1 = name1.toLowerCase().trim();
    final clean2 = name2.toLowerCase().trim();

    return clean1.contains(clean2) ||
        clean2.contains(clean1) ||
        clean1 == clean2;
  }

  // Keep existing methods for backward compatibility
  static Future<List<MapboxSearchResult>> searchPlaces(String query) async {
    return comprehensiveSearch(query);
  }

  static Future<List<MapboxSearchResult>> searchBusinesses(String query) async {
    return _searchGooglePlaces(query);
  }

  static Future<List<MapboxSearchResult>> searchWithLocationBias(
    String query,
    double? userLat,
    double? userLon,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final List<MapboxSearchResult> allResults = [];

      final results = await Future.wait([
        _searchMapboxWithBias(query, userLat, userLon),
        _searchGooglePlacesWithBias(query, userLat, userLon),
      ]);

      final mapboxResults = results[0];
      final googleResults = results[1];

      // Apply the same intelligent ranking system for location-biased search
      final combinedResults = <MapboxSearchResult>[];
      combinedResults.addAll(mapboxResults);
      combinedResults.addAll(googleResults);

      // Calculate relevance scores
      for (final result in combinedResults) {
        result.relevanceScore = _calculateRelevanceScore(query, result);

        // Add proximity bonus if user location is provided
        if (userLat != null && userLon != null) {
          final distance = _calculateDistance(
            userLat,
            userLon,
            result.latitude,
            result.longitude,
          );
          // Closer places get bonus points (up to 20 points for places within 1km)
          final proximityBonus = math.max(
            0,
            20 - (distance / 50),
          ); // 50m = 1 point deduction
          result.relevanceScore += proximityBonus;
        }
      }

      // Remove duplicates and sort by relevance
      final Map<String, MapboxSearchResult> uniqueResults = {};

      for (final result in combinedResults) {
        final placeKey =
            '${result.placeName.toLowerCase().trim()}_${result.longitude.toStringAsFixed(4)}_${result.latitude.toStringAsFixed(4)}';

        String? duplicateKey;
        for (final existingKey in uniqueResults.keys) {
          final existingResult = uniqueResults[existingKey]!;
          final distance = _calculateDistance(
            result.latitude,
            result.longitude,
            existingResult.latitude,
            existingResult.longitude,
          );

          if (distance < 100 &&
              _isSimilarName(result.placeName, existingResult.placeName)) {
            duplicateKey = existingKey;
            break;
          }
        }

        if (duplicateKey != null) {
          final existingResult = uniqueResults[duplicateKey]!;
          if (result.relevanceScore > existingResult.relevanceScore) {
            uniqueResults[duplicateKey] = result;
          }
        } else if (!uniqueResults.containsKey(placeKey)) {
          uniqueResults[placeKey] = result;
        }
      }

      allResults.addAll(uniqueResults.values);
      allResults.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      return allResults.take(20).toList();
    } catch (e) {
      print('Error in location-biased search: $e');
      return [];
    }
  }

  static Future<List<MapboxSearchResult>> _searchMapboxWithBias(
    String query,
    double? userLat,
    double? userLon,
  ) async {
    try {
      final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (accessToken == null) return [];

      final encodedQuery = Uri.encodeComponent(query);

      String proximityParam = '';
      if (userLat != null && userLon != null) {
        proximityParam = '&proximity=$userLon,$userLat';
      }

      final url =
          '$_mapboxBaseUrl/$encodedQuery.json?'
          'access_token=$accessToken&'
          'limit=10&'
          'autocomplete=true&'
          'fuzzyMatch=true&'
          'types=poi,address,place,locality,neighborhood&'
          'category=restaurant,food,shop,retail,accommodation,entertainment,health,automotive,finance,education,sports,tourism,attraction,services&'
          'language=en'
          '$proximityParam';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features
            .map((feature) => MapboxSearchResult.fromJson(feature))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error in Mapbox location-biased search: $e');
      return [];
    }
  }

  static Future<List<MapboxSearchResult>> _searchGooglePlacesWithBias(
    String query,
    double? userLat,
    double? userLon,
  ) async {
    try {
      final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
      if (apiKey == null) return [];

      final encodedQuery = Uri.encodeComponent(query);

      String locationParam = '';
      if (userLat != null && userLon != null) {
        locationParam = '&location=$userLat,$userLon&radius=10000';
      }

      final url =
          '$_googlePlacesBaseUrl/textsearch/json?'
          'query=$encodedQuery&'
          'key=$apiKey&'
          'type=establishment&'
          'language=en'
          '$locationParam';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results
              .map((result) => MapboxSearchResult.fromGooglePlaces(result))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error in Google Places location-biased search: $e');
      return [];
    }
  }

  static Future<List<MapboxSearchResult>> searchSpecificType(
    String query,
    String type,
  ) async {
    return _searchMapbox(query);
  }

  // Reverse geocoding - Convert coordinates to address
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (accessToken == null) {
        print('Mapbox access token not found');
        return null;
      }

      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$accessToken&types=address,locality,place,neighborhood,poi&limit=1';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          // Return the place name (full address)
          return features[0]['place_name'];
        }
        return null;
      } else {
        print('Failed to reverse geocode: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
      return null;
    }
  }
}
