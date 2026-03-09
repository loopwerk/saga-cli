build:
  swift build

build-swift510:
  docker run --rm -v "$PWD":/src -w /src --tmpfs /src/.build:exec swift:5.10 swift build

format:
  swiftformat -swift-version 5 .
