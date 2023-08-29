library;
// update this so the instead of using the bufferDuration it looks for all the keys between the preAmble and postAmble and then calls the callback with the result
// the preAmble is ][ witch are ascii 93 and 91 split with the splitToken , and the postAmble is CR witch is ascii 13

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

typedef BarcodeScannedCallback = void Function(String barcode);

//const Duration _hundredMs = Duration(milliseconds: 100);

enum SuffixType { enter, tab }

/// This widget will listen for raw PHYSICAL keyboard events　even when other controls have primary focus.
/// It will buffer all characters coming in specifed `bufferDuration` time frame　that end with line feed character and call callback function with result.
/// Keep in mind this widget will listen for events even when not visible.
/// Windows seems to be using the [KeyDownEvent] instead of the [KeyUpEvent], this behaviour can be managed by setting [useKeyDownEvent].
class CodeScanListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedCallback? onBarcodeScanned;
  //final Duration bufferDuration;
  final preAmble = '93,91';
  final postAmble = '13';
  final splitToken = ',';
  final bool useKeyDownEvent;
  final SuffixType suffixType;

  /// This widget will listFren for raw PHYSICAL keyboard events　even when other controls have primary focus.
  /// It will buffer all characters coming in specifed `bufferDuration` time frame　that end with line feed character and call callback function with result.
  /// Keep in mind this widget will listen for events even when not visible.
  const CodeScanListener({
    super.key,

    /// Child widget to be displayed.
    required this.child,

    /// Callback to be called when barcode is scanned.
    required this.onBarcodeScanned,

    /// When experiencing issueswith empty barcodes on Windows,set this value to true. Default value is `false`.
    this.useKeyDownEvent = false,

    /// Maximum time between two key events.
    /// If time between two key events is longer than this value
    /// previous keys will be ignored.
    //this.bufferDuration = _hundredMs,

    /// detect suffix type
    this.suffixType = SuffixType.enter,
  });

  @override
  State<CodeScanListener> createState() => _CodeScanListenerState();
}

class _CodeScanListenerState extends State<CodeScanListener> {
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

  DateTime? _lastScannedCharCodeTime;

  // TODO wrap this in a preamble check

  bool _keyBoardCallback(KeyEvent keyEvent) {
    if (keyEvent.character == "1" || keyEvent.character == "5" || keyEvent.character == "9"  || keyEvent.character == "9" ) {
    switch ((keyEvent, widget.useKeyDownEvent)) {
      case (KeyEvent(logicalKey: final key), _)
          when key.keyId > 255 && key != suffixKey:
        return false;
      case (KeyUpEvent(logicalKey: final key), false) when key == suffixKey:
        _controller.sink.add(suffix);
        return false;

      case (final KeyUpEvent event, false):
        _controller.sink.add(event.logicalKey.keyLabel);
        return false;

      case (KeyDownEvent(logicalKey: final key), true) when key == suffixKey:
        _controller.sink.add(suffix);
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
  }

  void onKeyEvent(String char) {
    // remove any pending characters older than bufferDuration value
    //checkPendingCharCodesToClear();
    //_lastScannedCharCodeTime = clock.now();
    if (char == suffix) {
      widget.onBarcodeScanned?.call(_scannedChars.join());
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
    _lastScannedCharCodeTime = null;
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
}
