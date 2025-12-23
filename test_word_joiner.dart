// Test for improved dynamic TextWordJoiner
import 'lib/services/text_word_joiner.dart';

void main() {
  print('🧪 Dynamic TextWordJoiner Test Suite\n');
  
  // Test 1: Split words (common suffix)
  testCase(
    'Split word with common suffix',
    'The rainy seas on comes in June',
    'The rainy season comes in June'
  );

  // Test 2: Split words (common suffix)
  testCase(
    'Split word with -tion suffix',
    'Gravitati on is a force',
    'Gravitation is a force'
  );

  // Test 3: Merged words (case transition)
  testCase(
    'Merged words with case transition',
    'earthThe object attracts',
    'earth The object attracts'
  );

  // Test 4: Repeating characters
  testCase(
    'Repeating characters',
    'GGGGRAVITATION and MMMMOTION',
    'GRAVITATION and MOTION'
  );

  // Test 5: Multiple split words
  testCase(
    'Multiple split words',
    'In dia is generally suited for agri culture production',
    'India is generally suited for agriculture production'
  );

  // Test 6: Number boundaries
  testCase(
    'Number boundaries',
    '9.1.2IMPORTANCE of farming',
    '9.1.2 IMPORTANCE of farming'
  );

  // Test 7: Mixed issues
  testCase(
    'Mixed split and merged words',
    'followingchemical reacti ons occur in soil',
    'following chemical reactions occur in soil'
  );

  // Test 8: List markers
  testCase(
    'List marker spacing',
    '(i)Text should have spacing',
    '(i) Text should have spacing'
  );

  // Test 9: Complex case - real world scenario
  testCase(
    'Complex real-world scenario',
    'The agriculti on sector requires underst anding of soil fertility and proper irrig ation techniques',
    'The agriculture sector requires understanding of soil fertility and proper irrigation techniques'
  );

  // Test 10: Preserve short words
  testCase(
    'Short words should not be modified',
    'in a of to at is',
    'in a of to at is'
  );
}

void testCase(String description, String input, String expected) {
  final output = TextWordJoiner.fixSplitWords(input);
  final passed = output.trim() == expected.trim();
  
  print('${passed ? '✅' : '❌'} $description');
  if (!passed) {
    print('   Input:    $input');
    print('   Expected: $expected');
    print('   Got:      $output');
  }
  print('');
}
