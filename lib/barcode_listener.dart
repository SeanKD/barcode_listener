// ToDo
// add a buffer / scan queue
// Queue idle time Enable Scan Queue
library;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import 'package:shared_preferences/shared_preferences.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

enum SuffixType { enter, tab }


final GlobalKey<_BarcodeListenerState> barcodeListenerKey = GlobalKey<_BarcodeListenerState>();

/// This widget will listen for raw PHYSICAL keyboard events　even when other controls have primary focus.
/// It will buffer all characters coming in specified `bufferDuration` time frame　that end with line feed character and call callback function with result.
/// Keep in mind this widget will listen for events even when not visible.
/// Windows seems to be using the [KeyDownEvent] instead of the [KeyUpEvent], this behavior can be managed by setting [useKeyDownEvent].
class BarcodeListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback? onBarcodeScanned;
  final bool useKeyDownEvent;
  final SuffixType suffixType;
  final String splitToken = ',';
  

  /// This widget will listen for raw PHYSICAL keyboard events　even when other controls have primary focus.
  /// It will buffer all characters coming in specified `bufferDuration` time frame　that end with line feed character and call callback function with result.
  /// Keep in mind this widget will listen for events even when not visible.
  const BarcodeListener({
    super.key,

    /// Child widget to be displayed.
    required this.child,

    /// Callback to be called when barcode is scanned.
    required this.onBarcodeScanned,

    /// When experiencing issues with empty barcode's on Windows,set this value to true. Default value is `false`.
    this.useKeyDownEvent = false,

    this.suffixType = SuffixType.enter,
  });

  @override
  State<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends State<BarcodeListener> {
  List<List<dynamic>>? preAmble;
  List<List<dynamic>>? postAmble;

  int preAmbleIndex = 0;
  int postAmbleIndex = 0;
  bool hasData = false;
  List<String> data = [];
  late final suffixKey = switch (widget.suffixType) {
    SuffixType.enter => LogicalKeyboardKey.enter,
    SuffixType.tab => LogicalKeyboardKey.tab,
  };

  late final suffix = switch (widget.suffixType) {
    SuffixType.enter => '\n',
    SuffixType.tab => '\t',
  };

  final List<String> _scannedChars = [];
  final _controller = StreamController<String?>();
  late StreamSubscription<String?> _keyboardSubscription;

bool bufferStarted = false; 


bool _keyBoardCallback(KeyEvent keyEvent) {
    String? keyChar = keyEvent.character;
    int? keyCode = keyEvent.logicalKey.keyId;

    // Handle preAmble
    if (preAmbleIndex < preAmble!.length && keyEvent is! KeyDownEvent) {
      if (keyChar == preAmble![preAmbleIndex][1] || keyCode == preAmble![preAmbleIndex][0]) {
        preAmbleIndex++;
      } else {
        preAmbleIndex = 0;
      }
      return false;
    }
/*
    // Handle postAmble
    if (postAmbleIndex < postAmble!.length) {
      if (keyChar == postAmble![postAmbleIndex][1] || keyCode == postAmble![postAmbleIndex][0]) {
        postAmbleIndex++;
        if (postAmbleIndex == postAmble!.length) {
          hasData = true;
          widget.onBarcodeScanned?.call(data.join());
          data = [];
        }
      } else {
        postAmbleIndex = 0;
      }
      return false;
    }
*/

    if (preAmbleIndex == preAmble!.length) {
    switch ((keyEvent, widget.useKeyDownEvent)) {
      case (KeyEvent(logicalKey: final key), _)
          when key.keyId > 255 && key != suffixKey:
        return false;
      case (KeyUpEvent(logicalKey: final key), false) when key == suffixKey:
        _controller.sink.add(suffix);
        preAmbleIndex = 0;
        return false;

      case (final KeyUpEvent event, false):
        _controller.sink.add(event.logicalKey.keyLabel);
        return false;

      case (KeyDownEvent(logicalKey: final key), true) when key == suffixKey:
        _controller.sink.add(suffix);
        preAmbleIndex = 0;
        return false;

      case (final KeyDownEvent event, true):
        _controller.sink.add(event.logicalKey.keyLabel);
        return false;
    }
    }
    return false;
}

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(_keyBoardCallback);
    _keyboardSubscription =
        _controller.stream.whereNotNull().listen(onKeyEvent);
    super.initState();
    _readPreAndPostAmbleFromPreferences();
  }

  void _readPreAndPostAmbleFromPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String preAmbleStr = prefs.getString('preAmble') ?? "[[93, \"]\"], [91, \"[\"]]";
    preAmble = List<List<dynamic>>.from(jsonDecode(preAmbleStr));
  }

void updatePreAndPostAmble(String newPreAmble, String newPostAmble) {
  List<List<dynamic>> convertedPreAmble = asciiAndCharArray(newPreAmble);
  List<List<dynamic>> convertedPostAmble = asciiAndCharArray(newPostAmble);

  setState(() {
    preAmble = convertedPreAmble;
    postAmble = convertedPostAmble;
  });

  _savePreAndPostAmbleToPreferences(convertedPreAmble, convertedPostAmble);
}

void _savePreAndPostAmbleToPreferences(List<List<dynamic>> preAmble, List<List<dynamic>> postAmble) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String preAmbleJson = jsonEncode(preAmble);
  String postAmbleJson = jsonEncode(postAmble);
  prefs.setString('preAmble', preAmbleJson);
  prefs.setString('postAmble', postAmbleJson);
}

  void onKeyEvent(String char) {
    if (char == suffix) {
      widget.onBarcodeScanned?.call(_scannedChars.join());
      resetScannedCharCodes();
    } else {
      // add character to list of scanned characters;
      _scannedChars.add(char);
    }
  }

  void resetScannedCharCodes() {
    _scannedChars.clear();
  }

  void addScannedCharCode(String charCode) => _scannedChars.add(charCode);

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _keyboardSubscription.cancel();
    _controller.close();
    HardwareKeyboard.instance.removeHandler(_keyBoardCallback);
    super.dispose();
  }

List<List<dynamic>> asciiAndCharArray(String asciiStr) {
  // Initialize an empty list to store the 2D array
  List<List<dynamic>> result = [];
  
  try {
    // Split the string into parts
    List<String> parts = asciiStr.split(',');
    
    // Loop through each part and convert it to its ASCII character
    for (String part in parts) {
      int codePoint = int.parse(part.trim()); // Convert the string to an integer
      String char = String.fromCharCode(codePoint); // Convert the integer to its ASCII character
      
      // Append a list containing the ASCII code and the character to the result
      result.add([codePoint, char]);
    }
  } catch (e) {
    print("Error parsing ASCII string: $e");
  }

  return result;
}

}