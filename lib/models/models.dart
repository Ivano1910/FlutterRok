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
      id: json['id'],
      customerName: json['customer_name'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AvailabilityResponse {
  final String date;
  final List<String> slots;

  AvailabilityResponse({required this.date, required this.slots});

  factory AvailabilityResponse.fromJson(Map<String, dynamic> json) {
    return AvailabilityResponse(
      date: json['date'],
      slots: List<String>.from(json['slots']),
    );
  }
}

class BookingRequest {
  final String customerName;
  final String startTime; // ISO String

  BookingRequest({required this.customerName, required this.startTime});

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'start_time': startTime,
    };
  }
}
