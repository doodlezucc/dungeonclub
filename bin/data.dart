class ServerData {
  var players = <ServerPlayer>[];

  ServerPlayer getPlayer(String name) {
    if (name == null) return null;
    return players.singleWhere((p) => p.name == name, orElse: () => null);
  }

  Map<String, dynamic> toJson() => {
        'players': players.map((e) => e.toJson(withPassword: true)).toList(),
      };
}

class ServerPlayer {
  final String name;
  String displayName;
  String password;

  ServerPlayer(this.name, this.displayName, this.password);

  Map<String, dynamic> toJson({withPassword = false}) => {
        'name': name,
        'displayName': displayName,
        if (withPassword) 'password': password,
      };
}
