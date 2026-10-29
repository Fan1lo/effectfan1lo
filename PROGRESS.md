# PROGRESS — кампания по исправлению багов EffectCraft

> **Этот файл — единственный источник правды о состоянии кампании.**
> Его читают перед началом работы и обновляют в том же коммите, что и фикс.
> Правила работы — `AGENTS.md`, раздел «ЛОКАЛЬНАЯ КАМПАНИЯ ПО ИСПРАВЛЕНИЮ БАГОВ».
> Реестр багов — `docs/bugfix/BUGS.md`. Команды и окружение — `docs/bugfix/WORKFLOW.md`.

## 0. Как вести этот файл

- «Сейчас» и «Следующий шаг» заполняются **в конце каждой сессии**, а не в начале.
- «Журнал сессий» — дописывать в конец, старые записи не переписывать.
- «Снимок» обновляется, когда меняется ветка, baseline или статус тулчейна.
- Одно утверждение = одна строка с датой и автором (`DeepSeek`, `Codex`, `owner`).
- Незакоммиченные правки в рабочем дереве описываются в «Сейчас» (что и почему не закоммичено).

## 1. Снимок состояния

| Параметр | Значение |
|---|---|
| Репозиторий | `C:\Users\ytrew\Projects\effectcraft` |
| Remote `origin` | `https://github.com/storytold/effectcraft.git` (upstream, только чтение) |
| Baseline-коммит | `990fa668cd3898935de91529425bb691a4dd3cb1` (2026-10-29), тег `v0.18.0-63-g990fa668` |
| Локальный тег | `campaign-baseline-2026-10-29` |
| Ветка `main` | чистая, синхронна `origin/main`, коммитить в неё нельзя |
| Рабочая ветка | `bugfix/campaign` (создана от baseline) |
| Версия workspace | `0.18.0`, edition 2024, `rust-version = 1.95` |
| Крейтов / файлов `.rs` | 35 крейтов + 3 приложения, 974 файла `.rs` (~18.9 МБ) |
| Тулчейн Rust | частично: rustup, rustc/cargo 1.99.1, rustfmt, clippy, wasm32 (установлено 2026-10-29) |
| MSVC / Windows SDK | **нет** (по решению владельца не ставим: слабый ноутбук) |
| Git | 2.56.0.windows.4, `C:\Program Files\Git\cmd\git.exe`; добавлен в пользовательский `PATH` |
| Хуки | установлены (`core.hooksPath = .githooks`) |
| Проверки кода | **GitHub Actions на форке**; локальная компиляция не выполняется |
| Последний полный `cargo xtask ci` | не запускался и локально не планируется |
| Последний зелёный коммит | `campaign-baseline-2026-10-29` (проверок не было — см. блокеры) |

## 2. Сейчас

**2026-10-29, owner + агент:** окружение подготовлено, исходный код **не изменялся**.
Созданы: раздел в `AGENTS.md`, этот файл, `docs/bugfix/BUGS.md`, `docs/bugfix/WORKFLOW.md`,
`scripts/check.ps1`, `scripts/setup-toolchain.ps1`, `scripts/install-hooks.ps1`, `.githooks/*`.
Рабочее дерево: только новые файлы + дописанный раздел `AGENTS.md` (коммит — после установки
тулчейна и первого зелёного прогона).

**Ни один баг ещё не взят в работу.** Список багов в `docs/bugfix/BUGS.md` пуст (только шаблон).

## 3. Следующий шаг

1. Проверки — в GitHub Actions: создать форк `storytold/effectcraft`, добавить remote `fork`,
   включить Actions в форке, запустить workflow `ci.yml` на ветке `bugfix/campaign`.
   Локально ничего не собираем (слабый ноутбук, нет MSVC-линковщика).
2. Внести первые баги в `docs/bugfix/BUGS.md` (список от владельца) и начать с P0/P1.
3. Локальный цикл: правка → `git commit` (хук быстрых проверок отключён осознанно, см. журнал) →
   прогон кода в Actions → запись результата в этот файл.

## 4. Доска (кратко; подробности — в `docs/bugfix/BUGS.md`)

| Статус | Кол-во | Примечание |
|---|---:|---|
| todo | 0 | реестр пуст, ждём список от владельца |
| in-progress | 0 | |
| blocked | 0 | |
| done | 0 | |

## 5. Блокеры и открытые вопросы

| # | Блокер | Что нужно | Статус |
|---|---|---|---|
| B1 | Локальная сборка невозможна: нет MSVC-линковщика | решение владельца — компиляция и тесты в GitHub Actions, локально не ставим | принят |
| B2 | Проверки в Actions требуют форка с включёнными Actions | форк + remote `fork` + запуск `ci.yml` | открыт |
| B3 | Нет списка багов от владельца | перечень симптомов/крашей/приоритетов | открыт |

## 6. Журнал сессий

### 2026-10-29 — owner + агент (подготовка)

- Проверена доступность проекта: `C:\Users\ytrew\Projects\effectcraft` (git-клон, `main`, чисто,
  1317 файлов под контролем версий, синхронно `origin/main`).
- Изучены: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `Cargo.toml` (workspace), `xtask/src/main.rs`
  (гейты `fmt/clippy/tests/pdf-deps/layers/assets/wasm`), `docs/architecture.md`, `docs/testing.md`,
  `.github/workflows/ci.yml`, `.cargo/config.toml`, `.config/nextest.toml`.
- Создана инфраструктура кампании (документы, скрипты, хуки, ветка, тег, резервный bundle).
- Исходный код не тронут: изменения — только новые файлы и дописанные разделы `AGENTS.md`.
- Установлен Rust 1.99.1 (rustup, rustfmt, clippy, wasm32). Установка `cargo-nextest` и MSVC
  Build Tools **отменена владельцем**: ноутбук слабый, компиляция и тесты — в GitHub Actions.
  MSVC не установлен, локальная сборка невозможна — так и задумано.
- Добавлены правила экономии контекста (10 пунктов) в `AGENTS.md`.

## 7. Решения (короткие ADR)

- **R1.** `main` остаётся чистым зеркалом upstream; вся работа — в `bugfix/campaign` и
  `bugfix/BF-*`. Причина: возможность в любой момент сравнить с upstream и откатиться.
- **R2.** Один баг = один коммит с ID `BF-<nnn>`; `PROGRESS.md` и `BUGS.md` обновляются в том же
  коммите. Причина: два агента работают по очереди, нужен однозначный след.
- **R3.** Двухуровневые проверки: `fast` (fmt + clippy/tests изменённых крейтов + layers + assets)
  на коммит, `full` (`cargo xtask ci`) перед закрытием бага. Причина: полный гейт слишком долгий
  для каждого коммита, но и без него нельзя.
- **R4.** Отдельный `CARGO_TARGET_DIR` на агента. Причина: одновременная сборка в один `target/`
  блокируется file-lock'ом Cargo.
- **R5.** Push в `origin` запрещён хуком. Причина: `origin` — чужой репозиторий.
- **R6.** Не добавляем `.gitattributes` и не воюем с `core.autocrlf=true`. Причина: массовая
  перенормализация дала бы диф на весь репозиторий.

## 8. Быстрые команды

```powershell
# состояние
& "C:\Program Files\Git\cmd\git.exe" status --short
& "C:\Program Files\Git\cmd\git.exe" log --oneline -5

# проверки
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode fast
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode full
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Crate effectcraft-render

# коммит
& "C:\Program Files\Git\cmd\git.exe" add -A
& "C:\Program Files\Git\cmd\git.exe" commit -m "BF-012: <что> (crates/<crate>)"
```
