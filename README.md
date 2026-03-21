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

**From source:**

```shell-session
$ git clone https://github.com/loopwerk/saga-cli.git
$ cd saga-cli
$ swift package experimental-install
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

Start a development server with auto-reload on port 3000:

```
$ saga dev
$ saga dev --port 8080
```

> **Note:** saga-cli 2.x requires Saga 3.x or later.

## Requirements

Swift 6.0+ and macOS 14+ or Linux.

## License

MIT
