import Yams

struct TargetsUpdater {

    enum Error: Swift.Error {
        case dependencyNotFound
    }

    func generateUpdatedOutputTargets(
        for inputConfig: InputConfig,
        using outputTargets: [OutputTarget]
    ) -> [OutputTarget] {
        let newTargets = inputConfig.targets.filter { inputTarget  in
            !outputTargets.contains { existingTarget in
                existingTarget.name == inputTarget.name.prefixed(with: inputConfig.projectName)
            }
        }

        var newOutputTargets: [OutputTarget] = newTargets.compactMap { newTarget -> OutputTarget? in

            var inheritedTarget: OutputTarget?

            if let inherit = newTarget.inherit {
                inheritedTarget = outputTargets.first {
                    $0.name == inherit.prefixed(with: inputConfig.projectName)
                }
            } else {
                let filteredTargets = outputTargets.filter { outputTarget in
                    inputConfig.targets.contains(where: { outputTarget.name == $0.name.prefixed(with: inputConfig.projectName) })
                }
                inheritedTarget = filteredTargets.first
            }

            guard let inheritedTarget = inheritedTarget else {
                print("Can't find target to inherit")
                return nil
            }

            return .init(
                originalName: newTarget.name,
                name: newTarget.name.prefixed(with: inputConfig.projectName),
                config: .init(
                    type: inheritedTarget.config.type,
                    platform: inheritedTarget.config.platform,
                    settings: inheritedTarget.config.settings,
                    sources: [
                        "/COMMON".prefixed(with: inputConfig.projectName),
                        "/\(newTarget.name)".prefixed(with: inputConfig.projectName)
                    ],
                    dependencies: inheritedTarget.config.dependencies,
                    postCompileScripts: inheritedTarget.config.postCompileScripts
                )
            )
        }

        newOutputTargets.enumerated().forEach { index, target in
            if var base = target.config.settings?.base {
                base["INFOPLIST_FILE"] = "/\(target.originalName)/Resources/Info.plist".prefixed(with: inputConfig.projectName)
                newOutputTargets[index].config.settings?.base = base
            }
        }

        return newOutputTargets
    }

    func generateUpdatedTargetsSection(
        for lines: [String],
        inserAtIndex index: Int,
        using targets: [OutputTarget]
    ) throws -> [String] {
        let yamlDict: [String: OutputTarget.Config] = .init(uniqueKeysWithValues: targets.map { ($0.name, $0.config) })

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

    func addDependency(
        named dependency: String,
        usingInputConfig inputConfig: InputConfig,
        outputTargets: [OutputTarget],
        packages: [String]
    ) throws -> [OutputTarget] {

        let dependecyType: DependencyType

        if packages.contains(dependency) {
            dependecyType = .package
        } else if inputConfig.targets.contains(where: { $0.name == dependency }) {
            dependecyType = .target
        } else {
            throw Error.dependencyNotFound
        }

        var outputTargets = outputTargets

        outputTargets.enumerated().forEach { index, outputTarget in
            guard inputConfig.targets
                .contains(where: { $0.name.prefixed(with: inputConfig.projectName) == outputTarget.name }) else {
                return
            }

            let newDependency = [dependecyType.rawValue: dependency]
            let newDependencies: [Dependency]

            if let dependencies = outputTarget.config.dependencies {
                newDependencies = dependencies + [newDependency]
            } else {
                newDependencies = [newDependency]
            }

            let newOutputTarget = OutputTarget(
                originalName: outputTarget.originalName,
                name: outputTarget.name,
                config: .init(
                    type: outputTarget.config.type,
                    platform: outputTarget.config.platform,
                    settings: outputTarget.config.settings,
                    sources: outputTarget.config.sources,
                    dependencies: newDependencies,
                    postCompileScripts: outputTarget.config.postCompileScripts
                )
            )

            outputTargets[index] = newOutputTarget
        }

        return outputTargets
    }
}
