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

class _PlaceSearchBarState extends State<PlaceSearchBar>
    with SingleTickerProviderStateMixin {
  final GeocodingService _geocodingService = GeocodingService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  List<PlaceSuggestion> _suggestions = [];

  /// Az utolsó nem-üres suggestions lista.
  /// A bezáró animáció alatt még ezt rendereljük, hogy ne ugorjon üresre.
  List<PlaceSuggestion> _lastNonEmptySuggestions = [];

  /// Nyomon követjük, hogy a billentyűzet látható volt-e az előző frame-ben.
  bool _wasKeyboardVisible = false;

  // ---------------------------------------------------------------
  // ANIMÁCIÓ: A lista megjelenését/eltűnését smooth-á teszi.
  // SizeTransition + FadeTransition — NEM töri el a Flexible-t.
  // ---------------------------------------------------------------
  late final AnimationController _listAnimController;
  late final Animation<double> _listSizeFactor;
  late final Animation<double> _listOpacity;

  @override
  void initState() {
    super.initState();

    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Smooth easing a méretváltozáshoz
    _listSizeFactor = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Az opacity kicsit gyorsabban ér el 1-re mint a méret → kellemesebb hatás
    _listOpacity = CurvedAnimation(
      parent: _listAnimController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 3) {
      _setSuggestions([]);
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _geocodingService.searchPlaces(query);
      if (mounted) {
        _setSuggestions(results);
        setState(() => _isLoading = false);
      }
    });
  }

  /// Központi setter: kezeli az animáció indítását is.
  void _setSuggestions(List<PlaceSuggestion> newSuggestions) {
    final bool wasEmpty = _suggestions.isEmpty;
    final bool willBeEmpty = newSuggestions.isEmpty;

    setState(() {
      _suggestions = newSuggestions;
      if (newSuggestions.isNotEmpty) {
        _lastNonEmptySuggestions = newSuggestions;
      }
    });

    if (wasEmpty && !willBeEmpty) {
      // Lista megjelenik → forward animáció
      _listAnimController.forward();
    } else if (!wasEmpty && willBeEmpty) {
      // Lista eltűnik → reverse animáció
      _listAnimController.reverse();
    }
  }

  void _selectPlace(PlaceSuggestion place) {
    // Először unfocus, utána setState — így a billentyűzet NEM jön vissza
    _focusNode.unfocus();
    _setSuggestions([]);
    setState(() {
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
    // ---------------------------------------------------------------
    if (_wasKeyboardVisible && !isKeyboardVisible && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      });
    }
    _wasKeyboardVisible = isKeyboardVisible;

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
          // A lista MINDIG a widget tree-ben van (nem if-fel vezérelve),
          // a SizeTransition 0-ra animálja ha üres → nincs layout ugrás.
          // ---------------------------------------------------------------
          _buildAnimatedSuggestionsList(),
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

  /// Animált wrapper: SizeTransition + FadeTransition.
  /// A Flexible KÖZVETLENÜL a Column gyereke marad → nem töri el a flex-et.
  Widget _buildAnimatedSuggestionsList() {
    return Flexible(
      child: SizeTransition(
        sizeFactor: _listSizeFactor,
        axisAlignment: -1.0, // Felülről lefelé nyílik
        child: FadeTransition(
          opacity: _listOpacity,
          child: _buildSuggestionsListContent(),
        ),
      ),
    );
  }

  /// A tényleges lista tartalom — kiemelve a tiszta SoC érdekében.
  Widget _buildSuggestionsListContent() {
    // A bezáró animáció alatt a _lastNonEmptySuggestions-t rendereljük,
    // hogy ne villanjon üresre mielőtt összezárul.
    final displayItems = _suggestions.isNotEmpty
        ? _suggestions
        : _lastNonEmptySuggestions;

    // Ha soha nem volt suggestion, ne rendereljünk semmit
    if (displayItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,

        // A NotificationListener elfogja a görgetést, így az AppBar nem színeződik el
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) => true,
          child: Stack(
            children: [
              // A tényleges lista — shrinkWrap NÉLKÜL!
              // A Flexible már biztosít bounded constraints-et.
              Scrollbar(
                radius: const Radius.circular(8),
                thickness: 4,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: displayItems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = displayItems[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(place.name),
                      subtitle: Text(place.formattedAddress),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),

              // Fade effekt a lista alján
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
    );
  }
}
