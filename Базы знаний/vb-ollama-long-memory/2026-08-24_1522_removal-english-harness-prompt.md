# Ollama 0.33.0-rc2: убран английская boilerplate из стартового system-prompt

Дата/время: 2026-08-24 ~15:22, бинарник v0.33.0-rc2 (собственный билд).

## Что сделано
В `cmd/agent_tui.go` → `agentDefaultSystemPromptWithWorkingDir()` удалён весь
английский harness-boilerplate из system-prompt, который TUI вставляет при старте
(«You are running in Ollama... model is <name>.», «Be concise...», «Use bash carefully...»,
«Tell the user about meaningful changes...»). Оставлено ТОЛЬКО:
- `Current date: <дата>`
- `Current working directory: "<cwd>"`

Функция теперь:
    func agentDefaultSystemPromptWithWorkingDir(now time.Time, modelName string, workingDir string) string {
        date := now.Format("Monday, January 2, 2006")
        parts := []string{"Current date: " + date + "."}
        if workingDir != "" { parts = append(parts, "Current working directory: "+strconv.Quote(workingDir)+".") }
        return strings.Join(parts, "\n")
    }

Побочные правки в том же файле:
- удалён импорт `runtime` (раньше использовался только для shellName bash/PowerShell — теперь не нужен).
- параметр `modelName` в этой функции остался в сигнатуре, но не используется (в Go так допустимо; компилируется).

## Важно: репозиторий ПЕРЕДВИНУТ
Путь к исходникам: `/home/voron/Документы/VB-ollama/GitHub ollama/ollama`
(в старых нотах был `/home/voron/Документы/VB-ollama/ollama` — его больше нет).

## Сборка (проверено 2026-08-24, EXIT=0)
    cd "/home/voron/Документы/VB-ollama/GitHub ollama/ollama"
    go build ./cmd/                       # быстрая проверка компиляции
    go build -ldflags "-X github.com/ollama/ollama/version.Version=0.33.0-rc2" -o /tmp/ollama-patched .
    sudo mv /tmp/ollama-patched /usr/local/bin/ollama && sudo chmod 755 /usr/local/bin/ollama
mv атомарен — работающие сервер/TUI продолжают жить со старым inode, перезапуск не нужен.
Следующий старт TUI подхватит новый бинарник (новый system-prompt без английской boilerplate).

## Откат
`git checkout -- cmd/agent_tui.go` в репо + повторная сборка. (Но и другие свои правки
в cmd/agent_tui.go из прошлых сессий — git покажет diff; откатывать только эту функцию.)
