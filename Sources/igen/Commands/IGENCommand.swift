import ArgumentParser

enum Error: Swift.Error {
    case noProjectNameFound
    case failedToDecodeTargetsYAML
    case noTargetFieldFound
    case targetInfoMissingInProjectYAML
    case noLinesAfterTargetInProjectYAML
    case failedToDecodeProjectYAML
}

@main
struct IGENCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "igen",
        subcommands: [
            RegenerateCommand.self,
            AddDependencyCommand.self
        ])
}
