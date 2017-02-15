import PackageDescription

let package = Package(
    name: "Http",
    dependencies: [
      .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1)
    ]
)
