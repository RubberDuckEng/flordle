import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() async {
  runApp(const FlordleApp());
}

class FlordleApp extends StatelessWidget {
  const FlordleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flordle',
      theme: ThemeData.dark(),
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
  late Future<List<String>> wordsFuture;

  Future<List<String>> _loadWords() async {
    var wordsString = await rootBundle.loadString('assets/words.txt');
    return LineSplitter.split(wordsString).toList();
  }

  @override
  void initState() {
    super.initState();
    wordsFuture = _loadWords();
  }

  // This is a hack, but seems close enough?
  double _scaleFactor(BuildContext context) {
    var windowSize = MediaQuery.of(context).size;
    var heightScale = windowSize.height / 700;
    var widthScale = windowSize.width / 400;
    return math.min(heightScale, widthScale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<List<String>>(
            future: wordsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Transform.scale(
                  scale: _scaleFactor(context),
                  child: FlordleGame(words: snapshot.data!),
                );
              } else {
                return const Center(child: Text('Loading...'));
              }
            }),
      ),
    );
  }
}

class FlordleGame extends StatefulWidget {
  final List<String> words;

  const FlordleGame({required this.words, Key? key}) : super(key: key);

  @override
  _FlordleGameState createState() => _FlordleGameState();
}

class _FlordleGameState extends State<FlordleGame> {
  late FlordleModel _model;
  final _random = math.Random();

  String _getRandomWord() {
    final index = _random.nextInt(widget.words.length);
    return widget.words[index];
  }

  @override
  void initState() {
    super.initState();
    _model = FlordleModel.init(_getRandomWord());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        FlordleGrid(model: _model),
        FlordleKeyboard(
            model: _model,
            onKeyPressed: (String key) {
              setState(() {
                _model = _model.withPendingLetter(key);
              });
            },
            onBackspace: () {
              setState(() {
                _model = _model.withBackspace();
              });
            },
            onEnter: () {
              setState(() {
                final guess = _model.pendingGuess;
                if (!widget.words.contains(guess)) {
                  var snackBar = const SnackBar(
                    content: Text('Guesses must be valid words.'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  _model = _model.withClearPending();
                } else {
                  _model = _model.withGuess(guess);
                }
              });
            }),
      ],
    );
  }
}

class FlordleModel {
  final List<String> guesses;
  final String target;
  final String pendingGuess;
  Map<String, FlordleTileDisposition>? _letterDispositions;

  FlordleModel._(
      {required this.guesses,
      required this.target,
      required this.pendingGuess});

  factory FlordleModel.init(String target) {
    return FlordleModel._(
      guesses: <String>[],
      target: target,
      pendingGuess: '',
    );
  }

  Map<String, FlordleTileDisposition> get letterDispositions {
    if (_letterDispositions != null) {
      return _letterDispositions!;
    }
    final map = <String, FlordleTileDisposition>{};
    for (var guessIndex = 0; guessIndex < guesses.length; ++guessIndex) {
      final guess = guesses[guessIndex];
      for (var letterIndex = 0; letterIndex < guess.length; ++letterIndex) {
        final letter = guess[letterIndex];
        final oldDisposition = map[letter] ?? FlordleTileDisposition.missing;
        final newDisposition = getDisposition(guessIndex, letterIndex);
        map[letter] = FlordleTileDisposition
            .values[math.max(oldDisposition.index, newDisposition.index)];
      }
    }
    _letterDispositions = map;
    return map;
  }

  FlordleTileDisposition getDisposition(int guessIndex, int letterIndex) {
    final guess = guesses[guessIndex];
    final letter = guess[letterIndex];
    if (target[letterIndex] == letter) {
      return FlordleTileDisposition.correct;
    } else if (target.contains(letter)) {
      return FlordleTileDisposition.present;
    } else {
      return FlordleTileDisposition.missing;
    }
  }

  FlordleModel withGuess(String guess) {
    return FlordleModel._(
      guesses: List<String>.from(guesses)..add(guess),
      target: target,
      pendingGuess: '',
    );
  }

  FlordleModel withPendingLetter(String letter) {
    if (pendingGuess.length >= kNumberOfLetters) {
      return this;
    }
    return FlordleModel._(
      guesses: guesses,
      target: target,
      pendingGuess: pendingGuess + letter,
    );
  }

  FlordleModel withClearPending() {
    return FlordleModel._(
      guesses: guesses,
      target: target,
      pendingGuess: '',
    );
  }

  FlordleModel withBackspace() {
    if (pendingGuess.isEmpty) {
      return this;
    }
    return FlordleModel._(
      guesses: guesses,
      target: target,
      pendingGuess: pendingGuess.substring(0, pendingGuess.length - 1),
    );
  }
}

enum FlordleTileDisposition {
  // The letter has never been guessed.
  unknown,

  // The letter is not in the word.
  missing,

  // The letter is in the word but not in the correct place.
  present,

  // The letter is in the word and in the correct place.
  correct,
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
        return Colors.green.shade500;
      case FlordleTileDisposition.present:
        return Colors.yellow.shade800;
      case FlordleTileDisposition.missing:
        return Colors.black26;
      case FlordleTileDisposition.unknown:
        return Colors.black45;
    }
  }

  Widget? _buildLetterText() {
    var letter = this.letter;
    if (letter == null) {
      return null;
    }
    return Center(
      child: Text(letter.toUpperCase(),
          style: const TextStyle(
            fontSize: 32.0,
            fontWeight: FontWeight.bold,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87, width: 1.0),
        borderRadius: BorderRadius.circular(5.0),
        color: _getColor(context),
      ),
      margin: const EdgeInsets.all(4.0),
      width: 60.0,
      height: 60.0,
      child: _buildLetterText(),
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
    if (wordIndex == model.guesses.length) {
      if (letterIndex >= model.pendingGuess.length) {
        return const FlordleTile.empty();
      }
      return FlordleTile(
        letter: model.pendingGuess[letterIndex],
        disposition: FlordleTileDisposition.unknown,
      );
    }
    if (wordIndex >= model.guesses.length) {
      return const FlordleTile.empty();
    }
    final letter = model.guesses[wordIndex][letterIndex];
    final disposition = model.getDisposition(wordIndex, letterIndex);
    return FlordleTile(letter: letter, disposition: disposition);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int wordIndex = 0; wordIndex < kNumberOfGuesses; ++wordIndex)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int letterIndex = 0;
                  letterIndex < kNumberOfLetters;
                  ++letterIndex)
                _buildTile(context, wordIndex, letterIndex)
            ],
          ),
      ],
    );
  }
}

class FlordleKey extends StatelessWidget {
  final String letter;
  final FlordleTileDisposition disposition;
  final ValueChanged<String> onKeyPressed;

  const FlordleKey({
    Key? key,
    required this.letter,
    required this.disposition,
    required this.onKeyPressed,
  }) : super(key: key);

  Color _getColor(BuildContext context) {
    switch (disposition) {
      case FlordleTileDisposition.correct:
        return Colors.green.shade500;
      case FlordleTileDisposition.present:
        return Colors.yellow.shade800;
      case FlordleTileDisposition.missing:
        return Colors.red.shade900;
      case FlordleTileDisposition.unknown:
        return Colors.black45;
    }
  }

  Widget? _buildLetterText() {
    return Center(
      child: Text(letter.toUpperCase(),
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onKeyPressed(letter);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87, width: 1.0),
          borderRadius: BorderRadius.circular(5.0),
          color: _getColor(context),
        ),
        margin: const EdgeInsets.all(4.0),
        width: 30.0,
        height: 30.0,
        child: _buildLetterText(),
      ),
    );
  }
}

class FlordleKeyboard extends StatefulWidget {
  final FlordleModel model;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;
  final ValueChanged<String> onKeyPressed;

  const FlordleKeyboard({
    required this.onKeyPressed,
    required this.onEnter,
    required this.onBackspace,
    required this.model,
    Key? key,
  }) : super(key: key);

  @override
  State<FlordleKeyboard> createState() => _FlordleKeyboardState();
}

class _FlordleKeyboardState extends State<FlordleKeyboard> {
  final focusNode = FocusNode();

  Widget _buildKeyRow(String letters) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < letters.length; ++i)
          FlordleKey(
            onKeyPressed: widget.onKeyPressed,
            letter: letters[i],
            disposition: widget.model.letterDispositions[letters[i]] ??
                FlordleTileDisposition.unknown,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    assert(letters.length == 26);
    final enterEnabled = widget.model.pendingGuess.length == kNumberOfLetters;
    final backspaceEnabled = widget.model.pendingGuess.isNotEmpty;

    return RawKeyboardListener(
      autofocus: true,
      focusNode: focusNode,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (enterEnabled &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            widget.onEnter();
            return;
          } else if (backspaceEnabled &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.onBackspace();
            return;
          }
        }
        final char = event.character;
        if (char == null) {
          return;
        }
        final lowerChar = char.toLowerCase();
        if (!letters.contains(lowerChar)) {
          return;
        }
        widget.onKeyPressed(lowerChar);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _buildKeyRow('qwertyuiop'),
          _buildKeyRow('asdfghjkl'),
          _buildKeyRow('zxcvbnm'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ElevatedButton(
                onPressed: enterEnabled
                    ? () {
                        widget.onEnter();
                      }
                    : null,
                child: const Text('ENTER'),
              ),
              ElevatedButton(
                onPressed: backspaceEnabled
                    ? () {
                        widget.onBackspace();
                      }
                    : null,
                child: const Icon(Icons.backspace),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
