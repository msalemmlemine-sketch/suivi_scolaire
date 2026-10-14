import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelStudentRow {
  final String? nationalId;
  final String fullNameAr;
  final String fullNameFr;
  final String? gender;
  final String? birthDate;

  ExcelStudentRow({
    this.nationalId,
    required this.fullNameAr,
    required this.fullNameFr,
    this.gender,
    this.birthDate,
  });
}

class ExcelService {
  /// اختيار ملف Excel من الجهاز باستخدام file_selector الرسمي
  static Future<List<ExcelStudentRow>?> pickAndParseStudents() async {
    const typeGroup = XTypeGroup(
      label: 'Excel Files',
      extensions: <String>['xlsx', 'xls'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return parseStudentsFromBytes(bytes);
  }

  /// قراءة واستيراد التلاميذ من مصفوفة بايتات
  static List<ExcelStudentRow> parseStudentsFromBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<ExcelStudentRow> students = [];

    if (excel.tables.isEmpty) return [];
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.maxRows <= 1) return [];

    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      final id = row.isNotEmpty ? row[0]?.value?.toString().trim() : null;
      final nameAr = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
      final nameFr = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
      final gender = row.length > 3 ? row[3]?.value?.toString().trim() : null;
      final dob = row.length > 4 ? row[4]?.value?.toString().trim() : null;

      if (nameAr.isEmpty && nameFr.isEmpty) continue;

      students.add(ExcelStudentRow(
        nationalId: id,
        fullNameAr: nameAr,
        fullNameFr: nameFr,
        gender: gender,
        birthDate: dob,
      ));
    }

    return students;
  }

  /// تصدير لائحة تلاميذ قسم إلى ملف Excel (.xlsx) حقيقي ومشاركته
  static Future<String> exportClassRoster({
    required String institutionName,
    required String className,
    required String academicYear,
    required List<Map<String, dynamic>> studentsList,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final safeSheetName = className.replaceAll('/', '-');
    excel.rename(defaultSheet, safeSheetName);
    final Sheet sheet = excel[safeSheetName];

    // ترويسة اللائحة
    sheet.appendRow([
      TextCellValue('المؤسسة: $institutionName'),
      TextCellValue('السنة: $academicYear'),
      TextCellValue('القسم: $className'),
    ]);
    sheet.appendRow([]);

    // أعمدة الجدول
    sheet.appendRow([
      TextCellValue('الرقم'),
      TextCellValue('رقم التسجيل'),
      TextCellValue('الاسم الكامل (بالعربية)'),
      TextCellValue('Nom et Prénom (Français)'),
      TextCellValue('الجنس'),
      TextCellValue('تاريخ الميلاد'),
    ]);

    for (int i = 0; i < studentsList.length; i++) {
      final s = studentsList[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s['national_id']?.toString() ?? ''),
        TextCellValue(s['full_name_ar']?.toString() ?? ''),
        TextCellValue(s['full_name_original']?.toString() ?? s['full_name_fr']?.toString() ?? ''),
        TextCellValue(s['gender']?.toString() ?? ''),
        TextCellValue(s['date_of_birth']?.toString() ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل إنشاء ملف Excel');

    final dir = await getTemporaryDirectory();
    final sanitizedClassName = className.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${dir.path}/Liste_$sanitizedClassName.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'لائحة قسم $className',
    );

    return filePath;
  }
}
