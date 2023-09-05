import 'package:barcode_listener/barcode_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
//import 'second_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Initialize the binding
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String preAmble = prefs.getString('preAmble') ?? "";
  String postAmble = prefs.getString('postAmble') ?? "";
  runApp(MyApp(preAmble: preAmble, postAmble: postAmble));
}

class MyApp extends StatelessWidget {
  final String preAmble;
  final String postAmble;

  const MyApp({Key? key, required this.preAmble, required this.postAmble}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Scanner Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(
        title: 'Barcode Scanner Demo',
        preAmble: preAmble,
        postAmble: postAmble,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final String preAmble;
  final String postAmble;

  const MyHomePage({Key? key, required this.title, required this.preAmble, required this.postAmble}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _barcode;
  late bool visible;
  TextEditingController preAmbleController = TextEditingController();
  TextEditingController postAmbleController = TextEditingController();

  void _saveToPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('preAmble', preAmbleController.text);
    prefs.setString('postAmble', postAmbleController.text);
  }

  void _updateBarcodeListenerSettings() {
    barcodeListenerKey.currentState?.updatePreAndPostAmble(
      preAmbleController.text,
      postAmbleController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: VisibilityDetector(
          onVisibilityChanged: (VisibilityInfo info) {
            visible = info.visibleFraction > 0;
          },
        key: const Key('visible-detector-key'),
        child: BarcodeListener(
          key: barcodeListenerKey,
          onBarcodeScanned: (barcode) {
            if (!visible) return;
            debugPrint(barcode);
            setState(() {
              _barcode = barcode;
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: preAmbleController,
                decoration: InputDecoration(labelText: "Pre-amble"),
              ),
              TextField(
                controller: postAmbleController,
                decoration: InputDecoration(labelText: "Post-amble"),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveToPrefs();
                  _updateBarcodeListenerSettings();
                },
                child: Text("Save Preferences"),
              ),
              Text(
                _barcode == null ? 'SCAN BARCODE' : 'BARCODE: $_barcode',
                style: Theme.of(context).textTheme.headline6,
              ),
              // ... (existing code)
            ],
          ),
        ),
        ),
      ),
    );
  }
}