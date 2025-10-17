class NIDScraper {
  /// Parses NID text extracted from OCR and returns structured data
  static Map<String, String> parseNIDData(String text) {
    Map<String, String> data = {'name': '', 'dob': '', 'nidNumber': ''};

    // Split text into lines
    List<String> lines = text.split('\n');

    // Common patterns for Bangladesh NID
    RegExp nidNumberPattern = RegExp(r'\b\d{10,17}\b');
    RegExp datePattern = RegExp(
      r'\b\d{1,2}\s*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s*\d{2,4}\b',
      caseSensitive: false,
    );
    RegExp numericDatePattern = RegExp(
      r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b',
    );

    // Process each line
    for (String line in lines) {
      String cleanLine = line.trim();
      String lowerLine = cleanLine.toLowerCase();

      // Extract Name (look for "Name:" or "name:" label)
      if ((lowerLine.contains('name') || lowerLine.contains('নাম')) &&
          cleanLine.contains(':')) {
        List<String> parts = cleanLine.split(':');
        if (parts.length > 1) {
          String namePart = parts[1].trim();
          // Remove Bengali characters and extract English name
          String englishName = namePart
              .replaceAll(RegExp(r'[\u0980-\u09FF]'), '')
              .trim();
          if (englishName.isNotEmpty && data['name']!.isEmpty) {
            data['name'] = englishName;
          }
        }
      }

      // Extract Date of Birth (look for "Date of Birth:" label or date patterns)
      if ((lowerLine.contains('date of birth') ||
              lowerLine.contains('dob') ||
              lowerLine.contains('জন্ম')) &&
          cleanLine.contains(':')) {
        List<String> parts = cleanLine.split(':');
        if (parts.length > 1) {
          String datePart = parts[1].trim();
          // Try to match date patterns
          var monthDateMatch = datePattern.firstMatch(datePart);
          var numericDateMatch = numericDatePattern.firstMatch(datePart);

          if (monthDateMatch != null && data['dob']!.isEmpty) {
            data['dob'] = monthDateMatch.group(0)!;
          } else if (numericDateMatch != null && data['dob']!.isEmpty) {
            data['dob'] = numericDateMatch.group(0)!;
          }
        }
      }

      // Extract ID Number (look for "ID NO:" or "NID NO:" label)
      if ((lowerLine.contains('id no') ||
              lowerLine.contains('nid') ||
              lowerLine.contains('আইডি')) &&
          cleanLine.contains(':')) {
        List<String> parts = cleanLine.split(':');
        if (parts.length > 1) {
          String idPart = parts[1].trim();
          var nidMatch = nidNumberPattern.firstMatch(idPart);
          if (nidMatch != null && data['nidNumber']!.isEmpty) {
            String potentialNID = nidMatch.group(0)!;
            // Bangladesh NID is typically 10, 13, or 17 digits
            if (potentialNID.length == 10 ||
                potentialNID.length == 13 ||
                potentialNID.length == 17) {
              data['nidNumber'] = potentialNID;
            }
          }
        }
      }
    }

    // Fallback: Extract NID number if not found with label
    if (data['nidNumber']!.isEmpty) {
      for (String line in lines) {
        var nidMatch = nidNumberPattern.firstMatch(line);
        if (nidMatch != null) {
          String potentialNID = nidMatch.group(0)!;
          if (potentialNID.length == 10 ||
              potentialNID.length == 13 ||
              potentialNID.length == 17) {
            data['nidNumber'] = potentialNID;
            break;
          }
        }
      }
    }

    // Fallback: Extract date if not found with label
    if (data['dob']!.isEmpty) {
      for (String line in lines) {
        var monthDateMatch = datePattern.firstMatch(line);
        var numericDateMatch = numericDatePattern.firstMatch(line);

        if (monthDateMatch != null) {
          data['dob'] = monthDateMatch.group(0)!;
          break;
        } else if (numericDateMatch != null) {
          data['dob'] = numericDateMatch.group(0)!;
          break;
        }
      }
    }

    return data;
  }
}
