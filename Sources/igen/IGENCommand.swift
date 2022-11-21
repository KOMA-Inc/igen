import ArgumentParser

enum Error: Swift.Error {
    case noProjectNameFound
    case failedToDecodeTargetsYAML
    case noTargetFieldFFound
    case targetInfoMissingInProjectYAML
    case noLinesAfrerTargetInProjectYAML
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
