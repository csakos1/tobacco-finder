// app/lib/widgets/place_search_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_suggestion.dart';
import '../services/geocoding_service.dart';

class PlaceSearchBar extends StatefulWidget {
  final Function(LatLng) onPlaceSelected;

  const PlaceSearchBar({super.key, required this.onPlaceSelected});

  @override
  State<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends State<PlaceSearchBar> {
  final GeocodingService _geocodingService = GeocodingService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _geocodingService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    });
  }

  void _selectPlace(PlaceSuggestion place) {
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _controller.text = place.name;
    });
    widget.onPlaceSelected(LatLng(place.lat, place.lon));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          // --- UI VÁLTOZTATÁS: Belső margók a sávnak ---
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.only(left: 16.0, right: 16.0),
          ),
          // --- UI VÁLTOZTATÁS: A nagyító ikon beljebb tolása ---
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0, right: 8.0),
            child: Icon(Icons.search),
          ),
          hintText: 'Keress városra, címre...',
          elevation: const WidgetStatePropertyAll<double>(4.0),
          onChanged: _onSearchChanged,
          trailing: [
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _onSearchChanged('');
                  _focusNode.unfocus();
                },
              ),
          ],
        ),

        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(place.name),
                    subtitle: Text(place.formattedAddress),
                    onTap: () => _selectPlace(place),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
