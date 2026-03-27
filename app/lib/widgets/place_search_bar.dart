// app/lib/widgets/place_search_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_suggestion.dart';
import '../services/geocoding_service.dart';

class PlaceSearchBar extends StatefulWidget {
  final Function(LatLng) onPlaceSelected;

  /// A szülő LayoutBuilder constraints.maxHeight értéke.
  /// Ez NEM változik a billentyűzet megjelenésekor (mert resizeToAvoidBottomInset: false).
  final double parentConstraintsHeight;

  const PlaceSearchBar({
    super.key,
    required this.onPlaceSelected,
    required this.parentConstraintsHeight,
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

  /// Nyomon követjük, hogy a billentyűzet látható volt-e az előző frame-ben.
  /// Ha igen és most már nem → a felhasználó bezárta (vissza gomb / swipe),
  /// tehát el kell engedni a focus-t, hogy a kurzor ne villogjon tovább.
  bool _wasKeyboardVisible = false;

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
    // Először unfocus, utána setState — így a billentyűzet NEM jön vissza
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _controller.text = place.name;
    });
    widget.onPlaceSelected(LatLng(place.lat, place.lon));
  }

  @override
  Widget build(BuildContext context) {
    // ---------------------------------------------------------------
    // A viewInsets-et ITT olvassuk, NEM a HomeScreen-ben!
    // Így a billentyűzet animáció során CSAK ez a widget épül újra.
    // ---------------------------------------------------------------
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isKeyboardVisible = bottomInset > 0;

    // ---------------------------------------------------------------
    // AUTO-UNFOCUS: Ha a billentyűzet eltűnt (vissza gomb / swipe)
    // de a FocusNode még aktív → unfocus, hogy a kurzor ne villogjon.
    // Post-frame callback-ben csináljuk, mert build közben nem
    // szabad állapotot változtatni.
    //
    // Ez megoldja azt is, hogy a modal bezárása után ne jöjjön vissza
    // a billentyűzet: mire a modal eltűnik, a focus már nincs a
    // SearchBar-on.
    // ---------------------------------------------------------------
    if (_wasKeyboardVisible && !isKeyboardVisible && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      });
    }
    _wasKeyboardVisible = isKeyboardVisible;

    // A keresősáv pozíciója (top: 16) + biztonsági margin
    final double maxHeight =
        widget.parentConstraintsHeight - 32.0 - bottomInset;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight.clamp(100.0, double.infinity),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(child: _buildSearchInput()),
          // ---------------------------------------------------------------
          // JAVÍTÁS: A Flexible KÖZVETLENÜL a Column gyereke!
          // Az előző verzióban az AnimatedSize törte a flex constraint
          // propagálást → BOTTOM OVERFLOW (440px / 868px).
          // ---------------------------------------------------------------
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
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,

          // A NotificationListener elfogja a görgetést, így az AppBar nem színeződik el
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) => true,
            child: Stack(
              children: [
                // A tényleges lista — shrinkWrap ELTÁVOLÍTVA!
                // A Flexible már biztosít bounded constraints-et,
                // shrinkWrap nélkül a ListView CSAK annyi helyet foglal,
                // amennyit a Flexible/ConstrainedBox megenged.
                Scrollbar(
                  radius: const Radius.circular(8),
                  thickness: 4,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16.0),
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

                // Fade effekt a lista alján — olcsó DecoratedBox, nem ShaderMask
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).cardColor.withOpacity(0.0),
                            Theme.of(context).cardColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
