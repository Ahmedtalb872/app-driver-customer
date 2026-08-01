import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/colors.dart';
import '../data/models/destination_suggestion.dart';
import '../data/repositories/destination_search_repository.dart';
import 'destination_map_picker_screen.dart';

/// Full-screen "where to?" search, pushed from [CustomerHomeScreen]. Pops
/// with the chosen [DestinationSuggestion], or null if the user backs out.
class DestinationSearchScreen extends StatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final _repository = DestinationSearchRepository();
  final _controller = TextEditingController();
  final _speech = SpeechToText();
  Timer? _debounce;

  List<DestinationSuggestion> _results = [];
  bool _isLoading = false;
  String? _error;
  bool _speechAvailable = false;
  bool _isListening = false;

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
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _speech.stop();
    super.dispose();
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
      final results = await _repository.search(query: query);
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

  Future<void> _pickFromMap() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => const DestinationMapPickerScreen(),
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
        title: const Text('إلى أين تريد الذهاب؟'),
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
              'اختر الوجهة من الخريطة',
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    if (_controller.text.trim().length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'اكتب اسم الحي أو المكان الذي تريد الذهاب إليه.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    if (!_isLoading && _results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد نتائج مطابقة لبحثك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
      itemBuilder: (context, index) {
        final suggestion = _results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(
              _iconFor(suggestion.resultType),
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            suggestion.title,
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
      },
    );
  }
}
