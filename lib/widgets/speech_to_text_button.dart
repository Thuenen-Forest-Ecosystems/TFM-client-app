import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToTextButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onTextChanged;
  final String? fieldType;

  const SpeechToTextButton({
    super.key,
    required this.controller,
    this.onTextChanged,
    this.fieldType,
  });

  @override
  State<SpeechToTextButton> createState() => _SpeechToTextButtonState();
}

class _SpeechToTextButtonState extends State<SpeechToTextButton> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Speech recognition not available')));
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            String newText = result.recognizedWords;

            // Handle type conversion based on fieldType
            if (widget.fieldType == 'number' || widget.fieldType == 'integer') {
              // Extract numbers from recognized text
              final numberPattern = RegExp(r'-?\d+([.,]\d+)?');
              final match = numberPattern.firstMatch(newText);
              if (match != null) {
                newText = match.group(0)!.replaceAll(',', '.');
                if (widget.fieldType == 'integer') {
                  // Remove decimal part for integers
                  newText = newText.split('.')[0];
                }
              } else {
                // No number found, keep original text
                newText = result.recognizedWords;
              }
            }

            widget.controller.text = newText;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: newText.length),
            );

            widget.onTextChanged?.call();
          }
        },
        localeId: 'de_DE', // German locale, change as needed
      );
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: _isListening ? Colors.green : null,
      ),
      onPressed: _isAvailable ? _toggleListening : null,
      tooltip: _isListening ? 'Stop listening' : 'Start speech recognition',
    );
  }
}
