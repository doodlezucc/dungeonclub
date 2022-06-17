import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) async {
  await build(Directory('build/latest'));
}

void printStep(String msg) {
  print('\n\n--- $msg\n');
}

Future<void> build(
  Directory output, {
  bool includeMusicTracks = false,
  bool includeMailTemplates = true,
}) async {
  if (await output.exists()) {
    await output.delete(recursive: true);
  }

  // printStep('Copying files');
  await copySourceWebFiles(output);
  await copyAmbience(output, includeMusicTracks);

  if (includeMailTemplates) await copyMail(output);

  printStep('Compiling SCSS');
  await compileStyling(output);

  printStep('Compiling frontend');
  await compileFrontend(output);

  printStep('Compiling backend');
  await compileBackend(output);
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
  var excludeExt = ['.dart', '.scss', '.sh', '.deps', '.map'];
  await copyDirectory('web', p.join(output.path, 'web'), (fse) {
    if (fse is Directory) {
      var path = p.split(fse.path);
      return !path.contains('dart') && !path.contains('sass');
    }

    if (fse is File) {
      return !excludeExt.contains(p.extension(fse.path));
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

Future<void> compileFrontend(Directory output) {
  return cmdAwait(Process.start('dart', [
    'compile',
    'js',
    '-O4',
    '-o',
    p.join(output.path, 'web', 'main.dart.js'),
    'web/main.dart',
    '-v',
  ]));
}

Future<void> compileBackend(Directory output) {
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
