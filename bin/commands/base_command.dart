// ignore_for_file: avoid_print

abstract class BaseCommand {
  /// The name of this command
  String get name;
  
  /// A brief description of what this command does
  String get description;
  
  /// Print usage information for this command
  void printUsage();
  
  /// Run the command with the given arguments
  /// Returns exit code (0 for success, non-zero for error)
  Future<int> run(List<String> args);
  
  /// Parse command line arguments into a map
  Map<String, String> parseArgs(List<String> args) {
    final params = <String, String>{};
    final flags = <String>{};
    
    for (final arg in args) {
      if (arg.startsWith('--')) {
        final idx = arg.indexOf('=');
        if (idx > 0) {
          // --key=value format
          final key = arg.substring(2, idx);
          final value = arg.substring(idx + 1);
          params[key] = value;
        } else {
          // --flag format
          final flag = arg.substring(2);
          flags.add(flag);
          params[flag] = 'true';
        }
      } else if (arg.startsWith('-') && arg.length == 2) {
        // -f format (single character flags)
        final flag = arg.substring(1);
        flags.add(flag);
        params[flag] = 'true';
      }
    }
    
    return params;
  }
  
  /// Check if required parameters are present
  bool validateRequiredParams(Map<String, String> params, List<String> required) {
    for (final param in required) {
      if (!params.containsKey(param) || params[param]?.isEmpty == true) {
        print('Error: Missing required parameter: --$param');
        return false;
      }
    }
    return true;
  }
}