import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// The tile + attribution layers every `flutter_map` view in this feature
/// must include.
///
/// Google Maps is explicitly prohibited by the product PRD — this app uses
/// OpenStreetMap tiles exclusively via `flutter_map`. OSM's tile usage policy
/// requires visible attribution, hence the [RichAttributionWidget] alongside
/// the [TileLayer]. Centralized here so [ProjectMapPage] and
/// [ProjectFormPage] (the only two map views in this feature) don't each
/// redefine the tile URL/attribution.
List<Widget> osmMapLayers() => [
  TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.scfms.mobile',
  ),
  RichAttributionWidget(
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
    ],
  ),
];
