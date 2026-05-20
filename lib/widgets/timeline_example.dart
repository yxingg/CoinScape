import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coinscape/timeline/timeline.dart';
import 'package:coinscape/widgets/timeline_scrubber_wrapper.dart';

class TimelineExamplePage extends StatefulWidget {
  const TimelineExamplePage({Key? key}) : super(key: key);

  @override
  _TimelineExamplePageState createState() => _TimelineExamplePageState();
}

class _TimelineExamplePageState extends State<TimelineExamplePage> {
  TimelineController? _controller;
  TimelineCalculator? _calculator;
  List<TimelineBucket> _buckets = [];
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    try {
      final uri = Uri.parse('http://localhost:9876/api/timeline/metadata');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final buckets = (data['buckets'] as List).map((m) => TimelineBucket.fromJson(m as Map<String, dynamic>)).toList();
        setState(() {
          _buckets = buckets;
          _total = data['total'] as int;
        });

        _calculator = TimelineCalculator(
          buckets: _buckets,
          itemsPerRow: 3, // 示例值：可根据屏幕宽度动态计算
          itemHeight: 120.0,
          vSpacing: 8.0,
          headerHeight: 40.0,
        );

        _controller = TimelineController(calculator: _calculator!);

        setState(() {
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Timeline Example')),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              controller: _controller?.scrollController,
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      height: 120,
                      color: index % 2 == 0 ? Colors.grey[100] : Colors.white,
                      child: Center(child: Text('Item #$index')),
                    ),
                    childCount: _total,
                  ),
                ),
              ],
            ),
          ),

          // 右侧 scrubber
          Align(
            alignment: Alignment.centerRight,
            child: _controller == null ? const SizedBox.shrink() : TimelineScrubberWrapper(controller: _controller!),
          ),
        ],
      ),
    );
  }
}
