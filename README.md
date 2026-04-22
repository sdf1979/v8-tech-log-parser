# CALL.PL (Методика подсчета потребления CPU процессами 1С)

## Основные возможности
- Анализ событий CALL технологического журнала и агрегация контекстов по полю CpuTime

## Параметры командной строки

| Option | Description | Default |
|--------|-------------|---------|
| `--help` | Show help message | — |
| `--dir=DIR` | Directory to search | Current directory (`.`) |
| `--fmt=FORMAT` | File format: `txt` or `html` | `txt` |
| `--cpu-cum-lt=FLOAT` | Max CPU cumulative value | `100.0` |
| `--date-ge=DATE` | Start date (inclusive). Format: `DD-MM-YY HH:MM` | No filter |
| `--date-le=DATE` | End date (inclusive). Format: `DD-MM-YY HH:MM` | No filter |
| `--title=TITLE` | Title | Empty (all titles) |


# Методика обработки технологического журнала 1С

## Шаг 1. Удаление BOM (Byte Order Mark)
```bash
find /home/sdf1979/v8_tech_log/JMR/1c_log/ -name '*.log' -exec perl -i -pe 'if($.==1){s/\xEF\xBB\xBF//}' {} \;
```

## Шаг 2. Добавление метки времени и нормализация переносов строк
```bash
find /home/sdf1979/v8_tech_log/JMR/1c_log/ -name '*.log' -exec perl -i -ne 'if($.==1){($ts)=$ARGV=~/(\d{8})/};if(/^\d\d:\d\d\.\d{6}-/){$b=~s/\r/\x01/g;$b=~s/\n/\x02/g;print "$ts:$b$p" if$p;$b=""}else{$b.=$p};$p=$_;if(eof){$b=~s/\r/\x01/g;$b=~s/\n/\x02/g;print "$ts:$b$p"}' {} \;
```

## Шаг 3. Формирование данных за необходимый период
```bash
perl <>/call.pl --dir /home/sdf1979/v8_tech_log/JMR/1c_log --fmt=html --title JMR --cpu-cum-lt 80 --date-ge '20-04-26 03:00' --date-le '20-04-26 06:00' > /home/sdf1979/v8_tech_log/night.html
```