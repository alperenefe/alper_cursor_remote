import 'package:flutter/foundation.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;



/// Telefonun yerel STT servisi (Android: Google / sistem; ek API ücreti yok).

class ComposerSpeechService {

  ComposerSpeechService();



  final stt.SpeechToText _engine = stt.SpeechToText();



  bool _initialized = false;

  bool _available = false;

  bool _listening = false;

  /// Dinleme oturumu bittikten sonra geciken partial'ları yoksay.

  bool _acceptResults = false;

  String _sessionBase = '';

  String _snapshotBeforeListen = '';



  VoidCallback? onListeningChanged;



  bool get isListening => _listening;

  bool get isAvailable => _available;



  void _setListening(bool value) {

    if (_listening == value) return;

    _listening = value;

    onListeningChanged?.call();

  }



  Future<bool> ensureReady() async {

    if (_initialized) return _available;

    _available = await _engine.initialize(

      onError: (_) {

        _acceptResults = false;

        _setListening(false);

      },

      onStatus: (status) {

        if (status == 'notListening' || status == 'done') {

          _acceptResults = false;

          _setListening(false);

        }

      },

    );

    _initialized = true;

    return _available;

  }



  Future<bool> ensureMicrophonePermission() async {

    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    status = await Permission.microphone.request();

    return status.isGranted;

  }



  Future<String?> startListening({

    required String existingText,

    required void Function(String displayText) onDisplayText,

  }) async {

    if (_listening) return null;



    if (!await ensureReady()) {

      return 'Ses tanıma bu cihazda kullanılamıyor. Google uygulaması / Play Hizmetleri yüklü mü?';

    }

    if (!await ensureMicrophonePermission()) {

      return 'Mikrofon izni gerekli — Ayarlar\'dan izin verebilirsin.';

    }



    _snapshotBeforeListen = existingText;

    _sessionBase = existingText.trim();



    final localeId = await _pickTurkishLocaleId();



    try {

      _acceptResults = true;

      await _engine.listen(

        onResult: (SpeechRecognitionResult result) {

          if (!_acceptResults || !_listening) return;

          final words = result.recognizedWords.trim();

          if (words.isEmpty) return;

          onDisplayText(_composeDisplay(_sessionBase, words));

        },

        listenOptions: stt.SpeechListenOptions(

          localeId: localeId,

          listenMode: stt.ListenMode.dictation,

          partialResults: true,

          cancelOnError: true,

          pauseFor: const Duration(seconds: 4),

          listenFor: const Duration(minutes: 2),

        ),

      );

      _setListening(true);

      return null;

    } catch (e) {

      _acceptResults = false;

      _setListening(false);

      return 'Ses tanıma başlatılamadı: $e';

    }

  }



  Future<void> stopListening() async {

    if (!_listening && !_acceptResults) return;

    _acceptResults = false;

    _setListening(false);

    try {

      if (_engine.isListening) {

        await _engine.stop();

      }

    } catch (_) {}

  }



  /// Dinlemeyi iptal et; metni başlangıç haline döndürmek için snapshot ver.

  Future<String> cancelListening() async {

    _acceptResults = false;

    final wasListening = _listening || _engine.isListening;

    _setListening(false);

    if (wasListening) {

      try {

        await _engine.cancel();

      } catch (_) {}

    }

    return _snapshotBeforeListen;

  }



  Future<String?> _pickTurkishLocaleId() async {

    try {

      final locales = await _engine.locales();

      if (locales.isEmpty) return null;

      final tr = locales

          .where((l) => l.localeId.toLowerCase().startsWith('tr'))

          .toList();

      if (tr.isNotEmpty) return tr.first.localeId;

      return locales.first.localeId;

    } catch (_) {

      return null;

    }

  }



  static String _composeDisplay(String base, String sessionWords) {

    if (base.isEmpty) return sessionWords;

    if (sessionWords.isEmpty) return base;

    return '$base $sessionWords';

  }



  void dispose() {

    _acceptResults = false;

    if (_listening || _engine.isListening) {

      _engine.cancel();

    }

    _listening = false;

  }

}


