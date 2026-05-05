class SyncData {
  final List<dynamic> series;
  final List<dynamic> coins;
  final List<dynamic> links;
  final List<dynamic> coinImages;
  final List<dynamic> seriesImages;

  SyncData({
    required this.series,
    required this.coins,
    required this.links,
    required this.coinImages,
    required this.seriesImages,
  });

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      series: json['series'] as List<dynamic>,
      coins: json['coins'] as List<dynamic>,
      links: json['links'] as List<dynamic>,
      coinImages: (json['coinImages'] as List<dynamic>?) ?? const [],
      seriesImages: (json['seriesImages'] as List<dynamic>?) ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series,
      'coins': coins,
      'links': links,
      'coinImages': coinImages,
      'seriesImages': seriesImages,
    };
  }
}
