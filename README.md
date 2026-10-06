# Omni Manuals Flutter SDK

Status: initial SDK baseline.

This package exposes the supported Flutter integration surface for Omni Manuals:

- `OmniManuals.initialize` for SDK startup.
- `OmniManualsSource` for static/generated catalog data.
- `OmniManualsLibrary` for embedding a manual library inside host-owned UI.
- `OmniManualViewerPage` for the SDK-owned manual viewer route.
- `OmniManualsPage` for a simple page wrapper around the embeddable library.
- `OmniLibrary` and `OmniManual` as compatibility/lower-level integrations.
- `OmniLibraryCatalogSource` for server-controlled library organization.
- `dart run omni_manuals:generate` for generating a static registry provider from local manual assets.
- `HttpSource`, `ZipSource`, `DirectorySource` and `CachedSource` for
  backend-neutral distributed manuals.
- Dynamic remote catalogs so the app can discover manuals published after the
  Flutter binary was built.

The consumer application owns its Flutter shell. `OmniManualsLibrary` does not
create a `Scaffold` or `AppBar`; by default it pushes `OmniManualViewerPage`
when a manual is selected. Hosts that pass `onManualSelected` take over
navigation completely. Manuals render inside the canonical web runtime in
embedded mode, so Flutter consumers do not show or manage runtime HTML/JS/CSS.

## Minimal setup

```yaml
dependencies:
  omni_manuals:
    path: ../../packages/omni_manuals
```

Consumer apps declare manuals only under `assets/manuals/<manualId>/`. The
generator keeps the `flutter.assets` block synchronized:

```bash
dart run omni_manuals:generate
```

## Embedded runtime maintenance

The source of truth for the HTML/JS/CSS runtime is `framework/runtime/`. The
Flutter package embeds an exact synchronized copy in
`packages/omni_manuals/assets/runtime/`; consumer apps must never declare or
copy runtime or library assets.

Synchronize after runtime changes:

```bash
python3 scripts/sync_omni_manuals_runtime.py
```

CI/regression checks should use:

```bash
python3 scripts/sync_omni_manuals_runtime.py --check
diff -qr framework/runtime packages/omni_manuals/assets/runtime
```

Do not edit files under `packages/omni_manuals/assets/runtime/` by hand. Apply
runtime changes in `framework/runtime/` and synchronize with the script above.

```dart
await OmniManuals.initialize(
  config: OmniManualsConfig(
    defaultLanguage: 'es',
    source: GeneratedOmniManualsSource(),
    catalogSource: GeneratedOmniManualsCatalogSource(),
    userGroups: {'default'},
    publicApiBaseUrl: Uri.parse('https://manuals.example.com'),
  ),
);
```

Then render:

```dart
Scaffold(
  appBar: AppBar(title: const Text('Manuals')),
  body: const OmniManualsLibrary(language: 'es'),
)
```

For a complete default page, use `const OmniManualsPage()`. For advanced
integrations, compose `OmniManualsLibrary`, `OmniManualViewerPage` and
`OmniManual` directly.
See `../../examples/omni_library` for a small app using the public SDK API.

## Library customization

`OmniManualsLibrary` supports host-owned title, subtitle, theme, icons and
loading/error/empty builders:

```dart
OmniManualsLibrary(
  title: 'Technical library',
  subtitle: 'Embedded inside the host app shell.',
  theme: const OmniManualsThemeData(padding: EdgeInsets.all(20)),
  manualFallbackIcon: const Icon(Icons.article_outlined),
  loadingBuilder: (context) => const Center(
    child: CircularProgressIndicator(),
  ),
  onManualSelected: (context, manual) {
    // Optional: if provided, the SDK does not push its default viewer route.
  },
)
```

Library Catalog entries can also declare an `icon` field. Its value is the
official Material icon name, not an asset path:

```json
{ "type": "collection", "id": "setup", "icon": "settings" }
```

The SDK resolves supported names through `OmniMaterialIcons`. Legacy admin IDs
such as `controllers` are normalized for compatibility, but new catalogs should
store only canonical Material names such as `folder`, `menu_book`, `warning` or
`memory`.

The viewer keeps AppBar actions disabled until the runtime bridge reports
`ready`. Bridge actions use a deterministic JSON result contract and do not
depend on implicit JavaScript return values.

Runtime-originated events are re-emitted through `OmniManuals.events`. Since
`0.2.0`, native assessment blocks emit
`OmniManualsEventType.assessmentSubmitted` with a typed
`OmniAssessmentResult`. The result includes `manualId`, `testId`, attempt
metadata, score, passing score, passed state, remaining attempts, gate status
and `answers` as `questionId -> selectedOptionIds[]`. The SDK does not calculate
scores; the canonical runtime owns scoring and navigation gates.

`publicApiBaseUrl` is optional. Set it only when manuals contain runtime-backed
media such as API-streamed SharePoint videos. The embedded runtime uses it to
resolve relative endpoints like `/api/v1/videos/stream?name=demo.mp4`; manuals
must never contain SharePoint URLs, cookies, bearer tokens or other credentials.

## Library Catalog

The registry answers which manuals physically exist. The Library Catalog answers
how those manuals are organized and presented. Static apps may add an optional
generation-only file:

```text
assets/
  library_catalog.json
  manuals/
    manual_a/
    manual_b/
```

Example:

```json
{
  "schemaVersion": 1,
  "catalogVersion": "2026-07-20",
  "defaultLanguage": "es",
  "entries": [
    {
      "type": "collection",
      "id": "setup",
      "title": {
        "es": "Puesta en marcha",
        "en": "Setup"
      },
      "groups": ["default"],
      "children": [
        {
          "type": "collection",
          "id": "advanced",
          "title": {
            "es": "Avanzado",
            "en": "Advanced"
          },
          "children": [
            {
              "type": "manual",
              "manualId": "manual_b"
            }
          ]
        }
      ]
    }
  ]
}
```

Manual entries reference content only by `manualId`. Groups control who can see
an entry. Download policy belongs to the host application and is derived from
`OmniUpdateSummary`, not from the library catalog.

Omni Studio's **Biblioteca / Library** workspace edits the framework catalog used
by the web runtime. It does not change the Flutter SDK identity model: generated
SDK catalogs still reference manuals by `manualId`, and consumer apps still ship
only manuals under `assets/manuals/<manualId>/`.

Run `dart run omni_manuals:generate` after editing manuals or the catalog. The
generator emits:

- `GeneratedOmniManualsSource`: physical manual registry and assets;
- `GeneratedOmniManualsCatalogSource`: bundled Library Catalog fallback.

The web runtime never reads `library_catalog.json`. Manuals not assigned to any
catalog entry remain visible at the root after declared collections.

Validation rules:

- every referenced manual ID must exist;
- a manual may be assigned to at most one declared collection;
- collection IDs must be unique;
- nested collections are declared inline under `children`, so reference cycles
  are not representable in the local static format.

`collections.json` from early SDK iterations is still accepted by the generator
as a migration input and converted to a generated Library Catalog. New projects
should use `library_catalog.json`.

## Remote Library Catalog

Server-controlled organization is configured independently from manual content:

```dart
OmniManualsLibrary(
  source: const GeneratedOmniManualsSource(),
  catalogSource: OmniFallbackCatalogSource([
    OmniCachedCatalogSource(
      remote: OmniRemoteCatalogSource(
        endpoint: Uri.parse('https://example.com/api/v1/manuals/catalog'),
      ),
    ),
    const GeneratedOmniManualsCatalogSource(),
  ]),
  language: 'es',
  userGroups: const {'default'},
)
```

Recommended resolution order:

1. valid remote catalog;
2. cached remote catalog;
3. bundled/generated catalog;
4. flat library generated from the registry.

The library never becomes empty solely because a remote catalog is unavailable
or corrupt.

Architectural ownership is fixed:

- runtime HTML/JS/CSS: package assets;
- manuals: consumer assets under `assets/manuals/`;
- Library Catalog: generation-time or remote organization metadata;
- remote Library Catalog: server JSON, independent from manual content;
- viewer page and runtime AppBar: package;
- library `Scaffold`/outer AppBar: consumer app.

## Architecture Frozen

The SDK architecture is stabilized for the Release Candidate baseline:

- `OmniManualsSource` owns the Manual Registry: the manuals physically bundled,
  cached or installed.
- `OmniLibraryCatalogSource` owns the Library Catalog: organization, localized
  presentation, groups, visibility and editorial metadata.
- Manual content remains inside each manual package and is rendered only by the
  embedded runtime.

This separation is now frozen for `packages/omni_manuals` and `api_ota`.
Further product work should continue in `editor/` and `framework/` without
reintroducing runtime or library assets into consumer Flutter applications.

## Distributed manuals

Remote distribution is explicit. SDK initialization and `loadManuals()` are
local-only: they read bundled manuals and/or the installed cache, but they never
fetch manifests, download ZIPs, install packages or remove content.

Use a cached remote source when the application wants host-controlled updates:

```dart
await OmniManuals.initialize(
  config: OmniManualsConfig(
    source: CachedSource(
      upstream: HttpSource(endpoint: Uri.parse('https://example.com/manuals/')),
    ),
  ),
);
```

After the first frame, the host may check availability and decide its own UI
policy:

```dart
final summary = await OmniManuals.checkForUpdates();
if (summary.hasChanges) {
  // Show a banner, dialog, settings screen action or silent badge.
  await OmniManuals.synchronizeManuals(
    summary.downloadable.map((entry) => entry.manualId).toSet(),
  );
}
```

`OmniManuals.synchronizeAllAvailable()` is a convenience for host applications
that intentionally want every visible new/update package. It is still explicit:
the SDK never calls it from initialization or manual listing.

`OmniManuals.cancelSynchronization()` requests cancellation of the active
download/validation/extraction flow. Progress is reported through
`OmniManualsConfig.onSyncProgress`.

For apps that ship a bundled baseline and also allow updates, compose sources:

```dart
source: OmniCompositeSource(
  bundled: const GeneratedOmniManualsSource(),
  cached: CachedSource(
    upstream: HttpSource(endpoint: Uri.parse('https://example.com/manuals/')),
  ),
)
```

The composite source is local-only. It merges bundled and cached registries,
deduplicates by manual ID and lets the cached copy win only when its semantic
version is equal or newer. Assets are loaded from the winning source.

See `doc/distribution.md` for the manifest format, ZIP layout, OTA flow and
cache/security decisions.

## Dynamic remote catalog

The SDK separates:

- library catalog: organization, titles, groups and visibility;
- manifest: package versions, hashes, sizes and download URLs;
- registry: locally installed packages.

The application decides whether a new package is mandatory, deferred,
forbidden on metered networks, or controlled from a settings screen.

Visible manuals appear in `OmniLibrary` according to catalog groups and local
installation state. They can be installed on demand through the built-in page
actions or:

```dart
await OmniManuals.installManual('11111111-1111-4111-8111-111111111111');
```

Installed manuals remain available offline through the local registry and cached
content. Content that disappears from the remote manifest is not deleted during
update checks; call `reconcileInstalledContent(removeUnavailable: true)` on a
`CachedSource` only from an explicit host-owned cleanup action.
# Localized OTA catalog presentation

`language` selects presentation only; manual IDs and access groups never change.
Use `Localizations.localeOf(context).toLanguageTag()` to preserve a regional
locale such as `en-US`; `languageCode` deliberately passes only the base language.
Localized title, subtitle, description and badge labels resolve requested locale,
its base language, catalog/manual `defaultLanguage` (and its base), English, then
the first non-empty translation in sorted language-code order. Missing optional
text remains empty. A single-language catalog needs no additional translations.
Manual cards without catalog overrides resolve package metadata from the source
assets for the requested language; generated registry titles remain a fallback
for metadata-only sources. Studio `titleKey` documents are a separate format.

The API ETag hashes the complete catalog file. Translation additions, edits,
deletions, entry `groups` changes and presentation metadata changes invalidate it
without changing manual package versions. On a `200`, the SDK compares parsed,
canonical catalog content, so identical content does not report `catalogChanged`.
`304` means unchanged; checks do not apply updates. Refresh saves the validated
catalog and HTTP validators locally. `catalogVersion` is not the only change signal.

Admin group title/description metadata is stored separately and is not delivered
to Flutter/runtime. Clients receive group IDs for visibility filtering, not group
display names. Editing those Admin-only labels does not update manual packages.
