import 'dart:convert';

void main() {
  // 模拟用户选择的 3 个唤醒词
  final words = [
    {
      'text': 'hi buddy',
      'display': 'Hi Buddy',
      'phonemes': ['hi buddy'], // 只保留1个
    },
    {
      'text': 'hi assistant',
      'display': 'Hi Assistant',
      'phonemes': ['hi assistant'], // 只保留1个
    },
    {
      'text': 'hey friend',
      'display': 'Hey Friend',
      'phonemes': ['hey friend'], // 只保留1个
    },
  ];

  final command = {
    'cmd': 'set_wake_words',
    'data': {
      'words': words,
      'threshold': 0.4,
      'replace': true,
    },
  };

  final jsonString = jsonEncode(command);
  final dataSize = utf8.encode(jsonString).length;

  print('优化后的数据：');
  print(jsonString);
  print('\n数据大小: $dataSize 字节');
  print('限制: 250 字节');
  print('状态: ${dataSize <= 250 ? "✅ 成功" : "❌ 仍然超限"}');
}

