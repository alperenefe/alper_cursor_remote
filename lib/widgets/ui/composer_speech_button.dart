import 'package:flutter/material.dart';



import '../../services/composer_speech_service.dart';

import '../../theme/design_tokens.dart';



/// Composer mikrofon — yerel STT, metin kutusuna yazar (PC'ye ses gitmez).

class ComposerSpeechButton extends StatefulWidget {

  const ComposerSpeechButton({

    super.key,

    required this.enabled,

    required this.controller,

    this.onError,

  });



  final bool enabled;

  final TextEditingController controller;

  final void Function(String message)? onError;



  @override

  State<ComposerSpeechButton> createState() => ComposerSpeechButtonState();

}



/// Gönder / devre dışı kalınca dinlemeyi kesmek için [GlobalKey] ile erişilir.

class ComposerSpeechButtonState extends State<ComposerSpeechButton> {

  final ComposerSpeechService _speech = ComposerSpeechService();

  bool _listening = false;



  @override

  void initState() {

    super.initState();

    _speech.onListeningChanged = () {

      if (!mounted) return;

      final active = _speech.isListening;

      if (_listening != active) {

        setState(() => _listening = active);

      }

    };

  }



  @override

  void didUpdateWidget(ComposerSpeechButton oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (!widget.enabled && _listening) {

      stopIfListening();

    }

  }



  @override

  void dispose() {

    _speech.onListeningChanged = null;

    _speech.dispose();

    super.dispose();

  }



  /// Gönderim veya composer temizlenmeden önce çağır — STT metni tekrar yazmasın.

  Future<void> stopIfListening() async {

    if (!_listening && !_speech.isListening) return;

    await _speech.stopListening();

    if (mounted) setState(() => _listening = false);

  }



  Future<void> _toggle() async {

    if (!widget.enabled) return;



    if (_listening) {

      await stopIfListening();

      return;

    }



    FocusManager.instance.primaryFocus?.unfocus();



    final err = await _speech.startListening(

      existingText: widget.controller.text,

      onDisplayText: (text) {

        if (!_speech.isListening) return;

        widget.controller.value = TextEditingValue(

          text: text,

          selection: TextSelection.collapsed(offset: text.length),

        );

        if (mounted && !_listening) {

          setState(() => _listening = true);

        }

      },

    );

    if (err != null) {

      widget.onError?.call(err);

      return;

    }

    if (mounted) setState(() => _listening = _speech.isListening);

  }



  Future<void> _cancelLongPress() async {

    if (!_listening) return;

    final restored = await _speech.cancelListening();

    widget.controller.text = restored;

    if (mounted) setState(() => _listening = false);

  }



  @override

  Widget build(BuildContext context) {

    final active = _listening;

    return IconButton(

      key: const Key('composer_speech_mic'),

      tooltip: active

          ? 'Dinlemeyi bitir (basılı tut: iptal)'

          : 'Sesle yaz (telefon STT)',

      visualDensity: VisualDensity.compact,

      padding: EdgeInsets.zero,

      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),

      onPressed: widget.enabled ? _toggle : null,

      onLongPress: active ? _cancelLongPress : null,

      icon: Icon(

        active ? Icons.mic : Icons.mic_none_outlined,

        size: 22,

        color: active

            ? DesignTokens.amber500

            : widget.enabled

                ? DesignTokens.slate400

                : DesignTokens.slate600,

      ),

    );

  }

}


