import 'package:flutter/material.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:slick_slides_client/slick_slides_client.dart';
import 'package:slick_slides_remote/remote.dart';

var client = Client('http://172.20.10.3:8080/')
  ..connectivityMonitor = FlutterConnectivityMonitor();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RemoteHomePage(),
    );
  }
}

class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({super.key});

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  DeckState? _deckState;

  @override
  void initState() {
    super.initState();
    print('Connecting to server');
    client.remote.deckUpdates().listen((deckState) {
      setState(() {
        _deckState = deckState;
        print('Connected! Deck is online: ${deckState.isConnected}');
      });
    }, onDone: () {
      setState(() {
        _deckState = null;
      });
    }, onError: (e) {
      setState(() {
        _deckState = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Slick Slides Remote'),
      ),
      body: _deckState == null
          ? const Scaffold(
              body: Center(
              child: CircularProgressIndicator(),
            ))
          : Remote(
              deckState: _deckState!,
              onNext: client.remote.next,
              onPrevious: client.remote.previous,
            ),
    );
  }
}
