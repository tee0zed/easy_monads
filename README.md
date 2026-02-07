## Not vibecoded (Except READMEs)

# EasyMonad

Монадоподобная обёртка с ранним выходом и расширенными возможностями для Ruby.

## ПОЧЕМУ (WHY)

### Проблема

При разработке бизнес-логики в Ruby-приложениях часто возникают следующие проблемы:

- **Разбросанная обработка ошибок**: try-catch блоки повсюду, нет единого стандарта
- **Отсутствие раннего выхода**: необходимость использовать вложенные условия или множественные return
- **Сложность композиции**: трудно комбинировать несколько операций с правильной обработкой ошибок
- **Повторяющийся код**: логирование, валидация параметров, санитизация — дублируются в каждом сервисе
- **Отсутствие стандартизации**: каждый разработчик решает эти задачи по-своему

### Решение

EasyMonad предоставляет унифицированный паттерн для:

- **Стандартизированной обработки ошибок**: все операции возвращают объект с понятным интерфейсом `success?`/`failure?`
- **Раннего выхода без исключений**: использует `catch/throw` для элегантного прерывания выполнения
- **Простой композиции**: методы `join` и `strict_join!` для объединения операций
- **Встроенного логирования**: автоматическое логирование с метриками производительности
- **Безопасности**: автоматическая санитизация чувствительных параметров
- **Интернационализации**: встроенная поддержка переводов ошибок

## КАК ЭТО РАБОТАЕТ (HOW)

### Архитектура

EasyMonad построен на трёх основных концепциях:

#### 1. Паттерн операции (Operation Pattern)

```ruby
class Operation
  def call
    # Бизнес-логика
  end
  
  class << self
    def call(*args)
      operation = new(*args)
      operation.within_early_exit_block do
        operation.call
        operation
      end
    end
  end
end
```

Каждая операция:
- Инкапсулирует одну бизнес-операцию
- Получает параметры через конструктор
- Возвращает себя для цепочечных вызовов
- Хранит результат и ошибки

#### 2. Ранний выход через catch/throw

```ruby
def within_early_exit_block(&block)
  catch(:critical, &block)
end

def critical_error!(error, description)
  errors.add(error, description)
  throw(:critical, self)  # Немедленный выход без исключения
end
```

Вместо исключений используется механизм `catch/throw`:
- Более производительный чем exceptions
- Не загрязняет stacktrace
- Явное управление потоком выполнения

#### 3. Модульная система

Модули подключаются динамически через конфигурацию:

```ruby
Configuration.include_modules.each do |mod|
  Operation.include str_to_const(mod.to_s)
end
```

Это позволяет:
- Выборочно включать функциональность
- Переопределять поведение модулей
- Добавлять собственные модули

### Поток выполнения

1. **Вызов операции**: `MyOperation.call(params)`
2. **Создание инстанса**: `new(params)`
3. **Обёртка в early-exit блок**: `catch(:critical)`
4. **Логирование старта** (если модуль Logging включён)
5. **Выполнение бизнес-логики**: `call`
6. **Обработка ошибок**:
   - `error()` — добавляет ошибку, продолжает выполнение
   - `critical_error!()` — добавляет ошибку, делает `throw(:critical)`
7. **Логирование завершения**
8. **Возврат операции** с результатом и ошибками

### Объект Errors

Наследуется от Hash для простоты работы:

```ruby
class Errors < Hash
  def add(key, value)
    self[key] ||= value  # Не перезаписывает существующую ошибку
  end
end
```

Это позволяет:
- Хранить множественные ошибки
- Избегать дублирования
- Легко проверять наличие: `errors.any?`

### Интеграция модулей

#### Logging модуль

Переопределяет метод класса `call`:

```ruby
def self.call(*args)
  operation = new(*args)
  operation.within_early_exit_block do
    operation.log_start(operation)
    operation.call
    operation.log_end(operation)
    operation
  end
end
```

#### ParamsSanitizer модуль

Использует regex для замены чувствительных данных:

```ruby
def params_for_logging(params)
  regex = /(#{filter_parameters.join('|')})":"([^"]*)"/
  params.inspect.gsub(regex, '\1":"[FILTERED]"')
end
```

#### I18n модуль

Формирует ключ перевода из имени класса:

```ruby
def desc(error)
  I18n.t("operations.#{self.class.name.underscore.gsub('/', '.')}.#{error}")
end
```

## Установка

Добавьте в ваш Gemfile:

```ruby
gem 'easy_monad'
```

Затем выполните:

```bash
bundle install
```

Или установите напрямую:

```bash
gem install easy_monad
```

## Требования

- Ruby >= 3.3.1

## Использование

### Базовое использование

Создайте класс операции, наследуясь от `EasyMonad::Operation`:

```ruby
class MyOperation < EasyMonad::Operation
  def call
    # Ваша бизнес-логика здесь
    @result = perform_some_work
    
    # Добавление ошибки
    error(:invalid_data, 'Данные невалидны') if invalid?
    
    self
  end
  
  private
  
  def perform_some_work
    # Реализация
  end
  
  def invalid?
    # Проверка
  end
end
```

Вызов операции:

```ruby
operation = MyOperation.call(params: { key: 'value' })

if operation.success?
  puts "Результат: #{operation.result}"
else
  puts "Ошибки: #{operation.errors}"
end
```

### Работа с ошибками

EasyMonad поддерживает два типа ошибок:

#### Обычные ошибки

```ruby
def call
  error(:validation_error, 'Email невалиден') unless valid_email?
  # Операция продолжает выполнение
end
```

#### Критические ошибки (ранний выход)

```ruby
def call
  critical_error!(:unauthorized, 'Требуется авторизация') unless authorized?
  # Код ниже не выполнится, если ошибка возникла
end
```

### Проверка статуса

```ruby
operation = MyOperation.call(params)

operation.success?  # => true если ошибок нет
operation.failure?  # => true если есть ошибки
operation.result    # => результат операции
operation.result!   # => результат или raises ProcessError при ошибках
```

### Объединение операций

#### join - мягкое объединение

```ruby
def call
  other_operation = AnotherOperation.call(params)
  join(other_operation)  # Объединяет ошибки, продолжает выполнение
end
```

#### strict_join! - строгое объединение

```ruby
def call
  other_operation = AnotherOperation.call(params)
  strict_join!(other_operation)  # Прерывает выполнение при наличии ошибок
end
```

### Объект Errors

```ruby
operation.errors.add(:key, 'Описание ошибки')
operation.errors.to_a          # => ["key: Описание ошибки"]
operation.errors.to_s          # => "key: Описание ошибки"
operation.errors.only_messages # => ["Описание ошибки"]
```

## Конфигурация

### Базовая конфигурация

```ruby
EasyMonad::Configuration.configure do |config|
  config.logger = Rails.logger  # Ваш логгер
  config.include_modules = [:params_sanitizer, :logging, :i18n]
  config.filter_parameters = %w[password secret token]
end
```

### Параметры конфигурации

- `logger` - логгер для вывода сообщений (по умолчанию: `Logger.new(STDOUT)`)
- `include_modules` - модули для подключения (по умолчанию: `[:params_sanitizer, :logging, :i18n]`)
- `filter_parameters` - параметры для фильтрации в логах (по умолчанию: `['password', 'password_confirmation', 'secret', 'password_salt']`)
- `rails_environment` - автоматически определяется наличие Rails
- `configured` - флаг конфигурации

## Модули

### Logging

Автоматически логирует начало и окончание операций, а также ошибки:

```ruby
# Логи автоматически включают:
# - Время начала операции
# - Время окончания операции
# - Длительность выполнения
# - Параметры (с санитизацией)
# - Ошибки (если есть)
```

### ParamsSanitizer

Фильтрует чувствительные параметры в логах:

```ruby
# Параметры из filter_parameters будут заменены на [FILTERED]
operation.call(params: { email: 'test@test.com', password: 'secret123' })
# В логах: { email: 'test@test.com', password: '[FILTERED]' }
```

### I18n

Поддержка интернационализации для описаний ошибок:

```ruby
def call
  error(:invalid_email, desc(:invalid_email))
end

# В файле локализации:
# operations:
#   my_operation:
#     invalid_email: "Email адрес невалиден"
```

### Отключение модулей

Если вам не нужны определённые модули:

```ruby
EasyMonad::Configuration.configure do |config|
  config.include_modules = [:logging]  # Только логирование
end
```

## Примеры использования

### Пример 1: Простая валидация

```ruby
class ValidateUser < EasyMonad::Operation
  def call
    error(:empty_name, 'Имя не может быть пустым') if params[:name].blank?
    error(:empty_email, 'Email не может быть пустым') if params[:email].blank?
    
    @result = { valid: true } if success?
    self
  end
end

operation = ValidateUser.call(params: { name: '', email: 'test@test.com' })
operation.errors # => { empty_name: 'Имя не может быть пустым' }
```

### Пример 2: Цепочка операций

```ruby
class CreateUser < EasyMonad::Operation
  def call
    validation = ValidateUser.call(params)
    strict_join!(validation)
    
    user = User.create(params)
    critical_error!(:creation_failed, 'Не удалось создать пользователя') unless user.persisted?
    
    @result = user
    self
  end
end
```

### Пример 3: Использование альтернативного синтаксиса

```ruby
# Использование [] вместо call
operation = MyOperation[params: { key: 'value' }]
```

## Обработка исключений

```ruby
begin
  result = MyOperation.call(params).result!
  # Работа с результатом
rescue EasyMonad::ProcessError => e
  puts "Операция #{e.operation.class} завершилась с ошибками"
  puts "Ошибки: #{e.operation.errors}"
end
```

## Интеграция с Rails

EasyMonad автоматически определяет окружение Rails и интегрируется с:

- `ActionController::Parameters` для санитизации параметров
- `Rails.configuration.filter_parameters` для фильтрации параметров
- `Rails.logger` (если настроен)
- `I18n` для локализации

## Разработка

## Лицензия

Гем доступен как open source под лицензией [MIT License](https://opensource.org/licenses/MIT).

## Автор

T.Zhuk (tee0zed@gmail.com)

## Версия

0.0.3
