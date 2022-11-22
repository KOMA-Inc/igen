import Yams

struct TargetsUpdater {
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
}
