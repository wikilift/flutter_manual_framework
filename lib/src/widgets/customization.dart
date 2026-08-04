import 'package:flutter/material.dart';

import '../errors.dart';
import '../models.dart';

typedef OmniManualsLoadingBuilder = Widget Function(BuildContext context);
typedef OmniManualsEmptyBuilder = Widget Function(BuildContext context);
typedef OmniManualsErrorBuilder =
    Widget Function(BuildContext context, OmniManualsException error);
typedef OmniManualSelectedCallback =
    void Function(BuildContext context, OmniManualInfo manual);
typedef OmniManualIconBuilder =
    Widget Function(BuildContext context, OmniManualInfo manual);
typedef OmniCollectionIconBuilder =
    Widget Function(BuildContext context, OmniCollectionEntry collection);

typedef OmniManualsHeaderBuilder =
    Widget Function(
      BuildContext context,
      String title,
      String? subtitle,
      Widget? icon,
    );

typedef OmniManualsSearchBuilder =
    Widget Function(BuildContext context, TextEditingController controller);

typedef OmniManualCardBuilder =
    Widget Function(
      BuildContext context,
      OmniManualLibraryEntry entry,
      VoidCallback onTap,
    );

typedef OmniCollectionCardBuilder =
    Widget Function(
      BuildContext context,
      OmniCollectionEntry entry,
      VoidCallback onTap,
    );

typedef OmniItemCountLabelBuilder = String Function(int count);
typedef OmniVersionLabelBuilder = String Function(String version);

String _defaultItemCountLabel(int count) =>
    count == 1 ? '1 elemento' : '$count elementos';

String _defaultVersionLabel(String version) => 'v$version';

/// All user-facing strings rendered by the Flutter SDK widgets.
///
/// Applications can provide one instance from their own localization layer:
///
/// ```dart
/// OmniManualsStrings(
///   defaultTitle: appLocalizations.manualsTitle,
///   searchLabel: appLocalizations.searchManuals,

/// )
/// ```
@immutable
final class OmniManualsStrings {
  const OmniManualsStrings({
    this.defaultTitle = 'Omni Manuals',
    this.rootLabel = 'Biblioteca',
    this.searchLabel = 'Buscar manuales',
    this.noManuals = 'No hay manuales disponibles.',
    this.noSearchResults = 'No hay manuales que coincidan con la búsqueda.',
    this.searchTooltip = 'Buscar',
    this.tableOfContentsTooltip = 'Índice',
    this.languageTooltip = 'Idioma',
    this.loadingSemanticsLabel = 'Cargando manual',
    this.genericLoadError = 'No se pudo cargar Omni Manuals.',
    this.runtimeLoadError = 'El runtime embebido no pudo completar la carga.',
    this.webViewLoadError = 'No se pudo cargar el runtime embebido.',
    this.itemCountLabelBuilder = _defaultItemCountLabel,
    this.versionLabelBuilder = _defaultVersionLabel,
  });

  final String defaultTitle;
  final String rootLabel;
  final String searchLabel;
  final String noManuals;
  final String noSearchResults;
  final String searchTooltip;
  final String tableOfContentsTooltip;
  final String languageTooltip;
  final String loadingSemanticsLabel;
  final String genericLoadError;
  final String runtimeLoadError;
  final String webViewLoadError;
  final OmniItemCountLabelBuilder itemCountLabelBuilder;
  final OmniVersionLabelBuilder versionLabelBuilder;

  OmniManualsStrings copyWith({
    String? defaultTitle,
    String? rootLabel,
    String? searchLabel,
    String? noManuals,
    String? noSearchResults,
    String? searchTooltip,
    String? tableOfContentsTooltip,
    String? languageTooltip,
    String? loadingSemanticsLabel,
    String? genericLoadError,
    String? runtimeLoadError,
    String? webViewLoadError,
    OmniItemCountLabelBuilder? itemCountLabelBuilder,
    OmniVersionLabelBuilder? versionLabelBuilder,
  }) {
    return OmniManualsStrings(
      defaultTitle: defaultTitle ?? this.defaultTitle,
      rootLabel: rootLabel ?? this.rootLabel,
      searchLabel: searchLabel ?? this.searchLabel,
      noManuals: noManuals ?? this.noManuals,
      noSearchResults: noSearchResults ?? this.noSearchResults,
      searchTooltip: searchTooltip ?? this.searchTooltip,
      tableOfContentsTooltip:
          tableOfContentsTooltip ?? this.tableOfContentsTooltip,
      languageTooltip: languageTooltip ?? this.languageTooltip,
      loadingSemanticsLabel:
          loadingSemanticsLabel ?? this.loadingSemanticsLabel,
      genericLoadError: genericLoadError ?? this.genericLoadError,
      runtimeLoadError: runtimeLoadError ?? this.runtimeLoadError,
      webViewLoadError: webViewLoadError ?? this.webViewLoadError,
      itemCountLabelBuilder:
          itemCountLabelBuilder ?? this.itemCountLabelBuilder,
      versionLabelBuilder: versionLabelBuilder ?? this.versionLabelBuilder,
    );
  }
}

/// Responsive geometry and spacing used by the default widgets.
@immutable
final class OmniManualsLayout {
  const OmniManualsLayout({
    this.maxContentWidth = 1120,
    this.wideBreakpoint = 720,
    this.desktopBreakpoint = 1040,
    this.mediumColumnCount = 2,
    this.desktopColumnCount = 3,
    this.compactPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 20,
    ),
    this.widePadding = const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
    this.headerSpacing = 20,
    this.breadcrumbSpacing = 12,
    this.searchSpacing = 20,
    this.cardSpacing = 14,
    this.cardPadding = const EdgeInsets.all(18),
    this.cardHeaderSpacing = 16,
    this.cardTextSpacing = 6,
    this.cardMetadataSpacing = 12,
    this.cardAspectRatioWide = 1.45,
    this.cardAspectRatioCompact = 2.2,
    this.headerIconSize = 36,
    this.headerIconSpacing = 14,
    this.entryIconPadding = const EdgeInsets.all(12),
    this.entryIconRadius = 14,
    this.entryActionIconSize = 20,
    this.chipRadius = 999,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    this.chipSpacing = 6,
    this.emptyStateVerticalPadding = 48,
  });

  final double maxContentWidth;
  final double wideBreakpoint;
  final double desktopBreakpoint;
  final int mediumColumnCount;
  final int desktopColumnCount;
  final EdgeInsetsGeometry compactPadding;
  final EdgeInsetsGeometry widePadding;
  final double headerSpacing;
  final double breadcrumbSpacing;
  final double searchSpacing;
  final double cardSpacing;
  final EdgeInsetsGeometry cardPadding;
  final double cardHeaderSpacing;
  final double cardTextSpacing;
  final double cardMetadataSpacing;
  final double cardAspectRatioWide;
  final double cardAspectRatioCompact;
  final double headerIconSize;
  final double headerIconSpacing;
  final EdgeInsetsGeometry entryIconPadding;
  final double entryIconRadius;
  final double entryActionIconSize;
  final double chipRadius;
  final EdgeInsetsGeometry chipPadding;
  final double chipSpacing;
  final double emptyStateVerticalPadding;

  OmniManualsLayout copyWith({
    double? maxContentWidth,
    double? wideBreakpoint,
    double? desktopBreakpoint,
    int? mediumColumnCount,
    int? desktopColumnCount,
    EdgeInsetsGeometry? compactPadding,
    EdgeInsetsGeometry? widePadding,
    double? headerSpacing,
    double? breadcrumbSpacing,
    double? searchSpacing,
    double? cardSpacing,
    EdgeInsetsGeometry? cardPadding,
    double? cardHeaderSpacing,
    double? cardTextSpacing,
    double? cardMetadataSpacing,
    double? cardAspectRatioWide,
    double? cardAspectRatioCompact,
    double? headerIconSize,
    double? headerIconSpacing,
    EdgeInsetsGeometry? entryIconPadding,
    double? entryIconRadius,
    double? entryActionIconSize,
    double? chipRadius,
    EdgeInsetsGeometry? chipPadding,
    double? chipSpacing,
    double? emptyStateVerticalPadding,
  }) {
    return OmniManualsLayout(
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      wideBreakpoint: wideBreakpoint ?? this.wideBreakpoint,
      desktopBreakpoint: desktopBreakpoint ?? this.desktopBreakpoint,
      mediumColumnCount: mediumColumnCount ?? this.mediumColumnCount,
      desktopColumnCount: desktopColumnCount ?? this.desktopColumnCount,
      compactPadding: compactPadding ?? this.compactPadding,
      widePadding: widePadding ?? this.widePadding,
      headerSpacing: headerSpacing ?? this.headerSpacing,
      breadcrumbSpacing: breadcrumbSpacing ?? this.breadcrumbSpacing,
      searchSpacing: searchSpacing ?? this.searchSpacing,
      cardSpacing: cardSpacing ?? this.cardSpacing,
      cardPadding: cardPadding ?? this.cardPadding,
      cardHeaderSpacing: cardHeaderSpacing ?? this.cardHeaderSpacing,
      cardTextSpacing: cardTextSpacing ?? this.cardTextSpacing,
      cardMetadataSpacing: cardMetadataSpacing ?? this.cardMetadataSpacing,
      cardAspectRatioWide: cardAspectRatioWide ?? this.cardAspectRatioWide,
      cardAspectRatioCompact:
          cardAspectRatioCompact ?? this.cardAspectRatioCompact,
      headerIconSize: headerIconSize ?? this.headerIconSize,
      headerIconSpacing: headerIconSpacing ?? this.headerIconSpacing,
      entryIconPadding: entryIconPadding ?? this.entryIconPadding,
      entryIconRadius: entryIconRadius ?? this.entryIconRadius,
      entryActionIconSize: entryActionIconSize ?? this.entryActionIconSize,
      chipRadius: chipRadius ?? this.chipRadius,
      chipPadding: chipPadding ?? this.chipPadding,
      chipSpacing: chipSpacing ?? this.chipSpacing,
      emptyStateVerticalPadding:
          emptyStateVerticalPadding ?? this.emptyStateVerticalPadding,
    );
  }
}

/// Visual customization for the default Flutter library and viewer surfaces.
@immutable
final class OmniManualsThemeData {
  const OmniManualsThemeData({
    this.backgroundColor,
    this.cardColor,
    this.foregroundColor,
    this.accentColor,
    this.mutedForegroundColor,
    this.iconBackgroundColor,
    this.chipBackgroundColor,
    this.chipForegroundColor,
    this.viewerOverlayColor,
    this.webViewBackgroundColor = const Color(0xffffffff),
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
    this.cardTitleStyle,
    this.cardSubtitleStyle,
    this.chipTextStyle,
    this.emptyTextStyle,
    this.searchDecoration,
    this.cardShape,
    this.cardElevation,
    this.progressIndicatorColor,
    this.headerIcon,
    this.manualIcon,
    this.collectionIcon,
    this.manualActionIcon,
    this.collectionActionIcon,
    this.searchIcon,
    this.tableOfContentsIcon,
    this.languageIcon,
    this.homeIcon,
    this.breadcrumbSeparatorIcon,
  });

  final Color? backgroundColor;
  final Color? cardColor;
  final Color? foregroundColor;
  final Color? accentColor;
  final Color? mutedForegroundColor;
  final Color? iconBackgroundColor;
  final Color? chipBackgroundColor;
  final Color? chipForegroundColor;
  final Color? viewerOverlayColor;
  final Color webViewBackgroundColor;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? cardTitleStyle;
  final TextStyle? cardSubtitleStyle;
  final TextStyle? chipTextStyle;
  final TextStyle? emptyTextStyle;
  final InputDecoration? searchDecoration;
  final ShapeBorder? cardShape;
  final double? cardElevation;
  final Color? progressIndicatorColor;
  final IconData? headerIcon;
  final IconData? manualIcon;
  final IconData? collectionIcon;
  final IconData? manualActionIcon;
  final IconData? collectionActionIcon;
  final IconData? searchIcon;
  final IconData? tableOfContentsIcon;
  final IconData? languageIcon;
  final IconData? homeIcon;
  final IconData? breadcrumbSeparatorIcon;

  OmniManualsThemeData copyWith({
    Color? backgroundColor,
    Color? cardColor,
    Color? foregroundColor,
    Color? accentColor,
    Color? mutedForegroundColor,
    Color? iconBackgroundColor,
    Color? chipBackgroundColor,
    Color? chipForegroundColor,
    Color? viewerOverlayColor,
    Color? webViewBackgroundColor,
    EdgeInsetsGeometry? padding,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? cardTitleStyle,
    TextStyle? cardSubtitleStyle,
    TextStyle? chipTextStyle,
    TextStyle? emptyTextStyle,
    InputDecoration? searchDecoration,
    ShapeBorder? cardShape,
    double? cardElevation,
    Color? progressIndicatorColor,
    IconData? headerIcon,
    IconData? manualIcon,
    IconData? collectionIcon,
    IconData? manualActionIcon,
    IconData? collectionActionIcon,
    IconData? searchIcon,
    IconData? tableOfContentsIcon,
    IconData? languageIcon,
    IconData? homeIcon,
    IconData? breadcrumbSeparatorIcon,
  }) {
    return OmniManualsThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cardColor: cardColor ?? this.cardColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      accentColor: accentColor ?? this.accentColor,
      mutedForegroundColor: mutedForegroundColor ?? this.mutedForegroundColor,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      chipBackgroundColor: chipBackgroundColor ?? this.chipBackgroundColor,
      chipForegroundColor: chipForegroundColor ?? this.chipForegroundColor,
      viewerOverlayColor: viewerOverlayColor ?? this.viewerOverlayColor,
      webViewBackgroundColor:
          webViewBackgroundColor ?? this.webViewBackgroundColor,
      padding: padding ?? this.padding,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      cardTitleStyle: cardTitleStyle ?? this.cardTitleStyle,
      cardSubtitleStyle: cardSubtitleStyle ?? this.cardSubtitleStyle,
      chipTextStyle: chipTextStyle ?? this.chipTextStyle,
      emptyTextStyle: emptyTextStyle ?? this.emptyTextStyle,
      searchDecoration: searchDecoration ?? this.searchDecoration,
      cardShape: cardShape ?? this.cardShape,
      cardElevation: cardElevation ?? this.cardElevation,
      progressIndicatorColor:
          progressIndicatorColor ?? this.progressIndicatorColor,
      headerIcon: headerIcon ?? this.headerIcon,
      manualIcon: manualIcon ?? this.manualIcon,
      collectionIcon: collectionIcon ?? this.collectionIcon,
      manualActionIcon: manualActionIcon ?? this.manualActionIcon,
      collectionActionIcon: collectionActionIcon ?? this.collectionActionIcon,
      searchIcon: searchIcon ?? this.searchIcon,
      tableOfContentsIcon: tableOfContentsIcon ?? this.tableOfContentsIcon,
      languageIcon: languageIcon ?? this.languageIcon,
      homeIcon: homeIcon ?? this.homeIcon,
      breadcrumbSeparatorIcon:
          breadcrumbSeparatorIcon ?? this.breadcrumbSeparatorIcon,
    );
  }
}

/// Optional replacement builders for default SDK components.
@immutable
final class OmniManualsBuilders {
  const OmniManualsBuilders({
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.headerBuilder,
    this.searchBuilder,
    this.manualCardBuilder,
    this.collectionCardBuilder,
    this.manualIconBuilder,
    this.collectionIconBuilder,
  });

  final OmniManualsLoadingBuilder? loadingBuilder;
  final OmniManualsEmptyBuilder? emptyBuilder;
  final OmniManualsErrorBuilder? errorBuilder;
  final OmniManualsHeaderBuilder? headerBuilder;
  final OmniManualsSearchBuilder? searchBuilder;
  final OmniManualCardBuilder? manualCardBuilder;
  final OmniCollectionCardBuilder? collectionCardBuilder;
  final OmniManualIconBuilder? manualIconBuilder;
  final OmniCollectionIconBuilder? collectionIconBuilder;
}

/// Controls which viewer chrome and actions are shown.
@immutable
final class OmniManualViewerOptions {
  const OmniManualViewerOptions({
    this.showAppBar = true,
    this.showSearch = true,
    this.showTableOfContents = true,
    this.showLanguageSelector = true,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
  });

  final bool showAppBar;
  final bool showSearch;
  final bool showTableOfContents;
  final bool showLanguageSelector;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
}
