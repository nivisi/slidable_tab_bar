import 'package:flutter/material.dart';
import 'package:slidable_tab_bar/src/slidable_tab_bar_data.dart';

import 'helpers/calculate_text_size.dart';

typedef PressableBuidler = Widget Function(
  BuildContext context,
  Widget child,
  VoidCallback onPressed,
);

class SlidableTabBar extends StatefulWidget {
  const SlidableTabBar({
    Key? key,
    this.tabs = const [],
    this.titleTextPadding = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 8.0,
    ),
    this.contentPadding = const EdgeInsets.all(12),
    this.titleListPadding = const EdgeInsets.symmetric(horizontal: 12.0),
    this.titlePhysics,
    this.contentPhysics,
    this.indicatorHeight = 3.0,
    this.dividerHeight = 1.0,
    this.slideDuration = const Duration(milliseconds: 400),
    this.slideCurve = Curves.linearToEaseOut,
    this.selectedTitleStyle = const TextStyle(),
    this.unselectedTitleStyle = const TextStyle(),
    this.pressableBuilder,
    this.indicatorColor,
  }) : super(key: key);

  /// Tabs of the widget.
  final List<SlidableTabData> tabs;

  /// Padding of a single title widget.
  final EdgeInsets titleTextPadding;

  /// Padding of a single title widget.
  final EdgeInsets titleListPadding;

  /// Padding of the content.
  final EdgeInsets contentPadding;

  /// Physics of the titles list.
  final ScrollPhysics? titlePhysics;

  /// Physics of the content.
  final ScrollPhysics? contentPhysics;

  /// Height of the slider.
  final double indicatorHeight;

  /// Height of the dividing line.
  final double dividerHeight;

  /// Duration of the slide animation.
  final Duration slideDuration;

  /// Curve of the slide animation.
  final Curve slideCurve;

  /// Text style of the selected title.
  final TextStyle selectedTitleStyle;

  /// Text style of unselected titles.
  final TextStyle unselectedTitleStyle;

  final PressableBuidler? pressableBuilder;

  final Color? indicatorColor;

  @override
  State<SlidableTabBar> createState() => _SlidableTabBarState();
}

class _SlidableTabBarState extends State<SlidableTabBar> {
  /// Controller of the page content.
  final pageController = PageController();

  /// Controller of the titles list.
  final titlesScrollController = ScrollController();

  List<Size> titleSizes = [];

  int currentPage = 0;
  int nextIndexPage = 1;
  int lastEnsuredVisiblePage = 0;

  /// Used in [processAndAnimate] as the previous value of the [pageController.page]
  double previousPage = .0;

  /// Indicator's leading horizontal padding, left in LTR directionality and right in RTL directionality.
  final ValueNotifier<double> indicatorLeadingOffsetNotifier =
      ValueNotifier<double>(0.0);

  /// Indicator's width.
  final ValueNotifier<double> indicatorWidthNotifier =
      ValueNotifier<double>(0.0);

  /// Stored the [BuildContext]s of the title widgets.
  /// Required to call ensureVisible during [ensureCurrentTitleVisible].
  Map<int, BuildContext> titleWidgetsContexts = {};

  Map<int, ValueNotifier<TextStyle>> textStylesNotifier = {};

  /// Contains calculated list of widths to avoid endlessly doing
  /// `titleSizes.take(pageFloor).sumWidths()`
  Map<int, double> calculatedWidthsSum = {};

  bool isDirectionalityLTR = true;

  @override
  void initState() {
    super.initState();

    _calculateTextSizes();
    createTextNotifiers();

    indicatorWidthNotifier.value = titleSizes[0].width;
    indicatorLeadingOffsetNotifier.value = widget.titleListPadding.left;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final isRightToLeft =
          Directionality.maybeOf(context) == TextDirection.rtl;
      isDirectionalityLTR = !isRightToLeft;
    });

    pageController.addListener(() {
      processAndAnimate();
      previousPage = pageController.page ?? .0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isRightToLeft = Directionality.maybeOf(context) == TextDirection.rtl;

    if (isDirectionalityLTR == isRightToLeft) {
      isDirectionalityLTR = !isRightToLeft;
    }
  }

  void createTextNotifiers() {
    for (var index = 0; index < widget.titleTextPadding.left; index++) {
      textStylesNotifier[index] = ValueNotifier(widget.unselectedTitleStyle);
    }

    textStylesNotifier[0]?.value = widget.selectedTitleStyle;
  }

  void updateTextStyles(double page, int pageFloored) {
    if (page == pageFloored && page == widget.tabs.length - 1) {
      // This avoid setting the last item text style to unselected
      // Cause the progress will be 0.
      return;
    }

    final currentNotifier = textStylesNotifier[currentPage];
    final nextNotifier = textStylesNotifier[nextIndexPage];

    final currentProgress = page - pageFloored;
    final nextProgress = 1 - currentProgress;

    final currentTextStyle = TextStyle.lerp(
      widget.selectedTitleStyle,
      widget.unselectedTitleStyle,
      currentProgress,
    );

    final nextTextStyle = TextStyle.lerp(
      widget.selectedTitleStyle,
      widget.unselectedTitleStyle,
      nextProgress,
    );

    currentNotifier?.value = currentTextStyle ?? const TextStyle();
    nextNotifier?.value = nextTextStyle ?? const TextStyle();
  }

  void ensureCurrentTitleVisible(double page) {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    final velocity = pageController.position.activity?.velocity ?? 0;

    /// Only triggered when scrolling the titles very fast.
    /// For example, when the selected index is 0 and you tap on the last one.
    /// This is required to avoid triggering this method to early,
    /// e.g. we will only ensure to make the slidingTo widget visible.
    if (velocity.abs() >= 300) {
      return;
    }

    final isLeft = page - previousPage < 0;

    int toShow = 0;

    if (isLeft) {
      toShow = page.floor();
    } else {
      toShow = page.ceil();
    }

    if (toShow == lastEnsuredVisiblePage) {
      return;
    }

    lastEnsuredVisiblePage = toShow;

    final context = titleWidgetsContexts[toShow];
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: widget.slideDuration,
        curve: widget.slideCurve,
        alignment: !isLeft ? .65 : .35,
      );
    }
  }

  /// Defines the current item and the next one.
  void defineCurrentAndNext(double page, int pageFloored) {
    if (currentPage == pageFloored) {
      return;
    }

    nextIndexPage = pageFloored + 1;

    if (nextIndexPage >= titleSizes.length) {
      nextIndexPage = titleSizes.length - 1;
    }

    currentPage = pageFloored;
  }

  void processAndAnimate() {
    final page = pageController.page ?? 0.0;

    final pageFloored = page.floor();

    ensureCurrentTitleVisible(page);

    defineCurrentAndNext(page, pageFloored);
    updateTextStyles(page, pageFloored);

    final currentPageProgress = page - pageFloored;
    final currentTitleProgressedSize =
        titleSizes[pageFloored] * currentPageProgress;

    final previousTitlesWidthSum = calculatedWidthsSum[pageFloored] ?? .0;

    final titleTextLeftPadding = widget.titleTextPadding.left;
    final titleTextRightPadding = widget.titleTextPadding.right;

    // This value represents the offset caused
    // by all the left paddings of the previous titles.
    final offsetOfLeftPaddings = widget.titleListPadding.left +
        titleTextLeftPadding * pageFloored +
        titleTextLeftPadding * currentPageProgress;

    // This value represents the offset caused
    // by all the right paddings of the previous titles.
    final offsetOfRightPaddings = titleTextRightPadding * page;

    final leadingOffset = previousTitlesWidthSum +
        currentTitleProgressedSize.width +
        offsetOfLeftPaddings +
        offsetOfRightPaddings;

    indicatorLeadingOffsetNotifier.value = leadingOffset;

    /// WIDTH OF THE INDICATOR

    final currentSize = titleSizes.elementAt(currentPage);
    final nextSize = titleSizes.elementAt(nextIndexPage);

    const curve = Curves.easeInOut;

    final easedCurrentSizeProgress = curve.transform(1 - currentPageProgress);
    final easedNextProgress = curve.transform(currentPageProgress);

    final indicatorSize = currentSize.width * easedCurrentSizeProgress +
        easedNextProgress * nextSize.width;

    indicatorWidthNotifier.value = indicatorSize;

    return;
  }

  void _calculateTextSizes() {
    titleSizes = widget.tabs.map((e) {
      return calculateTextSize(e.title, const TextStyle());
    }).toList();

    _calculateTitleWidthsSums();
  }

  void _calculateTitleWidthsSums() {
    calculatedWidthsSum.clear();

    int index = 0;

    final toIterate = isDirectionalityLTR ? titleSizes : titleSizes.reversed;

    while (index < toIterate.length) {
      calculatedWidthsSum[index] = toIterate.take(index).sumWidths();
      index++;
    }
  }

  void adjustNotifiersToNewLength(
    int oldLength,
    int newLength,
  ) {
    if (newLength > oldLength) {
      for (var index = oldLength; index < newLength; index++) {
        textStylesNotifier[index] = ValueNotifier(widget.unselectedTitleStyle);
      }
    } else {
      for (var index = oldLength; index >= newLength; index--) {
        textStylesNotifier[index]?.dispose();
        textStylesNotifier.remove(index);
      }
    }
  }

  void clearNotifiers() {
    for (final notifier in textStylesNotifier.values) {
      notifier.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant SlidableTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLength = oldWidget.tabs.length;
    final newLength = widget.tabs.length;
    if (oldLength != newLength) {
      adjustNotifiersToNewLength(oldLength, newLength);

      _calculateTextSizes();
    } else if (oldWidget.tabs.map((e) => e.title) !=
        widget.tabs.map((e) => e.title)) {
      _calculateTextSizes();
    }
  }

  @override
  void dispose() {
    titlesScrollController.dispose();
    pageController.dispose();
    clearNotifiers();
    indicatorWidthNotifier.dispose();
    indicatorLeadingOffsetNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.onSurface;

    final sliderColor = widget.indicatorColor ?? surfaceColor;

    final tabTitles = widget.tabs.map(
      (e) {
        final index = widget.tabs.indexOf(e);
        return Builder(
          builder: (context) {
            titleWidgetsContexts[index] = context;
            final text = Padding(
              padding: widget.titleTextPadding,
              child: ValueListenableBuilder<TextStyle>(
                valueListenable: textStylesNotifier[index]!,
                builder: (context, textStyle, child) {
                  return Text(
                    e.title,
                    style: textStyle,
                  );
                },
              ),
            );

            void onTap() {
              final isLeft = currentPage - index > 0;
              Scrollable.ensureVisible(
                context,
                duration: widget.slideDuration,
                curve: widget.slideCurve,
                alignment: isLeft ? .35 : .65,
              );
              pageController.animateToPage(
                index,
                duration: widget.slideDuration,
                curve: widget.slideCurve,
              );
            }

            if (widget.pressableBuilder != null) {
              return widget.pressableBuilder!(context, text, onTap);
            }

            return InkWell(
              onTap: onTap,
              child: Padding(
                padding: widget.titleTextPadding,
                child: ValueListenableBuilder<TextStyle>(
                  valueListenable: textStylesNotifier[index]!,
                  builder: (context, textStyle, child) {
                    return Text(
                      e.title,
                      style: textStyle,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    ).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            SizedBox(
              height: widget.titleListPadding.vertical +
                  widget.titleTextPadding.vertical +
                  6 +
                  titleSizes[0].height,
              child: SingleChildScrollView(
                padding: widget.titleListPadding,
                controller: titlesScrollController,
                scrollDirection: Axis.horizontal,
                physics: widget.titlePhysics,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: tabTitles,
                      ),
                    ),
                    Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                              top: widget.indicatorHeight / 2.0),
                          child: Container(
                            width: titleSizes.sumWidths() +
                                widget.titleTextPadding.horizontal *
                                    (titleSizes.length),
                            height: widget.dividerHeight,
                            color: sliderColor.withOpacity(.15),
                          ),
                        ),
                        ValueListenableBuilder<double>(
                            valueListenable: indicatorWidthNotifier,
                            builder: (context, width, child) {
                              return ValueListenableBuilder<double>(
                                valueListenable: indicatorLeadingOffsetNotifier,
                                builder: (context, page, child) {
                                  final leadingOffset =
                                      page - widget.titleTextPadding.left * 1.5;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: isDirectionalityLTR
                                          ? leadingOffset
                                          : .0,
                                      right: isDirectionalityLTR
                                          ? .0
                                          : leadingOffset,
                                    ),
                                    child: Container(
                                      height: widget.indicatorHeight,
                                      width:
                                          width + widget.titleTextPadding.right,
                                      color: sliderColor,
                                    ),
                                  );
                                },
                              );
                            }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                physics: widget.contentPhysics,
                controller: pageController,
                children: widget.tabs
                    .map((e) => Padding(
                          padding: widget.contentPadding,
                          child: e.child,
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension _SizeIterableExtensions on Iterable<Size> {
  double sumWidths() {
    double sum = 0;

    int index = 0;

    while (index < length) {
      sum += elementAt(index).width;
      index++;
    }

    return sum;
  }
}
