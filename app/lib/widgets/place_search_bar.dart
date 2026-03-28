// app/lib/widgets/place_search_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/place_suggestion.dart';
import '../models/geocoding_result.dart';
import '../services/geocoding_service.dart';

class PlaceSearchBar extends StatefulWidget {
  /// Hely kiválasztásakor a teljes PlaceSuggestion-t visszaadjuk,
  /// hogy a hívó fél (HomeScreen) eldönthesse a zoom szintet az extent alapján.
  final Function(PlaceSuggestion) onPlaceSelected;

  /// Callback a keresés törlésekor (X gomb vagy üres keresőmező).
  final VoidCallback? onSearchCleared;

  /// A szülő LayoutBuilder constraints.maxHeight értéke.
  /// Ez NEM változik a billentyűzet megjelenésekor (mert resizeToAvoidBottomInset: false).
  final double parentConstraintsHeight;

  const PlaceSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onSearchCleared,
    required this.parentConstraintsHeight,
  });

  @override
  State<PlaceSearchBar> createState() => PlaceSearchBarState();
}

/// Publikus State osztály, hogy a HomeScreen GlobalKey-n keresztül
/// meghívhassa a [clearSearch] metódust (pl. boltos pin koppintáskor).
class PlaceSearchBarState extends State<PlaceSearchBar>
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

  /// Aktuális hibatípus — null, ha nincs hiba.
  /// Nem üres lista és hiba egyszerre nem fordulhat elő,
  /// mert hiba esetén a _suggestions mindig [].
  GeocodingErrorKind? _errorKind;

  /// Nincs találat jelzés — true, ha a keresés sikeres volt, de 0 eredmény jött.
  bool _isEmptyResult = false;

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
      _clearStatusFlags();
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await _geocodingService.searchPlaces(query);
      if (!mounted) return;

      switch (result) {
        case GeocodingSuccess(:final suggestions):
          _setSuggestions(suggestions);
          setState(() {
            _isLoading = false;
            _errorKind = null;
            _isEmptyResult = suggestions.isEmpty;
          });
          // Ha nincs találat, megmutatjuk a "nincs találat" panelt
          if (suggestions.isEmpty) {
            _showStatusPanel();
          }

        case GeocodingError(:final kind):
          _setSuggestions([]);
          setState(() {
            _isLoading = false;
            _errorKind = kind;
            _isEmptyResult = false;
          });
          // Hiba esetén megmutatjuk a hiba panelt
          _showStatusPanel();
      }
    });
  }

  /// Állapotjelző flagek törlése (hiba / nincs találat).
  void _clearStatusFlags() {
    if (_errorKind != null || _isEmptyResult) {
      setState(() {
        _errorKind = null;
        _isEmptyResult = false;
      });
    }
  }

  /// A státusz panel (hiba vagy "nincs találat") megjelenítése animációval.
  /// Csak akkor indít forward-ot, ha az animáció még nincs kinyitva.
  void _showStatusPanel() {
    if (_listAnimController.status != AnimationStatus.completed &&
        _listAnimController.status != AnimationStatus.forward) {
      _listAnimController.forward();
    }
  }

  /// Központi setter: kezeli az animáció indítását is.
  void _setSuggestions(List<PlaceSuggestion> newSuggestions) {
    final bool wasVisible =
        _suggestions.isNotEmpty || _errorKind != null || _isEmptyResult;
    final bool willBeVisible = newSuggestions.isNotEmpty;

    setState(() {
      _suggestions = newSuggestions;
      if (newSuggestions.isNotEmpty) {
        _lastNonEmptySuggestions = newSuggestions;
      }
    });

    if (!wasVisible && willBeVisible) {
      // Lista megjelenik → forward animáció
      _listAnimController.forward();
    } else if (wasVisible &&
        !willBeVisible &&
        _errorKind == null &&
        !_isEmptyResult) {
      // Lista eltűnik (és nincs hiba/üres panel sem) → reverse animáció
      _listAnimController.reverse();
    }
  }

  void _selectPlace(PlaceSuggestion place) {
    // Először unfocus, utána setState — így a billentyűzet NEM jön vissza
    _focusNode.unfocus();
    _setSuggestions([]);
    _clearStatusFlags();
    setState(() {
      _controller.text = place.name;
    });
    widget.onPlaceSelected(place);
  }

  /// Újrapróbálkozás: az aktuális szövegre újra keres.
  void _retrySearch() {
    final query = _controller.text;
    if (query.trim().length >= 3) {
      _clearStatusFlags();
      _listAnimController.reverse();
      _onSearchChanged(query);
    }
  }

  /// Publikus metódus: keresés teljes törlése kívülről (pl. boltos pin koppintás).
  /// A HomeScreen GlobalKey-n keresztül hívja meg.
  void clearSearch() {
    _debounce?.cancel();
    _focusNode.unfocus();
    _setSuggestions([]);
    _clearStatusFlags();
    setState(() {
      _controller.clear();
      _isLoading = false;
    });
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
              // Értesítjük a szülőt, hogy a keresés törölve lett → pin eltűnik
              widget.onSearchCleared?.call();
            },
          ),
      ],
    );
  }

  /// Animált wrapper: SizeTransition + FadeTransition.
  /// A Flexible KÖZVETLENÜL a Column gyereke marad → nem töri el a flex-et.
  Widget _buildAnimatedSuggestionsList() {
    // Tartalom meghatározása: hiba > üres találat > normál lista
    final Widget content;
    if (_errorKind != null) {
      content = _buildErrorTile();
    } else if (_isEmptyResult) {
      content = _buildEmptyResultTile();
    } else {
      // Ha a lista üres ÉS az animáció NEM játszik épp → a cache-elt listát mutatjuk
      final displayItems = _suggestions.isNotEmpty
          ? _suggestions
          : _lastNonEmptySuggestions;
      content = _buildSuggestionListView(displayItems);
    }

    return Flexible(
      child: SizeTransition(
        sizeFactor: _listSizeFactor,
        axisAlignment: -1.0, // Felülről nyílik lefelé
        child: FadeTransition(
          opacity: _listOpacity,
          child: Card(
            margin: const EdgeInsets.only(top: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4.0,
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ),
    );
  }

  /// Normál találati lista ScrollView-val és fade effekttel.
  Widget _buildSuggestionListView(List<PlaceSuggestion> displayItems) {
    return Stack(
      children: [
        // A Flexible már biztosít bounded constraints-et.
        Scrollbar(
          radius: const Radius.circular(8),
          thickness: 4,
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16.0),
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: displayItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
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
    );
  }

  /// "Nincs találat" állapotjelző tile.
  Widget _buildEmptyResultTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nincs találat erre a keresésre.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hálózati/szerver hiba állapotjelző tile "Újra" gombbal.
  Widget _buildErrorTile() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Icon(
            _errorIconForKind(_errorKind!),
            color: colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessageForKind(_errorKind!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _retrySearch,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Újra'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  /// Magyar nyelvű hibaüzenet a hibatípus alapján.
  String _errorMessageForKind(GeocodingErrorKind kind) {
    switch (kind) {
      case GeocodingErrorKind.network:
        return 'Nincs internetkapcsolat.';
      case GeocodingErrorKind.timeout:
        return 'A keresés időtúllépés miatt sikertelen.';
      case GeocodingErrorKind.server:
        return 'A keresőszerver átmenetileg nem elérhető.';
      case GeocodingErrorKind.unknown:
        return 'Nem sikerült végrehajtani a keresést.';
    }
  }

  /// Ikon a hibatípus alapján.
  IconData _errorIconForKind(GeocodingErrorKind kind) {
    switch (kind) {
      case GeocodingErrorKind.network:
        return Icons.wifi_off_rounded;
      case GeocodingErrorKind.timeout:
        return Icons.timer_off_rounded;
      case GeocodingErrorKind.server:
        return Icons.cloud_off_rounded;
      case GeocodingErrorKind.unknown:
        return Icons.error_outline_rounded;
    }
  }
}
