# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a closed commercial Flutter library that provides an offline translation engine for mobile apps. The library targets two main application types:

1. **Mobile Offline Translator**: Fast text translation without internet connection
2. **Book Reading Applications**: Real-time text translation while reading

### Project Status
- **Version**: 0.0.1 (Active Development)
- **Development Timeline**: 11 weeks to production-ready
- **License**: Commercial/Proprietary

### Performance Characteristics
- **Package Size**: ~75-100MB
- **Translation Time**: 20-50ms
- **Memory Usage**: 80-120MB RAM
- **Translation Quality**: 7.5/10 for main scenarios

## Key Commands

### Development & Testing
```powershell
# Get dependencies
flutter pub get

# Run all tests
flutter test

# Run specific test file
flutter test test/unit/data/database_manager_test.dart

# Run tests with coverage
flutter test --coverage

# Analyze code quality
flutter analyze

# Format code
dart format lib/ test/

# Check for dependency issues
flutter pub deps
```

### Build & Package
```powershell
# Build the library (dry run)
flutter pub publish --dry-run

# Check package structure
flutter pub deps --style=tree
```

## Architecture Overview

### Core Architecture Pattern
The translation engine follows a **layered pipeline architecture** with strict separation of concerns:

1. **Translation Pipeline**: Orchestrates translation through multiple layers
2. **Translation Layers**: Six specialized processing layers (dictionary, grammar, phrase translation, pre/post-processing, word order)
3. **Data Layer**: Three separate SQLite databases with repositories and caching
4. **Core Engine**: Main translation engine and context management
5. **Adaptation Layer**: Interfaces for extending functionality

### Database Architecture
The system uses **three separate SQLite databases**:

- `dictionaries.db`: Word translations, frequencies, and word cache
- `phrases.db`: Phrase translations and phrase cache  
- `user_data.db`: User corrections, translation history, and context cache

Each database includes:
- Schema versioning via `schema_info` table
- Optimized indexes for frequent queries
- Integrity constraints and validation
- LRU caching (10k words / 5k phrases in-memory)

### Data Sources
Translation data is sourced from:
- OPUS, Wiktionary, Tatoeba, Apertium
- OpenRussian, Project Gutenberg

### Directory Structure
```
lib/src/
├── core/              # Engine, pipeline, context management
├── layers/            # 6 translation processing layers
├── data/              # Database managers, repositories
├── adaptation/        # Extension interfaces
├── models/            # Data classes and models
└── utils/             # Cache, logging, profiling, exceptions
```

### Translation Layers (Sequential Processing)
1. **Pre-processing Layer**: Text normalization, tokenization, language detection
2. **Phrase Translation Layer**: Ready-made translation lookups for expressions
3. **Dictionary Layer**: Individual word translation lookups
4. **Grammar Layer**: Language rules and grammar correction application
5. **Word Order Layer**: Syntactic restructuring and word order adjustments
6. **Post-processing Layer**: Final formatting, capitalization, punctuation

### Technology Stack
- **Dart 3.0+**: Primary development language
- **Flutter**: Cross-platform framework
- **SQLite**: Local dictionary storage
- **In-memory Cache**: Performance optimization

## Development Patterns

### Database Pattern
- **Singleton DatabaseManager** handles all three databases
- **Repository pattern** for data access abstraction
- **Integrity checking** across all databases
- **LRU caching** with configurable limits

### Testing Pattern
- **Test database setup** using `sqflite_common_ffi` for desktop testing
- **Unit tests** for each layer in isolation
- **Integration tests** for full pipeline
- **Test helpers** in `test/helpers/` directory

### Error Handling
- Custom exception hierarchy (`TranslationException`, `DatabaseInitException`, etc.)
- Comprehensive error propagation through layers
- Database integrity validation

## Key Implementation Rules

### Database Rules
- All three databases must maintain schema versioning
- Mandatory indexes for frequent queries (`idx_word_lang`, `idx_frequency`, etc.)
- NOT NULL and CHECK constraints on critical fields
- Cache tables with LRU eviction strategy

### Code Organization Rules  
- **PascalCase** for classes, **camelCase** for methods, **UPPER_SNAKE** for constants
- Maximum 20-30 lines per function
- Maximum 200-300 lines per class
- Private fields/methods use `_prefix`
- Named parameters for better readability

### Layer Isolation Rules
- Each translation layer must be independently testable
- Layers communicate only through standardized interfaces
- No direct database access from layers (use repositories)
- Dependency injection for all external dependencies

## Performance Considerations

- **In-memory caching** is mandatory for frequently accessed data
- **Database connection pooling** through singleton pattern
- **Lazy loading** of translation resources
- **Memory profiling** tools available in `utils/memory_profiler.dart`

## Testing Requirements

- **Unit tests** required for each new component
- **Integration tests** for pipeline modifications  
- **Performance benchmarks** for cache and database operations
- Test database isolation using FFI implementation

## Development Status & Roadmap

### Current Status (v0.0.1)
**✅ Completed:**
- Project structure setup
- DatabaseManager implementation
- Basic configuration

**🔄 In Progress:**
- Data models development
- Repository implementations
- Translation layers development

### Development Plan (11 weeks total)
1. **Basic Architecture & Database** (3 weeks)
2. **Translation Layers** (3 weeks)
3. **Quality & Data Integration** (2 weeks)
4. **Additional Features** (2 weeks)
5. **Final Preparation** (1 week)

## Commercial Library Considerations

- This is a **closed-source commercial library**
- **Business Model**: Developer licensing for mobile app integration
- **Monetization**: Premium features support
- Focus on **offline capability** and **mobile constraints**
- **SemVer versioning** for releases
- End-developer focused documentation approach

## Development Principles

This project is developed as a **clean Flutter library** following:
- **SOLID principles** for architecture design
- **Clean Code** practices for maintainability
- **Full test coverage** for reliability
- **Commercial licensing** for business use

## Language Setting

По правилам разработки проекта все объяснения и коммуникация должны вестись **на русском языке**.
