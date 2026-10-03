import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/colors.dart';
import '../../core/services/voice_search/voice_route_pipeline.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/presentation/destination_search_screen.dart';

enum _VoiceStep { idle, listening, searching, error, confirm }

/// Bottom sheet for [TripPlannerScreen]'s "مشوار عادي" section - lets the
/// customer say pickup and destination in one sentence ("من X إلى Y")
/// instead of picking each separately through [DestinationSearchScreen].
/// Pops with a (pickup, destination) record on success, or null if the
/// customer backs out.
///
/// Speech recognition ([SpeechToText], Stage 1) stays local to this widget;
/// everything after the raw transcript - normalizing the text, correcting
/// misheard local place names against `assets/data/places.json`, splitting
/// "from"/"to", and searching for each - is [VoiceRoutePipeline], so it can
/// be unit-tested and reused on its own.
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
  final _speech = SpeechToText();
  final _pipeline = VoiceRoutePipeline();

  _VoiceStep _step = _VoiceStep.idle;
  bool _speechAvailable = false;
  String _transcript = '';
  String? _errorMessage;
  DestinationSuggestion? _pickupResult;
  DestinationSuggestion? _destinationResult;

  @override
  void initState() {
    super.initState();
    // Best-effort, same as DestinationSearchScreen - if this fails (denied
    // permission, no recognizer on the device), the mic button just stays
    // disabled with an explanatory line instead of the sheet erroring.
    _speech
        .initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') &&
                _step == _VoiceStep.listening) {
              _finishListening();
            }
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _step = _VoiceStep.error;
                _errorMessage =
                    'تعذر الاستماع الآن، تحقق من إذن الميكروفون وحاول مرة أخرى.';
              });
            }
          },
        )
        .then((available) {
          if (mounted) setState(() => _speechAvailable = available);
        });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _step = _VoiceStep.listening;
      _transcript = '';
      _errorMessage = null;
    });
    await _speech.listen(
      localeId: 'ar',
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
    );
  }

  Future<void> _finishListening() async {
    await _speech.stop();
    if (!mounted) return;
    await _resolve(_transcript);
  }

  /// Runs the full Text Normalization -> Place Correction -> From/To
  /// Extraction -> Place Search pipeline on [transcript] (see
  /// [VoiceRoutePipeline]) and lands on either the confirm step or an error
  /// message naming exactly which side (or the sentence shape itself)
  /// couldn't be resolved.
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

      if (!result.from.isResolved || !result.to.isResolved) {
        setState(() {
          _step = _VoiceStep.error;
          _errorMessage = !result.from.isResolved
              ? 'لم أجد "${result.from.text}". حاول أن تنطقها بوضوح أكبر أو استخدم اسمًا مختلفًا.'
              : 'لم أجد "${result.to.text}". حاول أن تنطقها بوضوح أكبر أو استخدم اسمًا مختلفًا.';
        });
        return;
      }

      setState(() {
        _pickupResult = result.from.suggestion;
        _destinationResult = result.to.suggestion;
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

  /// Manual correction for a misrecognized pickup - opens the same typed/
  /// map search screen [TripPlannerScreen] itself uses, so picking a
  /// different place here follows the exact same trusted path as the rest
  /// of the app.
  Future<void> _editPickup() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          title: 'نقطة الانطلاق',
          mapPickerTitle: 'اختر نقطة الانطلاق من الخريطة',
          nearLat: widget.nearLat,
          nearLng: widget.nearLng,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _pickupResult = result);
  }

  Future<void> _editDestination() async {
    final result = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          mapPickerTitle: 'اختر الوجهة من الخريطة',
          nearLat: _pickupResult?.latitude ?? widget.nearLat,
          nearLng: _pickupResult?.longitude ?? widget.nearLng,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _destinationResult = result);
  }

  void _retry() {
    setState(() {
      _step = _VoiceStep.idle;
      _transcript = '';
      _errorMessage = null;
      _pickupResult = null;
      _destinationResult = null;
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
        return Column(
          children: [
            _buildMicButton(onTap: _speechAvailable ? _startListening : null),
            if (!_speechAvailable) ...[
              const SizedBox(height: 12),
              const Text(
                'البحث الصوتي غير متاح على هذا الجهاز حاليًا.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        );

      case _VoiceStep.listening:
        return Column(
          children: [
            _buildMicButton(onTap: _finishListening, active: true),
            const SizedBox(height: 12),
            const Text(
              'جاري إنشاء طلب...',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _transcript,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ],
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
          ],
        );

      case _VoiceStep.confirm:
        return Column(
          children: [
            _buildResultRow(
              icon: Icons.radio_button_checked_rounded,
              iconColor: AppColors.success,
              label: 'نقطة الانطلاق',
              title: _pickupResult!.title,
              onEdit: _editPickup,
            ),
            const SizedBox(height: 10),
            _buildResultRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.error,
              label: 'الوجهة',
              title: _destinationResult!.title,
              onEdit: _editDestination,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirm,
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

  Widget _buildResultRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String title,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.secondaryText,
            ),
            tooltip: 'تعديل',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
