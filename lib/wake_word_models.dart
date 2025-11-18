/// 唤醒词相关数据模型
library;

/// 唤醒词
class WakeWord {
  final String text; // 原始文本（如："hi plaud"）
  final String display; // 显示名称（如："Hi Plaud"）
  final List<String> phonemes; // 音素列表

  WakeWord({
    required this.text,
    required this.display,
    required this.phonemes,
  });

  factory WakeWord.fromJson(Map<String, dynamic> json) {
    return WakeWord(
      text: json['text'] as String? ?? '',
      display: json['display'] as String? ?? '',
      phonemes: (json['phonemes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'display': display,
      'phonemes': phonemes,
    };
  }

  @override
  String toString() => '$display (${phonemes.length}个音素变体)';
}

/// 唤醒词配置结果
class WakeWordResult {
  final bool success;
  final String message;
  final int? count; // 配置的唤醒词数量
  final List<WakeWord>? words; // 获取到的唤醒词列表
  final double? threshold; // 检测阈值
  final int? errorCode;

  WakeWordResult({
    required this.success,
    required this.message,
    this.count,
    this.words,
    this.threshold,
    this.errorCode,
  });

  factory WakeWordResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'error';
    final success = status == 'success';

    final data = json['data'] as Map<String, dynamic>?;
    final errorData = json['error'] as Map<String, dynamic>?;

    List<WakeWord>? words;
    if (data != null && data['words'] != null) {
      words = (data['words'] as List<dynamic>)
          .map((item) => WakeWord.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return WakeWordResult(
      success: success,
      message: success
          ? (data?['message'] as String? ?? '操作成功')
          : (errorData?['message'] as String? ?? '操作失败'),
      count: data?['count'] as int?,
      words: words,
      threshold: data?['threshold'] as double?,
      errorCode: errorData?['code'] as int?,
    );
  }

  /// 获取友好的错误描述
  String getErrorDescription() {
    if (success) return message;

    switch (errorCode) {
      case -1:
        return 'JSON 解析失败，请重试';
      case -2:
        return '音素列表为空，请检查唤醒词配置';
      case -3:
        return '设备存储失败，请重启设备后重试';
      case -4:
        return '唤醒词数量超过限制（最多10个）';
      case -5:
        return '音素格式错误，请使用预置唤醒词';
      default:
        return message;
    }
  }
}

/// 预置唤醒词配置
class PresetWakeWord {
  final String text; // 原始文本
  final String display; // 显示名称
  final List<String> phonemes; // 音素列表
  final String category; // 分类
  final String? description; // 描述

  PresetWakeWord({
    required this.text,
    required this.display,
    required this.phonemes,
    required this.category,
    this.description,
  });

  /// 转换为 WakeWord
  WakeWord toWakeWord() {
    return WakeWord(
      text: text,
      display: display,
      phonemes: phonemes,
    );
  }
}

/// 唤醒词分类
class WakeWordCategory {
  final String id;
  final String name;
  final String icon;

  WakeWordCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

