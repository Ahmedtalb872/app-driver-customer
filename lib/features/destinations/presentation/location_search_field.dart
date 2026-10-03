import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/colors.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/destination_suggestion.dart';
import '../data/repositories/destination_search_repository.dart';

/// A pickup/destination field you type directly into - no navigating to a
/// separate screen just to search. Debounced live search as you type, plus
/// an explicit search button for an immediate search, both backed by the
/// same [DestinationSearchRepository] [DestinationSearchScreen] itself uses
/// (this app's own places/districts/neighborhoods merged with Google
/// Places). The map icon still opens a full-screen map picker (see
/// [onPickFromMap]) as a fallback for picking a point with no name to
/// search for. Shared by [TripPlannerScreen] (normal/open ride) and the
/// delivery pickup/destination screen so both flows offer the same picking
/// options.
class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onSelected,
    required this.onPickFromMap,
    this.initialText,
    this.nearLat,
    this.nearLng,
    this.showCurrentLocation = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? initialText;
  final double? nearLat;
  final double? nearLng;
  final ValueChanged<DestinationSuggestion> onSelected;
  final VoidCallback onPickFromMap;

  /// Shows an extra "استخدام موقعي الحالي" button that fetches a fresh GPS
  /// fix and fills the field with it directly - a pickup point (unlike a
  /// destination) is overwhelmingly "right where the customer is standing",
  /// so it shouldn't require typing/searching at all. Off by default;
  /// pickup fields turn it on explicitly.
  final bool showCurrentLocation;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final _repository = DestinationSearchRepository();
  late final _controller = TextEditingController(text: widget.initialText ?? '');
  Timer? _debounce;
  List<DestinationSuggestion> _options = [];
  bool _searching = false;
  bool _searched = false;
  bool _locating = false;

  @override
  void didUpdateWidget(covariant LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the field in sync when a point is set some other way (voice
    // request, map picker) while this field isn't the one driving the
    // change - e.g. picking the destination from the map still needs the
    // pickup field's already-typed text left alone, but a fresh
    // initialText (voice sheet filling both at once) must actually show.
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _options = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().length < 2) return;
    _debounce?.cancel();
    setState(() => _searching = true);
    try {
      final results = await _repository.search(
        query: query,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted) return;
      setState(() {
        _options = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = [];
        _searching = false;
        _searched = true;
      });
    }
  }

  void _select(DestinationSuggestion suggestion) {
    _controller.text = suggestion.title;
    setState(() {
      _options = [];
      _searched = false;
    });
    FocusScope.of(context).unfocus();
    widget.onSelected(suggestion);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final address = await GeocodingService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      _select(
        DestinationSuggestion(
          resultType: DestinationResultType.place,
          id: 'current_location',
          title: address ?? AppLocalizations.of(context)!.myCurrentLocation,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.locateMeError,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10.5,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.typePlaceNameHint,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: () => _runSearch(_controller.text),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  l10n.searchButton,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 20),
              color: AppColors.secondaryText,
              onPressed: widget.onPickFromMap,
              tooltip: l10n.pickFromMapTooltip,
            ),
            if (widget.showCurrentLocation)
              IconButton(
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                color: AppColors.primary,
                onPressed: _locating ? null : _useCurrentLocation,
                tooltip: l10n.useCurrentLocationTooltip,
              ),
          ],
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_options.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final option = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    option.title,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                  subtitle: option.subtitle == null
                      ? null
                      : Text(
                          option.subtitle!,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                        ),
                  onTap: () => _select(option),
                );
              },
            ),
          )
        else if (_searched)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.noSearchResults,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.secondaryText,
              ),
            ),
          ),
      ],
    );
  }
}
