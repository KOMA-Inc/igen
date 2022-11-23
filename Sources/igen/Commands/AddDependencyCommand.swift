import ArgumentParser

struct AddDependencyCommand: ParsableCommand {

    static let configuration = CommandConfiguration(commandName: "add-dependency")

    @Argument(help: "The name of the dependency")
    var dependencyName: String

    @Argument(help: "The filepath to .yaml with targets info")
    var targetsYAMLFilepath: String

    @Argument(help: "The filepath to your project.yaml")
    var projectYAMLFilepath: String

    func run() throws {

        // Parse

        let parser = YAMLParser()
        let (inputConfig, _) = try parser.parseTargetsYAML(using: targetsYAMLFilepath)
        let (lines, targetsStartLineNumber, outputTargets) = try parser.parseProjectYAML(using: projectYAMLFilepath)
        let packages = try parser.parsePackagesInProjectYAML(using: projectYAMLFilepath)

        // Update
        let updater = TargetsUpdater()
        let newOutputTargets = try updater.addDependency(
            named: dependencyName,
            usingInputConfig: inputConfig,
            outputTargets: outputTargets,
            packages: packages
        )
        let newLines = try updater.generateUpdatedTargetsSection(
            for: lines,
            inserAtIndex: targetsStartLineNumber,
            using: newOutputTargets
        )

        // Write to files
        let filesManager = FilesManager()
        try filesManager.updateProjectYAML(path: projectYAMLFilepath, lines: newLines)
    }
}
