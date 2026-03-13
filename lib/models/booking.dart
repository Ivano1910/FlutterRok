class Booking {
  final int id;
  final String customerName;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.customerName,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: (json['id'] as num).toInt(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '') as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
