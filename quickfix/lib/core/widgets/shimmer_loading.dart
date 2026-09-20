import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:quickfix/core/theme/app_colors.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  });

  const ShimmerLoading.circular({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = size / 2,
      shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        highlightColor: isDark
            ? const Color(0xFF334155)
            : const Color(0xFFF1F5F9),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            shape: shape,
            borderRadius: shape == BoxShape.rectangle
                ? BorderRadius.circular(borderRadius)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Urban Company Skeletal Shimmer for Category Cards
class CategoryGridShimmer extends StatelessWidget {
  const CategoryGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Column(
          children: [
            ShimmerLoading(width: 56, height: 56, borderRadius: 16),
            SizedBox(height: 8),
            ShimmerLoading(width: 48, height: 10, borderRadius: 4),
          ],
        );
      },
    );
  }
}

/// Urban Company Skeletal Shimmer for Service Cards
class ServiceCardShimmer extends StatelessWidget {
  const ServiceCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: double.infinity, height: 100, borderRadius: 12),
          SizedBox(height: 12),
          ShimmerLoading(width: 100, height: 14, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerLoading(width: 60, height: 12, borderRadius: 4),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoading(width: 50, height: 14, borderRadius: 4),
              ShimmerLoading(width: 28, height: 28, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}
