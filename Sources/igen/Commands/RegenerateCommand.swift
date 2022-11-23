import ArgumentParser
import Foundation
import Yams

struct RegenerateCommand: ParsableCommand {

    static let configuration = CommandConfiguration(commandName: "regenerate")

    @Argument(help: "The filepath to .yaml with targets info")
    var targetsYAMLFilepath: String

    @Argument(help: "The filepath to your project.yaml")
    var projectYAMLFilepath: String

    func run() throws {

        // Parse

        let parser = YAMLParser()
        let (inputConfig, targetYAMLLines) = try parser.parseTargetsYAML(using: targetsYAMLFilepath)
        let (lines, targetsStartLineNumber, outputTargets) = try parser.parseProjectYAML(using: projectYAMLFilepath)

        // Update

        let updater = TargetsUpdater()
        let newOutputTargets = updater.generateUpdatedOutputTargets(
            for: inputConfig,
            using: outputTargets
        )
        let newLines = try updater.generateUpdatedTargetsSection(
            for: lines,
            inserAtIndex: targetsStartLineNumber,
            using: outputTargets + newOutputTargets
        )

        // Create sources
        let manager = SourcesManager()
        manager.createSourceDirs(for: newOutputTargets)
        manager.stealFiles(inputConfig: inputConfig, outputTargets: newOutputTargets)

        // Write to files
        let filesManager = FilesManager()
        try filesManager.updateProjectYAML(path: projectYAMLFilepath, lines: newLines)
        try filesManager.updateTargetsYAML(path: targetsYAMLFilepath, config: inputConfig, lines: targetYAMLLines)
    }
}
