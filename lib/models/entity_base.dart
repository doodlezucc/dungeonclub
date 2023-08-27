mixin EntityBase {
  late int size;

  int get jsonFallbackSize;

  void fromJson(Map<String, dynamic> json) {
    size = json['size'] ?? jsonFallbackSize;
  }

  Map<String, dynamic> toJson() => {
        'size': size,
      };
}

mixin HasInitiativeMod on EntityBase {
  int mod = 0;

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    mod = json['mod'] ?? 0;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'mod': mod,
      };
}
