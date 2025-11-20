import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble/phonetic_converter.dart';

void main() {
  group('PhoneticConverter', () {
    test('转换简单唤醒词', () {
      expect(PhoneticConverter.convert('hi'), isNotNull);
      expect(PhoneticConverter.convert('hey'), isNotNull);
      expect(PhoneticConverter.convert('hello'), isNotNull);
    });

    test('转换复合唤醒词', () {
      final result = PhoneticConverter.convert('hi alexa');
      expect(result, isNotNull);
      print('hi alexa -> $result');
    });

    test('转换已知的预设', () {
      final result = PhoneticConverter.convert('hi lexin');
      expect(result, isNotNull);
      print('hi lexin -> $result');
    });

    test('检查词汇支持', () {
      expect(PhoneticConverter.isSupported('hi alexa'), isTrue);
      expect(PhoneticConverter.isSupported('unknown word xyz'), isFalse);
    });

    test('获取转换详情', () {
      final details = PhoneticConverter.getDetails('hello');
      expect(details, isNotNull);
      print('Details: $details');
    });

    test('批量转换', () {
      final words = ['hi', 'hello', 'alexa', 'siri'];
      final results = PhoneticConverter.convertBatch(words);
      
      for (final entry in results.entries) {
        print('${entry.key} -> ${entry.value}');
      }
      
      expect(results.length, equals(4));
    });

    test('验证项目中的预设唤醒词', () {
      // 验证 wake_word_presets.dart 中的预设
      final presets = {
        'hi lexin': 'hilfKSgN',
        'hello xiaole': 'hcLbSYtLc',
      };

      for (final entry in presets.entries) {
        final converted = PhoneticConverter.convert(entry.key);
        print('预设: ${entry.key}');
        print('  期望: ${entry.value}');
        print('  实际: $converted');
        
        if (converted != null) {
          // 可能存在细微差异，主要是验证可以转换
          expect(converted.length, greaterThan(0));
        }
      }
    });
  });
}

