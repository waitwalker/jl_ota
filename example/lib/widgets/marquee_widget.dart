import 'package:flutter/cupertino.dart';

/// Marquee Effect Component
///
/// This component enables its child components to produce a horizontal scrolling animation effect when space is insufficient.
class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Axis direction;
  final Duration animationDuration;
  final double spacing; // Space between repeated children for seamless looping

  static const Duration defaultAnimationDuration = Duration(milliseconds: 100000);
  static const double defaultSpacing = 20.0;

  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = defaultAnimationDuration,
    this.spacing = defaultSpacing,
  });

  @override
  MarqueeWidgetState createState() => MarqueeWidgetState();
}

class MarqueeWidgetState extends State<MarqueeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late ScrollController _scrollController;

  // To measure the size of the child widget
  final GlobalKey _childKey = GlobalKey();
  double _childWidth = 0;
  bool _needsMarquee = false;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _controller = AnimationController(duration: widget.animationDuration, vsync: this)
      ..addListener(() {
        if (_scrollController.hasClients && _needsMarquee) {
          // Calculate the scroll position based on animation value
          final double maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(_controller.value * maxScroll);
        }
      });

    // Start the animation
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Schedule a post-frame callback to measure the child size
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChild());
  }

  void _measureChild() {
    if (_childKey.currentContext != null) {
      final RenderBox renderBox = _childKey.currentContext!.findRenderObject() as RenderBox;
      final double childWidth = renderBox.size.width;

      setState(() {
        _childWidth = childWidth;
        // Check if we need marquee (child is wider than available space)
        _needsMarquee = _childWidth > _getAvailableWidth();
      });
    }
  }

  double _getAvailableWidth() {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null) {
      final RenderBox box = renderObject as RenderBox;
      return box.size.width;
    }
    return 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we don't know the child width yet or don't need marquee, show single child
        if (_childWidth == 0 || !_needsMarquee) {
          return SingleChildScrollView(
            scrollDirection: widget.direction,
            physics: const NeverScrollableScrollPhysics(),
            child: Container(key: _childKey, child: widget.child),
          );
        }

        // For marquee effect, we need to duplicate the content for seamless looping
        final double availableWidth = constraints.maxWidth;
        final int repetitions = (_childWidth / availableWidth).ceil() + 1;

        return SingleChildScrollView(
          scrollDirection: widget.direction,
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            key: _childKey,
            children: List.generate(repetitions * 2, (index) {
              return Row(
                children: [
                  widget.child,
                  if (index < repetitions * 2 - 1) SizedBox(width: widget.spacing),
                ],
              );
            }),
          ),
        );
      },
    );
  }
}
