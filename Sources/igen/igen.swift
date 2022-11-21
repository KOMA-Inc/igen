import ArgumentParser
import Yams
import Foundation

enum Error: Swift.Error {
    case noProjectNameFound
    case failedToDecodeTargetsYAML
    case noTargetFieldFFound
    case targetInfoMissingInProjectYAML
    case noLinesAfrerTargetInProjectYAML
    case failedToDecodeProjectYAML
}

@main
struct IGEN: ParsableCommand {

    @Argument(help: "The filepath to .yaml with targen info")
    var filepath: String

    @Argument(help: "This filepath to your project.yaml")
    var projectYAMLFilepath: String


    func run() throws {

        // Parse

        let (inputConfig, targetYAMLLines) = try parseTargetsYAML()
        let (lines, targetsStartLineNumber, projectTargets) = try parseProjectYAML()

        // Update

        let newProjectTargets = generateUpdatedProjectTargets(
            for: inputConfig,
            using: projectTargets
        )

        let newLines = try generateUpdatedTargetsSection(
            for: lines,
            inserAtIndex: targetsStartLineNumber,
            using: projectTargets + newProjectTargets
        )

         // Create sources

        createSourceDirs(for: newProjectTargets)

        let newTargets = inputConfig.targets.filter { target in
            newProjectTargets.contains {
                $0.name == "\(inputConfig.projectName) \(target.name)"
            }
        }
        stealFiles(projectName: inputConfig.projectName, targets: newTargets)

        // Update .yaml files

        try updateProjectYAML(path: projectYAMLFilepath, lines: newLines)
        try updateTargetsYAML(path: filepath, config: inputConfig, lines: targetYAMLLines)
    }

    private func parseTargetsYAML() throws -> (config: InputConfig, lines: [String]) {
        let data = try Data(contentsOf: URL(fileURLWithPath: filepath))
        let dataString = String(decoding: data, as: UTF8.self)

        guard let dict = try Yams.load(yaml: dataString) as? Dictionary<String, Any> else {
            print("Failed to decode your project.yaml config file")
            throw Error.failedToDecodeProjectYAML
        }

        guard let projectName = dict["project"] as? String else {
            print("No project name found")
            throw Error.noProjectNameFound
        }

        guard let targetsDict = dict["targets"] as? Dictionary<String, Any> else {
            print("No field named `targets` found!")
            throw Error.noTargetFieldFFound
        }

        let targets: [Target] = targetsDict.compactMap { key, config in
            let target = targetsDict[key] as? Dictionary<String, Any>
            let steals = target?["steals"] as? [String]
            let inherit = target?["inherit"] as? String
            return .init(name: key, steals: steals, inherit: inherit)
        }

        return (.init(projectName: projectName, targets: targets), dataString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
    }

    private func parseProjectYAML() throws -> (cleanedLines: [String], indexToInsert: Int, projectTargets: [ProjectTarget]) {
        let projectYAMLData = try Data(contentsOf: URL(fileURLWithPath: projectYAMLFilepath))
        let projectYAMLString = String(decoding: projectYAMLData, as: UTF8.self)

        // All lines in project.yaml file
        var lines = projectYAMLString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Find the start of `targets:` section
        guard let targetsStartLineNumber = lines.firstIndex(of: "targets:") else {
            print("Didn't fint and target info in your project.yaml")
            throw Error.targetInfoMissingInProjectYAML
        }

        guard targetsStartLineNumber + 1 < lines.count else {
            print("No lines after `targets:` found")
            throw Error.noLinesAfrerTargetInProjectYAML
        }

        // Find the end of `targets:` section
        let targetsEndLineNumber = lines[(targetsStartLineNumber + 1)...].firstIndex(where: {
            guard let firstChar = $0.first else { return false }
            return !firstChar.isWhitespace
        })

        // Extract the targets section
        let targetsLines = lines[targetsStartLineNumber..<(targetsEndLineNumber ?? lines.endIndex)]
        let targetsYAMLText = targetsLines.joined(separator: "\n")

        // Remove targets section from all lines
        lines.removeSubrange(targetsStartLineNumber..<(targetsEndLineNumber ?? lines.endIndex))

        guard let targetsYAML = try Yams.load(yaml: targetsYAMLText) as? Dictionary<String, Any> else {
            print("Failed to decode your project.yaml config file")
            throw Error.failedToDecodeProjectYAML
        }

        guard let targets = targetsYAML["targets"] as? Dictionary<String, Any> else {
            print("Didn't find any target info in your project.yaml")
            throw Error.targetInfoMissingInProjectYAML
        }

        let projectTargets: [ProjectTarget] = targets.compactMap { key, value -> ProjectTarget? in
            guard let dict = value as? Dictionary<String, Any> else {
                print("Could not case value to dictionary")
                return nil
            }

            guard let type = dict["type"] as? String else {
                print("type not found")
                return nil
            }

            guard let platform = dict["platform"] as? String else {
                print("platform not found")
                return nil
            }

            guard let settings = dict["settings"] as? Dictionary<String, Any> else {
                print("settings not found in expected format")
                return nil
            }

            guard let groups = settings["groups"] as? [String] else {
                print("settings.groups not found")
                return nil
            }

            guard let base = settings["base"] as? Dictionary<String, Any> else {
                print("settings.base not found in expected format")
                return nil
            }

            let baseMapped: [String: String] = base.mapValues { "\($0)" }

            guard let sources = dict["sources"] as? [String] else {
                print("sources not found")
                return nil
            }

            return .init(
                originalName: key,
                name: key,
                config: .init(
                    type: type,
                    platform: platform,
                    settings: .init(
                        groups: groups,
                        base: baseMapped
                    ),
                    sources: sources
                )
            )
        }

        return (lines, targetsStartLineNumber, projectTargets)
    }

    private func generateUpdatedProjectTargets(
        for inputConfig: InputConfig,
        using projectTargets: [ProjectTarget]
    ) -> [ProjectTarget] {
        let newTargets = inputConfig.targets.filter { inputTarget  in
            !projectTargets.contains { existingTarget in
                existingTarget.name == "\(inputConfig.projectName) \(inputTarget.name)"
            }
        }

        var newProjectTargets: [ProjectTarget] = newTargets.compactMap { newTarget -> ProjectTarget? in

            var inheritedTarget: ProjectTarget?

            if let inherit = newTarget.inherit {
                inheritedTarget = projectTargets.first {
                    $0.name == "\(inputConfig.projectName) \(inherit)"
                }
            } else {
                inheritedTarget = projectTargets.first
            }

            guard let inheritedTarget = inheritedTarget else {
                print("Can't find target to inherit")
                return nil
            }

            return .init(
                originalName: newTarget.name,
                name: "\(inputConfig.projectName) \(newTarget.name)",
                config: .init(
                    type: inheritedTarget.config.type,
                    platform: inheritedTarget.config.platform,
                    settings: inheritedTarget.config.settings,
                    sources: [
                        "\(inputConfig.projectName)/COMMON",
                        "\(inputConfig.projectName)/\(newTarget.name)"
                    ]
                )
            )
        }

        newProjectTargets.enumerated().forEach { index, target in
            var base = target.config.settings.base
            base["INFOPLIST_FILE"] = "\(inputConfig.projectName)/\(target.originalName)/Resources/Info.plist"
            newProjectTargets[index].config.settings.base = base
        }

        return newProjectTargets
    }

    private func generateUpdatedTargetsSection(
        for lines: [String],
        inserAtIndex index: Int,
        using targets: [ProjectTarget]
    ) throws -> [String] {
        let yamlDict: [String: ProjectTarget.Config] = .init(uniqueKeysWithValues: targets.map { ($0.name, $0.config) })

        let targetDict = ["targets": yamlDict]

        let encoder = YAMLEncoder()
        encoder.options.indent = 4
        encoder.options.sortKeys = true

        let yaml = try encoder.encode(targetDict)
        let yamlLines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var newLines = lines
        newLines.insert(contentsOf: yamlLines, at: index)

        return newLines
    }

    private func createSourceDirs(for targets: [ProjectTarget]) {
        targets.forEach { target in
            target.config.sources.forEach { source in
                if source.isDirectory {
                    print(shell("mkdir \(source)"))
                }
            }
        }
    }

    private func stealFiles(projectName: String, targets: [Target]) {
        targets.forEach { target in
            guard let steals = target.steals else {
                print("Target \(target.name) has nothing to steal")
                return
            }
            steals.forEach { steal in
                guard let stealDir = steal.stealDirectory else {
                    print("Can't understand \(steal) directory")
                    return
                }

                let destinationStealDir = "\(projectName)/\(target.name)/\(stealDir)"
                print(shell("mkdir \(destinationStealDir)"))
                print(shell("cp -R \(steal) \(destinationStealDir)"))
            }
        }
    }

    private func updateProjectYAML(path: String, lines: [String]) throws {
        let url = URL(fileURLWithPath: path)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func updateTargetsYAML(path: String, config: InputConfig, lines: [String]) throws {

        let newConfig = InputConfig(
            projectName: config.projectName,
            targets: config.targets.map { .init(name: $0.name, steals: nil, inherit: nil) }
        )

        guard let targetsIndex = lines.firstIndex(where: { $0 == "targets:" }) else {
            print("No field named `targets` found!")
            throw Error.noTargetFieldFFound
        }

        let targetsLines = newConfig.targets
            .sorted { $0.name < $1.name }
            .map { "    \($0.name):"}

        var newLines = lines
        newLines.removeSubrange((targetsIndex + 1)...)
        newLines.insert(contentsOf: targetsLines, at: (targetsIndex + 1))

        let url = URL(fileURLWithPath: path)
        try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}


fileprivate extension String {
    var isDirectory: Bool {
        let components = self.split(separator: "/").map(String.init)
        guard let lastComponent = components.last else { return false}
        return !lastComponent.contains(".")
    }

    var stealDirectory: String? {
        self.split(separator: "/").map(String.init).last
    }
}
