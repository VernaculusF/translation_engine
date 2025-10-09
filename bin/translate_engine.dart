#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'commands/db_command.dart';
import 'commands/import_command.dart';
import 'commands/base_command.dart';

void printUsage() {
  print('Translation Engine CLI');
  print('');
  print('Usage:');
  print('  dart run bin/translate_engine.dart <command> [options]');
  print('  dart translate_engine <command> [options]  (if activated globally)');
  print('');
  print('Available commands:');
  print('  db       Download and manage dictionary databases');
  print('  import   Import dictionary data from files');
  print('  help     Show this help message');
  print('');
  print('Use "dart run bin/translate_engine.dart <command> --help" for command-specific help.');
}

Future<int> main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    return 0;
  }
  
  final command = args[0];
  final commandArgs = args.skip(1).toList();
  
  // Check for global help flags only if no valid command
  if ((command == '--help' || command == '-h' || command == 'help') && commandArgs.isEmpty) {
    printUsage();
    return 0;
  }

  BaseCommand? commandInstance;

  switch (command) {
    case 'db':
      commandInstance = DbCommand();
      break;
    case 'import':
      commandInstance = ImportCommand();
      break;
    case 'help':
      printUsage();
      return 0;
    default:
      print('Unknown command: $command');
      print('');
      printUsage();
      return 64; // EX_USAGE
  }

  try {
    return await commandInstance.run(commandArgs);
  } catch (e) {
    print('Error: $e');
    return 1;
  }
}