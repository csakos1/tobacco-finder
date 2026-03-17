// app/lib/widgets/place_search_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_suggestion.dart';
import '../services/geocoding_service.dart';

class PlaceSearchBar extends StatefulWidget {
  final Function(LatLng) onPlaceSelected;
  final double maxAvailableHeight; // <-- ÚJ: Ezt fogja megkapni a főképernyőtől

  const PlaceSearchBar({
    super.key,
    required this.onPlaceSelected,
    required this.maxAvailableHeight, // <-- ÚJ
  });

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
    return ConstrainedBox(
      // --- ÚJ: A külső maximum magasságot itt állítjuk be ---
      constraints: BoxConstraints(maxHeight: widget.maxAvailableHeight),
      child: Column(
        mainAxisSize:
            MainAxisSize.min, // Csak akkora legyen a Column, amekkora muszáj
        children: [
          _buildSearchInput(),
          if (_suggestions.isNotEmpty) _buildSuggestionsList(),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return SearchBar(
      controller: _controller,
      focusNode: _focusNode,
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.only(left: 16.0, right: 16.0),
      ),
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
    );
  }

  Widget _buildSuggestionsList() {
    return Flexible(
      // --- ÚJ: A Flexible engedi, hogy a lista dinamikusan kitöltse a rendelkezésre álló magasságot ---
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8.0,
        ), // Itt már nem kell alsó margó, a LayoutBuilder megoldja
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,

          // --- ÚJ: A NotificationListener elfogja a görgetést, így az AppBar NEM SZÍNEZŐDIK EL! ---
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) => true,
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.90, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Scrollbar(
                radius: const Radius.circular(8),
                thickness: 4,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
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
          ),
        ),
      ),
    );
  }
}
