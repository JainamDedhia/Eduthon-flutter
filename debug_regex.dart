void main() {
  final text = "The rainy seas on comes in June";
  final pattern = RegExp(r'\b([a-z]+)\s+([a-z]+)\b', multiLine: true);
  
  print('Text: $text');
  print('Pattern: ${pattern.pattern}');
  print('');
  
  final matches = pattern.allMatches(text);
  print('Matches found: ${matches.length}');
  
  for (var match in matches) {
    print('Match: "${match.group(0)}" -> part1="${match.group(1)}" part2="${match.group(2)}"');
  }
}
