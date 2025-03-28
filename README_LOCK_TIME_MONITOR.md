# Мониторинг времени блокировки ПК для Zabbix

Это решение позволяет отслеживать общее время блокировки ПК в Windows с помощью Zabbix Agent. Оно ведет учет как последних событий блокировки/разблокировки, так и общего времени, проведенного в заблокированном состоянии.

## Возможности

- Отслеживание текущего статуса блокировки ПК (заблокирован/разблокирован)
- Запись времени каждой блокировки и разблокировки
- Расчет длительности каждой блокировки в секундах
- Подсчет общего времени блокировки ПК
- Подсчет ежедневного времени блокировки ПК (сбрасывается в полночь)
- Ведение истории всех событий блокировки/разблокировки
- Автоматический запуск мониторинга при загрузке системы

## Преимущества

- Не требует настройки аудита событий Windows
- Использует несколько методов для надежного определения статуса блокировки
- Работает на всех версиях Windows (7, 8, 10, 11, Server)
- Минимальное потребление ресурсов
- Простая установка и настройка

## Установка

1. Запустите скрипт установки от имени администратора:
   ```powershell
   .\install_lock_time_tracker.ps1
   ```

2. Скрипт выполнит следующие действия:
   - Копирование скриптов мониторинга в директорию Zabbix Agent
   - Копирование файлов конфигурации в директорию Zabbix Agent
   - Создание запланированной задачи для автозапуска при старте системы
   - Перезапуск службы Zabbix Agent
   - Запуск скрипта мониторинга в фоновом режиме

## Настройка Zabbix

1. Импортируйте шаблон `template_lock_time_monitor.xml` в Zabbix
2. Привяжите шаблон к хостам, которые вы хотите мониторить
3. Проверьте, что данные начали поступать (это может занять несколько минут)

## Доступные метрики

В Zabbix будут доступны следующие метрики:

1. **Статус блокировки ПК**
   - Ключ: `system.lock.status`
   - Тип: Числовой (беззнаковый)
   - Значения: 0 = разблокирован, 1 = заблокирован

2. **Время последней блокировки**
   - Ключ: `system.lock.last_lock_time`
   - Тип: Текст
   - Формат: YYYY-MM-DD HH:MM:SS

3. **Время последней разблокировки**
   - Ключ: `system.lock.last_unlock_time`
   - Тип: Текст
   - Формат: YYYY-MM-DD HH:MM:SS

4. **Длительность последней блокировки**
   - Ключ: `system.lock.last_duration`
   - Тип: Числовой (беззнаковый)
   - Единицы измерения: секунды

5. **Общее время блокировки**
   - Ключ: `system.lock.total_time`
   - Тип: Числовой (беззнаковый)
   - Единицы измерения: секунды
   - Описание: Общее время, проведенное в заблокированном состоянии с момента установки

6. **Ежедневное время блокировки**
   - Ключ: `system.lock.daily_time`
   - Тип: Числовой (беззнаковый)
   - Единицы измерения: секунды
   - Описание: Общее время, проведенное в заблокированном состоянии за текущий день (сбрасывается в полночь)

## Тестирование

Для тестирования решения:

1. Заблокируйте компьютер (Win+L)
2. Подождите несколько минут
3. Разблокируйте компьютер
4. Проверьте значения элементов данных в Zabbix

Вы также можете проверить файлы в директории `C:\ProgramData\PC_Lock_Monitor\`:

- `lock_time_tracker.log` - журнал событий блокировки/разблокировки
- `lock_status.txt` - текущий статус блокировки
- `last_lock_time.txt` - время последней блокировки
- `last_unlock_time.txt` - время последней разблокировки
- `last_lock_duration.txt` - длительность последней блокировки
- `total_lock_time.txt` - общее время блокировки
- `daily_lock_time.txt` - ежедневное время блокировки
- `lock_history.csv` - история всех событий блокировки/разблокировки

## Устранение неполадок

Если мониторинг не работает:

1. Проверьте, запущена ли запланированная задача:
   ```powershell
   Get-ScheduledTask -TaskName "PC_Lock_Time_Tracker" | Get-ScheduledTaskInfo
   ```

2. Проверьте содержимое журнала:
   ```powershell
   Get-Content "C:\ProgramData\PC_Lock_Monitor\lock_time_tracker.log"
   ```

3. Проверьте, работает ли служба Zabbix Agent:
   ```powershell
   Get-Service "Zabbix Agent"
   ```

4. Проверьте конфигурацию Zabbix Agent:
   ```powershell
   Get-Content "C:\Program Files\Zabbix Agent\zabbix_agentd.conf"
   ```

## Как это работает

Решение использует несколько методов для определения статуса блокировки:

1. Проверка наличия отключенных сеансов с помощью команды `quser`
2. Проверка наличия активного пользователя с помощью WMI (Win32_ComputerSystem)
3. Проверка наличия процесса LogonUI.exe, который запускается при блокировке экрана

Скрипт запускается в фоновом режиме и проверяет изменение статуса блокировки каждые 5 секунд. При изменении статуса он записывает событие в журнал и обновляет файлы состояния.

Когда ПК разблокируется, скрипт рассчитывает длительность блокировки и добавляет ее к общему и ежедневному счетчикам времени блокировки. Ежедневный счетчик сбрасывается в полночь.

## Дополнительные возможности

Вы можете настроить триггеры в Zabbix для оповещения о длительной блокировке ПК. Например:

- Оповещение, если ПК заблокирован более 10 минут
- Оповещение, если ПК заблокирован более 1 часа
- Оповещение, если общее время блокировки за день превышает 4 часа

Эти триггеры уже настроены в шаблоне `template_lock_time_monitor.xml`.
