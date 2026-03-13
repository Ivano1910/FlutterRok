class AvailabilityResponse {
  final String date; // "YYYY-MM-DD"
  final List<String> slots; // ["10:00","10:30",...]

  AvailabilityResponse({required this.date, required this.slots});

  factory AvailabilityResponse.fromJson(Map<String, dynamic> json) {
    final rawSlots = (json['slots'] as List?) ?? [];
    return AvailabilityResponse(
      date: (json['date'] ?? '') as String,
      slots: rawSlots.map((e) => e.toString()).toList(),
    );
  }
}
