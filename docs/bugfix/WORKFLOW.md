# WORKFLOW — как работать над багами в этом клоне

Локальный документ кампании. Общие правила проекта — `AGENTS.md` (включая раздел о кампании),
состояние — `PROGRESS.md`, реестр — `docs/bugfix/BUGS.md`.

## 1. Что это за репозиторий

EffectCraft — чистый Rust, workspace из 35 крейтов + 3 приложений (`apps/effectcraft`,
`apps/effectcraft-cli`, `apps/effectcraft-web`) плюс `xtask`. Слои L0–L6, зависимости только вниз
(проверяет `cargo xtask layers`). Всё, что делает пользователь, — команда движка с id; UI, CLI,
control-канал и MCP идут через один реестр команд.

Точки входа для понимания кода:

- `docs/architecture.md` — слои, модель документа, `Tick`-время, команды, пайплайн.
- `docs/testing.md` — что и как тестируется, headless-снимки UI, бенчмарки.
- `docs/gaps.md` — известные отставания и приоритетные направления.
- `crates/<crate>/README.md` — назначение крейта.
- `CLAUDE.md` — краткие инструкции для агентов (обновляются upstream).

## 2. Окружение

| Инструмент | Зачем | Статус на 2026-10-29 |
|---|---|---|
| Git 2.56 | версии, хуки, `xtask assets` (`git ls-files`) | установлен, **не в `PATH`** |
| Rust stable (≥1.95) + `rustfmt` + `clippy` | сборка, `cargo xtask ci` | **не установлен** |
| MSVC Build Tools 2022 (workload VCTools) + Windows SDK | линковка | **не установлен** |
| `wasm32-unknown-unknown` target | гейт `wasm` в `cargo xtask ci` | нет |
| `cargo-nextest` ≥ 0.9.150 | быстрый прогон тестов (CI использует, если есть) | нет |
| PowerShell 5.1 | скрипты проверок и хуков | есть |
| `ffmpeg`/`ffprobe` (опционально) | внешние оракулы тестов экспорта, не линкуются | нет |
| `wasm-bindgen-cli` 0.2.129 (опционально) | только `cargo xtask web`, в CI не нужен | нет |

Установка всего обязательного:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-toolchain.ps1
```

Скрипт идемпотентен. Шаг MSVC требует прав администратора (UAC). Если Build Tools уже стоят в
нестандартном месте — `-SkipVs`. Дополнительно: `-WithFfmpeg`, `-SkipNextest`.

После установки один раз включить хуки:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-hooks.ps1
```

## 3. Проверки

Полный гейт проекта — `cargo xtask ci`: `fmt --check`, `clippy --workspace --all-targets -D warnings`,
тесты (`cargo nextest run`, отдельно `effectcraft-gpu` одним процессом, отдельно doctests),
`pdf-deps` (пиннинг PDF-парсера), `layers`, `assets` (атрибуция ассетов), `wasm`.

Локально он разбит на два тира:

```powershell
# быстрый: fmt + clippy/tests только изменённых крейтов + layers + assets
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode fast

# полный: cargo xtask ci
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode full

# явно указать крейты (когда git-детект не подходит)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Crate effectcraft-render,effectcraft-engine
```

`check.ps1` сам находит `git` и `cargo` и добавляет их в `PATH` дочерних процессов. Код возврата
0 = зелёный.

Хуки: `.githooks/pre-commit` запрещает коммит в `main` и запускает `-Mode fast`;
`.githooks/pre-push` запрещает push в `origin`. Обход (только осознанно, с записью в
`PROGRESS.md`): `SKIP_CHECKS=1 git commit ...`, `ALLOW_PUSH=1 git push ...`.

## 4. Рабочий цикл одного бага

```powershell
$git = "C:\Program Files\Git\cmd\git.exe"

# 0. синхронизация (main только читаем)
& $git switch main
& $git fetch origin
& $git status --short                 # должно быть пусто; иначе — разобраться, не твоё ли

# 1. ветка на баг (или работа в bugfix/campaign)
& $git switch bugfix/campaign
& $git switch -c bugfix/BF-012-broken-psd

# 2. сначала падающий тест, потом фикс
#    тест кладём рядом с существующими: crates/<crate>/tests/it/<file>.rs

# 3. проверки
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode fast

# 4. коммит (обновить PROGRESS.md и docs/bugfix/BUGS.md в этом же коммите)
& $git add -A
& $git commit -m "BF-012: не падать на битом PSD (crates/psd)"

# 5. перед закрытием бага — полный гейт
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Mode full
```

Требования к фиксу (из `AGENTS.md`, раздел «Never crash»): без `unwrap`/`expect`/`panic!` в
не-тестовом коде, индексация и арифметика от входных данных — через `get()` и checked/saturating,
рекурсия с ограничением глубины, ошибки — через `Result` своего крейта, и обязательный
регрессионный тест, который падал до фикса.

Полезные точечные команды:

```powershell
cargo test -p effectcraft-render                     # тесты одного крейта
cargo test -p effectcraft-engine --test it commands:: # один файл интеграционных тестов
cargo clippy -p effectcraft-render --all-targets -- -D warnings
cargo run -p effectcraft -- --demo                   # приложение
cargo run -p effectcraft-cli -- info --json          # headless CLI
cargo run -p effectcraft -- --control 9877           # живой UI + control-канал
```

## 5. Два агента на одном дереве

- Не собирать одновременно в один `target/`: Cargo блокирует каталог. У каждого свой:
  `$env:CARGO_TARGET_DIR = "target/deepseek"` / `"target/codex"` (каталог в `.gitignore`).
- Один агент — одна ветка в работе. Перед переключением: `git status` должен быть чистым,
  либо изменения закоммичены.
- Эстафета описана в `AGENTS.md` («Эстафета между агентами») и в `PROGRESS.md` §3.
- Если предыдущий агент оставил `in-progress`, сначала прочитать его заметки в `BUGS.md` и
  `docs/bugfix/bf/BF-<nnn>.md`, затем `git log --oneline -5`.

## 6. Типовые проблемы (Windows)

| Симптом | Причина | Решение |
|---|---|---|
| `git: не найден` | Git не в `PATH` | полный путь `C:\Program Files\Git\cmd\git.exe` или `scripts/*.ps1` |
| `link.exe not found` / `LINK : fatal error` | нет MSVC Build Tools | `scripts/setup-toolchain.ps1` (нужен UAC) |
| `cargo xtask ci` падает на `wasm` | нет target | `rustup target add wasm32-unknown-unknown` |
| `nextest ... REQUIRED_VERSION_NOT_MET` | старый cargo-nextest | `cargo install cargo-nextest --version 0.9.150 --locked` |
| `error: could not compile ... (proc macro)` при `cargo check` | нет линковщика (proc-macro — dll) | то же: MSVC Build Tools |
| Хук не срабатывает | не включён `core.hooksPath` | `scripts/install-hooks.ps1` |
| `pre-commit: refusing to commit on 'main'` | работа в `main` | `git switch -c bugfix/BF-<nnn>-<slug>` |
| Долгая первая сборка | git-зависимости (`craft-libs`, `filmcraft`, `egui`-форк) | один раз `cargo fetch`, дальше из кеша |
| Кириллица в консоли «кракозябрами» | консоль в CP866 | файлы читать редактором/`read`, в PowerShell: `[Console]::OutputEncoding = [Text.Encoding]::UTF8` |
| `target/` разросся | dev+release+wasm | `cargo clean -p <crate>` точечно; полный `cargo clean` — только по согласованию |

## 7. Что считается «готово» (чек-лист)

- [ ] Есть падавший до фикса тест, теперь зелёный.
- [ ] `check.ps1 -Mode fast` — зелёный.
- [ ] `check.ps1 -Mode full` — зелёный (или исключение записано в `PROGRESS.md`).
- [ ] `PROGRESS.md` §2–§4 и `docs/bugfix/BUGS.md` обновлены.
- [ ] Коммит с `BF-<nnn>` в заголовке, тело содержит причину и проверки.
- [ ] Ветка не `main`, push не делался.
- [ ] Рабочее дерево чистое (или описано в `PROGRESS.md`).
