class BookingRequest {
  final String customerName;
  final String startTime; // ISO8601 string

  BookingRequest({required this.customerName, required this.startTime});

  Map<String, dynamic> toJson() => {
        'customer_name': customerName,
        'start_time': startTime,
      };
}
