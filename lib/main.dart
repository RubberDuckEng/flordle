import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

void main() async {
  // var wordsString = await rootBundle.loadString('assets/words.txt');
  // var words = LineSplitter.split(wordsString).toList();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flordle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flordle'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Center(child: FlordleGrid(model: FlordleModel.init('floor'))),
          ],
        ),
      ),
    );
  }
}

class FlordleModel {
  final List<String> guesses;
  final String target;

  FlordleModel._({required this.guesses, required this.target});

  factory FlordleModel.init(String target) {
    return FlordleModel._(
      guesses: <String>[],
      target: target,
    );
  }

  FlordleModel withGuess(String guess) {
    return FlordleModel._(
      guesses: List<String>.from(guesses)..add(guess),
      target: target,
    );
  }
}

enum FlordleTileDisposition {
  // The letter is in the word and in the correct place.
  correct,

  // The letter is in the word but not in the correct place.
  present,

  // The letter is not in the word.
  missing,
}

class FlordleTile extends StatelessWidget {
  final String? letter;
  final FlordleTileDisposition disposition;

  const FlordleTile({
    Key? key,
    required String this.letter,
    required this.disposition,
  }) : super(key: key);

  const FlordleTile.empty({
    Key? key,
  })  : letter = null,
        disposition = FlordleTileDisposition.missing,
        super(key: key);

  Color _getColor(BuildContext context) {
    switch (disposition) {
      case FlordleTileDisposition.correct:
        return Colors.blue.shade500;
      case FlordleTileDisposition.present:
        return Colors.yellow.shade500;
      case FlordleTileDisposition.missing:
        return Colors.black26;
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = this.letter;
    return Container(
      decoration: BoxDecoration(
        color: _getColor(context),
      ),
      width: 100.0,
      height: 300.0,
      child: letter != null ? Text(letter) : null,
    );
  }
}

const int kNumberOfGuesses = 6;
const int kNumberOfLetters = 5;

class FlordleGrid extends StatelessWidget {
  final FlordleModel model;

  const FlordleGrid({
    required this.model,
    Key? key,
  }) : super(key: key);

  FlordleTile _buildTile(BuildContext context, int wordIndex, int letterIndex) {
    if (wordIndex >= model.guesses.length) {
      return const FlordleTile.empty();
    }
    final guess = model.guesses[wordIndex];
    final letter = guess[letterIndex];
    FlordleTileDisposition disposition;
    if (model.target[letterIndex] == letter) {
      disposition = FlordleTileDisposition.correct;
    } else if (model.target.contains(letter)) {
      disposition = FlordleTileDisposition.missing;
    } else {
      disposition = FlordleTileDisposition.missing;
    }

    return FlordleTile(letter: letter, disposition: disposition);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      for (int wordIndex = 0; wordIndex < kNumberOfGuesses; ++wordIndex)
        Row(
          children: <Widget>[
            for (int letterIndex = 0;
                letterIndex < kNumberOfLetters;
                ++letterIndex)
              _buildTile(context, wordIndex, letterIndex)
          ],
        ),
    ]);
  }
}
