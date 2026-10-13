import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
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
  /// قراءة واستيراد التلاميذ من ملف Excel
  static List<ExcelStudentRow> parseStudentsFromBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<ExcelStudentRow> students = [];

    // اختيار أول ورقة عمل تحتوي على بيانات
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.maxRows <= 1) return [];

    // تخطي سطر الترويسة (Header)
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      // قراءة الحقول بحسب الترتيب الشائع:
      // 0: رقم التعريف/التسجيل، 1: الاسم بالعربية، 2: الاسم بالفرنسية، 3: الجنس، 4: تاريخ الميلاد
      final id = row.isNotEmpty ? row[0]?.value?.toString().trim() : null;
      final nameAr = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
      final nameFr = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
      final gender = row.length > 3 ? row[3]?.value?.toString().trim() : null;
      final dob = row.length > 4 ? row[4]?.value?.toString().trim() : null;

      // تجاهل الأسطر الفارغة بالكامل
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
    excel.rename(defaultSheet, className.replaceAll('/', '-'));
    final Sheet sheet = excel[className.replaceAll('/', '-')];

    // ترويسة اللائحة
    sheet.appendRow([
      TextCellValue('المؤسسة: $institutionName'),
      TextCellValue('السنة: $academicYear'),
      TextCellValue('القسم: $className'),
    ]);
    sheet.appendRow([]); // سطر فارغ

    // عناوين الأعمدة
    sheet.appendRow([
      TextCellValue('الرقم'),
      TextCellValue('رقم التسجيل'),
      TextCellValue('الاسم الكامل (بالعربية)'),
      TextCellValue('Nom et Prénom (Français)'),
      TextCellValue('الجنس'),
      TextCellValue('تاريخ الميلاد'),
    ]);

    // تعبئة بيانات التلاميذ
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

    // حفظ الملف محلياً
    final bytes = excel.encode();
    if (bytes == null) throw Exception('فشل إنشاء ملف Excel');

    final dir = await getTemporaryDirectory();
    final sanitizedClassName = className.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${dir.path}/Liste_$sanitizedClassName.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // فتح نافذة مشاركة وحفظ الملف
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'لائحة قسم $className',
    );

    return filePath;
  }
}
