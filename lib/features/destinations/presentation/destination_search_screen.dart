import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/colors.dart';
import '../data/models/destination_suggestion.dart';
import '../data/models/place_category.dart';
import '../data/repositories/categories_repository.dart';
import '../data/repositories/destination_search_repository.dart';
import '../data/repositories/places_repository.dart';
import '../data/repositories/recent_places_repository.dart';
import 'destination_map_picker_screen.dart';
import 'widgets/category_icon.dart';

/// Full-screen "where to?" search, pushed from [TripPlannerScreen] for
/// either a pickup or a destination point (see [title]/[mapPickerTitle]).
/// Pops with the chosen [DestinationSuggestion], or null if the user backs
/// out.
///
/// Before anything is typed, shows the customer's own recently-requested
/// destinations (see [RecentPlacesRepository]) and a "browse by category"
/// chip row - both also offered as a fallback when a search comes back
/// empty, so a search that fails isn't a dead end.
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({
    super.key,
    this.title = 'إلى أين تريد الذهاب؟',
    this.mapPickerTitle = 'اختر الموقع من الخريطة',
    this.nearLat,
    this.nearLng,
  });

  final String title;
  final String mapPickerTitle;

  /// The customer's current/pickup location, when known - passed straight
  /// through to [DestinationSearchRepository.search] so results are ranked
  /// closest-first once text relevance is already accounted for. Optional;
  /// omit when no location is known yet and ranking simply falls back to
  /// relevance/popularity alone.
  final double? nearLat;
  final double? nearLng;

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _repository = DestinationSearchRepository();
  final _recentPlacesRepository = RecentPlacesRepository();
  final _categoriesRepository = CategoriesRepository();
  final _placesRepository = PlacesRepository();
  final _controller = TextEditingController();
  final _speech = SpeechToText();
  Timer? _debounce;

  List<DestinationSuggestion> _results = [];
  bool _isLoading = false;
  String? _error;
  bool _speechAvailable = false;
  bool _isListening = false;

  List<DestinationSuggestion> _recentPlaces = [];
  List<PlaceCategory> _categories = [];
  Map<String, PlaceCategory> _categoryByCode = {};
  bool _loadingExtras = true;

  /// True while [_results] holds a category's places rather than a text
  /// search's results - kept separate from the query text so browsing a
  /// category doesn't fight with the "type at least 2 characters" empty
  /// state below.
  bool _isBrowsingCategory = false;

  @override
  void initState() {
    super.initState();
    // Best-effort - if this fails (denied permission, no recognizer on the
    // device), the mic button simply never appears rather than the screen
    // erroring; typed search always keeps working either way.
    _speech
        .initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _isListening = false);
          },
        )
        .then((available) {
          if (mounted) setState(() => _speechAvailable = available);
        });
    _loadExtras();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Recent places and categories for the empty/no-results states - both
  /// best-effort: a failure here just means those sections stay empty,
  /// never an error blocking the search screen itself.
  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        _recentPlacesRepository.loadRecent(),
        _categoriesRepository.loadActiveCategories(),
      ]);
      if (!mounted) return;
      final categories = results[1] as List<PlaceCategory>;
      setState(() {
        _recentPlaces = results[0] as List<DestinationSuggestion>;
        _categories = categories;
        _categoryByCode = {for (final c in categories) c.code: c};
        _loadingExtras = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  /// Transcribed speech only ever fills the same text field typed search
  /// already uses - it's never sent straight to a request. The existing
  /// fuzzy place search absorbs most recognition mistakes, and the
  /// suggestion list still requires an explicit tap before anything is
  /// picked, so a misheard word costs a re-try, never a wrong booking.
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      localeId: 'ar',
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _onQueryChanged(result.recognizedWords);
      },
    );
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _isBrowsingCategory = false;
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _repository.search(
        query: query,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر البحث الآن، تحقق من الاتصال بالإنترنت وحاول مرة أخرى.';
      });
    }
  }

  /// Fallback for when a text/voice search misses (or before anything's
  /// typed): browse a category's places directly instead of retrying the
  /// search with a different word.
  Future<void> _pickCategory(PlaceCategory category) async {
    setState(() {
      _isBrowsingCategory = true;
      _isLoading = true;
      _error = null;
    });
    try {
      final places = await _placesRepository.search(
        query: '',
        categoryId: category.id,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _results = places
            .map(
              (place) => DestinationSuggestion.fromPlace(
                place,
                categoryCode: category.code,
              ),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر تحميل الأماكن الآن، تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _pickFromMap() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) =>
            DestinationMapPickerScreen(title: widget.mapPickerTitle),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  IconData _iconFor(DestinationResultType type) {
    switch (type) {
      case DestinationResultType.place:
        return Icons.place_rounded;
      case DestinationResultType.district:
        return Icons.location_city_rounded;
      case DestinationResultType.neighborhood:
        return Icons.holiday_village_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث عن حي، مكان، أو عنوان...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondaryText,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      ),
                    if (_speechAvailable)
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening
                              ? AppColors.error
                              : AppColors.secondaryText,
                        ),
                        onPressed: _toggleListening,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'جارٍ الاستماع... تكلّم الآن',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.map_rounded, color: AppColors.primary),
            title: const Text(
              'اختر من الخريطة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.darkText,
              ),
            ),
            onTap: _pickFromMap,
          ),
          const Divider(height: 1),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildMessage(_error!);
    }

    if (_isBrowsingCategory) {
      if (!_isLoading && _results.isEmpty) {
        return _buildMessage('لا توجد أماكن في هذه الفئة حالياً.');
      }
      return _buildResultsList(_results);
    }

    if (_controller.text.trim().length < 2) {
      return _buildEmptyQueryState();
    }

    if (!_isLoading && _results.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildResultsList(_results);
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyQueryState() {
    if (_loadingExtras) {
      return const SizedBox.shrink();
    }
    if (_recentPlaces.isEmpty && _categories.isEmpty) {
      return _buildMessage('اكتب اسم الحي أو المكان الذي تريد الذهاب إليه.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (_recentPlaces.isNotEmpty) ...[
          _buildSectionLabel('أماكن استخدمتها مؤخراً'),
          ..._recentPlaces.map(_buildResultTile),
          const Divider(height: 24),
        ],
        if (_categories.isNotEmpty) ...[
          _buildSectionLabel('تصفح حسب الفئة'),
          const SizedBox(height: 10),
          _buildCategoryChips(),
        ],
      ],
    );
  }

  Widget _buildNoResultsState() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد نتائج مطابقة لبحثك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.secondaryText),
          ),
        ),
        if (_categories.isNotEmpty) ...[
          _buildSectionLabel('أو تصفح حسب الفئة'),
          const SizedBox(height: 10),
          _buildCategoryChips(),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _categories.map((category) {
          return ActionChip(
            avatar: Icon(
              iconForCategory(category.iconName),
              size: 16,
              color: AppColors.primary,
            ),
            label: Text(
              category.nameAr,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
            onPressed: () => _pickCategory(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsList(List<DestinationSuggestion> results) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
      itemBuilder: (context, index) => _buildResultTile(results[index]),
    );
  }

  /// A place with a known category leads with what it *is* before its
  /// name ("بقالة / Epicerie Charee Bastami"), same as every major maps
  /// app labels a search result. Falls back to the bare title for a
  /// district/neighborhood or a place with no resolved category
  /// (categories still loading, or none set).
  Widget _buildResultTile(DestinationSuggestion suggestion) {
    final category = suggestion.categoryCode == null
        ? null
        : _categoryByCode[suggestion.categoryCode];
    final title = category == null
        ? suggestion.title
        : '${category.nameAr} / ${suggestion.title}';
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          category != null
              ? iconForCategory(category.iconName)
              : _iconFor(suggestion.resultType),
          color: AppColors.accent,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: suggestion.subtitle != null
          ? Text(
              suggestion.subtitle!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            )
          : null,
      onTap: () => Navigator.of(context).pop(suggestion),
    );
  }
}
