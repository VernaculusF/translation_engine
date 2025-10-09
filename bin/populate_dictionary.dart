#!/usr/bin/env dart

import 'dart:io';
import 'package:translation_engine/translation_engine.dart';

void main() async {
  print('📝 Заполнение словаря тестовыми данными');
  
  try {
    final engine = TranslationEngine();
    await engine.initialize();
    
    // Получаем repository напрямую для добавления данных
  
    print('✅ Движок инициализирован, добавляем переводы...');
    
    // К сожалению, repository не доступен напрямую из TranslationEngine
    // Нужно создать его отдельно
    print('❌ Не могу получить прямой доступ к repository из TranslationEngine');
    print('💡 Попробуем через прямое создание компонентов...');
    
    await engine.dispose();
    
  } catch (e, stackTrace) {
    print('❌ Ошибка: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}