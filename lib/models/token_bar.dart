enum TokenBarVisibility {
  VISIBLE_TO_ALL(0),
  VISIBLE_TO_OWNERS(1),
  HIDDEN(2);

  final int id;

  const TokenBarVisibility(this.id);

  static TokenBarVisibility parse(int id) {
    switch (id) {
      case 0:
        return TokenBarVisibility.VISIBLE_TO_ALL;
      case 1:
        return TokenBarVisibility.VISIBLE_TO_OWNERS;
      case 2:
        return TokenBarVisibility.HIDDEN;
    }

    throw RangeError('Invalid token bar visibility $id');
  }
}

class TokenBar {
  int id;
  String label = '';
  double value = 0;
  double maxValue = 100;

  TokenBarVisibility visibility = TokenBarVisibility.HIDDEN;

  TokenBar(this.id);
  TokenBar.parse(Map<String, dynamic> json) : id = json['id'] {
    fromJson(json);
  }

  void fromJson(Map<String, dynamic> json) {
    label = json['label'];
    value = json['value'];
    maxValue = json['maxValue'];
    visibility = TokenBarVisibility.parse(json['visibility']);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'maxValue': maxValue,
        'visibility': visibility.id,
      };
}
