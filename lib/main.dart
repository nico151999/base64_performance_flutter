import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final String _title = 'BASE64 Test';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: _title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<String> _files;
  bool _running;
  Map<String, Uint8List> _fileBinaries;
  Map<String, List<Tuple2<int, int>>> _fileResults;

  @override
  void initState() {
    super.initState();
    _files = List<String>();
    _running = false;
    _readAssets().then((bins) {
      _fileBinaries = bins;
      setState(() {
        _fileResults = Map<String, List<Tuple2<int, int>>>();
        for (String file in _files) {
          _fileResults[file] = List<Tuple2<int, int>>();
        }
      });
    });
  }

  Future<Map<String, Uint8List>> _readAssets() async {
    AssetBundle bundle = DefaultAssetBundle.of(context);
    Map<String, dynamic> manifestMap = jsonDecode(
        await bundle.loadString('AssetManifest.json')
    );
    _files = manifestMap.keys.toList();

    Map<String, Uint8List> ret = Map<String, Uint8List>();
    for (String file in _files) {
      ret[file] = (await bundle.load(file))
          .buffer.asUint8List();
    }
    return ret;
  }

  void _runPerformanceTest() async {
    setState(() {
      _fileResults.keys.forEach((key) {
        _fileResults[key].clear();
      });
      _running = true;
    });
    // Without timer UI will be blocked. Dirty solution but 2 seconds should
    // be enough to run build() on every device
    Timer(Duration(seconds: 2), () {
      int iterations = 10;
      String encoded;
      Uint8List binary;
      for (int i = 0; i < iterations; i++) {
        for (String file in _files) {
          binary = _fileBinaries[file];
          int startTimestamp = DateTime
              .now()
              .microsecondsSinceEpoch;
          encoded = base64Encode(binary);
          int encodedTimestamp = DateTime
              .now()
              .microsecondsSinceEpoch;
          base64Decode(encoded);
          int endTimestamp = DateTime
              .now()
              .microsecondsSinceEpoch;
          int encodingTime = encodedTimestamp - startTimestamp;
          int decodingTime = endTimestamp - encodedTimestamp;
          print("Encoding $file took $encodingTimeµs");
          print("Decoding $file took $decodingTimeµs");
          _fileResults[file].add(Tuple2<int, int>(encodingTime, decodingTime));
        }
      }
      setState(() {
        _running = false;
      });
    });
  }

  String _getAverages(List<Tuple2<int, int>> measurements) {
    int encodingSum = 0;
    int decodingSum = 0;
    measurements.forEach((measurement) {
      encodingSum += measurement.item1;
      decodingSum += measurement.item2;
    });
    int itemCount = measurements.length;
    return 'Encoding: ${encodingSum/itemCount}µs\nDecoding: ${decodingSum/itemCount}µs';
  }

  List<Text> _getAverageVisualization() {
    List<Text> ret = List<Text>();
    for (String file in _files) {
      ret.add(Text('$file file average:'));
      String value;
      if (_fileResults[file].isEmpty) {
        value = 'Waiting...';
      } else {
        value = _getAverages(_fileResults[file]);
      }
      ret.add(Text(
        value,
        style: Theme.of(context).textTheme.headline6,
      ));
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _getAverageVisualization(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _running ? null : _runPerformanceTest,
        tooltip: 'Start performance test',
        child: _running ? Icon(Icons.data_usage) : Icon(Icons.play_arrow),
        backgroundColor: _running ? Colors.red : null,
      ),
    );
  }
}