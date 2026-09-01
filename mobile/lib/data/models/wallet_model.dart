enum WalletType {
  eWallet('e_wallet', 'E-Wallet'),
  bank('bank', 'Bank'),
  cash('cash', 'Tunai');

  const WalletType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static WalletType fromApi(String value) =>
      WalletType.values.firstWhere((t) => t.apiValue == value, orElse: () => cash);
}

class WalletModel {
  const WalletModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final WalletType type;

  /// API kirim string ("150000.00"), di sini sudah jadi angka.
  final double balance;
  final String icon;
  final String color;

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
    id: json['id'] as String,
    name: json['name'] as String,
    type: WalletType.fromApi(json['type'] as String),
    balance: double.parse(json['balance'] as String),
    icon: json['icon'] as String,
    color: json['color'] as String,
  );
}
