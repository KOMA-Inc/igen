import ArgumentParser

struct AddDependencyCommand: ParsableCommand {

    static let configuration = CommandConfiguration(commandName: "add-dependency")

    @Argument(help: "The name of the package or static library")
    var libName: String

    @Argument(help: "The filepath to .yaml with targen info")
    var filepath: String

    @Argument(help: "This filepath to your project.yaml")
    var projectYAMLFilepath: String

    func run() throws {
        print("hello world")
    }
}
