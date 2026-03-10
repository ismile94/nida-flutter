import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../utils/scaling.dart';

/// Flutter equivalent of CustomNavigationBar.js – same layout, scaled sizes, colors, and behavior.
/// Bar height reduced via padding only; active indicator animates between tabs.
class CustomNavigationBar extends StatefulWidget {
  const CustomNavigationBar({super.key});

  @override
  State<CustomNavigationBar> createState() => _CustomNavigationBarState();
}

class _CustomNavigationBarState extends State<CustomNavigationBar> {
  double? _indicatorIndex;

  double _begin(int current) => _indicatorIndex ?? current.toDouble();
  double _end(int current) => current.toDouble();

  @override
  Widget build(BuildContext context) {
    final scope = NavBarScope.of(context);
    if (scope == null) return const SizedBox.shrink();

    final bottom = MediaQuery.paddingOf(context).bottom;
    final barHeight = scaleSize(context, 64);
    final topRadius = scaleSize(context, 24);
    final horizontalPadding = scaleSize(context, 14);
    final verticalPadding = scaleSize(context, 4);

    return Container(
      height: barHeight + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: scaleSize(context, 8),
              offset: Offset(0, scaleSize(context, -2)),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rowWidth = constraints.maxWidth - horizontalPadding * 2;
            final itemWidth = rowWidth / 5;

            return Padding(
              padding: EdgeInsets.only(
                top: verticalPadding,
                bottom: verticalPadding,
                left: horizontalPadding,
                right: horizontalPadding,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: _begin(scope.currentIndex), end: _end(scope.currentIndex)),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    onEnd: () {
                      if (mounted) setState(() => _indicatorIndex = scope.currentIndex.toDouble());
                    },
                    builder: (context, value, child) {
                      return Positioned(
                        left: value * itemWidth,
                        top: 0,
                        bottom: 0,
                        width: itemWidth,
                        child: IgnorePointer(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: scaleSize(context, 2)),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(scaleSize(context, 12)),
                              border: Border.all(color: const Color(0xFF6366F1), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  offset: Offset(0, scaleSize(context, 2)),
                                  blurRadius: scaleSize(context, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _NavItem(
                        label: AppLocalizations.t(context, 'prayer'),
                        assetPath: 'assets/men.png',
                        isActive: scope.currentIndex == 0,
                        onTap: () => scope.onTap(0),
                        showActiveBackground: false,
                        iconSizeActive: 36,
                        iconSizeInactive: 26,
                      ),
                      _NavItem(
                        label: AppLocalizations.t(context, 'quran'),
                        assetPath: 'assets/koran.png',
                        isActive: scope.currentIndex == 1,
                        onTap: () => scope.onTap(1),
                        showActiveBackground: false,
                        iconSizeActive: 36,
                        iconSizeInactive: 26,
                      ),
                      _NavItem(
                        label: AppLocalizations.t(context, 'home'),
                        assetPath: 'assets/homescreen.png',
                        isActive: scope.currentIndex == 2,
                        onTap: () => scope.onTap(2),
                        isCenter: true,
                        showActiveBackground: false,
                        iconSizeActive: 46,
                        iconSizeInactive: 36,
                        iconOffset: 4,
                        labelOffset: -2,
                      ),
                      _NavItem(
                        label: AppLocalizations.t(context, 'nearby'),
                        assetPath: 'assets/nearbymosque.png',
                        isActive: scope.currentIndex == 3,
                        onTap: () => scope.onTap(3),
                        showActiveBackground: false,
                        iconSizeActive: 40,
                        iconSizeInactive: 34,
                      ),
                      _NavItem(
                        label: AppLocalizations.t(context, 'menu'),
                        icon: Icons.menu,
                        isActive: scope.currentIndex == 4,
                        onTap: () => scope.onTap(4),
                        showActiveBackground: false,
                        iconSizeActive: 36,
                        iconSizeInactive: 26,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final String? assetPath;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCenter;
  final bool showActiveBackground;
  final double iconSizeActive;
  final double iconSizeInactive;
  final double iconOffset;
  final double labelOffset;

  const _NavItem({
    required this.label,
    this.assetPath,
    this.icon,
    required this.isActive,
    required this.onTap,
    this.isCenter = false,
    this.showActiveBackground = true,
    this.iconSizeActive = 32,
    this.iconSizeInactive = 22,
    this.iconOffset = 0,
    this.labelOffset = 0,
  }) : assert(assetPath != null || icon != null);

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _pressed = true);
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    _scaleController.reverse();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final iconSize = scaleSize(ctx, widget.isActive ? widget.iconSizeActive : widget.iconSizeInactive);
    final color = widget.isActive ? const Color(0xFF6366F1) : const Color(0xFF94A3B8);
    final iconWidget = widget.assetPath != null
        ? Image.asset(
            widget.assetPath!,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          )
        : Icon(widget.icon!, size: iconSize, color: color);

    return Expanded(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: () => widget.onTap(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1,
          duration: const Duration(milliseconds: 50),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(scaleSize(ctx, 12)),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: scaleSize(ctx, 2), horizontal: scaleSize(ctx, 2)),
              margin: EdgeInsets.symmetric(horizontal: scaleSize(ctx, 2)),
              decoration: BoxDecoration(
              color: (widget.showActiveBackground && widget.isActive) ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(scaleSize(ctx, 12)),
              border: (widget.showActiveBackground && widget.isActive)
                  ? Border.all(color: const Color(0xFF6366F1), width: 1)
                  : null,
              boxShadow: (widget.showActiveBackground && widget.isActive)
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        offset: Offset(0, scaleSize(ctx, 2)),
                        blurRadius: scaleSize(ctx, 6),
                      ),
                    ]
                  : null,
            ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    height: scaleSize(ctx, 28),
                    width: double.infinity,
                    alignment: Alignment.center,
                    margin: EdgeInsets.only(
                      bottom: scaleSize(ctx, 2),
                      top: scaleSize(ctx, widget.iconOffset),
                    ),
                    child: iconWidget,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, scaleSize(ctx, widget.labelOffset)),
                  child: SizedBox(
                    height: scaleSize(ctx, 18),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        widget.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: scaleFont(ctx, 12),
                          fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                          color: widget.isActive ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                          height: 1.2,
                          letterSpacing: 0.25,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavBarScope extends InheritedWidget {
  final int currentIndex;
  final void Function(int index) onTap;

  const NavBarScope({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required super.child,
  });

  static NavBarScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavBarScope>();
  }

  @override
  bool updateShouldNotify(NavBarScope oldWidget) {
    return oldWidget.currentIndex != currentIndex || oldWidget.onTap != onTap;
  }
}
