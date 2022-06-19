class Environment {
  static const ENV_ENABLE_MUSIC = 'music';
  static const enableMusic =
      bool.fromEnvironment(ENV_ENABLE_MUSIC, defaultValue: true);

  static const ENV_TIMESTAMP = 'timestamp';
  static const buildTimestamp = int.fromEnvironment(ENV_TIMESTAMP);

  static const allKeys = [ENV_ENABLE_MUSIC, ENV_TIMESTAMP];

  static List<String> declareArgs(Map<String, dynamic> declarations) {
    return declarations.entries
        .where((d) => allKeys.contains(d.key))
        .map((d) => '-D${d.key}=${d.value}')
        .toList();
  }
}
