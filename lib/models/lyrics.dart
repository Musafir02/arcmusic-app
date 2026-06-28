class LyricsResult {
  final String? syncedLrc;
  final String? plainText;

  LyricsResult({this.syncedLrc, this.plainText});

  bool get isEmpty => syncedLrc == null && plainText == null;
  bool get hasSynced => syncedLrc != null && syncedLrc!.isNotEmpty;
}

class LrcLine {
  final Duration timestamp;
  final String text;
  LrcLine(this.timestamp, this.text);
}

List<LrcLine> parseLrc(String lrc) {
  final lines = <LrcLine>[];
  final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d+))?\]\s*(.*)');

  for (final line in lrc.split('\n')) {
    final match = regex.firstMatch(line.trim());
    if (match != null) {
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final msStr = match.group(3);
      int ms = 0;
      if (msStr != null) {
        if (msStr.length == 1) {
          ms = int.parse(msStr) * 100;
        } else if (msStr.length == 2) {
          ms = int.parse(msStr) * 10;
        } else {
          ms = int.parse(msStr.substring(0, 3));
        }
      }
      final text = match.group(4)?.trim() ?? '';
      if (text.isNotEmpty) {
        lines.add(LrcLine(
          Duration(minutes: min, seconds: sec, milliseconds: ms),
          text,
        ));
      }
    }
  }

  lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return lines;
}
