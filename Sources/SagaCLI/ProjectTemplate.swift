import Foundation

enum ProjectTemplate {
  static func packageSwift(name: String) -> String {
    """
    // swift-tools-version:6.0

    import PackageDescription

    let package = Package(
      name: "\(name)",
      platforms: [
        .macOS(.v14),
      ],
      dependencies: [
        .package(url: "https://github.com/loopwerk/Saga", from: "3.0.0"),
        .package(url: "https://github.com/loopwerk/SagaParsleyMarkdownReader", from: "1.0.0"),
        .package(url: "https://github.com/loopwerk/SagaSwimRenderer", from: "1.0.0"),
        .package(url: "https://github.com/loopwerk/Moon", from: "1.0.0"),
        .package(url: "https://github.com/loopwerk/Bonsai", from: "1.1.0"),
      ],
      targets: [
        .executableTarget(
          name: "\(name)",
          dependencies: [
            "Saga",
            "SagaParsleyMarkdownReader",
            "SagaSwimRenderer",
            "Moon",
            "Bonsai",
          ]
        ),
      ]
    )
    """
  }

  static func mainSwift(name: String) -> String {
    """
    import Bonsai
    import Foundation
    import Saga
    import SagaParsleyMarkdownReader
    import SagaSwimRenderer

    struct ArticleMetadata: Metadata {
      let tags: [String]
      var summary: String?
    }

    try await Saga(input: "content", output: "deploy")
      .register(
        folder: "articles",
        metadata: ArticleMetadata.self,
        readers: [.parsleyMarkdownReader],
        writers: [
          .itemWriter(swim(renderArticle)),
          .listWriter(swim(renderArticles)),
          .tagWriter(swim(renderTag), tags: \\.metadata.tags),
        ]
      )
      .register(
        metadata: EmptyMetadata.self,
        readers: [.parsleyMarkdownReader],
        writers: [.itemWriter(swim(renderPage))]
      )
      .postProcess { html, _ in
        // postProcess runs on every generated file before it's written
        guard !Saga.isDev else { return html }
        return Bonsai.minifyHTML(html)
      }
      .run()
    """
  }

  static func templatesSwift() -> String {
    #"""
    import Foundation
    import HTML
    import Moon
    import Saga
    import SagaSwimRenderer

    func baseHtml(title pageTitle: String, @NodeBuilder children: () -> NodeConvertible) -> Node {
      html(lang: "en-US") {
        head {
          meta(charset: "utf-8")
          meta(content: "width=device-width, initial-scale=1", name: "viewport")
          title { pageTitle }
          link(href: Saga.hashed("/static/style.css"), rel: "stylesheet")
        }
        body {
          header {
            nav {
              a(class: "site-title", href: "/") { "My Site" }
              div(class: "nav-links") {
                a(href: "/articles/") { "Articles" }
              }
            }
          }
          main {
            children()
          }
          footer {
            p {
              "Built with "
              a(href: "https://github.com/loopwerk/Saga") { "Saga" }
            }
          }
        }
      }
    }

    func renderArticle(context: ItemRenderingContext<ArticleMetadata>) -> Node {
      baseHtml(title: context.item.title) {
        article {
          h1 { context.item.title }
          ul(class: "tags") {
            context.item.metadata.tags.map { tag in
              li {
                a(href: "/articles/tag/\(tag.slugified)/") { tag }
              }
            }
          }
          Node.raw(Moon.shared.highlightCodeBlocks(in: context.item.body))
        }
      }
    }

    func renderArticles(context: ItemsRenderingContext<ArticleMetadata>) -> Node {
      baseHtml(title: "Articles") {
        h1 { "Articles" }
        context.items.map { article in
          div(class: "article-card") {
            h2 {
              a(href: article.url) { article.title }
            }
            if let summary = article.metadata.summary {
              p { summary }
            }
          }
        }
      }
    }

    func renderTag<T>(context: PartitionedRenderingContext<T, ArticleMetadata>) -> Node {
      baseHtml(title: "Articles tagged \(context.key)") {
        h1 { "Articles tagged \(context.key)" }
        context.items.map { article in
          div(class: "article-card") {
            h2 {
              a(href: article.url) { article.title }
            }
          }
        }
      }
    }

    func renderPage(context: ItemRenderingContext<EmptyMetadata>) -> Node {
      baseHtml(title: context.item.title) {
        div(class: "page") {
          h1 { context.item.title }
          Node.raw(Moon.shared.highlightCodeBlocks(in: context.item.body))
        }
      }
    }
    """#
  }

  static func indexMarkdown() -> String {
    """
    ---
    title: Home
    ---
    # Welcome to my site

    This site is built with [Saga](https://github.com/loopwerk/Saga), a static site generator written in Swift.
    """
  }

  static func helloWorldMarkdown() -> String {
    """
    ---
    tags: swift, saga
    summary: Getting started with Saga, a static site generator written in Swift.
    date: \(currentDateString())
    ---
    # Hello, World!

    This is your first article. Edit this file or create new markdown files in the `content/articles` folder.

    ## Getting Started

    Saga uses a **Reader → Processor → Writer** pipeline:

    1. **Readers** parse your content files (like this Markdown file) into typed items
    2. **Processors** can transform items with custom logic
    3. **Writers** generate the output HTML files

    Happy writing!
    """
  }

  static func styleCss() -> String {
    """
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 0 20px;
    }

    header nav {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20px 0;
      border-bottom: 1px solid #eee;
      margin-bottom: 40px;
    }

    .site-title {
      font-size: 1.2rem;
      font-weight: 700;
      color: #333;
      text-decoration: none;
    }

    .nav-links a {
      color: #666;
      text-decoration: none;
      margin-left: 20px;
    }

    .nav-links a:hover {
      color: #333;
    }

    main {
      min-height: 60vh;
    }

    h1 {
      font-size: 2rem;
      margin-bottom: 20px;
    }

    h2 {
      font-size: 1.4rem;
      margin: 30px 0 10px;
    }

    p {
      margin-bottom: 16px;
    }

    a {
      color: #0066cc;
    }

    a:hover {
      color: #004499;
    }

    article {
      margin-bottom: 40px;
    }

    .tags {
      list-style: none;
      display: flex;
      gap: 8px;
      margin-bottom: 20px;
    }

    .tags li a {
      background: #f0f0f0;
      padding: 2px 10px;
      border-radius: 12px;
      font-size: 0.85rem;
      color: #555;
      text-decoration: none;
    }

    .tags li a:hover {
      background: #e0e0e0;
    }

    .article-card {
      padding: 20px 0;
      border-bottom: 1px solid #eee;
    }

    .article-card h2 {
      margin: 0 0 8px;
    }

    .article-card p {
      color: #666;
      margin: 0;
    }

    footer {
      margin-top: 60px;
      padding: 20px 0;
      border-top: 1px solid #eee;
      color: #999;
      font-size: 0.85rem;
    }

    ol, ul {
      margin-bottom: 16px;
      padding-left: 24px;
    }

    li {
      margin-bottom: 4px;
    }

    code {
      background: #f5f5f5;
      padding: 2px 6px;
      border-radius: 3px;
      font-size: 0.9em;
    }

    pre {
      background: #f5f5f5;
      padding: 16px;
      border-radius: 6px;
      overflow-x: auto;
      margin-bottom: 16px;
    }

    pre code {
      background: none;
      padding: 0;
    }
    """
  }

  static func readme(name: String) -> String {
    """
    # \(name)

    A static site built with [Saga](https://github.com/loopwerk/Saga), a code-first static site generator written in Swift.

    ## Commands

    Build the site, watch for changes, and serve it on http://localhost:3000 with auto-reload:

    ```
    $ saga dev
    ```

    Build the site once into `deploy/`:

    ```
    $ saga build
    ```

    ## Project structure

    ```
    Sources/\(name)/
      main.swift        The pipeline: which content to read, and how to write it
      templates.swift   The HTML templates, written in Swift using Swim
    content/
      index.md          The homepage
      articles/         Markdown articles
      static/           Files copied as-is: the stylesheet, images, ...
    deploy/             The generated site
    ```

    ## How it works

    Saga runs a **Reader → Processor → Writer** pipeline. Every `register` step in `main.swift` claims a folder of content, parses it into typed items, and hands those items to writers that render HTML:

    - `content/articles/*.md` is read into `Item<ArticleMetadata>` values, and written to `/articles/<slug>/`, plus an index at `/articles/` and a page per tag at `/articles/tag/<tag>/`.
    - Every other markdown file is written as a standalone page, so `content/index.md` becomes `/`.

    Metadata comes from the YAML front matter at the top of each markdown file. Add a field to `ArticleMetadata` in `main.swift` to make it available in your templates.

    Anything in `content/static/` that no step claims is copied to `deploy/` untouched.

    ## Learn more

    - [Getting started](https://getsaga.dev/docs/gettingstarted/)
    - [Guides](https://getsaga.dev/docs/guides/) — search, sitemaps, syntax highlighting, Tailwind CSS, and more
    """
  }

  static func gitignore() -> String {
    """
    .DS_Store
    .build/
    .swiftpm/
    *.xcodeproj
    xcuserdata/
    """
  }

  private static func currentDateString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}
