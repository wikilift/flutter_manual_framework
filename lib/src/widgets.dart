// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// import 'config.dart';
// import 'events.dart';
// import 'errors.dart';
// import 'internal/runtime_bridge.dart';
// import 'internal/sdk_controller.dart';
// import 'library_catalog.dart';
// import 'material_icons.dart';
// import 'models.dart';
// import 'omni_manuals.dart';
// import 'provider.dart';
// import 'state.dart';

// typedef OmniManualsLoadingBuilder = Widget Function(BuildContext context);
// typedef OmniManualsEmptyBuilder = Widget Function(BuildContext context);
// typedef OmniManualsErrorBuilder =
//     Widget Function(BuildContext context, OmniManualsException error);
// typedef OmniManualSelectedCallback =
//     void Function(BuildContext context, OmniManualInfo manual);
// typedef OmniManualIconBuilder =
//     Widget Function(BuildContext context, OmniManualInfo manual);
// typedef OmniCollectionIconBuilder =
//     Widget Function(BuildContext context, OmniCollectionEntry collection);

// @immutable
// final class OmniManualsThemeData {
//   const OmniManualsThemeData({
//     this.backgroundColor,
//     this.cardColor,
//     this.foregroundColor,
//     this.accentColor,
//     this.padding,
//     this.titleStyle,
//     this.subtitleStyle,
//     this.cardTitleStyle,
//     this.cardSubtitleStyle,
//   });

//   final Color? backgroundColor;
//   final Color? cardColor;
//   final Color? foregroundColor;
//   final Color? accentColor;
//   final EdgeInsetsGeometry? padding;
//   final TextStyle? titleStyle;
//   final TextStyle? subtitleStyle;
//   final TextStyle? cardTitleStyle;
//   final TextStyle? cardSubtitleStyle;
// }

// class OmniManualsPage extends StatelessWidget {
//   const OmniManualsPage({
//     super.key,
//     this.language,
//     this.source,
//     this.catalogSource,
//     this.title = 'Omni Manuals',
//     this.subtitle,
//     this.introduction,
//     this.theme = const OmniManualsThemeData(),
//     this.headerIcon,
//     this.manualFallbackIcon,
//     this.loadingBuilder,
//     this.emptyBuilder,
//     this.errorBuilder,
//     this.manualIconBuilder,
//     this.collectionIconBuilder,
//     this.userGroups = const <String>{'default'},
//     this.publicApiBaseUrl,
//   });

//   final String? language;
//   final OmniManualsSource? source;
//   final OmniLibraryCatalogSource? catalogSource;
//   final String title;
//   final String? subtitle;
//   final String? introduction;
//   final OmniManualsThemeData theme;
//   final Widget? headerIcon;
//   final Widget? manualFallbackIcon;
//   final OmniManualsLoadingBuilder? loadingBuilder;
//   final OmniManualsEmptyBuilder? emptyBuilder;
//   final OmniManualsErrorBuilder? errorBuilder;
//   final OmniManualIconBuilder? manualIconBuilder;
//   final OmniCollectionIconBuilder? collectionIconBuilder;
//   final Set<String> userGroups;
//   final Uri? publicApiBaseUrl;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(title)),
//       body: OmniManualsLibrary(
//         language: language,
//         source: source,
//         catalogSource: catalogSource,
//         title: title,
//         subtitle: subtitle ?? introduction,
//         theme: theme,
//         headerIcon: headerIcon,
//         manualFallbackIcon: manualFallbackIcon,
//         loadingBuilder: loadingBuilder,
//         emptyBuilder: emptyBuilder,
//         errorBuilder: errorBuilder,
//         manualIconBuilder: manualIconBuilder,
//         collectionIconBuilder: collectionIconBuilder,
//         userGroups: userGroups,
//         publicApiBaseUrl: publicApiBaseUrl,
//       ),
//     );
//   }
// }

// class OmniManualsLibrary extends StatefulWidget {
//   const OmniManualsLibrary({
//     super.key,
//     this.language,
//     this.source,
//     this.catalogSource,
//     this.title = 'Omni Manuals',
//     this.subtitle,
//     this.showHeader = true,
//     this.navigateOnManualTap = true,
//     this.theme = const OmniManualsThemeData(),
//     this.headerIcon,
//     this.manualFallbackIcon,
//     this.loadingBuilder,
//     this.emptyBuilder,
//     this.errorBuilder,
//     this.manualIconBuilder,
//     this.collectionIconBuilder,
//     this.rootLabel = 'Biblioteca',
//     this.onManualSelected,
//     this.userGroups = const <String>{'default'},
//     this.publicApiBaseUrl,
//   });

//   final String rootLabel;
//   final String? language;
//   final OmniManualsSource? source;
//   final OmniLibraryCatalogSource? catalogSource;
//   final String title;
//   final String? subtitle;
//   final bool showHeader;
//   final bool navigateOnManualTap;
//   final OmniManualsThemeData theme;
//   final Widget? headerIcon;
//   final Widget? manualFallbackIcon;
//   final OmniManualsLoadingBuilder? loadingBuilder;
//   final OmniManualsEmptyBuilder? emptyBuilder;
//   final OmniManualsErrorBuilder? errorBuilder;
//   final OmniManualIconBuilder? manualIconBuilder;
//   final OmniCollectionIconBuilder? collectionIconBuilder;
//   final OmniManualSelectedCallback? onManualSelected;
//   final Set<String> userGroups;
//   final Uri? publicApiBaseUrl;

//   @override
//   State<OmniManualsLibrary> createState() => _OmniManualsLibraryState();
// }

// class _OmniManualsLibraryState extends State<OmniManualsLibrary> {
//   late Future<List<OmniLibraryEntry>> _entries = _loadEntries();
//   final TextEditingController _searchController = TextEditingController();
//   final List<OmniCollectionEntry> _path = <OmniCollectionEntry>[];
//   StreamSubscription<OmniManualsEvent>? _eventsSubscription;
//   String _query = '';

//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       if (mounted) setState(() => _query = _searchController.text);
//     });
//     _eventsSubscription = OmniManuals.events.listen((event) {
//       if (event.type != OmniManualsEventType.libraryChanged || !mounted) {
//         return;
//       }
//       setState(() {
//         _entries = _loadEntries().then((entries) {
//           _preserveValidPath(entries);
//           return entries;
//         });
//       });
//     });
//   }

//   @override
//   void didUpdateWidget(covariant OmniManualsLibrary oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (!identical(oldWidget.source, widget.source) ||
//         !identical(oldWidget.catalogSource, widget.catalogSource) ||
//         oldWidget.userGroups != widget.userGroups ||
//         oldWidget.language != widget.language) {
//       _path.clear();
//       _entries = _loadEntries();
//     }
//   }

//   @override
//   void dispose() {
//     _eventsSubscription?.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }

//   Future<List<OmniLibraryEntry>> _loadEntries() async {
//     if (OmniManuals.state != OmniManualsState.ready) {
//       await OmniManuals.initialize(
//         config: OmniManualsConfig(
//           defaultLanguage: widget.language,
//           source: widget.source,
//           catalogSource: widget.catalogSource,
//           userGroups: widget.userGroups,
//           publicApiBaseUrl: widget.publicApiBaseUrl,
//         ),
//       );
//     }
//     return omniManualsController.resolveLibraryEntries(
//       catalogSource: widget.catalogSource,
//       language: widget.language,
//       userGroups: widget.userGroups,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: _path.isEmpty,
//       onPopInvokedWithResult: (didPop, result) {
//         if (!didPop && _path.isNotEmpty) {
//           setState(() => _path.removeLast());
//         }
//       },
//       child: FutureBuilder<List<OmniLibraryEntry>>(
//         future: _entries,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState != ConnectionState.done) {
//             return _loading(context);
//           }
//           if (snapshot.hasError) {
//             return _error(context, _exception(snapshot.error));
//           }

//           final rootEntries = snapshot.requireData;
//           final visibleEntries = _path.isEmpty
//               ? rootEntries
//               : _path.last.children;
//           final filteredEntries = _filterEntries(visibleEntries, _query);

//           if (rootEntries.isEmpty) {
//             return widget.emptyBuilder?.call(context) ??
//                 const Center(child: Text('No hay manuales disponibles.'));
//           }

//           return _LibrarySurface(
//             title: widget.title,
//             subtitle: widget.subtitle,
//             showHeader: widget.showHeader,
//             headerIcon: widget.headerIcon,
//             rootLabel: widget.rootLabel,
//             theme: widget.theme,
//             searchController: _searchController,
//             path: List<OmniCollectionEntry>.unmodifiable(_path),
//             entries: filteredEntries,
//             hasQuery: _query.trim().isNotEmpty,
//             manualFallbackIcon: widget.manualFallbackIcon,
//             manualIconBuilder: widget.manualIconBuilder,
//             collectionIconBuilder: widget.collectionIconBuilder,
//             onBreadcrumbSelected: (index) {
//               setState(() => _path.removeRange(index + 1, _path.length));
//             },
//             onCollectionSelected: (collection) {
//               setState(() => _path.add(collection));
//             },
//             onManualSelected: _selectManual,
//           );
//         },
//       ),
//     );
//   }

//   Widget _loading(BuildContext context) {
//     return widget.loadingBuilder?.call(context) ?? const _DefaultLoadingState();
//   }

//   Widget _error(BuildContext context, OmniManualsException error) {
//     return widget.errorBuilder?.call(context, error) ??
//         Center(child: Text(error.message, textAlign: TextAlign.center));
//   }

//   void _selectManual(OmniManualInfo manual) {
//     final customSelection = widget.onManualSelected;
//     if (customSelection != null) {
//       customSelection(context, manual);
//       return;
//     }
//     if (!widget.navigateOnManualTap) return;

//     Navigator.of(context).push(
//       MaterialPageRoute<void>(
//         builder: (_) => OmniManualViewerPage(
//           manual: manual,
//           language: widget.language,
//           loadingBuilder: widget.loadingBuilder,
//           errorBuilder: widget.errorBuilder,
//         ),
//       ),
//     );
//   }

//   List<OmniLibraryEntry> _filterEntries(
//     List<OmniLibraryEntry> entries,
//     String query,
//   ) {
//     final normalizedQuery = query.trim().toLowerCase();
//     if (normalizedQuery.isEmpty) return entries;
//     return entries
//         .where((entry) {
//           return _searchableEntryText(entry).contains(normalizedQuery);
//         })
//         .toList(growable: false);
//   }

//   String _searchableEntryText(OmniLibraryEntry entry) {
//     return switch (entry) {
//       OmniManualLibraryEntry(:final manual) => [
//         manual.id,
//         manual.title,
//         if (manual.subtitle != null) manual.subtitle!,
//         if (manual.version != null) manual.version!,
//         ...manual.languages,
//       ].join(' ').toLowerCase(),
//       OmniCollectionEntry(:final children) => [
//         entry.id,
//         entry.title,
//         if (entry.subtitle != null) entry.subtitle!,
//         for (final child in children) _searchableEntryText(child),
//       ].join(' ').toLowerCase(),
//     };
//   }

//   void _preserveValidPath(List<OmniLibraryEntry> rootEntries) {
//     if (_path.isEmpty) return;
//     var entries = rootEntries;
//     final nextPath = <OmniCollectionEntry>[];
//     for (final current in _path) {
//       final match = entries
//           .whereType<OmniCollectionEntry>()
//           .where((entry) => entry.id == current.id)
//           .firstOrNull;
//       if (match == null) break;
//       nextPath.add(match);
//       entries = match.children;
//     }
//     _path
//       ..clear()
//       ..addAll(nextPath);
//   }
// }

// class OmniLibrary extends StatelessWidget {
//   const OmniLibrary({
//     super.key,
//     this.language,
//     this.title = 'Omni Manuals',
//     this.introduction,
//     this.onManualSelected,
//     this.errorBuilder,
//     this.emptyBuilder,
//     this.manualFallbackIcon,
//     this.catalogSource,
//     this.userGroups = const <String>{'default'},
//     this.publicApiBaseUrl,
//   });

//   final String? language;
//   final String title;
//   final String? introduction;
//   final ValueChanged<OmniManualInfo>? onManualSelected;
//   final OmniManualsErrorBuilder? errorBuilder;
//   final WidgetBuilder? emptyBuilder;
//   final Widget? manualFallbackIcon;
//   final OmniLibraryCatalogSource? catalogSource;
//   final Set<String> userGroups;
//   final Uri? publicApiBaseUrl;

//   @override
//   Widget build(BuildContext context) {
//     return OmniManualsLibrary(
//       language: language,
//       catalogSource: catalogSource,
//       title: title,
//       subtitle: introduction,
//       navigateOnManualTap: onManualSelected == null,
//       onManualSelected: onManualSelected == null
//           ? null
//           : (context, manual) => onManualSelected!(manual),
//       errorBuilder: errorBuilder,
//       emptyBuilder: emptyBuilder,
//       manualFallbackIcon: manualFallbackIcon,
//       userGroups: userGroups,
//       publicApiBaseUrl: publicApiBaseUrl,
//     );
//   }
// }

// class _LibrarySurface extends StatelessWidget {
//   const _LibrarySurface({
//     required this.title,
//     required this.showHeader,
//     required this.theme,
//     required this.searchController,
//     required this.path,
//     required this.entries,
//     required this.hasQuery,
//     required this.onBreadcrumbSelected,
//     required this.onCollectionSelected,
//     required this.onManualSelected,
//     this.subtitle,
//     this.headerIcon,
//     this.manualFallbackIcon,
//     required this.rootLabel,
//     this.manualIconBuilder,
//     this.collectionIconBuilder,
//   });

//   final String rootLabel;
//   final String title;
//   final String? subtitle;
//   final bool showHeader;
//   final Widget? headerIcon;
//   final OmniManualsThemeData theme;
//   final TextEditingController searchController;
//   final List<OmniCollectionEntry> path;
//   final List<OmniLibraryEntry> entries;
//   final bool hasQuery;
//   final ValueChanged<int> onBreadcrumbSelected;
//   final ValueChanged<OmniCollectionEntry> onCollectionSelected;
//   final ValueChanged<OmniManualInfo> onManualSelected;
//   final Widget? manualFallbackIcon;
//   final OmniManualIconBuilder? manualIconBuilder;
//   final OmniCollectionIconBuilder? collectionIconBuilder;

//   @override
//   Widget build(BuildContext context) {
//     final materialTheme = Theme.of(context);
//     final colorScheme = materialTheme.colorScheme;
//     final backgroundColor = theme.backgroundColor ?? colorScheme.surface;
//     final foregroundColor = theme.foregroundColor ?? colorScheme.onSurface;
//     final accentColor = theme.accentColor ?? colorScheme.primary;

//     return Material(
//       type: MaterialType.transparency,
//       child: ColoredBox(
//         color: backgroundColor,
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             final wide = constraints.maxWidth >= 720;
//             final columns = constraints.maxWidth >= 1040
//                 ? 3
//                 : wide
//                 ? 2
//                 : 1;
//             final cards = [
//               for (final entry in entries)
//                 _LibraryEntryCard(
//                   entry: entry,
//                   theme: theme,
//                   foregroundColor: foregroundColor,
//                   accentColor: accentColor,
//                   manualFallbackIcon: manualFallbackIcon,
//                   manualIconBuilder: manualIconBuilder,
//                   collectionIconBuilder: collectionIconBuilder,
//                   onTap: () {
//                     switch (entry) {
//                       case OmniManualLibraryEntry(:final manual):
//                         onManualSelected(manual);
//                       case OmniCollectionEntry():
//                         onCollectionSelected(entry);
//                     }
//                   },
//                 ),
//             ];

//             return SingleChildScrollView(
//               padding:
//                   theme.padding ??
//                   EdgeInsets.symmetric(
//                     horizontal: wide ? 32 : 16,
//                     vertical: wide ? 32 : 20,
//                   ),
//               child: Center(
//                 child: ConstrainedBox(
//                   constraints: const BoxConstraints(maxWidth: 1120),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       if (showHeader)
//                         _LibraryHeader(
//                           title: title,
//                           subtitle: subtitle,
//                           icon: headerIcon,
//                           titleStyle: theme.titleStyle,
//                           subtitleStyle: theme.subtitleStyle,
//                           foregroundColor: foregroundColor,
//                           accentColor: accentColor,
//                         ),
//                       if (showHeader) const SizedBox(height: 20),
//                       if (path.isNotEmpty) ...[
//                         _Breadcrumbs(
//                           path: path,
//                           onSelected: onBreadcrumbSelected,
//                           rootLabel: rootLabel,
//                         ),
//                         const SizedBox(height: 12),
//                       ],
//                       TextField(
//                         controller: searchController,
//                         decoration: const InputDecoration(
//                           prefixIcon: Icon(Icons.search),
//                           labelText: 'Buscar manuales',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       if (entries.isEmpty)
//                         _EmptySearchState(hasQuery: hasQuery)
//                       else if (columns == 1)
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             for (
//                               var index = 0;
//                               index < cards.length;
//                               index += 1
//                             ) ...[
//                               if (index > 0) const SizedBox(height: 14),
//                               cards[index],
//                             ],
//                           ],
//                         )
//                       else
//                         GridView.builder(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           itemCount: cards.length,
//                           gridDelegate:
//                               SliverGridDelegateWithFixedCrossAxisCount(
//                                 crossAxisCount: columns,
//                                 crossAxisSpacing: 14,
//                                 mainAxisSpacing: 14,
//                                 childAspectRatio: wide ? 1.45 : 2.2,
//                               ),
//                           itemBuilder: (context, index) => cards[index],
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class _LibraryHeader extends StatelessWidget {
//   const _LibraryHeader({
//     required this.title,
//     required this.foregroundColor,
//     required this.accentColor,
//     this.subtitle,
//     this.icon,
//     this.titleStyle,
//     this.subtitleStyle,
//   });

//   final String title;
//   final String? subtitle;
//   final Widget? icon;
//   final TextStyle? titleStyle;
//   final TextStyle? subtitleStyle;
//   final Color foregroundColor;
//   final Color accentColor;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         icon ?? Icon(Icons.menu_book_outlined, color: accentColor, size: 36),
//         const SizedBox(width: 14),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style:
//                     titleStyle ??
//                     theme.textTheme.headlineMedium?.copyWith(
//                       color: foregroundColor,
//                     ),
//               ),
//               if (subtitle != null && subtitle!.isNotEmpty) ...[
//                 const SizedBox(height: 6),
//                 Text(
//                   subtitle!,
//                   style:
//                       subtitleStyle ??
//                       theme.textTheme.bodyLarge?.copyWith(
//                         color: foregroundColor.withValues(alpha: 0.72),
//                       ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _Breadcrumbs extends StatelessWidget {
//   const _Breadcrumbs({
//     required this.rootLabel,
//     required this.path,
//     required this.onSelected,
//   });

//   final String rootLabel;
//   final List<OmniCollectionEntry> path;
//   final ValueChanged<int> onSelected;

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       crossAxisAlignment: WrapCrossAlignment.center,
//       spacing: 4,
//       children: [
//         TextButton.icon(
//           onPressed: () => onSelected(-1),
//           icon: const Icon(Icons.home_outlined, size: 18),
//           label: Text(rootLabel),
//         ),
//         for (var index = 0; index < path.length; index += 1) ...[
//           const Icon(Icons.chevron_right, size: 18),
//           TextButton(
//             onPressed: index == path.length - 1
//                 ? null
//                 : () => onSelected(index),
//             child: Text(path[index].title),
//           ),
//         ],
//       ],
//     );
//   }
// }

// class _LibraryEntryCard extends StatelessWidget {
//   const _LibraryEntryCard({
//     required this.entry,
//     required this.theme,
//     required this.foregroundColor,
//     required this.accentColor,
//     required this.onTap,
//     this.manualFallbackIcon,
//     this.manualIconBuilder,
//     this.collectionIconBuilder,
//   });

//   final OmniLibraryEntry entry;
//   final OmniManualsThemeData theme;
//   final Color foregroundColor;
//   final Color accentColor;
//   final VoidCallback onTap;
//   final Widget? manualFallbackIcon;
//   final OmniManualIconBuilder? manualIconBuilder;
//   final OmniCollectionIconBuilder? collectionIconBuilder;

//   @override
//   Widget build(BuildContext context) {
//     final materialTheme = Theme.of(context);
//     final cardColor = theme.cardColor ?? materialTheme.colorScheme.surface;
//     final subtitle = entry.subtitle ?? entry.description;
//     final isCollection = entry is OmniCollectionEntry;

//     return Card(
//       clipBehavior: Clip.antiAlias,
//       color: cardColor,
//       child: InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.all(18),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   _EntryIcon(
//                     entry: entry,
//                     accentColor: accentColor,
//                     manualFallbackIcon: manualFallbackIcon,
//                     manualIconBuilder: manualIconBuilder,
//                     collectionIconBuilder: collectionIconBuilder,
//                   ),
//                   const Spacer(),
//                   Icon(
//                     isCollection ? Icons.chevron_right : Icons.arrow_forward,
//                     color: foregroundColor.withValues(alpha: 0.70),
//                     size: 20,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 entry.title,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 style:
//                     theme.cardTitleStyle ??
//                     materialTheme.textTheme.titleMedium?.copyWith(
//                       color: foregroundColor,
//                     ),
//               ),
//               if (subtitle != null && subtitle.isNotEmpty) ...[
//                 const SizedBox(height: 6),
//                 Text(
//                   subtitle,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style:
//                       theme.cardSubtitleStyle ??
//                       materialTheme.textTheme.bodyMedium?.copyWith(
//                         color: foregroundColor.withValues(alpha: 0.72),
//                       ),
//                 ),
//               ],
//               if (entry.badges.isNotEmpty) ...[
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 6,
//                   runSpacing: 6,
//                   children: [
//                     for (final badge in entry.badges)
//                       _ManualMetaChip(label: badge),
//                   ],
//                 ),
//               ],
//               if (entry case OmniManualLibraryEntry(:final manual)) ...[
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 6,
//                   runSpacing: 6,
//                   children: [
//                     if (manual.version != null)
//                       _ManualMetaChip(label: 'v${manual.version}'),
//                     for (final language in manual.languages.take(3))
//                       _ManualMetaChip(label: language.toUpperCase()),
//                   ],
//                 ),
//               ],
//               if (entry case OmniCollectionEntry(:final children)) ...[
//                 const SizedBox(height: 12),
//                 _ManualMetaChip(label: '${children.length} elementos'),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _EntryIcon extends StatelessWidget {
//   const _EntryIcon({
//     required this.entry,
//     required this.accentColor,
//     this.manualFallbackIcon,
//     this.manualIconBuilder,
//     this.collectionIconBuilder,
//   });

//   final OmniLibraryEntry entry;
//   final Color accentColor;
//   final Widget? manualFallbackIcon;
//   final OmniManualIconBuilder? manualIconBuilder;
//   final OmniCollectionIconBuilder? collectionIconBuilder;

//   @override
//   Widget build(BuildContext context) {
//     final custom = switch (entry) {
//       OmniManualLibraryEntry(:final manual) => manualIconBuilder?.call(
//         context,
//         manual,
//       ),
//       OmniCollectionEntry() => collectionIconBuilder?.call(
//         context,
//         entry as OmniCollectionEntry,
//       ),
//     };
//     if (custom != null) return custom;
//     if (entry is OmniManualLibraryEntry && manualFallbackIcon != null) {
//       return manualFallbackIcon!;
//     }

//     final iconData =
//         OmniMaterialIcons.iconData(entry.icon) ??
//         (entry is OmniCollectionEntry ? Icons.folder : Icons.menu_book);

//     return DecoratedBox(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(14),
//         color: accentColor.withValues(alpha: 0.12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Icon(iconData, color: accentColor),
//       ),
//     );
//   }
// }

// class _ManualMetaChip extends StatelessWidget {
//   const _ManualMetaChip({required this.label});

//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return DecoratedBox(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(999),
//         color: theme.colorScheme.secondaryContainer,
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//         child: Text(
//           label,
//           style: theme.textTheme.labelSmall?.copyWith(
//             color: theme.colorScheme.onSecondaryContainer,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _EmptySearchState extends StatelessWidget {
//   const _EmptySearchState({required this.hasQuery});

//   final bool hasQuery;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 48),
//         child: Text(
//           hasQuery
//               ? 'No hay manuales que coincidan con la búsqueda.'
//               : 'No hay manuales disponibles.',
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }
// }

// class OmniManualViewerPage extends StatefulWidget {
//   const OmniManualViewerPage({
//     super.key,
//     required this.manual,
//     this.language,
//     this.loadingBuilder,
//     this.errorBuilder,
//   });

//   final OmniManualInfo manual;
//   final String? language;
//   final OmniManualsLoadingBuilder? loadingBuilder;
//   final OmniManualsErrorBuilder? errorBuilder;

//   @override
//   State<OmniManualViewerPage> createState() => _OmniManualViewerPageState();
// }

// enum _ViewerState { initializing, loading, ready, error, closing, disposed }

// class _OmniManualViewerPageState extends State<OmniManualViewerPage> {
//   RuntimeBridge? _bridge;
//   _ViewerState _state = _ViewerState.initializing;
//   OmniManualsException? _error;
//   Future<void>? _activeAction;

//   bool get _ready =>
//       _state == _ViewerState.ready && _bridge != null && _activeAction == null;

//   @override
//   void initState() {
//     super.initState();
//     _state = _ViewerState.loading;
//   }

//   @override
//   void dispose() {
//     _bridge?.markClosing();
//     _state = _ViewerState.disposed;
//     super.dispose();
//   }

//   Future<bool> _close() async {
//     if (_state == _ViewerState.closing || _state == _ViewerState.disposed) {
//       return false;
//     }
//     setState(() {
//       _state = _ViewerState.closing;
//       _bridge?.markClosing();
//     });
//     return true;
//   }

//   Future<void> _runBridgeAction(
//     Future<RuntimeBridgeActionResult> Function(RuntimeBridge bridge) action,
//   ) async {
//     final bridge = _bridge;
//     if (!_ready || bridge == null) return;

//     late final Future<void> pending;

//     pending = () async {
//       try {
//         await action(bridge);
//       } catch (error) {
//         if (!mounted ||
//             _state == _ViewerState.closing ||
//             _state == _ViewerState.disposed) {
//           return;
//         }

//         final exception = _exception(error);

//         ScaffoldMessenger.maybeOf(
//           context,
//         )?.showSnackBar(SnackBar(content: Text(exception.message)));
//       } finally {
//         if (mounted &&
//             _state != _ViewerState.closing &&
//             _state != _ViewerState.disposed &&
//             identical(_activeAction, pending)) {
//           setState(() {
//             _activeAction = null;
//           });
//         }
//       }
//     }();

//     setState(() {
//       _activeAction = pending;
//     });

//     await pending;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final ready = _ready;
//     return PopScope(
//       canPop: true,
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//         unawaited(_close());
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: Text(widget.manual.title),
//           actions: [
//             IconButton(
//               tooltip: 'Buscar',
//               icon: const Icon(Icons.search),
//               onPressed: ready
//                   ? () => unawaited(
//                       _runBridgeAction((bridge) => bridge.openSearch()),
//                     )
//                   : null,
//             ),
//             IconButton(
//               tooltip: 'Índice',
//               icon: const Icon(Icons.format_list_bulleted),
//               onPressed: ready
//                   ? () => unawaited(
//                       _runBridgeAction(
//                         (bridge) => bridge.openTableOfContents(),
//                       ),
//                     )
//                   : null,
//             ),
//             _LanguageMenu(
//               languages: widget.manual.languages,
//               selectedLanguage: widget.language,
//               onSelected: ready
//                   ? (language) => unawaited(
//                       _runBridgeAction((bridge) => bridge.setLocale(language)),
//                     )
//                   : null,
//             ),
//           ],
//         ),
//         body: Stack(
//           children: [
//             OmniManual._embedded(
//               id: widget.manual.id,
//               language: widget.language,
//               onBridgeStateChanged: _handleBridgeState,
//               onBridgeReady: (bridge) {
//                 if (!mounted ||
//                     _state == _ViewerState.closing ||
//                     _state == _ViewerState.disposed) {
//                   return;
//                 }
//                 setState(() {
//                   _bridge = bridge;
//                   _state = _ViewerState.ready;
//                   _error = null;
//                 });
//               },
//               onBridgeError: (error) {
//                 if (!mounted ||
//                     _state == _ViewerState.closing ||
//                     _state == _ViewerState.disposed) {
//                   return;
//                 }
//                 setState(() {
//                   _state = _ViewerState.error;
//                   _error = error;
//                 });
//               },
//             ),
//             if (_state != _ViewerState.ready)
//               Positioned.fill(child: _viewerOverlay(context)),
//           ],
//         ),
//       ),
//     );
//   }

//   void _handleBridgeState(RuntimeBridgeState state) {
//     if (!mounted ||
//         _state == _ViewerState.closing ||
//         _state == _ViewerState.disposed) {
//       return;
//     }
//     if (state == RuntimeBridgeState.failed) {
//       setState(() {
//         _state = _ViewerState.error;
//         _error = const OmniManualsException(
//           code: OmniManualsErrorCode.webviewLoadFailed,
//           message: 'El runtime embebido no pudo completar la carga.',
//         );
//       });
//       return;
//     }
//     if (state == RuntimeBridgeState.loading && _state != _ViewerState.loading) {
//       setState(() => _state = _ViewerState.loading);
//     }
//   }

//   Widget _viewerOverlay(BuildContext context) {
//     if (_state == _ViewerState.error && _error != null) {
//       return ColoredBox(
//         color: Theme.of(context).colorScheme.surface,
//         child:
//             widget.errorBuilder?.call(context, _error!) ??
//             Center(child: Text(_error!.message, textAlign: TextAlign.center)),
//       );
//     }

//     return ColoredBox(
//       color: Theme.of(context).colorScheme.surface,
//       child:
//           widget.loadingBuilder?.call(context) ?? const _DefaultLoadingState(),
//     );
//   }
// }

// class OmniManual extends StatefulWidget {
//   const OmniManual({
//     super.key,
//     required this.id,
//     this.language,
//     this.initialSectionId,
//     this.errorBuilder,
//     this.onRouteChanged,
//   }) : _embedded = false,
//        onBridgeReady = null,
//        onBridgeStateChanged = null,
//        onBridgeError = null;

//   const OmniManual._embedded({
//     required this.id,
//     this.language,
//     required this.onBridgeReady,
//     required this.onBridgeStateChanged,
//     required this.onBridgeError,
//   }) : _embedded = true,
//        initialSectionId = null,
//        errorBuilder = null,
//        onRouteChanged = null,
//        super();

//   final String id;
//   final String? language;
//   final bool _embedded;
//   final String? initialSectionId;
//   final OmniManualsErrorBuilder? errorBuilder;
//   final ValueChanged<Uri>? onRouteChanged;
//   final ValueChanged<RuntimeBridge>? onBridgeReady;
//   final ValueChanged<RuntimeBridgeState>? onBridgeStateChanged;
//   final ValueChanged<OmniManualsException>? onBridgeError;

//   @override
//   State<OmniManual> createState() => _OmniManualState();
// }

// class _OmniManualState extends State<OmniManual> {
//   late final Future<WebViewController> _controller = _createController();
//   RuntimeBridge? _bridge;
//   WebViewController? _controllerInstance;
//   bool _reportedReady = false;
//   bool _closing = false;

//   Future<WebViewController> _createController() async {
//     try {
//       final uri = await omniManualsController.manualUri(
//         id: widget.id,
//         language: widget.language,
//         embedded: widget._embedded,
//       );
//       if (!mounted || _closing) {
//         throw StateError(
//           'OmniManual disposed before WebView creation completed',
//         );
//       }
//       final target = widget.initialSectionId == null
//           ? uri
//           : uri.replace(fragment: widget.initialSectionId);
//       widget.onRouteChanged?.call(target);
//       final controller = WebViewController()
//         ..setJavaScriptMode(JavaScriptMode.unrestricted)
//         ..setBackgroundColor(const Color(0xffffffff));
//       _controllerInstance = controller;
//       final bridge = RuntimeBridge(controller);
//       _bridge = bridge;
//       widget.onBridgeStateChanged?.call(RuntimeBridgeState.loading);
//       controller
//         ..addJavaScriptChannel(
//           'OmniManualBridge',
//           onMessageReceived: (message) {
//             if (!mounted || _closing || bridge.isDisposed) {
//               return;
//             }

//             final state = bridge.handleMessage(message.message);

//             if (state == null) {
//               return;
//             }

//             widget.onBridgeStateChanged?.call(state);

//             if (state == RuntimeBridgeState.ready && !_reportedReady) {
//               _reportedReady = true;
//               widget.onBridgeReady?.call(bridge);
//             }
//           },
//         )
//         ..setNavigationDelegate(
//           NavigationDelegate(
//             onWebResourceError: (error) {
//               if (!mounted || _closing) return;
//               widget.onBridgeError?.call(
//                 OmniManualsException(
//                   code: OmniManualsErrorCode.webviewLoadFailed,
//                   message: 'No se pudo cargar el runtime embebido.',
//                   context: error.description,
//                 ),
//               );
//             },
//           ),
//         )
//         ..loadRequest(target);
//       return controller;
//     } catch (error) {
//       final exception = _exception(error);
//       widget.onBridgeError?.call(exception);
//       throw exception;
//     }
//   }

//   @override
//   void dispose() {
//     _closing = true;
//     final controller = _controllerInstance;
//     if (controller != null) {
//       unawaited(
//         controller.removeJavaScriptChannel('OmniManualBridge').catchError((
//           Object error,
//         ) {
//           debugPrint(
//             '[OmniManuals] ignored WebView cleanup error after dispose: $error',
//           );
//         }),
//       );
//     }
//     _bridge?.markClosing();
//     _bridge?.dispose();
//     _bridge = null;
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<WebViewController>(
//       future: _controller,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState != ConnectionState.done) {
//           return const _DefaultLoadingState();
//         }
//         if (snapshot.hasError) {
//           final error = _exception(snapshot.error);
//           return widget.errorBuilder?.call(context, error) ??
//               Center(child: Text(error.message, textAlign: TextAlign.center));
//         }
//         return WebViewWidget(controller: snapshot.requireData);
//       },
//     );
//   }
// }

// class _LanguageMenu extends StatelessWidget {
//   const _LanguageMenu({
//     required this.languages,
//     required this.selectedLanguage,
//     required this.onSelected,
//   });

//   final List<String> languages;
//   final String? selectedLanguage;
//   final ValueChanged<String>? onSelected;

//   @override
//   Widget build(BuildContext context) {
//     if (languages.isEmpty) return const SizedBox.shrink();
//     return PopupMenuButton<String>(
//       tooltip: 'Idioma',
//       icon: const Icon(Icons.translate),
//       initialValue: selectedLanguage,
//       enabled: onSelected != null,
//       onSelected: onSelected,
//       itemBuilder: (context) => [
//         for (final language in languages)
//           PopupMenuItem<String>(
//             value: language,
//             child: Text(language.toUpperCase()),
//           ),
//       ],
//     );
//   }
// }

// class _DefaultLoadingState extends StatelessWidget {
//   const _DefaultLoadingState();

//   @override
//   Widget build(BuildContext context) {
//     return Semantics(
//       label: 'Cargando manual',
//       liveRegion: true,
//       child: const Center(child: CircularProgressIndicator()),
//     );
//   }
// }

// OmniManualsException _exception(Object? error) {
//   if (error is OmniManualsException) return error;
//   return OmniManualsException(
//     code: OmniManualsErrorCode.initializationFailed,
//     message: 'No se pudo cargar Omni Manuals.',
//     cause: error,
//   );
// }
export 'widgets/customization.dart';
export 'widgets/library.dart';
export 'widgets/viewer.dart';
