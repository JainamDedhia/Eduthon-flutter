// FILE: lib/services/library_service.dart

class LibraryItem {
  final String title;
  final String description;
  final String category;
  final String fileName;
  final String downloadUrl;
  final double sizeMB;

  LibraryItem({
    required this.title,
    required this.description,
    required this.category,
    required this.fileName,
    required this.downloadUrl,
    this.sizeMB = 0.0,
  });
}

class LibraryService {
  static List<LibraryItem> getAllItems() {
    return [
      // ENGLISH TEXTBOOK (Top 5 Chapters)
      LibraryItem(
        title: 'Where the Mind is Without Fear',
        description: 'English - Chapter 1',
        category: 'English',
        fileName: 'chapter_01_Where_the_Mind_is_Without_Fear.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/EnglishKumarBharti/chapter_01_Where_the_Mind_is_Without_Fear.pdf',
        sizeMB: 2.5,
      ),
      LibraryItem(
        title: 'The Thief\'s Story',
        description: 'English - Chapter 2',
        category: 'English',
        fileName: 'chapter_02_The_Thief_s_Story.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/EnglishKumarBharti/chapter_02_The_Thief_s_Story.pdf',
        sizeMB: 2.3,
      ),
      LibraryItem(
        title: 'On Wings of Courage',
        description: 'English - Chapter 3',
        category: 'English',
        fileName: 'chapter_03_On_Wings_of_Courage.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/EnglishKumarBharti/chapter_03_On_Wings_of_Courage.pdf',
        sizeMB: 2.4,
      ),
      LibraryItem(
        title: 'All the World\'s a Stage',
        description: 'English - Chapter 4',
        category: 'English',
        fileName: 'chapter_04_All_the_World_s_a_Stage.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/EnglishKumarBharti/chapter_04_All_the_World_s_a_Stage.pdf',
        sizeMB: 2.2,
      ),
      LibraryItem(
        title: 'Joan of Arc',
        description: 'English - Chapter 5',
        category: 'English',
        fileName: 'chapter_05_Joan_of_Arc.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/EnglishKumarBharti/chapter_05_Joan_of_Arc.pdf',
        sizeMB: 2.6,
      ),

      // SCIENCE PART 1 (All 4 Chapters)
      LibraryItem(
        title: 'Gravitation',
        description: 'Science Part 1 - Chapter 1',
        category: 'Science',
        fileName: 'chapter_01_Gravitation.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/sciencepart-1/chapter_01_Gravitation.pdf',
        sizeMB: 3.2,
      ),
      LibraryItem(
        title: 'Periodic Classification of Elements',
        description: 'Science Part 1 - Chapter 2',
        category: 'Science',
        fileName: 'chapter_02_Periodic_Classification_of_Elements.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/sciencepart-1/chapter_02_Periodic_Classification_of_Elements.pdf',
        sizeMB: 3.5,
      ),
      LibraryItem(
        title: 'Chemical Reactions and Equations',
        description: 'Science Part 1 - Chapter 3',
        category: 'Science',
        fileName: 'chapter_03_Chemical_Reactions_and_Equations.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/sciencepart-1/chapter_03_Chemical_Reactions_and_Equations.pdf',
        sizeMB: 3.4,
      ),
      LibraryItem(
        title: 'Effects of Electric Current',
        description: 'Science Part 1 - Chapter 4',
        category: 'Science',
        fileName: 'chapter_04_Effects_of_Electric_Current.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/sciencepart-1/chapter_04_Effects_of_Electric_Current.pdf',
        sizeMB: 3.3,
      ),

      // MATHS PART 1 (Top 5 Chapters)
      LibraryItem(
        title: 'Linear Equations in Two Variables',
        description: 'Maths Part 1 - Chapter 1',
        category: 'Maths',
        fileName: 'chapter_01_Linear_Equations_in_Two_Variables.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/mathspart-1/chapter_01_Linear_Equations_in_Two_Variables.pdf',
        sizeMB: 2.8,
      ),
      LibraryItem(
        title: 'Quadratic Equations',
        description: 'Maths Part 1 - Chapter 2',
        category: 'Maths',
        fileName: 'chapter_02_Quadratic_Equations.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/mathspart-1/chapter_02_Quadratic_Equations.pdf',
        sizeMB: 2.9,
      ),
      LibraryItem(
        title: 'Arithmetic Progression',
        description: 'Maths Part 1 - Chapter 3',
        category: 'Maths',
        fileName: 'chapter_03_Arithmetic_Progression.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/mathspart-1/chapter_03_Arithmetic_Progression.pdf',
        sizeMB: 2.7,
      ),
      LibraryItem(
        title: 'Financial Planning',
        description: 'Maths Part 1 - Chapter 4',
        category: 'Maths',
        fileName: 'chapter_04_Financial_Planning.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/mathspart-1/chapter_04_Financial_Planning.pdf',
        sizeMB: 3.0,
      ),
      LibraryItem(
        title: 'Probability',
        description: 'Maths Part 1 - Chapter 5',
        category: 'Maths',
        fileName: 'chapter_05_Probability.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/mathspart-1/chapter_05_Probability.pdf',
        sizeMB: 2.6,
      ),

      // HISTORY (Top 5 Chapters)
      LibraryItem(
        title: 'Historiography - Development in the West',
        description: 'History - Chapter 1',
        category: 'History',
        fileName: 'chapter_01_Historiography_Development_in_the_West.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/history1/chapter_01_Historiography_Development_in_the_West.pdf',
        sizeMB: 2.4,
      ),
      LibraryItem(
        title: 'Historiography - Indian Tradition',
        description: 'History - Chapter 2',
        category: 'History',
        fileName: 'chapter_02_Historiography_Indian_Tradition.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/history1/chapter_02_Historiography_Indian_Tradition.pdf',
        sizeMB: 2.5,
      ),
      LibraryItem(
        title: 'Applied History',
        description: 'History - Chapter 3',
        category: 'History',
        fileName: 'chapter_03_Applied_History.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/history1/chapter_03_Applied_History.pdf',
        sizeMB: 2.3,
      ),
      LibraryItem(
        title: 'History of Indian Arts',
        description: 'History - Chapter 4',
        category: 'History',
        fileName: 'chapter_04_History_of_Indian_Arts.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/history1/chapter_04_History_of_Indian_Arts.pdf',
        sizeMB: 2.6,
      ),
      LibraryItem(
        title: 'Mass Media and History',
        description: 'History - Chapter 5',
        category: 'History',
        fileName: 'chapter_05_Mass_Media_and_History.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/history1/chapter_05_Mass_Media_and_History.pdf',
        sizeMB: 2.4,
      ),

      // GEOGRAPHY (Top 5 Chapters)
      LibraryItem(
        title: 'Field Visit',
        description: 'Geography - Chapter 1',
        category: 'Geography',
        fileName: 'chapter_01_Field_Visit.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/geo-graphy/chapter_01_Field_Visit.pdf',
        sizeMB: 2.2,
      ),
      LibraryItem(
        title: 'Location and Extent',
        description: 'Geography - Chapter 2',
        category: 'Geography',
        fileName: 'chapter_02_Location_and_Extent.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/geo-graphy/chapter_02_Location_and_Extent.pdf',
        sizeMB: 2.5,
      ),
      LibraryItem(
        title: 'Physiography and Drainage',
        description: 'Geography - Chapter 3',
        category: 'Geography',
        fileName: 'chapter_03_Physiography_and_Drainage.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/geo-graphy/chapter_03_Physiography_and_Drainage.pdf',
        sizeMB: 2.7,
      ),
      LibraryItem(
        title: 'Climate',
        description: 'Geography - Chapter 4',
        category: 'Geography',
        fileName: 'chapter_04_Climate.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/geo-graphy/chapter_04_Climate.pdf',
        sizeMB: 2.6,
      ),
      LibraryItem(
        title: 'Natural Vegetation and Wildlife',
        description: 'Geography - Chapter 5',
        category: 'Geography',
        fileName: 'chapter_05_Natural_Vegetation_and_Wildlife.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/geo-graphy/chapter_05_Natural_Vegetation_and_Wildlife.pdf',
        sizeMB: 2.8,
      ),

      // DIGESTS (Master Keys)
      LibraryItem(
        title: 'Marathi Master Key',
        description: 'Complete Marathi Digest',
        category: 'Digests',
        fileName: 'X_Marathi_Master_Key.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/X+Marathi+-+Master+Key.pdf',
        sizeMB: 8.5,
      ),
      LibraryItem(
        title: 'Mathematics Part I Master Key',
        description: 'Complete Maths Digest',
        category: 'Digests',
        fileName: 'MATHEMATICS_PART_I.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/MATHEMATICS+PART+-+I.pdf',
        sizeMB: 9.2,
      ),
      LibraryItem(
        title: 'Science Part 1 Master Key',
        description: 'Complete Science Digest',
        category: 'Digests',
        fileName: 'SSC_Science_1_Master_Key.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/SSC-Science-1+Master+Key.pdf',
        sizeMB: 9.8,
      ),
      LibraryItem(
        title: 'English Master Key',
        description: 'Complete English Digest',
        category: 'Digests',
        fileName: 'X_English_Master_Key.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/X+English+-+Master+Key.pdf',
        sizeMB: 8.8,
      ),
      LibraryItem(
        title: 'Geography Master Key',
        description: 'Complete Geography Digest',
        category: 'Digests',
        fileName: 'X_Geography_Master_Key.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/X+Geography+-+Master+Key.pdf',
        sizeMB: 9.0,
      ),
      LibraryItem(
        title: 'History & Political Science Master Key',
        description: 'Complete History Digest',
        category: 'Digests',
        fileName: 'X_History_Political_Science_Master_Key.pdf',
        downloadUrl: 'https://study2material1.s3.eu-north-1.amazonaws.com/digests/X+History+%26+Political+Science+-+Master+Key.pdf',
        sizeMB: 9.5,
      ),
    ];
  }

  // Get items by category
  static List<LibraryItem> getItemsByCategory(String category) {
    return getAllItems()
        .where((item) =>
            item.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Get textbook chapters only
  static List<LibraryItem> getTextbookChapters() {
    return getAllItems()
        .where((item) => item.category != 'Digests')
        .toList();
  }

  // Get digests only
  static List<LibraryItem> getDigests() {
    return getAllItems()
        .where((item) => item.category == 'Digests')
        .toList();
  }

  // Search items
  static List<LibraryItem> searchItems(String query) {
    final lowerQuery = query.toLowerCase();
    return getAllItems()
        .where((item) =>
            item.title.toLowerCase().contains(lowerQuery) ||
            item.description.toLowerCase().contains(lowerQuery) ||
            item.category.toLowerCase().contains(lowerQuery))
        .toList();
  }
}