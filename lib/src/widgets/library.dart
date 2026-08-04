import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../events.dart';
import '../errors.dart';
import '../internal/sdk_controller.dart';
import '../library_catalog.dart';
import '../material_icons.dart';
import '../models.dart';
import '../omni_manuals.dart';
import '../provider.dart';
import '../state.dart';
import 'customization.dart';
import 'viewer.dart';

class OmniManualsPage extends StatelessWidget {
  const OmniManualsPage({
    super.key,
    this.language,
    this.source,
    this.catalogSource,
    this.title,
    this.subtitle,
    this.introduction,
    this.theme = const OmniManualsThemeData(),
    this.layout = const OmniManualsLayout(),
    this.strings = const OmniManualsStrings(),
    this.builders = const OmniManualsBuilders(),
    this.viewerOptions = const OmniManualViewerOptions(),
    this.headerIcon,
    this.manualFallbackIcon,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.manualIconBuilder,
    this.collectionIconBuilder,
    this.userGroups = const <String>{'default'},
    this.publicApiBaseUrl,
  });

  final String? language;
  final OmniManualsSource? source;
  final OmniLibraryCatalogSource? catalogSource;
  final String? title;
  final String? subtitle;
  final String? introduction;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final OmniManualsStrings strings;
  final OmniManualsBuilders builders;
  final OmniManualViewerOptions viewerOptions;
  final Widget? headerIcon;
  final Widget? manualFallbackIcon;

  @Deprecated('Use builders.loadingBuilder instead.')
  final OmniManualsLoadingBuilder? loadingBuilder;

  @Deprecated('Use builders.emptyBuilder instead.')
  final OmniManualsEmptyBuilder? emptyBuilder;

  @Deprecated('Use builders.errorBuilder instead.')
  final OmniManualsErrorBuilder? errorBuilder;

  @Deprecated('Use builders.manualIconBuilder instead.')
  final OmniManualIconBuilder? manualIconBuilder;

  @Deprecated('Use builders.collectionIconBuilder instead.')
  final OmniCollectionIconBuilder? collectionIconBuilder;

  final Set<String> userGroups;
  final Uri? publicApiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? strings.defaultTitle;
    return Scaffold(
      appBar: AppBar(title: Text(resolvedTitle)),
      body: OmniManualsLibrary(
        language: language,
        source: source,
        catalogSource: catalogSource,
        title: resolvedTitle,
        subtitle: subtitle ?? introduction,
        theme: theme,
        layout: layout,
        strings: strings,
        builders: builders,
        viewerOptions: viewerOptions,
        headerIcon: headerIcon,
        manualFallbackIcon: manualFallbackIcon,
        loadingBuilder: loadingBuilder,
        emptyBuilder: emptyBuilder,
        errorBuilder: errorBuilder,
        manualIconBuilder: manualIconBuilder,
        collectionIconBuilder: collectionIconBuilder,
        userGroups: userGroups,
        publicApiBaseUrl: publicApiBaseUrl,
      ),
    );
  }
}

class OmniManualsLibrary extends StatefulWidget {
  const OmniManualsLibrary({
    super.key,
    this.language,
    this.source,
    this.catalogSource,
    this.title,
    this.subtitle,
    this.showHeader = true,
    this.navigateOnManualTap = true,
    this.theme = const OmniManualsThemeData(),
    this.layout = const OmniManualsLayout(),
    this.strings = const OmniManualsStrings(),
    this.builders = const OmniManualsBuilders(),
    this.viewerOptions = const OmniManualViewerOptions(),
    this.headerIcon,
    this.manualFallbackIcon,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.manualIconBuilder,
    this.collectionIconBuilder,
    this.rootLabel,
    this.onManualSelected,
    this.userGroups = const <String>{'default'},
    this.publicApiBaseUrl,
  });

  final String? rootLabel;
  final String? language;
  final OmniManualsSource? source;
  final OmniLibraryCatalogSource? catalogSource;
  final String? title;
  final String? subtitle;
  final bool showHeader;
  final bool navigateOnManualTap;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final OmniManualsStrings strings;
  final OmniManualsBuilders builders;
  final OmniManualViewerOptions viewerOptions;
  final Widget? headerIcon;
  final Widget? manualFallbackIcon;

  @Deprecated('Use builders.loadingBuilder instead.')
  final OmniManualsLoadingBuilder? loadingBuilder;

  @Deprecated('Use builders.emptyBuilder instead.')
  final OmniManualsEmptyBuilder? emptyBuilder;

  @Deprecated('Use builders.errorBuilder instead.')
  final OmniManualsErrorBuilder? errorBuilder;

  @Deprecated('Use builders.manualIconBuilder instead.')
  final OmniManualIconBuilder? manualIconBuilder;

  @Deprecated('Use builders.collectionIconBuilder instead.')
  final OmniCollectionIconBuilder? collectionIconBuilder;

  final OmniManualSelectedCallback? onManualSelected;
  final Set<String> userGroups;
  final Uri? publicApiBaseUrl;

  @override
  State<OmniManualsLibrary> createState() => _OmniManualsLibraryState();
}

class _OmniManualsLibraryState extends State<OmniManualsLibrary> {
  late Future<List<OmniLibraryEntry>> _entries = _loadEntries();
  final TextEditingController _searchController = TextEditingController();
  final List<OmniCollectionEntry> _path = <OmniCollectionEntry>[];
  StreamSubscription<OmniManualsEvent>? _eventsSubscription;
  String _query = '';

  OmniManualsLoadingBuilder? get _loadingBuilder =>
      widget.loadingBuilder ?? widget.builders.loadingBuilder;

  OmniManualsEmptyBuilder? get _emptyBuilder =>
      widget.emptyBuilder ?? widget.builders.emptyBuilder;

  OmniManualsErrorBuilder? get _errorBuilder =>
      widget.errorBuilder ?? widget.builders.errorBuilder;

  OmniManualIconBuilder? get _manualIconBuilder =>
      widget.manualIconBuilder ?? widget.builders.manualIconBuilder;

  OmniCollectionIconBuilder? get _collectionIconBuilder =>
      widget.collectionIconBuilder ?? widget.builders.collectionIconBuilder;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _eventsSubscription = OmniManuals.events.listen(_handleSdkEvent);
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() => _query = _searchController.text);
    }
  }

  void _handleSdkEvent(OmniManualsEvent event) {
    if (event.type != OmniManualsEventType.libraryChanged || !mounted) {
      return;
    }
    setState(() {
      _entries = _loadEntries().then((entries) {
        _preserveValidPath(entries);
        return entries;
      });
    });
  }

  @override
  void didUpdateWidget(covariant OmniManualsLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source) ||
        !identical(oldWidget.catalogSource, widget.catalogSource) ||
        oldWidget.userGroups != widget.userGroups ||
        oldWidget.language != widget.language) {
      _path.clear();
      _entries = _loadEntries();
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<List<OmniLibraryEntry>> _loadEntries() async {
    if (OmniManuals.state != OmniManualsState.ready) {
      await OmniManuals.initialize(
        config: OmniManualsConfig(
          defaultLanguage: widget.language,
          source: widget.source,
          catalogSource: widget.catalogSource,
          userGroups: widget.userGroups,
          publicApiBaseUrl: widget.publicApiBaseUrl,
        ),
      );
    }
    return omniManualsController.resolveLibraryEntries(
      catalogSource: widget.catalogSource,
      language: widget.language,
      userGroups: widget.userGroups,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _path.isNotEmpty) {
          setState(() => _path.removeLast());
        }
      },
      child: FutureBuilder<List<OmniLibraryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _loading(context);
          }
          if (snapshot.hasError) {
            return _error(context, _exception(snapshot.error, widget.strings));
          }

          final rootEntries = snapshot.requireData;
          final visibleEntries = _path.isEmpty
              ? rootEntries
              : _path.last.children;
          final filteredEntries = _filterEntries(visibleEntries, _query);

          if (rootEntries.isEmpty) {
            return _emptyBuilder?.call(context) ??
                _DefaultEmptyState(
                  message: widget.strings.noManuals,
                  theme: widget.theme,
                  layout: widget.layout,
                );
          }

          return _LibrarySurface(
            title: widget.title ?? widget.strings.defaultTitle,
            subtitle: widget.subtitle,
            showHeader: widget.showHeader,
            headerIcon: widget.headerIcon,
            rootLabel: widget.rootLabel ?? widget.strings.rootLabel,
            theme: widget.theme,
            layout: widget.layout,
            strings: widget.strings,
            builders: widget.builders,
            searchController: _searchController,
            path: List<OmniCollectionEntry>.unmodifiable(_path),
            entries: filteredEntries,
            hasQuery: _query.trim().isNotEmpty,
            manualFallbackIcon: widget.manualFallbackIcon,
            manualIconBuilder: _manualIconBuilder,
            collectionIconBuilder: _collectionIconBuilder,
            onBreadcrumbSelected: (index) {
              setState(() => _path.removeRange(index + 1, _path.length));
            },
            onCollectionSelected: (collection) {
              setState(() => _path.add(collection));
            },
            onManualSelected: _selectManual,
          );
        },
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return _loadingBuilder?.call(context) ??
        DefaultOmniManualsLoadingState(
          strings: widget.strings,
          theme: widget.theme,
        );
  }

  Widget _error(BuildContext context, OmniManualsException error) {
    return _errorBuilder?.call(context, error) ??
        Center(
          child: Text(
            error.message,
            textAlign: TextAlign.center,
            style: widget.theme.emptyTextStyle,
          ),
        );
  }

  void _selectManual(OmniManualInfo manual) {
    final customSelection = widget.onManualSelected;
    if (customSelection != null) {
      customSelection(context, manual);
      return;
    }
    if (!widget.navigateOnManualTap) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OmniManualViewerPage(
          manual: manual,
          language: widget.language,
          strings: widget.strings,
          theme: widget.theme,
          builders: widget.builders,
          options: widget.viewerOptions,
          loadingBuilder: _loadingBuilder,
          errorBuilder: _errorBuilder,
        ),
      ),
    );
  }

  List<OmniLibraryEntry> _filterEntries(
    List<OmniLibraryEntry> entries,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return entries;
    return entries
        .where((entry) => _searchableEntryText(entry).contains(normalizedQuery))
        .toList(growable: false);
  }

  String _searchableEntryText(OmniLibraryEntry entry) {
    return switch (entry) {
      OmniManualLibraryEntry(:final manual) => [
        manual.id,
        manual.title,
        if (manual.subtitle != null) manual.subtitle!,
        if (manual.version != null) manual.version!,
        ...manual.languages,
      ].join(' ').toLowerCase(),
      OmniCollectionEntry(:final children) => [
        entry.id,
        entry.title,
        if (entry.subtitle != null) entry.subtitle!,
        for (final child in children) _searchableEntryText(child),
      ].join(' ').toLowerCase(),
    };
  }

  void _preserveValidPath(List<OmniLibraryEntry> rootEntries) {
    if (_path.isEmpty) return;
    var entries = rootEntries;
    final nextPath = <OmniCollectionEntry>[];
    for (final current in _path) {
      final match = entries
          .whereType<OmniCollectionEntry>()
          .where((entry) => entry.id == current.id)
          .firstOrNull;
      if (match == null) break;
      nextPath.add(match);
      entries = match.children;
    }
    _path
      ..clear()
      ..addAll(nextPath);
  }
}

/// Compatibility wrapper retained for applications using the original name.
class OmniLibrary extends StatelessWidget {
  const OmniLibrary({
    super.key,
    this.language,
    this.title,
    this.introduction,
    this.onManualSelected,
    this.errorBuilder,
    this.emptyBuilder,
    this.manualFallbackIcon,
    this.catalogSource,
    this.userGroups = const <String>{'default'},
    this.publicApiBaseUrl,
    this.strings = const OmniManualsStrings(),
    this.theme = const OmniManualsThemeData(),
    this.layout = const OmniManualsLayout(),
    this.builders = const OmniManualsBuilders(),
    this.viewerOptions = const OmniManualViewerOptions(),
  });

  final String? language;
  final String? title;
  final String? introduction;
  final ValueChanged<OmniManualInfo>? onManualSelected;
  final OmniManualsErrorBuilder? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final Widget? manualFallbackIcon;
  final OmniLibraryCatalogSource? catalogSource;
  final Set<String> userGroups;
  final Uri? publicApiBaseUrl;
  final OmniManualsStrings strings;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final OmniManualsBuilders builders;
  final OmniManualViewerOptions viewerOptions;

  @override
  Widget build(BuildContext context) {
    return OmniManualsLibrary(
      language: language,
      catalogSource: catalogSource,
      title: title,
      subtitle: introduction,
      navigateOnManualTap: onManualSelected == null,
      onManualSelected: onManualSelected == null
          ? null
          : (context, manual) => onManualSelected!(manual),
      errorBuilder: errorBuilder,
      emptyBuilder: emptyBuilder,
      manualFallbackIcon: manualFallbackIcon,
      userGroups: userGroups,
      publicApiBaseUrl: publicApiBaseUrl,
      strings: strings,
      theme: theme,
      layout: layout,
      builders: builders,
      viewerOptions: viewerOptions,
    );
  }
}

class _LibrarySurface extends StatelessWidget {
  const _LibrarySurface({
    required this.title,
    required this.showHeader,
    required this.theme,
    required this.layout,
    required this.strings,
    required this.builders,
    required this.searchController,
    required this.path,
    required this.entries,
    required this.hasQuery,
    required this.onBreadcrumbSelected,
    required this.onCollectionSelected,
    required this.onManualSelected,
    required this.rootLabel,
    this.subtitle,
    this.headerIcon,
    this.manualFallbackIcon,
    this.manualIconBuilder,
    this.collectionIconBuilder,
  });

  final String rootLabel;
  final String title;
  final String? subtitle;
  final bool showHeader;
  final Widget? headerIcon;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final OmniManualsStrings strings;
  final OmniManualsBuilders builders;
  final TextEditingController searchController;
  final List<OmniCollectionEntry> path;
  final List<OmniLibraryEntry> entries;
  final bool hasQuery;
  final ValueChanged<int> onBreadcrumbSelected;
  final ValueChanged<OmniCollectionEntry> onCollectionSelected;
  final ValueChanged<OmniManualInfo> onManualSelected;
  final Widget? manualFallbackIcon;
  final OmniManualIconBuilder? manualIconBuilder;
  final OmniCollectionIconBuilder? collectionIconBuilder;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final colorScheme = materialTheme.colorScheme;
    final backgroundColor = theme.backgroundColor ?? colorScheme.surface;
    final foregroundColor = theme.foregroundColor ?? colorScheme.onSurface;
    final accentColor = theme.accentColor ?? colorScheme.primary;

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= layout.wideBreakpoint;
            final columns = constraints.maxWidth >= layout.desktopBreakpoint
                ? layout.desktopColumnCount
                : wide
                ? layout.mediumColumnCount
                : 1;

            final cards = [
              for (final entry in entries)
                _buildEntryCard(context, entry, foregroundColor, accentColor),
            ];

            return SingleChildScrollView(
              padding:
                  theme.padding ??
                  (wide ? layout.widePadding : layout.compactPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        builders.headerBuilder?.call(
                              context,
                              title,
                              subtitle,
                              headerIcon,
                            ) ??
                            _LibraryHeader(
                              title: title,
                              subtitle: subtitle,
                              icon: headerIcon,
                              theme: theme,
                              layout: layout,
                              foregroundColor: foregroundColor,
                              accentColor: accentColor,
                            ),
                      if (showHeader) SizedBox(height: layout.headerSpacing),
                      if (path.isNotEmpty) ...[
                        _Breadcrumbs(
                          path: path,
                          onSelected: onBreadcrumbSelected,
                          rootLabel: rootLabel,
                          theme: theme,
                        ),
                        SizedBox(height: layout.breadcrumbSpacing),
                      ],
                      builders.searchBuilder?.call(context, searchController) ??
                          TextField(
                            controller: searchController,
                            decoration:
                                theme.searchDecoration?.copyWith(
                                  prefixIcon:
                                      theme.searchDecoration?.prefixIcon ??
                                      Icon(theme.searchIcon ?? Icons.search),
                                  labelText:
                                      theme.searchDecoration?.labelText ??
                                      strings.searchLabel,
                                ) ??
                                InputDecoration(
                                  prefixIcon: Icon(
                                    theme.searchIcon ?? Icons.search,
                                  ),
                                  labelText: strings.searchLabel,
                                  border: const OutlineInputBorder(),
                                ),
                          ),
                      SizedBox(height: layout.searchSpacing),
                      if (entries.isEmpty)
                        _EmptySearchState(
                          message: hasQuery
                              ? strings.noSearchResults
                              : strings.noManuals,
                          theme: theme,
                          layout: layout,
                        )
                      else if (columns == 1)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var index = 0;
                              index < cards.length;
                              index += 1
                            ) ...[
                              if (index > 0)
                                SizedBox(height: layout.cardSpacing),
                              cards[index],
                            ],
                          ],
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cards.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: layout.cardSpacing,
                                mainAxisSpacing: layout.cardSpacing,
                                childAspectRatio: wide
                                    ? layout.cardAspectRatioWide
                                    : layout.cardAspectRatioCompact,
                              ),
                          itemBuilder: (context, index) => cards[index],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    OmniLibraryEntry entry,
    Color foregroundColor,
    Color accentColor,
  ) {
    void onTap() {
      switch (entry) {
        case OmniManualLibraryEntry(:final manual):
          onManualSelected(manual);
        case OmniCollectionEntry():
          onCollectionSelected(entry);
      }
    }

    return switch (entry) {
      OmniManualLibraryEntry() =>
        builders.manualCardBuilder?.call(context, entry, onTap) ??
            _LibraryEntryCard(
              entry: entry,
              theme: theme,
              layout: layout,
              strings: strings,
              foregroundColor: foregroundColor,
              accentColor: accentColor,
              manualFallbackIcon: manualFallbackIcon,
              manualIconBuilder: manualIconBuilder,
              collectionIconBuilder: collectionIconBuilder,
              onTap: onTap,
            ),
      OmniCollectionEntry() =>
        builders.collectionCardBuilder?.call(context, entry, onTap) ??
            _LibraryEntryCard(
              entry: entry,
              theme: theme,
              layout: layout,
              strings: strings,
              foregroundColor: foregroundColor,
              accentColor: accentColor,
              manualFallbackIcon: manualFallbackIcon,
              manualIconBuilder: manualIconBuilder,
              collectionIconBuilder: collectionIconBuilder,
              onTap: onTap,
            ),
    };
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.title,
    required this.theme,
    required this.layout,
    required this.foregroundColor,
    required this.accentColor,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? icon;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final Color foregroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final mutedColor =
        theme.mutedForegroundColor ?? foregroundColor.withValues(alpha: 0.72);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon ??
            Icon(
              theme.headerIcon ?? Icons.menu_book_outlined,
              color: accentColor,
              size: layout.headerIconSize,
            ),
        SizedBox(width: layout.headerIconSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    theme.titleStyle ??
                    materialTheme.textTheme.headlineMedium?.copyWith(
                      color: foregroundColor,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: layout.cardTextSpacing),
                Text(
                  subtitle!,
                  style:
                      theme.subtitleStyle ??
                      materialTheme.textTheme.bodyLarge?.copyWith(
                        color: mutedColor,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.rootLabel,
    required this.path,
    required this.onSelected,
    required this.theme,
  });

  final String rootLabel;
  final List<OmniCollectionEntry> path;
  final ValueChanged<int> onSelected;
  final OmniManualsThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: () => onSelected(-1),
          icon: Icon(theme.homeIcon ?? Icons.home_outlined, size: 18),
          label: Text(rootLabel),
        ),
        for (var index = 0; index < path.length; index += 1) ...[
          Icon(theme.breadcrumbSeparatorIcon ?? Icons.chevron_right, size: 18),
          TextButton(
            onPressed: index == path.length - 1
                ? null
                : () => onSelected(index),
            child: Text(path[index].title),
          ),
        ],
      ],
    );
  }
}

class _LibraryEntryCard extends StatelessWidget {
  const _LibraryEntryCard({
    required this.entry,
    required this.theme,
    required this.layout,
    required this.strings,
    required this.foregroundColor,
    required this.accentColor,
    required this.onTap,
    this.manualFallbackIcon,
    this.manualIconBuilder,
    this.collectionIconBuilder,
  });

  final OmniLibraryEntry entry;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final OmniManualsStrings strings;
  final Color foregroundColor;
  final Color accentColor;
  final VoidCallback onTap;
  final Widget? manualFallbackIcon;
  final OmniManualIconBuilder? manualIconBuilder;
  final OmniCollectionIconBuilder? collectionIconBuilder;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final cardColor = theme.cardColor ?? materialTheme.colorScheme.surface;
    final subtitle = entry.subtitle ?? entry.description;
    final isCollection = entry is OmniCollectionEntry;
    final mutedColor =
        theme.mutedForegroundColor ?? foregroundColor.withValues(alpha: 0.72);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      shape: theme.cardShape,
      elevation: theme.cardElevation,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: layout.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EntryIcon(
                    entry: entry,
                    accentColor: accentColor,
                    theme: theme,
                    layout: layout,
                    manualFallbackIcon: manualFallbackIcon,
                    manualIconBuilder: manualIconBuilder,
                    collectionIconBuilder: collectionIconBuilder,
                  ),
                  const Spacer(),
                  Icon(
                    isCollection
                        ? theme.collectionActionIcon ?? Icons.chevron_right
                        : theme.manualActionIcon ?? Icons.arrow_forward,
                    color: mutedColor,
                    size: layout.entryActionIconSize,
                  ),
                ],
              ),
              SizedBox(height: layout.cardHeaderSpacing),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.cardTitleStyle ??
                    materialTheme.textTheme.titleMedium?.copyWith(
                      color: foregroundColor,
                    ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                SizedBox(height: layout.cardTextSpacing),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      theme.cardSubtitleStyle ??
                      materialTheme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                      ),
                ),
              ],
              if (entry.badges.isNotEmpty) ...[
                SizedBox(height: layout.cardMetadataSpacing),
                Wrap(
                  spacing: layout.chipSpacing,
                  runSpacing: layout.chipSpacing,
                  children: [
                    for (final badge in entry.badges)
                      _ManualMetaChip(
                        label: badge,
                        theme: theme,
                        layout: layout,
                      ),
                  ],
                ),
              ],
              if (entry case OmniManualLibraryEntry(:final manual)) ...[
                SizedBox(height: layout.cardMetadataSpacing),
                Wrap(
                  spacing: layout.chipSpacing,
                  runSpacing: layout.chipSpacing,
                  children: [
                    if (manual.version != null)
                      _ManualMetaChip(
                        label: strings.versionLabelBuilder(manual.version!),
                        theme: theme,
                        layout: layout,
                      ),
                    for (final language in manual.languages.take(3))
                      _ManualMetaChip(
                        label: language.toUpperCase(),
                        theme: theme,
                        layout: layout,
                      ),
                  ],
                ),
              ],
              if (entry case OmniCollectionEntry(:final children)) ...[
                SizedBox(height: layout.cardMetadataSpacing),
                _ManualMetaChip(
                  label: strings.itemCountLabelBuilder(children.length),
                  theme: theme,
                  layout: layout,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({
    required this.entry,
    required this.accentColor,
    required this.theme,
    required this.layout,
    this.manualFallbackIcon,
    this.manualIconBuilder,
    this.collectionIconBuilder,
  });

  final OmniLibraryEntry entry;
  final Color accentColor;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;
  final Widget? manualFallbackIcon;
  final OmniManualIconBuilder? manualIconBuilder;
  final OmniCollectionIconBuilder? collectionIconBuilder;
  @override
  Widget build(BuildContext context) {
    final custom = switch (entry) {
      OmniManualLibraryEntry(:final manual) => manualIconBuilder?.call(
        context,
        manual,
      ),
      OmniCollectionEntry() => collectionIconBuilder?.call(
        context,
        entry as OmniCollectionEntry,
      ),
    };

    if (custom != null) return custom;

    if (entry is OmniManualLibraryEntry && manualFallbackIcon != null) {
      return manualFallbackIcon!;
    }

    final iconData =
        OmniMaterialIcons.iconData(entry.icon) ??
        (entry is OmniCollectionEntry
            ? theme.collectionIcon ?? Icons.folder
            : theme.manualIcon ?? Icons.menu_book);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.entryIconRadius),
        color: theme.iconBackgroundColor ?? accentColor.withValues(alpha: 0.12),
      ),
      child: Padding(
        padding: layout.entryIconPadding,
        child: Icon(iconData, color: accentColor),
      ),
    );
  }
}

class _ManualMetaChip extends StatelessWidget {
  const _ManualMetaChip({
    required this.label,
    required this.theme,
    required this.layout,
  });

  final String label;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final background =
        theme.chipBackgroundColor ??
        materialTheme.colorScheme.secondaryContainer;
    final foreground =
        theme.chipForegroundColor ??
        materialTheme.colorScheme.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.chipRadius),
        color: background,
      ),
      child: Padding(
        padding: layout.chipPadding,
        child: Text(
          label,
          style:
              theme.chipTextStyle ??
              materialTheme.textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.message,
    required this.theme,
    required this.layout,
  });

  final String message;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: layout.emptyStateVerticalPadding,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.emptyTextStyle,
        ),
      ),
    );
  }
}

class _DefaultEmptyState extends StatelessWidget {
  const _DefaultEmptyState({
    required this.message,
    required this.theme,
    required this.layout,
  });

  final String message;
  final OmniManualsThemeData theme;
  final OmniManualsLayout layout;

  @override
  Widget build(BuildContext context) {
    return _EmptySearchState(message: message, theme: theme, layout: layout);
  }
}

OmniManualsException _exception(Object? error, OmniManualsStrings strings) {
  if (error is OmniManualsException) return error;
  return OmniManualsException(
    code: OmniManualsErrorCode.initializationFailed,
    message: strings.genericLoadError,
    cause: error,
  );
}
