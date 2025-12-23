// Simple test for TextWordJoiner
import 'lib/services/text_word_joiner.dart';

void main() {
  // Test case from screenshot
  final input = 'In dia is generally from June to September';
  final output = TextWordJoiner.fixSplitWords(input);

  print('Input:  $input');
  print('Output: $output');
  print('');

  final input2 = 'call ed kharif crops';
  final output2 = TextWordJoiner.fixSplitWords(input2);

  print('Input:  $input2');
  print('Output: $output2');
  print('');

  final input3 = 'The rainy seas on';
  final output3 = TextWordJoiner.fixSplitWords(input3);

  print('Input:  $input3');
  print('Output: $output3');
}
