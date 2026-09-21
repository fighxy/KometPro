import 'package:flutter/material.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key, required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        final placeholder = cs.surfaceContainerHighest;
        final opacity = 0.3 + (0.4 * shimmer.value);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 8,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final hasImage = index % 3 == 0;
            final hasReactions = index % 2 == 0;
            final width1 = 60.0 + (index * 15 % 50);
            final width2 = 120.0 + (index * 25 % 80);

            return Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: placeholder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: width1,
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: width2,
                            height: 32,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          if (hasImage) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                color: placeholder,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                          if (hasReactions) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                3,
                                (i) => Container(
                                  width: 32,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: placeholder,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ShimmerCrossFade extends StatefulWidget {
  const ShimmerCrossFade({
    super.key,
    required this.showShimmer,
    required this.shimmer,
    required this.child,
  });

  final bool showShimmer;
  final Animation<double> shimmer;
  final Widget child;

  @override
  State<ShimmerCrossFade> createState() => _ShimmerCrossFadeState();
}

class _ShimmerCrossFadeState extends State<ShimmerCrossFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.showShimmer ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(ShimmerCrossFade old) {
    super.didUpdateWidget(old);
    if (widget.showShimmer == old.showShimmer) return;
    if (widget.showShimmer) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      child: widget.child,
      builder: (context, child) {
        final t = _fade.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: 1 - t, child: child),
            if (t > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: ShimmerLoading(shimmer: widget.shimmer),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
