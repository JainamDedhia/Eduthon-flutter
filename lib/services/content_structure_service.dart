// FILE: lib/services/content_structure_service.dart
import 'dart:math';

class ContentStructureService {
  // Organize raw summary into structured educational content
  static Map<String, dynamic> structureContent(
    String rawSummary,
    String subject, {
    List<String>? activities,
    List<String>? visualAidSuggestions,
  }) {
    // 1. Identify key sections
    final sentences = rawSummary.split(RegExp(r'(?<=[.!?])\s+'));

    // Group sentences into logical sections
    final sections = <Map<String, String>>[];

    if (sentences.length < 5) {
      sections.add({'title': 'Overview', 'content': rawSummary});
    } else {
      // Create Introduction
      sections.add({
        'title': 'Introduction',
        'content': sentences.take(2).join(' '),
      });

      // Create Core Concepts (Middle chunk)
      final middleCount = sentences.length - 4;
      if (middleCount > 0) {
        sections.add({
          'title': 'Key Concepts',
          'content': sentences.skip(2).take(middleCount).join(' '),
        });
      }

      // Create Conclusion (Last 2)
      sections.add({
        'title': 'Summary',
        'content': sentences.skip(max(0, sentences.length - 2)).join(' '),
      });
    }

    return {
      'subject': subject,
      'sections': sections,
      'learningObjectives': _extractLearningObjectives(rawSummary),
      'activities': activities ?? [],
      'visualAids':
          visualAidSuggestions ?? _generateVisualAidSuggestions(rawSummary),
    };
  }

  // Extract potential learning objectives
  static List<String> _extractLearningObjectives(String text) {
    final objectives = <String>[];
    final keywords = [
      'understand',
      'learn',
      'explain',
      'describe',
      'analyze',
      'calculate',
      'identify',
      'explore',
      'discover',
      'examine',
    ];

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    for (final sent in sentences) {
      final trimmed = sent.trim();
      if (trimmed.length < 10) continue;

      // Filter garbage
      if (trimmed.contains('Figure') || trimmed.contains('Table')) continue;
      if (trimmed.contains('CHEMIC') || trimmed.contains('EQUAAL')) continue;

      // Check for high uppercase ratio (often garbage headers)
      final upperCount =
          trimmed
              .split('')
              .where((c) => c == c.toUpperCase() && c != c.toLowerCase())
              .length;
      if (upperCount > trimmed.length * 0.5) continue;

      if (keywords.any((k) => trimmed.toLowerCase().contains(k))) {
        objectives.add(trimmed);
      }
    }

    // If no explicit objectives found, synthesize generic ones
    if (objectives.isEmpty) {
      objectives.add('Understand the core principles presented in the text.');
      objectives.add('Identify key terms and definitions.');
      objectives.add('Apply the concepts to real-world scenarios.');
    }

    return objectives.take(4).toList();
  }

  // Generate visual aid suggestions based on content keywords
  static List<String> _generateVisualAidSuggestions(String text) {
    final suggestions = <String>[];
    final lowerText = text.toLowerCase();

    if (lowerText.contains('process') ||
        lowerText.contains('cycle') ||
        lowerText.contains('step')) {
      suggestions.add(
        '🔄 Flowchart: Illustrating the process/cycle described.',
      );
    }
    if (lowerText.contains('compare') ||
        lowerText.contains('difference') ||
        lowerText.contains('versus')) {
      suggestions.add(
        '📊 Comparison Table: Highlighting differences between key terms.',
      );
    }
    if (lowerText.contains('location') ||
        lowerText.contains('map') ||
        lowerText.contains('region')) {
      suggestions.add('🗺️ Map: Showing the geographical regions mentioned.');
    }
    if (lowerText.contains('structure') ||
        lowerText.contains('parts') ||
        lowerText.contains('anatomy')) {
      suggestions.add('🖼️ Labeled Diagram: Showing the structure/parts.');
    }
    if (lowerText.contains('history') ||
        lowerText.contains('timeline') ||
        lowerText.contains('date')) {
      suggestions.add('⏳ Timeline: Chronological order of events.');
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        '📝 Concept Map: Visualizing relationships between key ideas.',
      );
    }

    return suggestions;
  }

  // Extract group activities from text
  static List<String> extractGroupActivities(String text) {
    final activities = <String>[];
    final activityHeaders = [
      'Activity',
      'Group Activity',
      'Project',
      'Let\'s Discuss',
      'Discuss',
      'Do and Learn',
      'Try This',
      'Think and Act',
    ];

    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      bool found = false;
      for (final header in activityHeaders) {
        if (line.toLowerCase().startsWith(header.toLowerCase())) {
          found = true;
          break;
        }
      }

      if (found) {
        // Capture this and next few lines until a blank line or next header
        final buffer = StringBuffer();
        buffer.write(line);

        int j = i + 1;
        while (j < lines.length) {
          final nextLine = lines[j].trim();
          if (nextLine.isEmpty) break;

          // Check if next line is a new header
          bool isNewHeader = false;
          for (final h in activityHeaders) {
            if (nextLine.toLowerCase().startsWith(h.toLowerCase())) {
              isNewHeader = true;
              break;
            }
          }
          if (isNewHeader) break;

          buffer.write(' $nextLine');
          j++;
        }

        final activity = buffer.toString();
        if (activity.length > 15 && activity.length < 500) {
          activities.add(activity);
        }
      }
    }
    return activities.take(3).toList(); // Limit to 3 activities
  }

  // Format content as HTML with proper headers
  static String formatAsHtml(Map<String, dynamic> structuredData) {
    final sb = StringBuffer();

    sb.writeln('<div class="educational-content">');

    // Header
    sb.writeln('<h1 class="subject-header">${structuredData['subject']}</h1>');

    // Learning Objectives
    sb.writeln('<div class="objectives-box">');
    sb.writeln('<h3>🎯 Learning Objectives</h3>');
    sb.writeln('<ul>');
    for (final obj in structuredData['learningObjectives']) {
      sb.writeln('<li>$obj</li>');
    }
    sb.writeln('</ul>');
    sb.writeln('</div>');

    // Sections
    for (final section in structuredData['sections']) {
      sb.writeln('<h2>${section['title']}</h2>');
      sb.writeln('<p>${section['content']}</p>');
    }

    // Visual Aids
    final visuals = structuredData['visualAids'] as List<String>;
    if (visuals.isNotEmpty) {
      sb.writeln('<div class="visual-aids-box">');
      sb.writeln('<h3>👁️ Recommended Visual Aids</h3>');
      sb.writeln('<ul>');
      for (final aid in visuals) {
        sb.writeln('<li>$aid</li>');
      }
      sb.writeln('</ul>');
      sb.writeln('</div>');
    }

    // Activities
    final activities = structuredData['activities'] as List<String>;
    if (activities.isNotEmpty) {
      sb.writeln('<div class="activities-box">');
      sb.writeln('<h3>🤝 Group Activities</h3>');
      for (final activity in activities) {
        sb.writeln('<div class="activity-item">');
        sb.writeln('<p><strong>Activity:</strong> $activity</p>');
        sb.writeln(
          '<p><em>Context: This activity reinforces the concepts of ${structuredData['subject']}.</em></p>',
        );
        sb.writeln('</div>');
      }
      sb.writeln('</div>');
    }

    sb.writeln('</div>');
    return sb.toString();
  }
}
