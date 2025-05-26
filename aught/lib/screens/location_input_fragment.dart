import 'package:flutter/material.dart';
import '../services/mapbox_search_service.dart';
import 'dart:async';

class LocationInputScreen extends StatefulWidget {
  final String title;
  final String? initialValue;

  const LocationInputScreen({
    super.key,
    required this.title,
    this.initialValue,
  });

  @override
  State<LocationInputScreen> createState() => _LocationInputScreenState();
}

class _LocationInputScreenState extends State<LocationInputScreen> {
  late TextEditingController _controller;
  List<MapboxSearchResult> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_controller.text);
    });
  }

  void _clearText() {
    _controller.clear();
    setState(() {
      _searchResults = [];
      _isLoading = false;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the comprehensive search for better results
      final results = await MapboxSearchService.comprehensiveSearch(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Search error: $e');
    }
  }

  String _extractMainPlaceName(String fullPlaceName) {
    // Extract the main place name (first part before the first comma)
    final parts = fullPlaceName.split(',');
    return parts.isNotEmpty ? parts[0].trim() : fullPlaceName;
  }

  String _extractAddress(String fullPlaceName) {
    // Extract everything after the first comma as the address
    final parts = fullPlaceName.split(',');
    if (parts.length > 1) {
      return parts.sublist(1).join(',').trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search input section - fills from top with minimal padding
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 8, 
              bottom: 8,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (value) {
                // Handle Enter key press
                Navigator.pop(context, _controller.text);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search Anywhere..',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.0),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                prefixIcon: IconButton(
                  onPressed: () {
                    Navigator.pop(context, _controller.text);
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.black54,
                    size: 24,
                  ),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearText,
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.black54,
                          size: 20,
                        ),
                      )
                    : null,
              ),
              style: const TextStyle(color: Colors.black),
            ),
          ),

          // Search results section - starts immediately after input with no gap
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _searchResults.isEmpty && !_isLoading
                  ? Container()
                  : ListView.builder(
                      padding: EdgeInsets.zero, // Remove any default padding from ListView
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final mainPlaceName = _extractMainPlaceName(
                          result.placeName,
                        );
                        final address = _extractAddress(result.placeName);

                        return _buildSearchResultItem(
                          context,
                          mainPlaceName,
                          address,
                          result,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    String mainPlaceName,
    String address,
    MapboxSearchResult result,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: InkWell(
            onTap: () {
              // Return both name and address as a map when location is selected
              Navigator.pop(context, {
                'name': result.placeName,
                'address': result.address,
                'lat': result.latitude,
                'lng': result.longitude,
              });
            },
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 24),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mainPlaceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.address.isNotEmpty && result.address != result.placeName) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.address,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                Transform.flip(
                  flipX: true,
                  child: const Icon(
                    Icons.arrow_outward,
                    color: Colors.black54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }
}
