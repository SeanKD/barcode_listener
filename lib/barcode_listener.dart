// ToDo
// add a Scan Queue and Queue idle time
// use the Scan Queue form shared preference "EnableScanQueue" is set to Y
// QueueIdleTime from shared preference

library;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import 'package:shared_preferences/shared_preferences.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

enum SuffixType {enter}


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
  final List<String> _barcodeQueue = [];
  Timer? _queueTimer;
  int preAmbleIndex = 0;
  int postAmbleIndex = 0;

  late final suffixKey = switch (widget.suffixType) {
    SuffixType.enter => LogicalKeyboardKey.enter,

  };

  late final suffix = switch (widget.suffixType) {
    SuffixType.enter => '\n',

  };

  final List<String> _scannedChars = [];
  final _controller = StreamController<String?>();
  late StreamSubscription<String?> _keyboardSubscription;

bool bufferStarted = false; 


bool _keyBoardCallback(KeyEvent keyEvent) {
  bool isCorrectEventType = (widget.useKeyDownEvent && keyEvent is KeyDownEvent) || 
                            (!widget.useKeyDownEvent && keyEvent is KeyUpEvent);
                       
  if (!isCorrectEventType) {
    return false;
  }

  String? keyChar = keyEvent.character;
  int? keyCode = keyEvent.logicalKey.keyId;

  // Check preAmble sequence
  if (preAmbleIndex < preAmble!.length) {
    if (keyChar == preAmble![preAmbleIndex][1] || keyCode == preAmble![preAmbleIndex][0] || keyCode == preAmble![preAmbleIndex][2]) {
      preAmbleIndex++;
    } else {
      preAmbleIndex = 0; 
    }
    return false;
  }

  // Check postAmble sequence if preAmble was successfully detected
  if (preAmbleIndex == preAmble!.length) {
    if (postAmbleIndex < postAmble!.length) {
      if (keyChar == postAmble![postAmbleIndex][1] || keyCode == postAmble![postAmbleIndex][0] || keyCode == postAmble![postAmbleIndex][2]) {
        postAmbleIndex++;
        if (postAmbleIndex == postAmble!.length) {
          _controller.sink.add(suffix);
          postAmbleIndex = 0;
          preAmbleIndex = 0;
          return false;
        }
      } else {
        postAmbleIndex = 0;
        
        if (keyEvent.logicalKey.keyId > 255 && keyEvent.logicalKey != suffixKey) {
          return false;
        } else {
          _controller.sink.add(keyEvent.logicalKey.keyLabel);
          return false;
        }
      }
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
    String preAmbleStr = prefs.getString('preAmble') ?? "[[93,\"\\\"]\",93],[91,\"[\",91]]";
    try {
      preAmble = List<List<dynamic>>.from(jsonDecode(preAmbleStr));
    } catch (e) {
      print("Error decoding preAmble: $e");
      preAmble = [];
    }

    String postAmbleStr = prefs.getString('postAmble') ?? "[[13,\"\\r\",4294967309]]";
    try {
      postAmble = List<List<dynamic>>.from(jsonDecode(postAmbleStr));
    } catch (e) {
      print("Error decoding postAmble: $e");
      postAmble = []; // or some default value
    }
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
      String barcode = _scannedChars.join();
      _addBarcodeToQueue(barcode);  // Call the new method here
      resetScannedCharCodes();
    } else {
      // add character to list of scanned characters;
      _scannedChars.add(char);
    }
  }

  void _addBarcodeToQueue(String barcode) {
    _barcodeQueue.add(barcode);
    _queueTimer ??= Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_barcodeQueue.isNotEmpty) {
        handleSubmit();
      } else {
        timer.cancel();
        _queueTimer = null;
      }
    });
  }

  void handleSubmit() {
    String barcode = _barcodeQueue.removeAt(0);  // Dequeue the first barcode
    widget.onBarcodeScanned?.call(barcode);
  }

  void resetScannedCharCodes() {
    _scannedChars.clear();
  }

  void addScannedCharCode(String charCode) => _scannedChars.add(charCode);

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _queueTimer?.cancel();
    _keyboardSubscription.cancel();
    _controller.close();
    HardwareKeyboard.instance.removeHandler(_keyBoardCallback);
    super.dispose();
  }

  List<List<dynamic>> asciiAndCharArray(String asciiStr) {
    List<List<dynamic>> result = [];

    try {
      List<String> parts = asciiStr.split(',');

      for (String part in parts) {
        String trimmedPart = part.trim();
        if (trimmedPart.isEmpty) {
          print("Warning: Encountered an empty part after splitting and trimming.");

          continue;
        }

        int? codePoint;
        try {
          codePoint = int.parse(trimmedPart); // Convert the string to an integer
        } catch (e) {
          print("Error parsing part '$trimmedPart' to integer: $e");
          continue;
        }

        String char = String.fromCharCode(codePoint); // Convert the integer to its ASCII character
        
        int? keyId;

        if (codePoint >= 32 && codePoint <= 126) {
          // printable ASCII characters
          keyId = codePoint;
        } else {
          // For special keys
          switch (codePoint) {
            case 9:
              keyId = LogicalKeyboardKey.tab.keyId;
              break;
            case 10:
              keyId = LogicalKeyboardKey.enter.keyId;
              break;
            case 13:
              keyId = LogicalKeyboardKey.enter.keyId;
              break;
            default:
              print("Unknown key for ASCII code $codePoint");
          }
        }

        if (keyId != null) {
          result.add([codePoint, char, keyId]);
        }
      }
    } catch (e) {
      print("Error parsing ASCII string: $e");
    }

    return result;
  }

}