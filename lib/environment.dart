class Environment {
  static Map<String, dynamic> get defaultConfigServe => {
        ENV_MOCK_ACCOUNT: enableMockAccount,
        ENV_ENABLE_MUSIC: enableMusic,
      };

  static const ENV_MOCK_ACCOUNT = 'mock-account';
  static var enableMockAccount =
      const bool.fromEnvironment(ENV_MOCK_ACCOUNT, defaultValue: false);

  static const ENV_ENABLE_MUSIC = 'music';
  static var enableMusic =
      const bool.fromEnvironment(ENV_ENABLE_MUSIC, defaultValue: true);

  static const ENV_TIMESTAMP = 'timestamp';
  static const buildTimestamp =
      int.fromEnvironment(ENV_TIMESTAMP, defaultValue: -1);

  static const isCompiled = buildTimestamp >= 0;

  static const allKeys = [
    ENV_MOCK_ACCOUNT,
    ENV_ENABLE_MUSIC,
    ENV_TIMESTAMP,
  ];

  static void applyConfig(Map<String, dynamic> config) {
    enableMockAccount = config[ENV_MOCK_ACCOUNT] ?? enableMockAccount;
    enableMusic = config[ENV_ENABLE_MUSIC] ?? enableMusic;
  }

  static Map<String, dynamic> get frontendInjectionEntries => {
        ENV_ENABLE_MUSIC: enableMusic,
      };
}
