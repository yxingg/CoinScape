import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:coinscape/timeline/timeline_controller.dart';
import 'package:coinscape/widgets/mobile_scrubber.dart';
import 'package:coinscape/widgets/web_scrubber.dart';

class TimelineScrubberWrapper extends StatelessWidget {
  final TimelineController controller;

  const TimelineScrubberWrapper({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return WebScrubber(controller: controller);
    return MobileScrubber(controller: controller);
  }
}
