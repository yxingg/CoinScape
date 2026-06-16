// Timeline data models
class TimelineBucket {
  final String key; // "YYYY-MM"
  final int year;
  final int month;
  final int count;
  final int startIndex;
  final int startTs;
  final int endTs;

  TimelineBucket({
    required this.key,
    required this.year,
    required this.month,
    required this.count,
    required this.startIndex,
    required this.startTs,
    required this.endTs,
  });

  factory TimelineBucket.fromJson(Map<String, dynamic> json) => TimelineBucket(
        key: json['key'] as String,
        year: json['year'] as int,
        month: json['month'] as int,
        count: json['count'] as int,
        startIndex: json['start_index'] as int,
        startTs: json['start_ts'] as int,
        endTs: json['end_ts'] as int,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'year': year,
        'month': month,
        'count': count,
        'start_index': startIndex,
        'start_ts': startTs,
        'end_ts': endTs,
      };

  String get prettyLabel => "$year年 ${month.toString().padLeft(2, '0')}月";
}
