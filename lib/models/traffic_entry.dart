enum TrafficDirection { outbound, inbound }

class TrafficEntry {
  TrafficEntry({
    required this.id,
    required this.direction,
    required this.summary,
    required this.body,
    required this.at,
  });

  final String id;
  final TrafficDirection direction;
  final String summary;
  final String body;
  final DateTime at;
}
