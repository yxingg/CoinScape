import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/api_service.dart';

class GlobalImageViewer extends StatefulWidget {
  final List<String>? imagePaths;
  final Map<String, Uint8List>? imageBytes;
  final int initialIndex;
  final String? title;

  const GlobalImageViewer({
    super.key,
    this.imagePaths,
    this.imageBytes,
    this.initialIndex = 0,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    List<String>? imagePaths,
    Map<String, Uint8List>? imageBytes,
    int initialIndex = 0,
    String? title,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) => GlobalImageViewer(
        imagePaths: imagePaths,
        imageBytes: imageBytes,
        initialIndex: initialIndex,
        title: title,
      ),
    );
  }

  @override
  State<GlobalImageViewer> createState() => _GlobalImageViewerState();
}

class _GlobalImageViewerState extends State<GlobalImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  double _currentScale = 1.0;
  final FocusNode _focusNode = FocusNode();
  double _dragStartY = 0;
  bool _isDraggingDown = false;

  List<String> get _paths => widget.imagePaths ?? [];
  bool get _hasMultipleImages => _paths.length > 1;
  int get _totalCount => math.max(_paths.length, 1);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _totalCount - 1);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDismiss() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _onDismiss();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_currentIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_currentIndex < _totalCount - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildDismissableViewer(Widget child) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        if (_currentScale <= 1.0) {
          _dragStartY = details.globalPosition.dy;
          _isDraggingDown = false;
        }
      },
      onVerticalDragUpdate: (details) {
        if (_currentScale <= 1.0) {
          final delta = details.globalPosition.dy - _dragStartY;
          if (delta > 0) {
            _isDraggingDown = true;
          }
        }
      },
      onVerticalDragEnd: (details) {
        if (_currentScale <= 1.0) {
          final velocity = details.velocity.pixelsPerSecond.dy;
          if (_isDraggingDown && velocity.abs() > 200) {
            _onDismiss();
          }
          _isDraggingDown = false;
        }
      },
      child: child,
    );
  }

  Widget _buildSingleImageViewer() {
    final entry = _getImageEntry(0);
    return _buildDismissableViewer(
      InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        onInteractionEnd: (details) {},
        child: Center(
          child: _buildImageWidget(
            entry.path,
            entry.bytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiImageViewer() {
    return Column(
      children: [
        Expanded(
          child: _buildDismissableViewer(
            PageView.builder(
              controller: _pageController,
              itemCount: _totalCount,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _currentScale = 1.0;
                });
              },
              itemBuilder: (context, index) {
                final entry = _getImageEntry(index);
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  onInteractionEnd: (details) {},
                  child: Center(
                    child: _buildImageWidget(
                      entry.path,
                      entry.bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _buildThumbnailBar(),
      ],
    );
  }

  Widget _buildThumbnailBar() {
    return Container(
      height: 80,
      color: Colors.black.withValues(alpha: 0.8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _totalCount,
        itemBuilder: (context, index) {
          final isActive = index == _currentIndex;
          final entry = _getImageEntry(index);
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _buildImageWidget(
                  entry.path,
                  entry.bytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ({String? path, Uint8List? bytes}) _getImageEntry(int index) {
    if (_paths.isNotEmpty && index < _paths.length) {
      final imgPath = _paths[index];
      final imgBytes = widget.imageBytes != null ? widget.imageBytes![imgPath] : null;
      return (path: imgPath, bytes: imgBytes);
    }
    return (path: null, bytes: null);
  }

  Widget _buildImageWidget(String? path, Uint8List? bytes, {BoxFit fit = BoxFit.contain}) {
    if (bytes != null) {
      return Image.memory(bytes, fit: fit);
    }
    if (path == null || path.isEmpty) {
      return _buildPlaceholder();
    }
    if (path.startsWith('base64:')) {
      try {
        final decoded = base64Decode(path.substring(7));
        return Image.memory(decoded, fit: fit);
      } catch (_) {
        return _buildPlaceholder();
      }
    }
    if (kIsWeb) {
      return Image.network(
        ApiService.getImageUrl(path),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    }
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final file = File(p.join(
            snapshot.data!.path,
            path.replaceAll('/', p.separator),
          ));
          if (file.existsSync()) {
            return Image.file(file, fit: fit);
          }
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _hasMultipleImages ? _buildMultiImageViewer() : _buildSingleImageViewer(),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            if (_hasMultipleImages && _currentScale <= 1.0)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: _buildCounter(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: _onDismiss,
              tooltip: '关闭 (Esc)',
            ),
            if (widget.title != null)
              Expanded(
                child: Text(
                  widget.title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_hasMultipleImages)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / $_totalCount',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${_currentIndex + 1} / $_totalCount',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}
