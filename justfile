build:
  swift build

build-linux:
  docker run --rm -v "$PWD":/src -w /src --tmpfs /src/.build:exec swift:6.2 swift build

format:
  swiftformat -swift-version 6 .
