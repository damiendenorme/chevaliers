import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'widgets/top_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
}

/// Nombre de lignes dans la table `joueur`.
Future<int> fetchPlayerCount() =>
    Supabase.instance.client.from('joueur').count(CountOption.exact);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Les Chevaliers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        // Fond uni gris foncé ; le thème sombre garde le texte clair et lisible.
        scaffoldBackgroundColor: const Color(0xFF2B2B2B),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.loadPlayerCount = fetchPlayerCount});

  final Future<int> Function() loadPlayerCount;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final Future<int> _playerCount = widget.loadPlayerCount();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FutureBuilder<int>(
              future: _playerCount,
              builder: (context, snapshot) => TopBar(
                items: [
                  TopBarInfo(
                    icon: Icons.person,
                    value: snapshot.data,
                    tooltip: 'Joueurs',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
