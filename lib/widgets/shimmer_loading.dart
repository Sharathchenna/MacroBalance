import 'package:flutter/material.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(height: 200),
          SizedBox(height: 16),
          _buildShimmerBox(height: 24, width: 200),
          SizedBox(height: 32),
          ...List.generate(5, (index) => _buildShimmerRow()),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({
    required double height,
    double? width,
    BorderRadius? borderRadius,
  }) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: _buildShimmerEffect(),
      ),
    );
  }

  Widget _buildShimmerRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildShimmerBox(height: 20, width: 100),
          _buildShimmerBox(height: 20, width: 60),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Colors.grey[200]!,
            Colors.grey[350]!,
            Colors.grey[200]!,
          ],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, -0.3),
          end: Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: Container(color: Colors.white),
    );
  }
}
