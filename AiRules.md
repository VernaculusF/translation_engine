1 и основное правило - отвечай на русском.

# 🚀 Translation Engine - Development Rules

## 🎯 Project Context
- **Type**: Closed commercial Flutter library
- **Target**: Offline translation engine for mobile apps
- **Monetization**: Commercial license
- **Experience**: First Flutter library development

## 📋 Core Architecture Rules
- **Priority**: File structure → Database → Translation layers
- **Isolation**: Each layer must be maximally isolated
- **Caching**: In-memory caching mandatory for performance
- **Testing**: Unit tests parallel with each module

## 🗂 File Structure
lib/src/
├── core/ # Engine, pipeline, context
├── layers/ # 6 translation layers
├── data/ # DB managers, repositories
├── adaptation/ # Adaptation interfaces
├── models/ # Data classes
└── utils/ # Utilities, cache, logs

text

## 🗄 Database Rules
- **3 DBs**: dictionaries.db, phrases.db, user_data.db
- **Indexes**: Mandatory for frequent queries
- **Cache**: LRU in-memory for 10k words / 5k phrases
- **Integrity**: NOT NULL + CHECK constraints + IntegrityChecker

## 🔧 Development Workflow
1. Project setup (environment, structure, pubspec)
2. Data system (DatabaseManager, repositories, cache)
3. Translation layers (sequential with tests)
4. Integration (pipeline, engine, API)
5. Optimization (performance, memory)

## 🧹 Clean Code Principles
- **Naming**: PascalCase classes, camelCase methods, UPPER_SNAKE constants
- **Functions**: Max 20-30 lines, single responsibility, named parameters
- **Classes**: Max 200-300 lines, final fields, private `_prefix`
- **Organization**: Logical grouping, no dead code, regular refactoring

## 🏗 SOLID Principles
- **S**: Single responsibility per class
- **O**: Open for extension, closed for modification
- **L**: Liskov substitution - child classes replaceable
- **I**: Interface segregation - specialized interfaces
- **D**: Dependency inversion - depend on abstractions

## 🧪 Testing Requirements
- **Unit tests**: Isolated layer testing
- **Integration**: Full pipeline testing
- **Performance**: MemoryProfiler benchmarks
- **Quality**: 10k+ sentence pairs validation

## 🚀 Deployment
- **Package**: Private, commercial license
- **Versioning**: SemVer
- **CI/CD**: GitHub Actions, multi-version testing
- **Documentation**: End-developer focused

## 💬 Communication
- Explain Flutter-specific concepts clearly
- Focus on offline capability and mobile constraints
- Balance quality vs development speed
- Start simple, optimize incrementally

## 📋 Project Tracking & Reporting

### **Status Files Management**
- **CHECKLISTS/FILES_STATUS.md**: Детальный статус каждого файла проекта
- **CHECKLISTS/CHECKLIST.md**: Общий чеклист разработки
- **Обновление**: После каждого изменения кода обновлять статус файлов
- **Ответственность**: Warp Agent обязан поддерживать актуальность статусов

### **Reports Structure**
```
CHECKLISTS/
├── FILES_STATUS.md      # Статус готовности файлов (обновляется постоянно)
├── CHECKLIST.md         # Общий чеклист проекта
└── Reports/             # Отчеты о проделанной работе
    ├── TEST_REPORT.md   # Результаты тестирования
    ├── CHANGELOG.md     # История изменений
    └── [YYYY-MM-DD]_*.md # Ежедневные отчеты
```

### **Reporting Rules**
1. **FILES_STATUS.md** - обновлять после каждого созданного/измененного файла
2. **CHANGELOG.md** - записывать все значимые изменения с версионированием
3. **TEST_REPORT.md** - обновлять при создании новых тестов
4. **Ежедневные отчеты** - создавать при завершении крупных задач

### **Status Update Format**
- 🔴 **Не создан** (0%) - файл отсутствует или пустой
- 🟡 **Частично** (1-99%) - файл создан, но не завершен
- 🟢 **Готов** (100%) - файл полностью реализован и протестирован

### **Priority Levels**
- 🔥 **КРИТИЧНО** - блокирует дальнейшую разработку
- ⚡ **ВЫСОКИЙ** - нужно для текущего этапа
- 📋 **СРЕДНИЙ** - следующий этап разработки
- 📝 **НИЗКИЙ** - оптимизация и полировка

### **Development Stages Tracking**
- **CHECKLISTS/DEVELOPMENT_STAGES.md**: Детальная разбивка на этапы и подэтапы
- **Текущий этап**: ЭТАП 1 - Data System (недели 1-3)
- **Текущий подэтап**: 1.2 - Cache System (CacheManager с LRU)
- **Обновление**: Warp Agent обязан обновлять прогресс после каждой завершенной задачи
- **Отслеживание**: Статус задач, процент готовности, критерии завершения этапов

### **Stage Completion Criteria**
- Каждый подэтап имеет четкие критерии завершения
- Переход к следующему этапу только после полного завершения предыдущего
- Обязательное тестирование каждого компонента перед переходом
- Интеграционные тесты в конце каждого этапа

### **Agent Responsibilities for Stage Management**
1. **Перед началом задачи**: Проверить текущий этап в DEVELOPMENT_STAGES.md
2. **Во время работы**: Обновлять статус компонентов в FILES_STATUS.md
3. **После завершения**: Отметить выполненные задачи в DEVELOPMENT_STAGES.md
4. **При завершении подэтапа**: Проверить критерии завершения
5. **При завершении этапа**: Создать отчет в CHECKLISTS/Reports/
6. **Всегда**: Следовать приоритетам текущего этапа
