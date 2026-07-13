import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Load Poppins Regular font', () async {
    final data = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    expect(data.lengthInBytes, greaterThan(0));
    print('Poppins Regular loaded: ${data.lengthInBytes} bytes');
  });

  test('Load Poppins Bold font', () async {
    final data = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    expect(data.lengthInBytes, greaterThan(0));
    print('Poppins Bold loaded: ${data.lengthInBytes} bytes');
  });

  test('Load Noto Sans Gujarati font', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansGujarati-Regular.ttf');
    expect(data.lengthInBytes, greaterThan(0));
    print('Noto Sans Gujarati loaded: ${data.lengthInBytes} bytes');
  });

  test('Load Noto Sans Devanagari font', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    expect(data.lengthInBytes, greaterThan(0));
    print('Noto Sans Devanagari loaded: ${data.lengthInBytes} bytes');
  });
}
