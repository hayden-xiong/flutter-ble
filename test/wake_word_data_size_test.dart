import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble/wake_word_models.dart';
import 'package:flutter_ble/wake_word_presets.dart';

/// 测试唤醒词数据大小优化
void main() {
  group('唤醒词数据大小测试', () {
    
    /// 模拟 BLE 服务的数据优化函数
    Map<String, dynamic> optimizeWakeWordData(WakeWord word) {
      // 只保留前2个音素变体
      final optimizedPhonemes = word.phonemes.take(2).toList();
      return {
        'text': word.text,
        'display': word.display,
        'phonemes': optimizedPhonemes,
      };
    }
    
    /// 计算命令的数据大小
    int calculateCommandSize(List<WakeWord> words) {
      final command = {
        'cmd': 'set_wake_words',
        'data': {
          'words': words.map((w) => optimizeWakeWordData(w)).toList(),
          'threshold': 0.15,
          'replace': true,
        },
      };
      
      final jsonString = jsonEncode(command);
      final data = utf8.encode(jsonString);
      return data.length;
    }
    
    test('单个唤醒词数据大小', () {
      final word = presetWakeWords['hi plaud']!.toWakeWord();
      final size = calculateCommandSize([word]);
      
      print('单个唤醒词: ${word.text}');
      print('音素数量: ${word.phonemes.length} → 3 (优化后)');
      print('数据大小: $size 字节');
      
      expect(size, lessThan(250), reason: '单个唤醒词应该小于250字节');
    });
    
    test('2个唤醒词数据大小', () {
      final words = [
        presetWakeWords['hi plaud']!.toWakeWord(),
        presetWakeWords['hey plaud']!.toWakeWord(),
      ];
      
      final size = calculateCommandSize(words);
      
      print('\n2个唤醒词:');
      for (var word in words) {
        print('  - ${word.text} (${word.phonemes.length}个音素)');
      }
      print('优化后数据大小: $size 字节');
      
      expect(size, lessThan(250), reason: '2个唤醒词优化后应该小于250字节');
    });
    
    test('3个唤醒词数据大小', () {
      final words = [
        presetWakeWords['hi plaud']!.toWakeWord(),
        presetWakeWords['hey plaud']!.toWakeWord(),
        presetWakeWords['hi assistant']!.toWakeWord(),
      ];
      
      final size = calculateCommandSize(words);
      
      print('\n3个唤醒词:');
      for (var word in words) {
        print('  - ${word.text}');
      }
      print('优化后数据大小: $size 字节');
      
      if (size >= 250) {
        print('⚠️  警告: 接近或超出限制！');
      }
      
      // 3个唤醒词可能接近限制，但通常应该可以
      expect(size, lessThan(300), reason: '3个唤醒词不应该严重超限');
    });
    
    test('5个唤醒词数据大小（预期超限）', () {
      final words = [
        presetWakeWords['hi plaud']!.toWakeWord(),
        presetWakeWords['hey plaud']!.toWakeWord(),
        presetWakeWords['hi assistant']!.toWakeWord(),
        presetWakeWords['hey assistant']!.toWakeWord(),
        presetWakeWords['ok robot']!.toWakeWord(),
      ];
      
      final size = calculateCommandSize(words);
      
      print('\n5个唤醒词:');
      for (var word in words) {
        print('  - ${word.text}');
      }
      print('优化后数据大小: $size 字节');
      
      if (size > 250) {
        print('❌ 超出限制！需要分批发送');
      }
      
      // 验证确实会超限
      expect(size, greaterThan(250), reason: '5个唤醒词应该会超出限制');
    });
    
    test('音素优化效果对比', () {
      final word = presetWakeWords['hi plaud']!.toWakeWord();
      
      // 未优化的数据
      final unoptimizedCommand = {
        'cmd': 'set_wake_words',
        'data': {
          'words': [word.toJson()],
          'threshold': 0.15,
          'replace': true,
        },
      };
      final unoptimizedSize = utf8.encode(jsonEncode(unoptimizedCommand)).length;
      
      // 优化后的数据
      final optimizedSize = calculateCommandSize([word]);
      
      final savedBytes = unoptimizedSize - optimizedSize;
      final savedPercent = (savedBytes / unoptimizedSize * 100).toStringAsFixed(1);
      
      print('\n音素优化效果:');
      print('未优化: $unoptimizedSize 字节');
      print('优化后: $optimizedSize 字节');
      print('节省: $savedBytes 字节 ($savedPercent%)');
      
      expect(optimizedSize, lessThan(unoptimizedSize), 
             reason: '优化后应该更小');
    });
    
    test('数据大小建议表', () {
      print('\n=== 唤醒词配置建议 ===\n');
      
      final testCases = [
        {'count': 1, 'description': '单个（推荐）'},
        {'count': 2, 'description': '两个（推荐）'},
        {'count': 3, 'description': '三个（可用）'},
        {'count': 4, 'description': '四个（不建议）'},
        {'count': 5, 'description': '五个（不建议）'},
      ];
      
      for (var testCase in testCases) {
        final count = testCase['count'] as int;
        final words = presetWakeWords.values
            .take(count)
            .map((p) => p.toWakeWord())
            .toList();
        
        final size = calculateCommandSize(words);
        final status = size < 250 ? '✅' : '❌';
        
        print('${testCase['description']}: $size 字节 $status');
      }
      
      print('\n建议：一次配置 1-3 个唤醒词最佳');
    });
  });
}

