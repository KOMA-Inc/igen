import ArgumentParser

@main
struct IGENCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "igen",
        subcommands: [
            RegenerateCommand.self,
            AddDependencyCommand.self
        ])
}
