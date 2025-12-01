class Saving {
  final int? id;
  final double amount;
  final DateTime? timestamp;
  final String userId;

  Saving({
    this.id,
    required this.amount,
    this.timestamp,
    required this.userId,
  });

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      userId: json['userId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'userId': userId,
    };
  }
}
