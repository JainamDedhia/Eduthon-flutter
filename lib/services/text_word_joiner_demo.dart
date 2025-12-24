// FILE: lib/services/text_word_joiner_demo.dart
import 'text_word_joiner.dart';

void main() {
  print('=== TextWordJoiner High-Impact Repair Demo ===\n');

  final inputs = [
    "9 GGGGGRAVITATIONRAVITATIONRAVITATION Chapter 10",
    "the for ce ceacting vertically do wnwards.",
    "for a given for ce,accelerati on is in versely proportional",
    "force of at tracti on of the earth .",
    "universally graviti on successfully explained",
    "stone flies of falong a straight line.",
    "fix a poster on abullet in board",
    "We have learntth at a force is needed",
    "moti on of objects under the in fluence",
    "Thissystem is more usefulon uneven land",
  ];

  for (var input in inputs) {
    String output = TextWordJoiner.fixSplitWords(input);
    bool changed = input != output;
    print("IN : $input");
    print("OUT: $output");
    print("Status: ${changed ? 'FIXED ✅' : 'CLEAN 🆗'}");
    print("-" * 20);
  }
}
