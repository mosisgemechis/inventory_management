import 'dart:io';

void main() {
  final file = File('lib/features/admin/admin_dashboard_screen.dart');
  final content = file.readAsStringSync();
  final lines = content.split('\n');

  // Lines 5059-5061 (0-indexed: 5058-5060) are the broken wrapper.
  // L5059: '              ListTile('           <- orphan wrapper, DELETE
  // L5060: '                const Divider(height: 1),'  <- invalid child, DELETE
  // L5061: '                ListTile('         <- real Factory Reset tile, KEEP but de-indent

  // We also need to find the matching closing '),' for the outer ListTile
  // that was originally supposed to wrap the now-deleted Database Backup.
  // The outer ListTile starts at index 5058 (L5059). We need to find its
  // closing brace. Looking at the structure, the real Factory Reset ListTile
  // itself ends somewhere below. The outer ListTile's closing '),' will be
  // immediately after the real Factory Reset ListTile's closing ),
  // Let's scan for the nesting depth to find where the outer ) is.

  // Strategy:
  // 1. Remove lines 5058 and 5059 (L5059, L5060) — orphan wrapper + invalid child
  // 2. De-indent line 5060 (L5061) from '                ListTile(' to '              ListTile('
  // 3. De-indent all subsequent lines of the Factory Reset tile by 2 spaces until
  //    we hit the closing '),' of the outer wrapper and remove that too.

  // Find the outer ListTile closing. We track depth starting from line 5058.
  int depth = 0;
  int outerCloseIdx = -1;
  for (int i = 5058; i < lines.length; i++) {
    final line = lines[i].replaceAll('\r', '');
    depth += '('.allMatches(line).length;
    depth -= ')'.allMatches(line).length;
    if (depth <= 0 && i > 5058) {
      outerCloseIdx = i;
      break;
    }
  }

  if (outerCloseIdx == -1) {
    print('Could not find outer closing brace!');
    return;
  }

  print('Outer ListTile closes at line ${outerCloseIdx + 1}: ${lines[outerCloseIdx].replaceAll('\r', '')}');

  // New approach: build new lines list
  final result = <String>[];
  for (int i = 0; i < lines.length; i++) {
    if (i == 5058) {
      // Skip orphan 'ListTile(' wrapper (L5059)
      continue;
    }
    if (i == 5059) {
      // Skip orphan '  const Divider(height: 1),' (L5060)
      continue;
    }
    if (i == 5060) {
      // L5061: '                ListTile(' → de-indent by 2 spaces to '              ListTile('
      final line = lines[i].replaceAll('\r', '');
      result.add(line.replaceFirst('                ListTile(', '              ListTile('));
      continue;
    }
    if (i > 5060 && i < outerCloseIdx) {
      // De-indent inner Factory Reset tile content by 2 spaces
      final line = lines[i].replaceAll('\r', '');
      if (line.startsWith('                  ')) {
        result.add(line.replaceFirst('                  ', '                '));
      } else if (line.startsWith('                ')) {
        result.add(line.replaceFirst('                ', '              '));
      } else {
        result.add(lines[i]);
      }
      continue;
    }
    if (i == outerCloseIdx) {
      // This is the outer ListTile closing '),' — skip it (it belonged to the orphan)
      print('Removing outer close at L${i+1}: ${lines[i].replaceAll('\r', '')}');
      continue;
    }
    result.add(lines[i]);
  }

  file.writeAsStringSync(result.join('\n'));
  print('Fixed! Total lines: ${result.length} (was ${lines.length})');
}
