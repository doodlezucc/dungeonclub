import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dungeonclub/environment.dart';
import 'package:path/path.dart' as p;
import 'package:sass/sass.dart' as sass;

import 'util/entry_parser.dart';

const BUILD_COPY_MUSIC = 'copy-music';
const BUILD_ICONS = 'download-icons';

const BUILD_PART = 'part';
const BUILD_PART_SERVER = 'server';
const BUILD_PART_ALL = 'all';
const BUILD_PARTS = [BUILD_PART_SERVER, BUILD_PART_ALL];

final defaultConfig = {
  Environment.ENV_MOCK_ACCOUNT: true,
  Environment.ENV_ENABLE_MUSIC: false,
  Environment.ENV_TIMESTAMP: DateTime.now().millisecondsSinceEpoch,
  BUILD_COPY_MUSIC: false,
  BUILD_ICONS: true,
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
      addFlag(
          BUILD_ICONS,
          'Whether to download and include the latest release of Font Awesome '
          '(icons used on the website)');
    },
  );
  var config = parser.tryArgParse(args);
  await build(output, config);
}

void printStep(String msg) {
  print('\n\n--- $msg\n');
}

Future<void> build(Directory output, [Map<String, dynamic>? D]) async {
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
    bool replaceIconKit = D[BUILD_ICONS];

    await copySourceWebFiles(output, replaceIconKit: replaceIconKit);
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

    if (replaceIconKit) {
      printStep('Downloading Font Awesome icons');
      await downloadFontAwesome(
        p.join(output.path, 'web', 'style', 'fontawesome.css'),
        p.join(output.path, 'web', 'webfonts'),
      );
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

Future<void> copySourceWebFiles(
  Directory output, {
  bool replaceIconKit = false,
}) async {
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
  }, postProcess: (file) async {
    if (replaceIconKit && file.path.endsWith('index.html')) {
      // Replace font awesome's icon kit with a local stylesheet
      final source = RegExp(r'<script[^>]*fontawesome.*<\/script>');
      final replace = '<link rel="stylesheet" href="style/fontawesome.css">';

      var contents = await file.readAsString();
      contents = contents.replaceFirst(source, replace);
      await file.writeAsString(contents);
    }
  });
}

Future<void> copyDirectory(
  String src,
  String dst,
  bool Function(FileSystemEntity fse) doCopy, {
  Future<void> Function(File file)? postProcess,
}) async {
  await Directory(dst).create(recursive: true);
  await for (final file in Directory(src).list(recursive: true)) {
    if (!doCopy(file)) continue;

    final copyTo = p.join(dst, p.relative(file.path, from: src));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      final created = await File(file.path).copy(copyTo);
      if (postProcess != null) {
        await postProcess(created);
      }
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
    }
  }
}

Future<void> compileStyling(Directory output) async {
  final compileResult = sass.compileToResult(
    'web/sass/style.scss',
    style: sass.OutputStyle.compressed,
  );

  final outputPath = p.join(output.path, 'web', 'style', 'style.css');
  final outputFile = File(outputPath);

  await outputFile.create(recursive: true);
  await outputFile.writeAsString(compileResult.css);
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

extension ClientExtension on HttpClient {
  Future<Stream<List<int>>> download(String url) async {
    final request = await getUrl(Uri.parse(url));
    return await request.close();
  }

  Future<String> downloadString(String url) async {
    final response = await download(url);
    return await utf8.decodeStream(response);
  }

  Future<List> listGitHubReleaseAssets(
    String repo, {
    String release = 'latest',
  }) async {
    final latestReleaseUrl =
        'https://api.github.com/repos/$repo/releases/$release';
    final body = await downloadString(latestReleaseUrl);
    return jsonDecode(body)['assets'];
  }
}

extension ArchiveExtension on ArchiveFile {
  Future<void> writeToFile(String output) async {
    final out = OutputFileStream(output);
    writeContent(out);
    await out.close();
  }
}

Future<void> downloadFontAwesome(
    String outputCss, String outputWebfonts) async {
  print('Reading latest release');

  final client = HttpClient();
  final repo = 'FortAwesome/Font-Awesome';
  final assets = await client.listGitHubReleaseAssets(repo);

  final webAsset = assets.firstWhere((assetEntry) {
    String assetName = assetEntry['name'];
    return assetName.contains('-web');
  });

  print('Downloading ' + webAsset['name']);
  String assetUrl = webAsset['browser_download_url'];
  final downloadStream = await client.download(assetUrl);
  final zipBytes = await downloadStream.expand((chunk) => chunk).toList();

  final archive = ZipDecoder().decodeBytes(zipBytes);
  print('Unzipping bundled CSS file');

  final cssArchiveFile =
      archive.files.firstWhere((file) => file.name.endsWith('all.min.css'));
  await cssArchiveFile.writeToFile(outputCss);

  final webfontFiles = archive.files.where((file) =>
      file.name.contains('/webfonts/') && file.name.endsWith('.woff2'));

  for (var file in webfontFiles) {
    final path = p.join(outputWebfonts, p.basename(file.name));
    await file.writeToFile(path);
  }

  client.close();
}
