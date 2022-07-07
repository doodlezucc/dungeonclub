import 'dart:io';

import 'package:args/args.dart';
import 'package:dnd_interactive/environment.dart';

typedef ParserBuilder = void Function(
  ArgParser parser,
  void Function(String key, String description, [bool negatable]) addFlag,
);

class EntryParser {
  final Map<String, dynamic> defaultConfig;
  final ArgParser parser;

  EntryParser(
    this.defaultConfig, {
    ParserBuilder prepend,
    ParserBuilder append,
  }) : parser = _makeParser(defaultConfig, prepend: prepend, append: append);

  Map<String, dynamic> tryArgParse(Iterable<String> args) {
    var config = Map<String, dynamic>.of(defaultConfig);

    Null _exitWithHelp() {
      print('Valid arguments:\n${parser.usage}');
      return exit(1);
    }

    try {
      var results = parser.parse(args);
      if (results.wasParsed('help')) return _exitWithHelp();

      config.addEntries(
          results.options.map((key) => MapEntry(key, results[key])));
      return config;
    } on ArgParserException catch (e) {
      print('Error: ${e.message}\n');
      return _exitWithHelp();
    }
  }
}

ArgParser _makeParser(
  Map<String, dynamic> defaultConfig, {
  ParserBuilder prepend,
  ParserBuilder append,
}) {
  var parser = ArgParser(usageLineLength: 120)
    ..addFlag('help', abbr: 'h', negatable: false, hide: true);

  void addFlag(String key, String description, [bool negatable = true]) {
    parser.addFlag(key,
        defaultsTo: defaultConfig[key],
        negatable: negatable,
        help: description);
  }

  if (prepend != null) prepend(parser, addFlag);

  addFlag(
      Environment.ENV_MOCK_ACCOUNT,
      'Whether to accept contents of "login.yaml" as a list of '
      'registered accounts.');

  addFlag(
      Environment.ENV_ENABLE_MUSIC,
      'Whether to enable the integrated music player. '
      'Server hosts may need to install youtube-dl and ffmpeg to '
      'download 500 MB of background music.');

  if (append != null) append(parser, addFlag);

  return parser;
}

List<String> declareArgs(Map<String, dynamic> declarations) {
  return declarations.entries
      .where((d) => Environment.allKeys.contains(d.key))
      .map((d) => '-D${d.key}=${d.value}')
      .toList();
}
