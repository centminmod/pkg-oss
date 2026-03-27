# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Guidance

* Ignore GEMINI.md and GEMINI-*.md files
* To save main context space, for code searches, inspections, troubleshooting or analysis, use code-searcher subagent where appropriate - giving the subagent full context background for the task(s) you assign it.
* ALWAYS read and understand relevant files before proposing code edits. Do not speculate about code you have not inspected. If the user references a specific file/path, you MUST open and inspect it before explaining or proposing fixes. Be rigorous and persistent in searching code for key facts. Thoroughly review the style, conventions, and abstractions of the codebase before implementing new features or abstractions.
* After receiving tool results, carefully reflect on their quality and determine optimal next steps before proceeding. Use your thinking to plan and iterate based on this new information, and then take the best next action.
* After completing a task that involves tool use, provide a quick summary of what you've done.
* For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
* Before you finish, please verify your solution
* Do what has been asked; nothing more, nothing less.
* NEVER create files unless they're absolutely necessary for achieving your goal.
* ALWAYS prefer editing an existing file to creating a new one.
* NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
* If you create any temporary new files, scripts, or helper files for iteration, clean up these files by removing them at the end of the task.
* When you update or modify core context files, also update markdown documentation and memory bank
* When asked to commit changes, include .claude/ directory files and include CLAUDE.md and CLAUDE-*.md referenced memory bank system files from any commits. Never delete these files.

<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer - give grounded and hallucination-free answers.
</investigate_before_answering>

<do_not_act_before_instructions>
Do not jump into implementatation or changes files unless clearly instructed to make changes. When the user's intent is ambiguous, default to providing information, doing research, and providing recommendations rather than taking action. Only proceed with edits, modifications, or implementations when the user explicitly requests them.
</do_not_act_before_instructions>

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls, make all of the independent tool calls in parallel. Prioritize calling tools simultaneously whenever the actions can be done in parallel rather than sequentially. For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into context at the same time. Maximize use of parallel tool calls where possible to increase speed and efficiency. However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially. Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>

## Memory Bank System

This project uses a structured memory bank system with specialized context files. Always check these files for relevant information before starting work:

### Core Context Files

* **CLAUDE-activeContext.md** - Current session state, goals, and progress
* **CLAUDE-patterns.md** - Established code patterns and conventions
* **CLAUDE-decisions.md** - Architecture decisions and rationale
* **CLAUDE-troubleshooting.md** - Common issues and proven solutions
* **CLAUDE-config-variables.md** - Configuration variables reference (pkg-oss build system)
* **CLAUDE-temp.md** - Temporary scratch pad (only read when referenced)

### Project-Specific Context Files

* **CLAUDE-nginx-pkg-oss-defaults-info.md** - How upstream nginx pkg-oss handles RPM builds (spec templates, configure flags, modules, OS-specific handling)
* **CLAUDE-centminmod-nginx-info.md** - How Centmin Mod source-compiles Nginx (575+ variables, 4 crypto libraries, 46+ modules, compiler flags)
* **CLAUDE-nginx-rpm-ci-workflows.md** - CI/CD strategy, GitHub Actions patterns, Docker-based testing decisions

**Important:** Always reference the active context file first to understand what's currently being worked on and maintain session continuity.

## Claude Code Official Documentation

When working on Claude Code features (hooks, skills, subagents, MCP servers, etc.), use the `claude-docs-consultant` skill to selectively fetch official documentation from docs.claude.com.

## Project Overview

This is a **fork of nginx/pkg-oss** (branch: `centminmod`) being adapted to build **Centmin Mod Nginx RPM packages** for RedHat-based distributions (AlmaLinux/Rocky Linux 8, 9, 10; CentOS 7).

**Goal**: Modify the upstream nginx RPM build system to produce RPMs matching Centmin Mod's nginx configuration — including custom crypto libraries (OpenSSL, BoringSSL, AWS-LC, LibreSSL), 46+ third-party modules, compiler optimizations (GCC toolsets, LTO), and custom installation paths (`/usr/local/nginx` vs upstream `/etc/nginx`).

**Key constraints**:

* Development on macOS — all RPM building/testing via Docker-based GitHub Actions
* Focus on RPM/RedHat distros ONLY (ignore alpine/, debian/ directories)
* Centmin Mod reference codebase at `/Users/george/D7378/PC/gitrepos/www_git/centminmod-claudecode` is READ-ONLY
* CI workflow templates at `/Users/george/D7378/PC/gitrepos/www_git/centminmod-workflows/`

## Build Commands (RPM)

```bash
# Show current nginx version and available modules
cd rpm/SPECS && make list

# Generate the nginx spec file from template
cd rpm/SPECS && make nginx.spec

# Build the base nginx RPM (requires rpmbuild environment)
cd rpm/SPECS && make base

# Build base modules (acme, geoip, image-filter, njs, otel, perl, xslt)
cd rpm/SPECS && make base-modules

# Build a specific dynamic module
cd rpm/SPECS && make module-brotli
cd rpm/SPECS && make module-lua
cd rpm/SPECS && make module-headers-more

# Build everything (base + all base modules)
cd rpm/SPECS && make all

# Generate a module spec file
cd rpm/SPECS && make nginx-module-brotli.spec

# Run tests
cd rpm/SPECS && make test
cd rpm/SPECS && make test-debug

# Clean build artifacts
cd rpm/SPECS && make clean

# Root Makefile: version/release management
make                    # Show current vs latest version
make release            # Prepare nginx release (updates versions, changelogs)
make release-njs        # Prepare njs release
```

**Note**: RPM builds require a Linux rpmbuild environment (AlmaLinux container). Use GitHub Actions CI workflows for actual builds.

## Architecture

### Build System Flow (RPM)

```
Makefile (root)                    # Version management, release automation
  └── rpm/SPECS/Makefile           # RPM build orchestrator
        ├── nginx.spec.in          # Spec template → nginx.spec (via variable substitution)
        ├── nginx-module.spec.in   # Module spec template → nginx-module-*.spec
        ├── Makefile.module-*      # 19 per-module build configs (sources, patches, deps)
        └── rpmbuild -ba *.spec    # Actual RPM compilation
```

### Spec Template Variable Substitution

`nginx.spec.in` uses `%%VARIABLE%%` placeholders replaced by the Makefile:

* `%%BASE_VERSION%%` → nginx version (from `contrib/src/nginx/version`)
* `%%BASE_RELEASE%%` → release number
* `%%BASE_CONFIGURE_ARGS%%` → all --with-* configure flags
* `%%BASE_PATCHES%%` → auto-generated patch list from `contrib/src/`

### Module Build Pattern

Each module has a `Makefile.module-<name>` defining:

* `MODULE_SOURCES_*` — tarball dependencies
* `MODULE_PATCHES_*` — patches to apply
* `MODULE_CONFARGS_*` — nginx configure flags (--add-dynamic-module)
* `MODULE_DEFINITIONS_*` — BuildRequires/Requires for RPM
* `MODULE_ENV_*` — environment variables for build
* `MODULE_PREBUILD_*` — pre-build commands
* `MODULE_FILES_*` — files to include in RPM

### CI/CD (GitHub Actions)

* `.github/workflows/ci.yml` — Multi-platform build (Alpine, Ubuntu, RedHat/AlmaLinux 9)
* `.github/workflows/contrib-check.yml` — Validates contrib source integrity
* RPM builds run inside `almalinux:9` container with `rpmbuild`

### Key Directories

* `rpm/SPECS/` — Spec templates, Makefiles (RPM build logic lives here)
* `rpm/SOURCES/` — nginx.conf, systemd services, logrotate, scripts
* `contrib/src/` — Module source directories (23+ modules with patches)
* `contrib/tarballs/` — Downloaded source tarballs
* `docs/` — XML changelogs for spec generation



## ALWAYS START WITH THESE COMMANDS FOR COMMON TASKS

**Task: "List/summarize all files and directories"**

```bash
fd . -t f           # Lists ALL files recursively (FASTEST)
# OR
rg --files          # Lists files (respects .gitignore)
```

**Task: "Search for content in files"**

```bash
rg "search_term"    # Search everywhere (FASTEST)
```

**Task: "Find files by name"**

```bash
fd "filename"       # Find by name pattern (FASTEST)
```

### Directory/File Exploration

```bash
# FIRST CHOICE - List all files/dirs recursively:
fd . -t f           # All files (fastest)
fd . -t d           # All directories
rg --files          # All files (respects .gitignore)

# For current directory only:
ls -la              # OK for single directory view
```

### BANNED - Never Use These Slow Tools

* ❌ `tree` - NOT INSTALLED, use `fd` instead
* ❌ `find` - use `fd` or `rg --files`
* ❌ `grep` or `grep -r` - use `rg` instead
* ❌ `ls -R` - use `rg --files` or `fd`
* ❌ `cat file | grep` - use `rg pattern file`

### Use These Faster Tools Instead

```bash
# ripgrep (rg) - content search 
rg "search_term"                # Search in all files
rg -i "case_insensitive"        # Case-insensitive
rg "pattern" -t py              # Only Python files
rg "pattern" -g "*.md"          # Only Markdown
rg -1 "pattern"                 # Filenames with matches
rg -c "pattern"                 # Count matches per file
rg -n "pattern"                 # Show line numbers 
rg -A 3 -B 3 "error"            # Context lines
rg " (TODO| FIXME | HACK)"      # Multiple patterns

# ripgrep (rg) - file listing 
rg --files                      # List files (respects •gitignore)
rg --files | rg "pattern"       # Find files by name 
rg --files -t md                # Only Markdown files 

# fd - file finding 
fd -e js                        # All •js files (fast find) 
fd -x command {}                # Exec per-file 
fd -e md -x ls -la {}           # Example with ls 

# jq - JSON processing 
jq. data.json                   # Pretty-print 
jq -r .name file.json           # Extract field 
jq '.id = 0' x.json             # Modify field
```

### Search Strategy

1. Start broad, then narrow: `rg "partial" | rg "specific"`
2. Filter by type early: `rg -t python "def function_name"`
3. Batch patterns: `rg "(pattern1|pattern2|pattern3)"`
4. Limit scope: `rg "pattern" src/`

### INSTANT DECISION TREE

```
User asks to "list/show/summarize/explore files"?
  → USE: fd . -t f  (fastest, shows all files)
  → OR: rg --files  (respects .gitignore)

User asks to "search/grep/find text content"?
  → USE: rg "pattern"  (NOT grep!)

User asks to "find file/directory by name"?
  → USE: fd "name"  (NOT find!)

User asks for "directory structure/tree"?
  → USE: fd . -t d  (directories) + fd . -t f  (files)
  → NEVER: tree (not installed!)

Need just current directory?
  → USE: ls -la  (OK for single dir)
```
