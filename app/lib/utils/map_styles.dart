// app/lib/utils/map_styles.dart

class MapStyles {
  // Világos mód: Gyári térkép POI-k nélkül, szürkébb, körvonal nélküli utakkal a jobb kontrasztért.
  static const String lightStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#d4d4d4" }
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "geometry.stroke",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#bcbcbc" }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry.stroke",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#a8a8a8" }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        { "visibility": "off" }
      ]
    }
  ]
  ''';

  // Sötét mód: Google Maps Night téma, POI-k nélkül, MEGNÖVELT út kontraszttal (Ezt jónak ítélted, így maradt).
  static const String darkStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        { "color": "#242f3e" }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#746855" }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        { "color": "#242f3e" }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#d59563" }
      ]
    },
    {
      "featureType": "poi",
      "stylers": [
        { "visibility": "off" }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        { "color": "#263c3f" }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#6b9a76" }
      ]
    },
    
    /* --- UTAK KIEMELÉSE (DARK MODE) --- */
    {
      "featureType": "road.local",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#4a596e" } 
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#1a232f" },
        { "weight": 1.2 }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry.fill",
      "stylers": [
        { "color": "#5c6a82" }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#171f2b" },
        { "weight": 1.5 }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        { "color": "#746855" }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        { "color": "#1f2835" },
        { "weight": 2.0 }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#9ca5b3" }
      ]
    },
    /* ---------------------------------- */

    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [
        { "color": "#2f3948" }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#d59563" }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        { "color": "#17263c" }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        { "color": "#515c6d" }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [
        { "color": "#17263c" }
      ]
    }
  ]
  ''';
}
