import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Widget for selecting a position from measured values and support points
class PositionSelector extends StatelessWidget {
  final List<String> measuredPositionKeys;
  final Map<String, LatLng> measuredPositionCoordinates;
  final Map<String, Map<String, dynamic>>? measuredPositionMetadata;
  final List<String> supportPointKeys;
  final Map<String, LatLng> supportPointCoordinates;
  final Map<String, String> supportPointNotes;
  final String? selectedPositionKey;
  final ValueChanged<String?> onPositionSelected;
  final String label;
  final bool hasGpsPosition;
  final LatLng? currentGpsPosition;
  final String? subtitle;
  final ValueChanged<LatLng>? onFocusPosition;
  final IconData? icon;
  final VoidCallback? onSelectFromMap; // Callback to enable map tap mode
  final LatLng? mapTappedPosition; // Position selected from map tap
  final String? centerPositionKey; // Key of position currently set as center
  final ValueChanged<String?>? onSetAsCenter; // Callback to set position as center

  static const String gpsLiveKey = '__GPS_LIVE__';
  static const String gpsLockedKey = '__GPS_LOCKED__';
  static const String mapTappedKey = '__MAP_TAPPED__';
  static const String sollKey = '__SOLL__'; // Default SOLL position

  const PositionSelector({
    super.key,
    required this.measuredPositionKeys,
    required this.measuredPositionCoordinates,
    this.measuredPositionMetadata,
    required this.supportPointKeys,
    required this.supportPointCoordinates,
    required this.supportPointNotes,
    required this.selectedPositionKey,
    required this.onPositionSelected,
    required this.label,
    this.icon,
    this.hasGpsPosition = false,
    this.currentGpsPosition,
    this.subtitle,
    this.onFocusPosition,
    this.onSelectFromMap,
    this.mapTappedPosition,
    this.centerPositionKey,
    this.onSetAsCenter,
  });

  @override
  Widget build(BuildContext context) {
    // Get coordinates for selected position
    LatLng? selectedCoordinates;
    if (selectedPositionKey != null) {
      if (selectedPositionKey == gpsLiveKey || selectedPositionKey == gpsLockedKey) {
        selectedCoordinates = currentGpsPosition;
      } else if (selectedPositionKey == mapTappedKey) {
        selectedCoordinates = mapTappedPosition;
      } else {
        selectedCoordinates =
            measuredPositionCoordinates[selectedPositionKey] ??
            supportPointCoordinates[selectedPositionKey];
      }
    }

    return ExpansionTile(
      title: Row(
        children: [
          if (selectedPositionKey != null && onFocusPosition != null && selectedCoordinates != null)
            IconButton(
              icon: Icon(icon ?? Icons.my_location, color: Colors.blue),
              tooltip: 'Auf Karte anzeigen',
              onPressed: () => onFocusPosition!(selectedCoordinates!),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Icon(
              icon ?? Icons.radio_button_unchecked,
              color: selectedPositionKey != null ? Colors.blue : null,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (selectedPositionKey != null)
                  Text(
                    selectedPositionKey == mapTappedKey
                        ? 'Karte Position'
                        : selectedPositionKey == gpsLiveKey
                        ? 'Aktuelle GPS Position'
                        : selectedPositionKey == gpsLockedKey
                        ? 'Gespeichert'
                        : selectedPositionKey!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      children: [
        // GPS Position section
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 16, bottom: 8),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              'GPS Position',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
        ),
        // Live GPS tracking option
        ListTile(
          dense: true,
          selected: selectedPositionKey == gpsLiveKey,
          enabled: hasGpsPosition,
          leading: Icon(
            selectedPositionKey == gpsLiveKey
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selectedPositionKey == gpsLiveKey
                ? Colors.blue
                : (hasGpsPosition ? null : Colors.grey),
          ),
          title: Row(
            children: [
              Text(
                'Aktuelle GPS Position',
                style: TextStyle(color: hasGpsPosition ? null : Colors.grey),
              ),
            ],
          ),
          subtitle: hasGpsPosition && currentGpsPosition != null
              ? Text(
                  'Lat: ${currentGpsPosition!.latitude.toStringAsFixed(6)}, '
                  'Lon: ${currentGpsPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 11),
                )
              : const Text('Keine GPS-Daten verfügbar', style: TextStyle(fontSize: 11)),
          trailing: hasGpsPosition && selectedPositionKey == gpsLiveKey
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onFocusPosition != null && currentGpsPosition != null)
                      IconButton(
                        icon: const Icon(Icons.my_location, size: 20),
                        tooltip: 'Auf Karte anzeigen',
                        onPressed: () => onFocusPosition!(currentGpsPosition!),
                      ),
                    IconButton(
                      icon: const Icon(Icons.add_location, size: 20),
                      tooltip: 'Position festlegen',
                      onPressed: () => onPositionSelected(gpsLockedKey),
                    ),
                  ],
                )
              : (onFocusPosition != null && currentGpsPosition != null && hasGpsPosition)
              ? IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  tooltip: 'Auf Karte anzeigen',
                  onPressed: () => onFocusPosition!(currentGpsPosition!),
                )
              : null,
          onTap: hasGpsPosition
              ? () => onPositionSelected(selectedPositionKey == gpsLiveKey ? null : gpsLiveKey)
              : null,
        ),
        // Locked GPS position option
        if (selectedPositionKey == gpsLockedKey && currentGpsPosition != null) ...[
          ListTile(
            selected: true,
            leading: Icon(Icons.radio_button_checked, color: Colors.blue),
            title: Row(children: [const Text('gespeichert')]),
            subtitle: Text(
              'Lat: ${currentGpsPosition!.latitude.toStringAsFixed(6)}, '
              'Lon: ${currentGpsPosition!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onFocusPosition != null)
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: 'Auf Karte anzeigen',
                    onPressed: () => onFocusPosition!(currentGpsPosition!),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: 'Live-Tracking aktivieren',
                  onPressed: () => onPositionSelected(gpsLiveKey),
                ),
              ],
            ),
            onTap: () => onPositionSelected(null),
          ),
        ],

        // Map tap position option
        if (onSelectFromMap != null) ...[
          ListTile(
            dense: true,
            selected: selectedPositionKey == mapTappedKey,
            leading: Icon(
              selectedPositionKey == mapTappedKey
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selectedPositionKey == mapTappedKey ? Colors.blue : null,
            ),
            title: const Text('Position auf Karte wählen'),
            subtitle: selectedPositionKey == mapTappedKey && mapTappedPosition != null
                ? Text(
                    'Lat: ${mapTappedPosition!.latitude.toStringAsFixed(6)}, '
                    'Lon: ${mapTappedPosition!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 11),
                  )
                : const Text('Tippe auf die Karte', style: TextStyle(fontSize: 11)),
            trailing: selectedPositionKey == mapTappedKey && mapTappedPosition != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onFocusPosition != null)
                        IconButton(
                          icon: const Icon(Icons.my_location, size: 20),
                          tooltip: 'Auf Karte anzeigen',
                          onPressed: () => onFocusPosition!(mapTappedPosition!),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Löschen',
                        onPressed: () => onPositionSelected(null),
                      ),
                    ],
                  )
                : (selectedPositionKey == mapTappedKey
                      ? const Icon(Icons.touch_app, size: 20)
                      : null),
            onTap: () {
              if (selectedPositionKey == mapTappedKey) {
                onPositionSelected(null);
              } else {
                onSelectFromMap!();
                onPositionSelected(mapTappedKey);
              }
            },
          ),
        ],

        // Gemessene Werte section
        if (measuredPositionKeys.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 16, bottom: 8),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Messungen Ecken',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          ...measuredPositionKeys.asMap().entries.map((entry) {
            final key = entry.value;
            final isSelected = selectedPositionKey == key;
            final coordinate = measuredPositionCoordinates[key];
            final metadata = measuredPositionMetadata?[key];

            final isCenterPosition = centerPositionKey == key;

            // Build quality subtitle from metadata
            String? qualitySubtitle;
            if (metadata != null) {
              final parts = <String>[];

              if (metadata['quality'] != null) {
                parts.add('Q: ${metadata['quality']}');
              }

              if (metadata['hdop_mean'] != null) {
                final hdop = metadata['hdop_mean'] as num;
                parts.add('HDOP: ${hdop.toStringAsFixed(2)}');
              }

              if (metadata['satellites_count_mean'] != null) {
                final sats = metadata['satellites_count_mean'] as num;
                parts.add('Sat: ${sats.toStringAsFixed(0)}');
              }

              if (parts.isNotEmpty) {
                qualitySubtitle = parts.join(' | ');
              }
            }

            return Column(
              children: [
                ListTile(
                  selected: isSelected,
                  dense: true,
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  ),
                  title: Row(
                    children: [
                      Text(key),
                      if (isCenterPosition) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: const Text(
                            'Zentrum',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: qualitySubtitle != null
                      ? Text(
                          qualitySubtitle,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        )
                      : null,
                  trailing: onFocusPosition != null && coordinate != null
                      ? IconButton(
                          icon: const Icon(Icons.my_location, size: 20),
                          tooltip: 'Auf Karte anzeigen',
                          onPressed: () => onFocusPosition!(coordinate),
                        )
                      : null,
                  onTap: () => onPositionSelected(isSelected ? null : key),
                ),
                //if (index < measuredPositionKeys.length - 1) const Divider(height: 1),
              ],
            );
          }),
        ],

        // Hilfspunkte section
        if (supportPointKeys.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 16, bottom: 8),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Hilfspunkte',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          ...supportPointKeys.asMap().entries.map((entry) {
            final key = entry.value;
            final isSelected = selectedPositionKey == key;
            final note = supportPointNotes[key] ?? '';
            final coordinate = supportPointCoordinates[key];

            final isCenterPosition = centerPositionKey == key;

            return Column(
              children: [
                ListTile(
                  dense: true,
                  selected: isSelected,
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(key)),
                      if (isCenterPosition) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: const Text(
                            'Zentrum',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: note.isNotEmpty
                      ? Text(note)
                      : (isCenterPosition ? const Text('Als Zentrum gesetzt') : null),
                  trailing: onFocusPosition != null && coordinate != null
                      ? IconButton(
                          icon: const Icon(Icons.my_location, size: 20),
                          tooltip: 'Auf Karte anzeigen',
                          onPressed: () => onFocusPosition!(coordinate),
                        )
                      : null,
                  onTap: () => onPositionSelected(isSelected ? null : key),
                ),
                // if (index < supportPointKeys.length - 1) const Divider(height: 1),
              ],
            );
          }),
        ],
      ],
    );
  }
}
