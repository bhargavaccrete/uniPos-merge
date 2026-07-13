import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Parse Poppins Regular font', () async {
    final data = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final font = pw.Font.ttf(data);
    expect(font, isNotNull);
    print('Poppins Regular parsed successfully');
  });

  test('Parse Noto Sans Gujarati font', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansGujarati-Regular.ttf');
    final font = pw.Font.ttf(data);
    expect(font, isNotNull);
    print('Noto Sans Gujarati parsed successfully');
  });

  test('Parse Noto Sans Devanagari font', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final font = pw.Font.ttf(data);
    expect(font, isNotNull);
    print('Noto Sans Devanagari parsed successfully');
  });
}
