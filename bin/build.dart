import 'dart:io';

import 'package:dungeonclub/environment.dart';
import 'package:path/path.dart' as p;

import 'entry_parser.dart';

const BUILD_COPY_MUSIC = 'copy-music';

const BUILD_PART = 'part';
const BUILD_PART_SERVER = 'server';
const BUILD_PART_ALL = 'all';
const BUILD_PARTS = [BUILD_PART_SERVER, BUILD_PART_ALL];

final defaultConfig = {
  Environment.ENV_MOCK_ACCOUNT: true,
  Environment.ENV_ENABLE_MUSIC: false,
  Environment.ENV_TIMESTAMP: DateTime.now().millisecondsSinceEpoch,
  BUILD_COPY_MUSIC: false,
  BUILD_PART: BUILD_PART_ALL,
};

void main(List<String> args) async {
  await buildWithArgs(Directory('build/latest'), args);
}

Future<void> buildWithArgs(Directory output, List<String> args) async {
  var parser = EntryParser(
    defaultConfig,
    prepend: (parser, addFlag) {
      parser.addOption(BUILD_PART,
          help: 'Which parts to compile and include in the build.',
          allowed: BUILD_PARTS,
          defaultsTo: BUILD_PART_ALL);
    },
    append: (parser, addFlag) {
      addFlag(
          BUILD_COPY_MUSIC,
          'Whether to include locally downloaded music (ambience/tracks/*.mp3) '
          'in the build.');
    },
  );
  var config = parser.tryArgParse(args);
  await build(output, config);
}

void printStep(String msg) {
  print('\n\n--- $msg\n');
}

Future<void> build(Directory output, [Map<String, dynamic> D]) async {
  D ??= defaultConfig;
  var hide = ['help', Environment.ENV_TIMESTAMP];
  var env = declareArgs(D);

  print('Building Dungeon Club with configuration');
  for (var d in D.entries) {
    if (!hide.contains(d.key)) {
      print('  ${d.key}: ${d.value}');
    }
  }

  if (await output.exists()) {
    await output.delete(recursive: true);
  }

  await output.create(recursive: true);

  if (D[BUILD_PART] == BUILD_PART_ALL) {
    await copySourceWebFiles(output);
    await copyAmbience(output, D[BUILD_COPY_MUSIC]);
    await copyMail(output);

    if (D[Environment.ENV_MOCK_ACCOUNT]) {
      var mockFile = File(p.join(output.path, 'login.yaml'));
      await mockFile.create();
      await mockFile.writeAsString('''
# This file is interpreted as a list of registered accounts.
# Each line may define an account in a format of "username: password".
admin: admin
''');
    }

    printStep('Compiling SCSS');
    await compileStyling(output);

    printStep('Compiling frontend');
    await compileFrontend(output, env);
  }

  printStep('Compiling backend');
  await compileBackend(output, env);

  print('\nBuild successful!');
}

Future<void> copyAmbience(Directory output, bool includeTracks) {
  return copyDirectory('ambience', p.join(output.path, 'ambience'), (fse) {
    if (!includeTracks) {
      var path = p.split(fse.path);
      if (path.contains('tracks')) return false;
    }
    return true;
  });
}

Future<void> copyMail(Directory output) {
  return copyDirectory(
      'mail', p.join(output.path, 'mail'), (fse) => fse.path.endsWith('.html'));
}

Future<void> copySourceWebFiles(Directory output) async {
  var excludeExt = ['.dart', '.sh', '.deps', '.map'];
  await copyDirectory('web', p.join(output.path, 'web'), (fse) {
    if (fse is Directory) {
      var path = p.split(fse.path);
      return !path.contains('dart');
    }

    if (fse is File) {
      var ext = p.extension(fse.path);
      var name = p.basename(fse.path);
      return !excludeExt.contains(ext) && name != 'privacy.html';
    }

    return true;
  });
}

Future<void> copyDirectory(
  String src,
  String dst,
  bool Function(FileSystemEntity fse) doCopy,
) async {
  await Directory(dst).create(recursive: true);
  await for (final file in Directory(src).list(recursive: true)) {
    if (!doCopy(file)) continue;

    final copyTo = p.join(dst, p.relative(file.path, from: src));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await File(file.path).copy(copyTo);
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

Future<void> compileStyling(Directory output) async {
  await cmdAwait(Process.start('dart', [
    'pub',
    'global',
    'activate',
    'sass',
  ]));
  await cmdAwait(Process.start('dart', [
    'pub',
    'global',
    'run',
    'sass',
    'web/sass/style.scss',
    p.join(output.path, 'web', 'style', 'style.css'),
    '--style',
    'compressed',
  ]));
}

Future<void> compileFrontend(Directory output, List<String> declarations) {
  return cmdAwait(Process.start('dart', [
    'compile',
    'js',
    '-O4',
    '-o',
    p.join(output.path, 'web', 'main.dart.js'),
    'web/main.dart',
    '-v',
    ...declarations
  ]));
}

Future<void> compileBackend(Directory output, List<String> declarations) {
  var ext = '';
  if (Platform.isWindows) {
    ext = '.exe';
  }

  return cmdAwait(Process.start('dart', [
    'compile',
    'exe',
    'bin/server.dart',
    '-o',
    p.join(output.path, 'server$ext'),
    '-v',
    ...declarations
  ]));
}

Future<int> cmdAwait(Future<Process> processCompleter) async {
  var process = await processCompleter;

  process.stdout.listen((data) {
    stdout.add(data);
  });
  process.stderr.listen((data) {
    stderr.add(data);
  });

  return process.exitCode;
}
