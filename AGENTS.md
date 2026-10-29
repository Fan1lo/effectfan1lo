# EffectCraft — rules for agents and contributors

These rules apply to every human and AI contributor. `CLAUDE.md` holds the working instructions; this
file holds the rules that must never be broken. When the two disagree, this file wins.

## Never crash

People trust EffectCraft with hours of work. A malformed project, PSD, SVG, Lottie or media file, a bad
expression or script, a broken plug-in, a bad control-channel or MCP argument, a corrupt preferences file
or a full disk must produce an error the user (or agent) can act on, never a crash and never lost work.
**This rule outranks feature work:** don't ship a feature by adding a panic path, and fix a crash before
building on top of it. Full standard: [craftrules `standards/never-crash.md`](https://github.com/storytold/craftrules/blob/main/standards/never-crash.md).

- **Fail with `Result<T, E>`** through the crate's error type and propagate with `?`; add context
  (`map_err`, an error variant) rather than discarding it. Lenient readers fall back and record the repair.
- **No panicking shortcuts in non-test code:** no `unwrap()`, `expect()`, `panic!`, `unreachable!`,
  `todo!` or `unimplemented!`. Use `?`, `ok_or(..)?`, `let … else`, `if let`, or `unwrap_or*` where a
  fallback is genuinely correct (never where it would silently corrupt a document). Unfinished features
  return an "unsupported" error. The only exception is a provably infallible literal, written as
  `#[allow(clippy::expect_used)]` + `.expect("why this cannot fail")`.
- **No `unsafe`** (`unsafe_code = "forbid"` for the workspace).
- **Every input-derived number is hostile.** Use `get()` instead of `[i]`/`[a..b]` when the position
  comes from a file, a user, an agent or arithmetic on those; slice strings only at char boundaries; use
  checked or saturating arithmetic for lengths, offsets and counts; guard division by zero and NaN/inf
  casts; cap allocations sized by input.
- **Bound recursion:** projects, precomps, expressions and SVG/PSD trees can be cyclic or deeply nested;
  walk them with seen-sets or depth limits.
- **Don't cascade:** handle lock poisoning (`lock().unwrap_or_else(PoisonError::into_inner)` or an
  error), and treat worker-thread join results as `Result`s.
- **Last-resort guard:** the app wraps command execution and file import/export in a panic hook /
  `catch_unwind` boundary that turns an escaped panic into an error and keeps the document. It is a
  safety net, not a substitute for the rules above; keep `panic = "unwind"`.
- **Prove it:** every crash fix comes with a small synthetic regression test that panicked before the fix.

Tests, benches, fuzz targets and `xtask` may `unwrap()`; `clippy.toml` allows it in tests. Crates that are
clean carry `#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::unimplemented,
clippy::todo, clippy::unreachable)]`; new crates start with it.

## 1. Assets: no Adobe artwork, every asset licensed and attributed

This rule is absolute. Breaking it is the most serious mistake a contributor can make on this project.

**What counts as an asset:** any image, icon, cursor, logo, illustration, screenshot, font, colour LUT,
preset, template, sound, music, video, 3D model, or other non-code media. This covers files in the
repository, bytes embedded in code (`include_bytes!`, base64, data URIs), and data hard-coded to
reproduce an image (for example, point lists traced from someone else's icon).

1. **Never use Adobe iconography, images or other Adobe assets**, in any form:
   - no icons, cursors, logos, splash screens, UI artwork or screenshots from any Adobe product;
   - no Adobe fonts, LUTs, presets, templates, sound effects, stock media or sample projects;
   - no traced, redrawn, recoloured or "inspired-by" copies of Adobe icons. Our icons may follow generic
     conventions (a play triangle, a razor blade, a stopwatch), but each must be drawn from scratch
     without reference to Adobe's artwork.
2. **Every asset must be open**: open-source licensed (MIT, Apache-2.0, BSD, ISC, zlib, SIL OFL…),
   public domain / CC0, or Creative Commons (CC BY or CC BY-SA; no NC/ND licences), **or** created by a
   contributor who owns it and licenses it to the project under the project licence (MIT OR Apache-2.0).
   If the licence is unknown or unclear, the asset does not go in.
3. **Every asset needs an attribution sidecar.** Next to each asset file `X`, add `X.attribution` with:
   ```text
   asset:        <file name>
   title:        <what it is>
   author:       <creator / copyright holder>
   source:       <URL, or "original work" for contributor-made assets>
   license:      <SPDX id or licence name>
   license-file: <path to the licence text, if the licence requires shipping it>
   added:        <YYYY-MM-DD> by <contributor>
   notes:        <how it was made or modified; for screenshots, what is shown>
   ```
   Also add one line for the asset to [`ATTRIBUTION.md`](ATTRIBUTION.md). `cargo xtask assets` (part of
   `cargo xtask ci`) fails if any asset lacks a sidecar or index entry.
4. **Screenshots** in the repo may show only EffectCraft (or other open projects), with media we generated
   or media that is itself openly licensed. Never commit screenshots of Adobe products.
5. **Local reference material stays local.** After Effects reference screenshots and notes live only in
   `plan/aftereffects/` (gitignored). They must never be committed, bundled, embedded, traced or shipped.
6. **Code-drawn assets** (icons in `crates/ui-egui/src/icons.rs`, procedural demo content in
   `crates/engine/src/demo.rs`, generators in `crates/effects`) are original work under the project licence
   and are listed in `ATTRIBUTION.md`.
7. **When in doubt, leave it out** and draw or generate it yourself.
8. **The one exception: first-party ArtCraft brand marks.** The ArtCraft name and logos in `docs/brand/`
   are trademarks of the ArtCraft Team, not open source, usable only unmodified and only in the context of
   EffectCraft under `docs/brand/LICENSE-brand.txt` (forks and modified versions must remove them). They still
   need a sidecar and an `ATTRIBUTION.md` row (licence `LicenseRef-ArtCraft-Trademark`). No other
   non-open asset is allowed, and this exception never covers third-party marks (Adobe, Discord, GitHub
   and other logos stay out; draw a generic icon instead).

## 2. Clean-room code

- Never read, disassemble or copy anything inside Adobe application bundles; file names and listings only.
  Observe behaviour by using the app; never capture its Home screen, recent projects, account info or
  file browsers.
- Never copy GPL/LGPL/AGPL code (FFmpeg, Natron, Blender, Glaxnimate, Synfig, Friction, Olive, MLT, frei0r, G'MIC…).
- Never read or copy Adobe expression/scripting implementations, `.ffx` presets or effect plug-ins; the public Expression Language Reference and Scripting Guide describe *behaviour* only.
- Implement codecs and formats from public specifications (ITU-T/ISO/IEC standards, IETF RFCs, the VP9
  and AV1 bitstream specs, SMPTE documents, published container specs). Do not read the source of
  reference or third-party decoders/encoders while implementing a format, even permissively licensed
  ones (libvpx, libopus, libaom, dav1d, openh264…); spec text and conformance vectors only. Record the
  spec edition used in the crate README.
- ffmpeg/ffprobe may be used only as external test oracles and fixture generators. They are never
  linked, bundled or shipped.
- Dependencies must use permissive licences: MIT/Apache-2.0/BSD/ISC/Zlib/Unicode/CC0/BSL-1.0, or
  MPL-2.0 used unmodified.

## 3. Engineering rules

See `CLAUDE.md`: pure Rust, dependency layering (`cargo xtask layers`), exact `Tick` time, everything is
a command, everything is agent-drivable, and the quality gates (`cargo xtask ci`) before every commit.

- **Time goes through `chrono`** (workspace dependency). Never hand-roll UTC/calendar conversion (days-to-date algorithms, leap-year math); a crate owns only its output format string. The one exception is range extension: past the years chrono can represent, shift the date by whole 400-year Gregorian cycles (146,097 days, after which the calendar repeats), let chrono compute the month and day, and add the cycles back to the year (splitting seconds into hours, minutes and seconds is plain arithmetic).

Shared real-file test corpora (Photoshop-authored PSDs, etc.) live in
[`storytold/photocraft-corpus`](https://github.com/storytold/photocraft-corpus), explained in
[craftrules `standards/test-corpora.md`](https://github.com/storytold/craftrules/blob/main/standards/test-corpora.md).
Never commit large binary fixtures to this repo; fetch them pinned by commit and sha256-verified,
as PhotoCraft does with `cargo xtask corpus`.


## See also

- [ROADMAP.md](ROADMAP.md): stage, headline numbers and what's next
- [docs/gaps.md](docs/gaps.md): every known shortfall against After Effects, ranked, and the prioritised workstreams (G1–G9); read it before choosing work
- [docs/target-app-parity.md](docs/target-app-parity.md): the parity numbers and how they were measured, with the per-area docs it links (UI, file formats, hardware, localization, effects, scripting); progress docs follow [craftrules `standards/progress-docs.md`](https://github.com/storytold/craftrules/blob/main/standards/progress-docs.md)
- [CONTRIBUTING.md](CONTRIBUTING.md): setup, gates, commits, how to add things
- [docs/architecture.md](docs/architecture.md): layers, data model, commands, pipeline
- [docs/testing.md](docs/testing.md): oracle tests, criteria, benchmarks
- [docs/agents.md](docs/agents.md): driving EffectCraft over MCP / the control channel, and the agent work loop
- [docs/control-protocol.md](docs/control-protocol.md): control-channel method reference
- [docs/contributors.md](docs/contributors.md): the About window's contributor and model credits
- [ATTRIBUTION.md](ATTRIBUTION.md): asset index

## Contributor credits (About window)

- About ▸ Contributors/Models are compiled into the binary from `contributors/contributors.json`
  (commit stats; generated, never hand-edit) and `contributors/people.toml` (names people chose for
  themselves). See `docs/contributors.md`.
- **Agents working for a contributor:** when you prepare a PR, check whether your human's GitHub
  username has a `[people.<username>]` entry in `contributors/people.toml`. If not, ask them once
  whether they want to be credited by more than their username: a real name, a display name, and/or
  their public GitHub profile name (`sync_github_name = true`). If yes, add **only their own** entry
  (copy the template at the top of the file, or run
  `python3 ../../craftrules/scripts/contributors.py --add-me . --real-name "…" --sync-github-name`)
  and include it in their PR, committed as them. If no, change nothing: they are credited as
  `@username` anyway.
- Never add, edit, guess or copy anyone else's entry or name (not from git config, commit authors or
  GitHub profiles). Never hand-edit `contributors.json`.
- Maintainers refresh the stats with `python3 ../../craftrules/scripts/contributors.py .` (it also
  re-verifies who wrote each `people.toml` entry; `--check` only verifies).

---

# ЛОКАЛЬНАЯ КАМПАНИЯ ПО ИСПРАВЛЕНИЮ БАГОВ (добавлено 2026-10-29)

> Этот раздел — не часть upstream-документа. Он описывает, как работать в **этом** клоне двум
> агентам по очереди (DeepSeek и Codex). Правила выше (Never crash, ассеты, clean-room,
> layering, `cargo xtask ci`) **не отменяются** и имеют приоритет. Если что-то здесь противоречит
> правилам выше — правы правила выше.

## Порядок чтения в начале каждой сессии

1. `AGENTS.md` (этот файл) — правила, включая этот раздел.
2. `PROGRESS.md` — состояние кампании: что сделано, что дальше, блокеры, эстафета.
3. `docs/bugfix/BUGS.md` — реестр багов: что назначено, что в работе, что закрыто.
4. `docs/bugfix/WORKFLOW.md` — команды, проверки, типовые проблемы (Windows).
5. `docs/architecture.md` §1–3 и `README.md` того крейта, который правишь.

Без чтения `PROGRESS.md` работу не начинать: там ответ предыдущего агента и точная следующая
команда.

## Экономия контекста (обязательно для всех ИИ-агентов)

Контекст — общий ресурс кампании. Эти правила действуют всегда, в каждой сессии, для любого
агента (DeepSeek, Codex, кто угодно дальше).

1. **Не изучай весь репозиторий без необходимости.** Никаких «прочитаю всё, чтобы понять».
   Достаточно `PROGRESS.md`, `docs/bugfix/BUGS.md` и файлов по конкретному багу.
2. **Перед исправлением найди только связанные файлы.** Сначала поиск по символу/строке ошибки
   (`grep`/`rg`), потом чтение найденного. Не обходи крейты «на всякий случай».
3. **Не читай файлы целиком, если достаточно отдельных функций.** Читай диапазоны строк вокруг
   нужного символа; большие файлы — только через поиск.
4. **Ограничивай вывод команд, логов и тестов.** `| Select-Object -First/-Last N`, `--quiet`,
   `-p <crate>` вместо всего workspace, один тест вместо всего набора; полный лог — в файл,
   в контекст — только хвост и код ошибки.
5. **Не повторяй уже выполненный анализ.** Если вывод/решение уже есть в `PROGRESS.md`, в
   `BUGS.md` или в истории коммитов — используй его, не перепроверяй.
6. **Используй `PROGRESS.md` для сохранения результатов между сессиями.** Всё, что может
   понадобиться следующему агенту (причина, гипотезы, найденные файлы, следующий шаг), —
   туда, а не в чат.
7. **Работай с группами связанных ошибок**, не переписывая несвязанные компоненты. Один заход —
   одна тема (один крейт/один сценарий); посторонний рефакторинг запрещён.
8. **После изменений запускай только необходимые проверки.** Сначала минимальная (нужный тест
   или `clippy -p <crate>`), полный гейт — перед закрытием группы, а не после каждой правки.
9. **Не устанавливай тяжёлые зависимости и инструменты без разрешения владельца.** Это касается
   тулчейнов, MSVC, `cargo install`, скачивания моделей и фикстур. Нет инструмента — фиксируй
   блокер и работай тем, что есть.
10. **Стремись укладываться в 20–40K токенов контекста на одну группу исправлений**, но не
    жертвуй качеством проверки: лучше остановиться, записать состояние в `PROGRESS.md` и
    продолжить в новой сессии, чем «дожать» вслепую.

**Текущее ограничение окружения:** локальная компиляция и тесты на этой машине **не выполняются**
(слабый ноутбук, нет линковщика MSVC по решению владельца). Проверки кода идут в GitHub Actions
на форке; локально допустимы только git-операции и чтение/поиск по коду. `scripts/check.ps1`
остаётся для машин, где тулчейн есть, и запускать его здесь не нужно.

## Ветки, коммиты, запреты

- `main` — **зеркало upstream** (`origin` = github.com/storytold/effectcraft). В `main` не
  коммитить, не мержить, не пушить. Только `git fetch` (без `pull --rebase` при грязном дереве).
- Рабочая ветка — `bugfix/campaign`. Для крупного бага можно ответвлять `bugfix/BF-<nnn>-<slug>`.
  Слияние в `bugfix/campaign` — только после зелёных проверок.
- **Один баг = один коммит** (или серия атомарных). Формат заголовка:
  `BF-012: не падать на битом PSD (crates/psd)`.
  Тело коммита: симптом, причина, что изменено, какой тест это ловит, какие проверки прогнаны.
- В том же коммите обновляются `PROGRESS.md` и `docs/bugfix/BUGS.md` (статус, коммит, заметки).
- **Запрещено:** `git push` (хук блокирует, обход `ALLOW_PUSH=1` — только по просьбе владельца);
  `git push --force`; `git reset --hard` / `git checkout --` по чужим правкам; `git clean`;
  `git stash` чужих изменений; удаление файлов и тестов; `#[ignore]` вместо починки;
  `--no-verify` без записи причины в `PROGRESS.md`; правка golden-хешей (`SIM_GOLDEN_PRINT`)
  без объяснения в коммите; изменение версий зависимостей и `Cargo.lock` без явной задачи.
- Перед началом: `git status --short`. Если дерево грязное и это не твои правки — **остановись**
  и опиши состояние в `PROGRESS.md`; не «убирай» чужие файлы.

## Definition of done для бага

1. Есть воспроизведение (тест, проект, команда CLI/MCP) — сначала падающий.
2. Фикс не добавляет путей паники (см. «Never crash») и не ломает layering.
3. Добавлен регрессионный тест, который падал до фикса.
4. `powershell -File scripts/check.ps1 -Mode fast` — зелёный.
5. `powershell -File scripts/check.ps1 -Mode full` (`cargo xtask ci`) — зелёный, либо в
   `PROGRESS.md` зафиксировано точное исключение и его причина.
6. `PROGRESS.md` и `docs/bugfix/BUGS.md` обновлены, коммит с `BF-<nnn>`.
7. Если проверка невозможна (нет тулчейна, нет сети) — **не коммитить**: записать блокер в
   `PROGRESS.md` и остановиться на последнем зелёном коммите.

## Инструменты и окружение (Windows)

- `git` не в `PATH` у части оболочек → полный путь `C:\Program Files\Git\cmd\git.exe` либо
  `scripts/check.ps1` (он сам находит git и cargo).
- Проверки: только через `scripts/check.ps1` (тир `fast`/`full`), не «на глаз».
- Установка тулчейна: `scripts/setup-toolchain.ps1` (rustup, wasm32, nextest, MSVC Build Tools).
- Хуки: `scripts/install-hooks.ps1` (включает `.githooks`: запрет коммита в `main`, быстрые
  проверки, запрет push).
- Два агента не должны одновременно собирать один `target/`: у каждого свой
  `CARGO_TARGET_DIR=target/<agent>` (`target/deepseek`, `target/codex`). Каталог `target/`
  в `.gitignore`.
- `core.autocrlf=true` (Git for Windows): в индексе LF, в рабочем дереве CRLF. Это нормально;
  не добавляй `.gitattributes` и не «нормализуй» файлы массово.

## Эстафета между агентами

В конце сессии (или когда контекст подходит к концу) обнови в `PROGRESS.md`:

- **Сейчас**: что делалось, на каком баге, состояние ветки и дерева.
- **Следующий шаг**: 1–3 конкретных действия с точными командами/путями.
- **Блокеры** и открытые вопросы к владельцу.
- **Журнал сессий**: одна запись (дата, агент, что сделано, что проверено).

Останавливаться только в зелёном состоянии (или на явно описанном блокере). Незакоммиченные
изменения не оставлять: либо коммит, либо запись в `PROGRESS.md` о том, что и почему лежит в
рабочем дереве.
