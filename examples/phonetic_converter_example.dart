/// 音素转换器使用示例
/// 
/// 这个文件展示了如何使用 PhoneticConverter 类

import 'package:flutter_ble/phonetic_converter.dart';

void main() {
  print('=== 本地音素转换器示例 ===\n');
  
  // 示例 1: 基本转换
  example1();
  
  // 示例 2: 检查支持状态
  example2();
  
  // 示例 3: 获取详细信息
  example3();
  
  // 示例 4: 批量转换
  example4();
  
  // 示例 5: 常见唤醒词
  example5();
}

/// 示例 1: 基本转换
void example1() {
  print('📝 示例 1: 基本转换');
  print('─────────────────────');
  
  final examples = [
    'hi',
    'hello',
    'alexa',
    'hi alexa',
    'hey google',
  ];
  
  for (final text in examples) {
    final result = PhoneticConverter.convert(text);
    if (result != null) {
      print('✓ "$text" → "$result"');
    } else {
      print('✗ "$text" → (不支持)');
    }
  }
  print('');
}

/// 示例 2: 检查支持状态
void example2() {
  print('🔍 示例 2: 检查支持状态');
  print('─────────────────────');
  
  final testWords = [
    'hi alexa',           // 支持
    'hello world',        // world 不在词典中
    'ok google',          // 支持
    'unknown phrase',     // 不支持
  ];
  
  for (final word in testWords) {
    final isSupported = PhoneticConverter.isSupported(word);
    if (isSupported) {
      final phonetic = PhoneticConverter.convert(word);
      print('✓ "$word" - 支持 (音素: $phonetic)');
    } else {
      print('✗ "$word" - 不支持');
    }
  }
  print('');
}

/// 示例 3: 获取详细信息
void example3() {
  print('📊 示例 3: 获取详细信息');
  print('─────────────────────');
  
  final text = 'hi alexa';
  final details = PhoneticConverter.getDetails(text);
  
  if (details != null) {
    print('输入文本: ${details['input']}');
    print('标准化: ${details['normalized']}');
    print('最终结果: ${details['result']}');
    print('\n单词分解:');
    
    final words = details['words'] as List;
    for (var word in words) {
      print('  • ${word['word']}');
      print('    ARPAbet: ${word['arpabet']}');
      print('    Espressif: ${word['espressif']}');
    }
  }
  print('');
}

/// 示例 4: 批量转换
void example4() {
  print('📦 示例 4: 批量转换');
  print('─────────────────────');
  
  final words = [
    'hi', 'hey', 'hello',
    'alexa', 'siri', 'google',
    'turn', 'on', 'off',
  ];
  
  final results = PhoneticConverter.convertBatch(words);
  
  print('批量转换 ${words.length} 个词，成功 ${results.length} 个:\n');
  
  results.forEach((word, phonetic) {
    print('  $word → $phonetic');
  });
  print('');
}

/// 示例 5: 常见唤醒词组合
void example5() {
  print('🎤 示例 5: 常见唤醒词组合');
  print('─────────────────────');
  
  final wakeWords = {
    '问候': ['hi', 'hey', 'hello'],
    '品牌': ['alexa', 'siri', 'google', 'jarvis'],
    '组合': ['hi alexa', 'hey siri', 'ok google'],
    '控制': ['turn on', 'turn off', 'play', 'stop'],
  };
  
  wakeWords.forEach((category, words) {
    print('$category:');
    for (final word in words) {
      final phonetic = PhoneticConverter.convert(word);
      if (phonetic != null) {
        print('  • $word → $phonetic');
      } else {
        print('  • $word → (需要完整词典)');
      }
    }
    print('');
  });
}

/// 高级用法：自定义验证
bool isValidWakeWord(String text) {
  // 检查长度
  if (text.isEmpty || text.length > 50) {
    return false;
  }
  
  // 检查是否支持
  if (!PhoneticConverter.isSupported(text)) {
    return false;
  }
  
  // 检查音素长度（太短可能误触发）
  final phonetic = PhoneticConverter.convert(text);
  if (phonetic == null || phonetic.length < 2) {
    return false;
  }
  
  return true;
}

/// 高级用法：查找相似唤醒词
List<String> findSimilarWakeWords(String target) {
  final allWords = PhoneticConverter.getSupportedWords();
  final targetPhonetic = PhoneticConverter.convert(target);
  
  if (targetPhonetic == null) return [];
  
  final similar = <String>[];
  for (final word in allWords) {
    if (word == target) continue;
    
    final phonetic = PhoneticConverter.convert(word);
    if (phonetic != null && phonetic.length == targetPhonetic.length) {
      // 简单的长度相似度
      similar.add(word);
    }
  }
  
  return similar;
}

