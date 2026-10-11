import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../core/constants/colors.dart';
import '../../core/services/voice_search/voice_route_pipeline.dart';
import '../../core/services/voice_search/voice_transcription_service.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_search_screen.dart';

enum _VoiceStep { idle, listening, transcribing, searching, error, confirm }

/// Bottom sheet for [TripPlannerScreen]'s "مشوار عادي" section - lets the
/// customer say pickup and destination in one sentence ("من X إلى Y")
/// instead of picking each separately through [DestinationSearchScreen].
/// Pops with a (pickup, destination) record on success, or null if the
/// customer backs out.
///
/// Recording ([AudioRecorder], Stage 1) stays local to this widget; the
/// clip is sent to [VoiceTranscriptionService] (Google Cloud Speech-to-Text,
/// server-side, fed this app's own place names as recognition hints) for
/// the actual transcript. Everything after that - normalizing the text,
/// correcting misheard local place names against `assets/data/places.json`,
/// splitting "from"/"to", and searching for each - is [VoiceRoutePipeline],
/// so it can be unit-tested and reused on its own.
class VoiceRideRequestSheet extends StatefulWidget {
  const VoiceRideRequestSheet({super.key, this.nearLat, this.nearLng});

  /// The customer's current/pickup location, when known - biases both the
  /// pickup and destination search toward it, same as
  /// [DestinationSearchScreen.nearLat]/[nearLng].
  final double? nearLat;
  final double? nearLng;

  @override
  State<VoiceRideRequestSheet> createState() => _VoiceRideRequestSheetState();
}

class _VoiceRideRequestSheetState extends State<VoiceRideRequestSheet> {
  final _recorder = AudioRecorder();
  final _transcriptionService = const VoiceTranscriptionService();
  final _pipeline = VoiceRoutePipeline();

  _VoiceStep _step = _VoiceStep.idle;
  String? _recordingPath;
  int _recordedSeconds = 0;
  Timer? _recordingTimer;
  String? _errorMessage;
  DestinationSuggestion? _pickupResult;
  DestinationSuggestion? _destinationResult;
  // Every plausible match the pipeline found for each leg (best-first,
  // [_pickupResult]/[_destinationResult] is always candidates.first) - lets
  // the customer pick a different one in two taps when the auto-selected
  // top match is wrong, instead of only being able to accept it or fall
  // back to typing the whole thing manually.
  List<DestinationSuggestion> _pickupCandidates = [];
  List<DestinationSuggestion> _destinationCandidates = [];
  // What was actually heard for each leg, kept even when the search below
  // couldn't resolve it - prefills the manual-edit search box so the
  // customer fixes a typo/mis-hearing instead of retyping from scratch.
  String? _pickupHeardText;
  String? _destinationHeardText;

  /// Hard cap on a single recording - long enough for "من X إلى Y" said at
  /// a normal pace with some hesitation, short enough to keep the uploaded
  /// clip small on what's often a slow mobile connection.
  static const _maxRecordSeconds = 15;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _cleanupRecording();
    super.dispose();
  }

  void _cleanupRecording() {
    final path = _recordingPath;
    if (path == null) return;
    File(path).delete().catchError((_) => File(path));
  }

  /// Permission is requested here, right as the customer taps the mic -
  /// not proactively in [initState] - so the system prompt appears at the
  /// moment it's actually relevant instead of the instant this sheet opens.
  Future<void> _startListening() async {
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage =
            'تحتاج السماح بالوصول إلى الميكروفون من إعدادات الهاتف لاستخدام البحث الصوتي.';
      });
      return;
    }

    _cleanupRecording();
    final path =
        '${Directory.systemTemp.path}/hudhud_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (!mounted) return;

    setState(() {
      _step = _VoiceStep.listening;
      _recordingPath = path;
      _recordedSeconds = 0;
      _errorMessage = null;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordedSeconds++);
      if (_recordedSeconds >= _maxRecordSeconds) _finishListening();
    });
  }

  Future<void> _finishListening() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;

    setState(() => _step = _VoiceStep.transcribing);
    final file = path == null ? null : File(path);
    final bytes = (file != null && await file.exists())
        ? await file.readAsBytes()
        : const <int>[];
    final transcript = await _transcriptionService.transcribe(bytes);
    _cleanupRecording();
    if (!mounted) return;
    await _resolve(transcript);
  }

  /// Runs the full Text Normalization -> Place Correction -> From/To
  /// Extraction -> Place Search pipeline on [transcript] (see
  /// [VoiceRoutePipeline]). Lands on the confirm step even when one (or
  /// both) legs couldn't be resolved - that leg just shows as "not found"
  /// there with a direct edit action pre-filled with what was heard,
  /// instead of discarding a leg that *did* resolve correctly just because
  /// the other one didn't, and instead of forcing a full voice retry for a
  /// name the recognizer is likely to mishear again anyway.
  Future<void> _resolve(String transcript) async {
    if (transcript.trim().isEmpty) {
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage = 'لم أسمع شيئًا، حاول مرة أخرى.';
      });
      return;
    }

    setState(() => _step = _VoiceStep.searching);
    try {
      final result = await _pipeline.resolve(
        transcript,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted) return;

      setState(() {
        _pickupCandidates = result.from.candidates;
        _pickupResult = result.from.bestMatch;
        _pickupHeardText = result.from.text;
        _destinationCandidates = result.to.candidates;
        _destinationResult = result.to.bestMatch;
        _destinationHeardText = result.to.text;
        _step = _VoiceStep.confirm;
      });
    } on VoiceRouteParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage =
            'تعذر البحث الآن، تحقق من الاتصال بالإنترنت وحاول مرة أخرى.';
      });
    }
  }

  void _confirm() {
    final pickup = _pickupResult;
    final destination = _destinationResult;
    if (pickup == null || destination == null) return;
    Navigator.of(context).pop((pickup: pickup, destination: destination));
  }

  /// Manual correction for a misrecognized (or entirely unresolved) pickup -
  /// opens the same typed/map search screen [TripPlannerScreen] itself
  /// uses, pre-filled with whatever was heard so a near-miss is a quick fix
  /// rather than a blank search, so picking a different place here follows
  /// the exact same trusted path as the rest of the app.
  Future<void> _editPickup() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          title: 'نقطة الانطلاق',
          mapPickerTitle: 'اختر نقطة الانطلاق من الخريطة',
          nearLat: widget.nearLat,
          nearLng: widget.nearLng,
          initialQuery: _pickupHeardText,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickupResult = result;
        _pickupCandidates = [result];
      });
    }
  }

  Future<void> _editDestination() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          mapPickerTitle: 'اختر الوجهة من الخريطة',
          nearLat: _pickupResult?.latitude ?? widget.nearLat,
          nearLng: _pickupResult?.longitude ?? widget.nearLng,
          initialQuery: _destinationHeardText,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _destinationResult = result;
        _destinationCandidates = [result];
      });
    }
  }

  /// Lets the customer pick a different match than the auto-selected top
  /// one, from [candidates] the pipeline already found - no new search
  /// round-trip needed.
  Future<void> _pickAmongCandidates({
    required List<DestinationSuggestion> candidates,
    required String title,
    required ValueChanged<DestinationSuggestion> onPicked,
  }) async {
    final chosen = await showModalBottomSheet<DestinationSuggestion>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'أي "$title" تقصد؟',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ...candidates.map(
              (c) => ListTile(
                leading: const Icon(
                  Icons.place_rounded,
                  color: AppColors.accent,
                ),
                title: Text(c.title, style: const TextStyle(fontFamily: 'Cairo')),
                subtitle: c.subtitle != null
                    ? Text(
                        c.subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(c),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) onPicked(chosen);
  }

  /// Escape hatch for when the pipeline couldn't even find a "من X إلى Y"
  /// shape in the transcript (so there's no per-leg text to prefill a
  /// search with) - picks pickup then destination manually, landing on the
  /// same confirm step as a fully-resolved voice request.
  Future<void> _pickManually() async {
    final pickup = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          title: 'نقطة الانطلاق',
          mapPickerTitle: 'اختر نقطة الانطلاق من الخريطة',
          nearLat: widget.nearLat,
          nearLng: widget.nearLng,
        ),
      ),
    );
    if (pickup == null || !mounted) return;

    final destination = await Navigator.of(context)
        .push<DestinationSuggestion>(
          MaterialPageRoute(
            builder: (context) => DestinationSearchScreen(
              mapPickerTitle: 'اختر الوجهة من الخريطة',
              nearLat: pickup.latitude,
              nearLng: pickup.longitude,
            ),
          ),
        );
    if (!mounted) return;

    setState(() {
      _pickupResult = pickup;
      _pickupCandidates = [pickup];
      _pickupHeardText = null;
      _destinationResult = destination;
      _destinationCandidates = destination == null ? [] : [destination];
      _destinationHeardText = null;
      _step = _VoiceStep.confirm;
    });
  }

  void _retry() {
    _recordingTimer?.cancel();
    _cleanupRecording();
    setState(() {
      _step = _VoiceStep.idle;
      _recordingPath = null;
      _recordedSeconds = 0;
      _errorMessage = null;
      _pickupResult = null;
      _destinationResult = null;
      _pickupCandidates = [];
      _destinationCandidates = [];
      _pickupHeardText = null;
      _destinationHeardText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اطلب بالصوت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'قل نقطة الانطلاق والوجهة معًا، مثلاً:\n"من السوق المركزي إلى المطار"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 24),
            _buildBody(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _VoiceStep.idle:
        return _buildMicButton(onTap: _startListening);

      case _VoiceStep.listening:
        return Column(
          children: [
            _buildMicButton(onTap: _finishListening, active: true),
            const SizedBox(height: 12),
            Text(
              'جاري الاستماع... ($_recordedSeconds/$_maxRecordSeconds ث) - اضغط لإنهاء',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case _VoiceStep.transcribing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'جاري تحويل الصوت إلى نص...',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        );

      case _VoiceStep.searching:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                'جاري إنشاء طلب...',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        );

      case _VoiceStep.error:
        return Column(
          children: [
            Text(
              _errorMessage ?? 'حدث خطأ غير متوقع.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startListening,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('حاول مرة أخرى'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickManually,
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: const Text('اختيار الأماكن يدويًا'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                foregroundColor: AppColors.darkText,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        );

      case _VoiceStep.confirm:
        final bothResolved =
            _pickupResult != null && _destinationResult != null;
        return Column(
          children: [
            _buildResultRow(
              icon: Icons.radio_button_checked_rounded,
              iconColor: AppColors.success,
              label: 'نقطة الانطلاق',
              title: _pickupResult?.title,
              onEdit: _editPickup,
              alternativesCount: _pickupCandidates.length,
              onPickAlternative: () => _pickAmongCandidates(
                candidates: _pickupCandidates,
                title: 'نقطة الانطلاق',
                onPicked: (c) => setState(() => _pickupResult = c),
              ),
            ),
            const SizedBox(height: 10),
            _buildResultRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.error,
              label: 'الوجهة',
              title: _destinationResult?.title,
              onEdit: _editDestination,
              alternativesCount: _destinationCandidates.length,
              onPickAlternative: () => _pickAmongCandidates(
                candidates: _destinationCandidates,
                title: 'الوجهة',
                onPicked: (c) => setState(() => _destinationResult = c),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: bothResolved ? _confirm : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.darkText,
              ),
              child: const Text('تأكيد'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _retry, child: const Text('إعادة المحاولة')),
          ],
        );
    }
  }

  Widget _buildMicButton({required VoidCallback? onTap, bool active = false}) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: active ? AppColors.error : AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  /// [title] is null when this leg wasn't resolved - shown as a prompt to
  /// pick it manually instead of leaving the row looking identical to a
  /// resolved one, and [onEdit] (same handler either way) opens the search
  /// screen pre-filled with whatever was heard. When [alternativesCount] is
  /// more than 1, a "ليس هذا؟" link is shown so the customer can pick among
  /// the other candidates the pipeline found instead of only being able to
  /// accept the auto-selected top one or fall back to a full manual search.
  Widget _buildResultRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String? title,
    required VoidCallback onEdit,
    int alternativesCount = 0,
    VoidCallback? onPickAlternative,
  }) {
    final unresolved = title == null;
    final hasAlternatives = !unresolved && alternativesCount > 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: unresolved
            ? Border.all(color: AppColors.error.withOpacity(0.4))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unresolved
                          ? 'اضغط هنا لاختيار المكان'
                          : title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: unresolved
                            ? AppColors.error
                            : AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: Icon(
                  unresolved ? Icons.search_rounded : Icons.edit_rounded,
                  size: 16,
                ),
                label: Text(unresolved ? 'اختيار يدوي' : 'تعديل'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: unresolved
                      ? AppColors.error
                      : AppColors.darkText,
                  side: BorderSide(
                    color: unresolved
                        ? AppColors.error
                        : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (hasAlternatives)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onPickAlternative,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'ليس هذا؟ عرض $alternativesCount نتائج محتملة',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
