# Участие в разработке

Спасибо за интерес к проекту! Ниже — минимальные требования, чтобы изменения
было легко проверить и принять.

## Требования

- Debian 13 (trixie) или совместимый дистрибутив с KDE Plasma 6.3+;
- Qt 6.8+, `kpackagetool6`, `qt6-declarative-dev-tools` (для `qmllint`);
- для запуска виджета: `plasma-workspace`, `qml6-module-qtmultimedia`,
  `libqt6multimedia6`, `qml6-module-org-kde-kwindowsystem`,
  `qml6-module-org-kde-plasma-plasma5support`.

## Установка для разработки

```bash
./install.sh
systemctl --user restart plasma-plasmashell.service
```

После изменений QML достаточно повторить обе команды. Логи plasmashell:

```bash
journalctl --user -u plasma-plasmashell.service -f
```

## Проверка перед коммитом

```bash
./scripts/check.sh
```

Скрипт проверяет синтаксис QML (`qmllint --bare`) и структуру KPackage
(`kpackagetool6`). Полноценный `qmllint` без `--bare` в обычной оболочке будет
предупреждать об импортах `org.kde.plasma.*`: эти модули регистрирует
plasmashell во время работы.

## Стиль кода

- QML: отступы 4 пробела, пробелы вокруг операторов, `id` только там, где он
  нужен;
- комментарии к коду — на английском, пользовательские строки интерфейса — на
  русском;
- не добавляйте отладочные `console.log`, `TODO` и закомментированный код;
- новые повторяющиеся элементы интерфейса выносите в отдельные компоненты
  (`package/contents/ui/*.qml`).

## Коммиты и pull request

- один коммит — одно логическое изменение;
- сообщение коммита в повелительном наклонении, например
  `Fix embedded video sink ownership`;
- в pull request опишите, что изменено и как это проверить;
- при изменении поведения обновите `CHANGELOG.md`.

## Лицензия

Отправляя изменения, вы соглашаетесь с тем, что они распространяются на
условиях GPL-3.0-or-later (см. `LICENSE`).
