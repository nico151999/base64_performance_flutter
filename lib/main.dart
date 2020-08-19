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
    _fileResults = Map<String, List<Tuple2<int, int>>>();
    _readAssets();
  }

  Future<void> _readAssets() async {
    AssetBundle bundle = DefaultAssetBundle.of(context);
    Map<String, dynamic> manifestMap = jsonDecode(
        await bundle.loadString('AssetManifest.json')
    );
    _files = manifestMap.keys.toList();

    _fileBinaries = Map<String, Uint8List>();
    for (String file in _files) {
      _fileBinaries[file] = (await bundle.load(file))
          .buffer.asUint8List();
    }
  }

  void _runPerformanceTest() async {
    setState(() {
      _fileResults.clear();
      _running = true;
    });
    Map<String, List<Tuple2<int, int>>> result = await compute(
        testPerformance,
        _fileBinaries
    );
    setState(() {
      _fileResults = result;
      _running = false;
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
      if (_fileResults.isEmpty) {
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

Future<Map<String, List<Tuple2<int, int>>>> testPerformance(Map<String, Uint8List> binaries) async {
  Map<String, List<Tuple2<int, int>>> ret = Map<String, List<Tuple2<int, int>>>();
  binaries.keys.forEach((key) {
    ret[key] = List<Tuple2<int, int>>();
  });

  int iterations = 100;
  String encoded;
  Uint8List binary;
  for (int i = 0; i < iterations; i++) {
    for (String file in binaries.keys) {
      binary = binaries[file];
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
      ret[file].add(Tuple2<int, int>(encodingTime, decodingTime));
    }
  }

  return ret;
}