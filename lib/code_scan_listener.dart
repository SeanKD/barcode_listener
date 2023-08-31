// ToDo
// add system preference for suffix and prefix.
// add a buffer / scan queue
// Queue idle time Enable Scan Queue


library;

import 'dart:async';

//import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import 'package:shared_preferences/shared_preferences.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

//const Duration _hundredMs = Duration(milliseconds: 100);

enum SuffixType { enter, tab }
enum ScanState { idle, foundCloseBracket, foundOpenBracket }


/// This widget will listen for raw PHYSICAL keyboard events　even when other controls have primary focus.
/// It will buffer all characters coming in specified `bufferDuration` time frame　that end with line feed character and call callback function with result.
/// Keep in mind this widget will listen for events even when not visible.
/// Windows seems to be using the [KeyDownEvent] instead of the [KeyUpEvent], this behavior can be managed by setting [useKeyDownEvent].
class CodeScanListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback? onBarcodeScanned;
  //final Duration bufferDuration;
  final bool useKeyDownEvent;
  final SuffixType suffixType;
  //final String preAmble;
  //final String postAmble;
  final String splitToken = ',';
  

  /// This widget will listen for raw PHYSICAL keyboard events　even when other controls have primary focus.
  /// It will buffer all characters coming in specified `bufferDuration` time frame　that end with line feed character and call callback function with result.
  /// Keep in mind this widget will listen for events even when not visible.
  const CodeScanListener({
    super.key,

    /// Child widget to be displayed.
    required this.child,

    /// Callback to be called when barcode is scanned.
    required this.onBarcodeScanned,

    /// When experiencing issues with empty barcode's on Windows,set this value to true. Default value is `false`.
    this.useKeyDownEvent = false,

    /// Maximum time between two key events.
    /// If time between two key events is longer than this value
    /// previous keys will be ignored.
    //this.bufferDuration = _hundredMs,

    /// detect suffix type
    this.suffixType = SuffixType.enter,

    //required this.preAmble,
    //required this.postAmble,
  });

  @override
  State<CodeScanListener> createState() => _CodeScanListenerState();
}

class _CodeScanListenerState extends State<CodeScanListener> {
  String? preAmble;
  String? postAmble;
  ScanState currentScanState = ScanState.idle;
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

  //DateTime? _lastScannedCharCodeTime;


bool bufferStarted = false; 

bool _keyBoardCallback(KeyEvent keyEvent) {
  // If we've found ']' but the next character isn't '[', reset to idle state
  if (currentScanState == ScanState.foundCloseBracket &&
      !(keyEvent.character == "[" || keyEvent.logicalKey.keyId == 91)) {
    currentScanState = ScanState.idle;
    bufferStarted = false;  // Reset the buffer started flag
  }

  // Look for the ']' character
  if (keyEvent.character == "]" || keyEvent.logicalKey.keyId == 93) {
    currentScanState = ScanState.foundCloseBracket;
    return false;
  }

  // If we've found ']' and the next character is '[', start buffering
  if (currentScanState == ScanState.foundCloseBracket &&
      (keyEvent.character == "[" || keyEvent.logicalKey.keyId == 91)) {
    currentScanState = ScanState.foundOpenBracket;
    bufferStarted = true;  // Set the buffer started flag
    return false;
  }


  if (currentScanState == ScanState.foundOpenBracket) {
    switch ((keyEvent, widget.useKeyDownEvent)) {
      case (KeyEvent(logicalKey: final key), _)
          when key.keyId > 255 && key != suffixKey:
        return false;
      case (KeyUpEvent(logicalKey: final key), false) when key == suffixKey:
        widget.onBarcodeScanned?.call(_scannedChars.join());
        _scannedChars.clear();
        currentScanState = ScanState.idle;
        bufferStarted = false;  // Reset the buffer started flag
        return false;
      case (final KeyUpEvent event, false):
        if (!bufferStarted || 
            (bufferStarted && (event.logicalKey.keyId != 91 && event.logicalKey.keyId != 93))) {
          _scannedChars.add(event.logicalKey.keyLabel);
        }
        bufferStarted = true;  // Now, we can start adding any character
        return false;
      case (KeyDownEvent(logicalKey: final key), true) when key == suffixKey:
        widget.onBarcodeScanned?.call(_scannedChars.join());
        _scannedChars.clear();
        currentScanState = ScanState.idle;
        bufferStarted = false;  // Reset the buffer started flag
        return false;
      case (final KeyDownEvent event, true):
        if (!bufferStarted || 
            (bufferStarted && (event.logicalKey.keyId != 91 && event.logicalKey.keyId != 93))) {
          _scannedChars.add(event.logicalKey.keyLabel);
        }
        bufferStarted = true;  // Now, we can start adding any character
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
    setState(() {
      preAmble = prefs.getString('preAmble') ?? "91,93";  // set a default value
      postAmble = prefs.getString('postAmble') ?? "13";  // set a default value
    });
  }
/*
  void _savePreAndPostAmbleToPreferences(String preAmble, String postAmble) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('preAmble', preAmble);
    prefs.setString('postAmble', postAmble);
  }

    // Add a method to update pre and postamble, and save it to preferences
  void updatePreAndPostAmble(String newPreAmble, String newPostAmble) {
    setState(() {
      preAmble = newPreAmble;
      postAmble = newPostAmble;
    });
    _savePreAndPostAmbleToPreferences(newPreAmble, newPostAmble);
  }
*/

  void onKeyEvent(String char) {
    // remove any pending characters older than bufferDuration value
    //checkPendingCharCodesToClear();
    //_lastScannedCharCodeTime = clock.now();
    if (char == suffix) {
      // update this code to also send back the pre and post amble
      widget.onBarcodeScanned?.call('{_scannedChars.join()}');
      resetScannedCharCodes();
    } else {
      // add character to list of scanned characters;
      _scannedChars.add(char);
    }
  }

/*
  void checkPendingCharCodesToClear() {
    if (_lastScannedCharCodeTime case final lastScanned?
        when lastScanned
            .isBefore(clock.now().subtract(widget.bufferDuration))) {
      resetScannedCharCodes();
    }
  }
*/

  void resetScannedCharCodes() {
    //_lastScannedCharCodeTime = null;
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
    // Split the string into parts
    List<String> parts = asciiStr.split(',');
    
    // Initialize an empty list to store the 2D array
    List<List<dynamic>> result = [];
    
    // Loop through each part and convert it to its ASCII character
    for (String part in parts) {
      int codePoint = int.parse(part); // Convert the string to an integer
      String char = String.fromCharCode(codePoint); // Convert the integer to its ASCII character
      
      // Append a list containing the ASCII code and the character to the result
      result.add([codePoint, char]);
    }
    
    return result;
  }

}