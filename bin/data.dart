class ServerData {
  var players = <ServerPlayer>[];

  ServerPlayer getPlayer(String name) {
    if (name == null) return null;
    return players.singleWhere((p) => p.name == name, orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'players': players.map((e) => e.toJson()).toList(),
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
