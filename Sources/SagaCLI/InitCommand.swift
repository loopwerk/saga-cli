import ArgumentParser
import SagaPathKit

struct Init: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Create a new Saga project."
  )

  @Argument(help: "The name of the project to create, or '.' to create it in the current folder.")
  var name: String

  func run() throws {
    let createInPlace = name == "."
    let projectPath = createInPlace ? Path.current : Path.current + name

    if !createInPlace {
      guard !projectPath.exists else {
        throw ValidationError("Directory '\(name)' already exists.")
      }
    }

    let projectName = createInPlace ? projectPath.absolute().lastComponent : name

    guard let firstCharacter = projectName.first, firstCharacter.isLetter || firstCharacter.isNumber else {
      throw ValidationError("Could not determine a project name from the current folder.")
    }

    let capitalizedName = projectName.prefix(1).uppercased() + projectName.dropFirst()

    let files: [(Path, String)] = [
      (Path("Package.swift"), ProjectTemplate.packageSwift(name: capitalizedName)),
      (Path("Sources") + capitalizedName + "main.swift", ProjectTemplate.mainSwift(name: capitalizedName)),
      (Path("Sources") + capitalizedName + "templates.swift", ProjectTemplate.templatesSwift()),
      (Path("content") + "index.md", ProjectTemplate.indexMarkdown()),
      (Path("content") + "articles" + "hello-world.md", ProjectTemplate.helloWorldMarkdown()),
      (Path("content") + "static" + "style.css", ProjectTemplate.styleCss()),
      (Path("README.md"), ProjectTemplate.readme(name: capitalizedName)),
      (Path(".gitignore"), ProjectTemplate.gitignore()),
    ]

    // Create directory structure
    try (projectPath + "Sources" + capitalizedName).mkpath()
    try (projectPath + "content" + "articles").mkpath()
    try (projectPath + "content" + "static").mkpath()

    // Write files
    for (path, content) in files {
      try (projectPath + path).write(content)
    }

    print("Created new Saga project in '\(createInPlace ? projectPath.absolute().lastComponent : name)/'")
    print("")
    print("Next steps:")
    if !createInPlace {
      print("  cd \(name)")
    }
    print("  saga dev")
  }
}
