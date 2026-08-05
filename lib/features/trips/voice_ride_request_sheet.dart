import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/colors.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/data/repositories/destination_search_repository.dart';

enum _VoiceStep { idle, listening, searching, error, confirm }

/// Bottom sheet for [TripPlannerScreen]'s "مشوار عادي" section - lets the
/// customer say pickup and destination in one sentence ("من X إلى Y")
/// instead of picking each separately through [DestinationSearchScreen].
/// Pops with a (pickup, destination) record on success, or null if the
/// customer backs out.
class VoiceRideRequestSheet extends StatefulWidget {
  const VoiceRideRequestSheet({super.key});

  @override
  State<VoiceRideRequestSheet> createState() => _VoiceRideRequestSheetState();
}

class _VoiceRideRequestSheetState extends State<VoiceRideRequestSheet> {
  final _speech = SpeechToText();
  final _repository = DestinationSearchRepository();

  /// Matches "[من] X إلى Y" - the leading "من" is optional, "إلى"/"الى" are
  /// both accepted since speech-to-text output is inconsistent about the
  /// hamza. Loose on whitespace for the same reason.
  static final _fromToPattern = RegExp(
    r'^(?:من\s+)?(.+?)\s+(?:إلى|الى)\s+(.+)$',
  );

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

    if (_transcript.trim().isEmpty) {
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage = 'لم أسمع شيئًا، حاول مرة أخرى.';
      });
      return;
    }

    final match = _fromToPattern.firstMatch(_transcript.trim());
    if (match == null) {
      setState(() {
        _step = _VoiceStep.error;
        _errorMessage =
            'لم أفهم طلبك. قل مثلاً: "من السوق المركزي إلى المطار".';
      });
      return;
    }

    final pickupQuery = match.group(1)!.trim();
    final destinationQuery = match.group(2)!.trim();
    setState(() => _step = _VoiceStep.searching);

    try {
      final results = await Future.wait([
        _repository.search(query: pickupQuery, limit: 1),
        _repository.search(query: destinationQuery, limit: 1),
      ]);
      if (!mounted) return;

      final pickupMatches = results[0];
      final destinationMatches = results[1];
      if (pickupMatches.isEmpty || destinationMatches.isEmpty) {
        setState(() {
          _step = _VoiceStep.error;
          _errorMessage = pickupMatches.isEmpty
              ? 'لم أجد "$pickupQuery". حاول أن تنطقها بوضوح أكبر أو استخدم اسمًا مختلفًا.'
              : 'لم أجد "$destinationQuery". حاول أن تنطقها بوضوح أكبر أو استخدم اسمًا مختلفًا.';
        });
        return;
      }

      setState(() {
        _pickupResult = pickupMatches.first;
        _destinationResult = destinationMatches.first;
        _step = _VoiceStep.confirm;
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
              'جارٍ الاستماع... تكلّم الآن',
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
                'جارٍ البحث عن الموقعين...',
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
            ),
            const SizedBox(height: 10),
            _buildResultRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.error,
              label: 'الوجهة',
              title: _destinationResult!.title,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
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
            color: active ? AppColors.error : AppColors.primary,
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
        ],
      ),
    );
  }
}
