import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class SpeechToTextButton extends StatefulWidget {
  final Function onChanged;
  const SpeechToTextButton({super.key, required this.onChanged});

  @override
  State<SpeechToTextButton> createState() => _SpeechToTextButtonState();
}

class _SpeechToTextButtonState extends State<SpeechToTextButton> {
  bool _hasSpeech = false;
  bool _logEvents = false;
  bool _onDevice = false;
  final TextEditingController _pauseForController = TextEditingController(text: '3');
  final TextEditingController _listenForController = TextEditingController(text: '30');
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    //initSpeechState();
  }

  void errorListener(SpeechRecognitionError error) {
    print('Received error status: $error, listening: ${speech.isListening}');
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    print('Received listener status: $status, listening: ${speech.isListening}');
    setState(() {
      lastStatus = status;
    });
  }

  /// This initializes SpeechToText. That only has to be done
  /// once per application, though calling it again is harmless
  /// it also does nothing. The UX of the sample app ensures that
  /// it can only be called once.
  /*Future<void> initSpeechState() async {
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: _logEvents,
      );
      if (hasSpeech) {
        // Get the list of languages installed on the supporting platform so they
        // can be displayed in the UI for selection by the user.
        _localeNames = await speech.locales();

        var systemLocale = await speech.systemLocale();
        _currentLocaleId = systemLocale?.localeId ?? '';
      }
      if (!mounted) return;

      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
  }*/

  dynamic _parseWords(String words) {
    // Parse the words and return a list of strings
    List<String> parsedWords = words.split(' ');
    // Check if integer oder double
    for (int i = 0; i < parsedWords.length; i++) {
      String word = parsedWords[i];
      if (double.tryParse(word) != null) {
        speech.stop();
        return word;
      } else if (int.tryParse(word) != null) {
        speech.stop();
        return word;
      }
    }
    return null;
  }

  /// This callback is invoked each time new recognition results are
  /// available after `listen` is called.
  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      lastWords = '${result.recognizedWords} - ${result.finalResult}';

      widget.onChanged(_parseWords(lastWords));
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

  void startListening() async {
    const _currentLocaleId = 'de-DE';
    //var selectedLocale = locales[selectedLocale];
    print('start');
    //String? currentLanguage = await getSettings('language');
    //print('language: ${currentLanguage}');

    try {
      print('start');
      String languageCountry = context.watch<Language>().locale.toString();
      print("locale: ${languageCountry}");
    } catch (e) {
      print("Error: $e");
    }
    lastWords = '';
    lastError = '';
    final pauseFor = int.tryParse(_pauseForController.text);
    final listenFor = int.tryParse(_listenForController.text);
    final options = SpeechListenOptions(onDevice: _onDevice, listenMode: ListenMode.confirmation, cancelOnError: true, partialResults: true, autoPunctuation: true, enableHapticFeedback: true);
    // Note that `listenFor` is the maximum, not the minimum, on some
    // systems recognition will be stopped before this value is reached.
    // Similarly `pauseFor` is a maximum not a minimum and may be ignored
    // on some devices. , localeId: _currentLocaleId
    speech.listen(onResult: resultListener, localeId: _currentLocaleId, listenFor: Duration(seconds: listenFor ?? 30), pauseFor: Duration(seconds: pauseFor ?? 3), onSoundLevelChange: soundLevelListener, listenOptions: options);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // green if .isListening
    // red if .isNotListening
    return IconButton(
      onPressed: () {
        if (speech.isListening) {
          speech.stop();
          setState(() {
            lastWords = '';
            lastError = '';
          });
        } else {
          startListening();
        }
      },
      icon: speech.isListening ? Icon(Icons.mic, color: Colors.green) : Icon(Icons.mic),
    );
  }
}
