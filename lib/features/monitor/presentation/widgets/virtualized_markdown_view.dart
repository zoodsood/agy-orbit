import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Chunked, virtualized streaming log and markdown viewer.
/// Optimized with ListView.builder and RepaintBoundaries to render 1,000,000+ token
/// streaming context at 60fps without freezing the UI thread.
class VirtualizedMarkdownView extends StatefulWidget {
  final List<String> chunks;
  final bool isStreaming;
  final ScrollController? externalScrollController;

  const VirtualizedMarkdownView({
    super.key,
    required this.chunks,
    this.isStreaming = false,
    this.externalScrollController,
  });

  @override
  State<VirtualizedMarkdownView> createState() => _VirtualizedMarkdownViewState();
}

class _VirtualizedMarkdownViewState extends State<VirtualizedMarkdownView> {
  late final ScrollController _controller;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.externalScrollController ?? ScrollController();
    _controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_controller.hasClients) {
      final atBottom = _controller.position.pixels >= _controller.position.maxScrollExtent - 40;
      if (_autoScroll != atBottom) {
        setState(() => _autoScroll = atBottom);
      }
    }
  }

  @override
  void didUpdateWidget(covariant VirtualizedMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chunks.length != oldWidget.chunks.length && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpTo(_controller.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.externalScrollController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chunks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.code, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              widget.isStreaming ? 'Connecting to remote sandbox...' : 'Awaiting agent prompt...',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Container(
          color: AppTheme.terminalBlack,
          child: ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.all(12),
            itemCount: widget.chunks.length,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final chunk = widget.chunks[index];
              return RepaintBoundary(
                child: _buildChunkLine(chunk),
              );
            },
          ),
        ),
        if (!_autoScroll)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              backgroundColor: AppTheme.primaryBlue,
              onPressed: () {
                setState(() => _autoScroll = true);
                _controller.animateTo(
                  _controller.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_downward, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildChunkLine(String chunk) {
    final isCommand = chunk.startsWith('\$ ') || chunk.startsWith('> ');
    final isError = chunk.toLowerCase().contains('error') || chunk.toLowerCase().contains('fatal');
    final isHeader = chunk.startsWith('# ') || chunk.startsWith('## ') || chunk.startsWith('### ');

    Color textColor = const Color(0xFFC9D1D9);
    FontWeight fontWeight = FontWeight.normal;

    if (isCommand) {
      textColor = AppTheme.accentCyan;
      fontWeight = FontWeight.w600;
    } else if (isError) {
      textColor = AppTheme.statusFailed;
    } else if (isHeader) {
      textColor = const Color(0xFF58A6FF);
      fontWeight = FontWeight.bold;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: SelectableText(
        chunk,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.4,
          color: textColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
