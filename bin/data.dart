class ServerData {
  var players = <ServerPlayer>[];

  Map<String, dynamic> toJson() => {
        'players': players.map((e) => e.toJson()),
      };
}

class ServerPlayer {
  final String name;
  String displayName;
  String password;

  ServerPlayer(this.name, this.displayName, this.password);

  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'password': password,
      };
}
