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
  static const colors = [
    '#ec4141',
    '#e7783e',
    '#45c575',
    '#2badd7',
    '#9276f9',
    '#db6b98',
  ];

  String label = '';
  String color = colors[0];
  double value = 25;
  double maxValue = 0;

  TokenBarVisibility visibility = TokenBarVisibility.VISIBLE_TO_OWNERS;

  TokenBar({required this.label});
  TokenBar.parse(Map<String, dynamic> json) {
    fromJson(json);
  }

  void fromJson(Map<String, dynamic> json) {
    label = json['label'];
    color = json['color'];
    value = (json['value'] as num).toDouble();
    maxValue = (json['maxValue'] as num).toDouble();
    visibility = TokenBarVisibility.parse(json['visibility']);
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'color': color,
        'value': value,
        'maxValue': maxValue,
        'visibility': visibility.id,
      };
}
