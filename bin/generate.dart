import 'dart:io';

import 'package:omni_manuals/src/internal/registry_generator.dart';

void main(List<String> arguments) {
  RegistryGeneratorOptions options;

  try {
    options = RegistryGeneratorOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln();
    stderr.writeln(RegistryGeneratorOptions.usage);
    exitCode = 64;
    return;
  }

  if (options.help) {
    stdout.writeln(RegistryGeneratorOptions.usage);
    return;
  }

  try {
    final result = generateRegistry(options);

    stdout
      ..writeln('Omni Manuals preparado correctamente.')
      ..writeln('Manuales detectados: ${result.manualCount}')
      ..writeln('Colecciones detectadas: ${result.collectionCount}')
      ..writeln('Registro Dart: ${result.registryOutput}')
      ..writeln('Pubspec actualizado: ${result.pubspecPath}')
      ..writeln('Directorios de assets: ${result.assetDirectoryCount}');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(
      error.path == null ? error.message : '${error.message}: ${error.path}',
    );
    exitCode = 66;
  }
}
