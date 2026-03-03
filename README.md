# saga-cli

A CLI companion for [Saga](https://github.com/loopwerk/Saga), the code-first static site generator in Swift.

Scaffolds new projects, builds your site, and runs a development server with auto-reload.

## Installation

**Via [Homebrew](https://brew.sh):**

```
$ brew install loopwerk/tap/saga
```

**Via [Mint](https://github.com/yonaskolb/Mint):**

```
$ mint install loopwerk/saga-cli
```

> **Migrating from an older version?** The CLI previously lived inside the [Saga](https://github.com/loopwerk/Saga) repository. If you installed via Mint using `mint install loopwerk/Saga`, switch to `mint install loopwerk/saga-cli`.

## Commands

### `saga init`

Scaffold a new Saga project:

```
$ saga init mysite
$ cd mysite
$ saga dev
```

Creates a ready-to-run project with articles, tags, templates, and a stylesheet.

### `saga build`

Build your site (runs `swift run` in the current directory):

```
$ saga build
```

### `saga dev`

Start a development server with file watching and auto-reload:

```
$ saga dev
```

Options:

| Flag             | Default              | Description                                    |
| ---------------- | -------------------- | ---------------------------------------------- |
| `--watch`, `-w`  | `content`, `Sources` | Folders to watch for changes (repeatable)      |
| `--output`, `-o` | `deploy`             | Output folder for the built site               |
| `--port`, `-p`   | `3000`               | Port for the development server                |
| `--ignore`, `-i` |                      | Glob patterns for files to ignore (repeatable) |

Example with custom options:

```
$ saga dev --watch content --watch Sources --output deploy --port 8080 --ignore "*.tmp" --ignore "drafts/*"
```

## Requirements

Swift 5.5+ and macOS 12+.

## License

MIT
