import Foundation
import Yams

struct YAMLParser {
    func parseTargetsYAML(using filepath: String) throws -> (config: InputConfig, lines: [String]) {
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
            throw Error.noTargetFieldFound
        }

        let targets: [InputTarget] = targetsDict.compactMap { key, config in
            let target = targetsDict[key] as? Dictionary<String, Any>
            let steals = target?["steals"] as? [String]
            let inherit = target?["inherit"] as? String
            return .init(name: key, steals: steals, inherit: inherit)
        }

        return (.init(projectName: projectName, targets: targets), dataString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
    }

    func parseProjectYAML(using filepath: String) throws -> (cleanedLines: [String], indexToInsert: Int, outputTargets: [OutputTarget]) {
        let projectYAMLData = try Data(contentsOf: URL(fileURLWithPath: filepath))
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
            throw Error.noLinesAfterTargetInProjectYAML
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

        let outputTargets: [OutputTarget] = targets.compactMap { key, value -> OutputTarget? in
            guard let dict = value as? Dictionary<String, Any> else {
                print("🚨 Could not case value to dictionary")
                return nil
            }

            guard let type = dict["type"] as? String else {
                print("🚨 type not found")
                return nil
            }

            guard let platform = dict["platform"] as? String else {
                print("🚨 platform not found")
                return nil
            }

            var configSettings: OutputTarget.Config.Settings?

            let settings = dict["settings"] as? Dictionary<String, Any>
            if let settings {
                let groups = settings["groups"] as? [String]
                let base = settings["base"] as? Dictionary<String, Any>
                let baseMapped = base?.mapValues { "\($0)" }

                if groups != nil || baseMapped != nil {
                    configSettings = .init(groups: groups, base: baseMapped)
                }
            } else {
                print("⚠️ Warning! No settings found for target with name \(key)")
            }

            let sources = dict["sources"] as? [String]
            if sources == nil {
                print("⚠️ Warning! Sources not found for target with name \(key)")
            }

            let dependencies = dict["dependencies"] as? [Dictionary<String, String>]
            let postCompileScripts: [OutputTarget.Config.PostCompileScript]? =
            (dict["postCompileScripts"] as? [Dictionary<String, String>])?.compactMap {
                guard let script = $0["script"] else {
                    print("postCompileScripts script field not found")
                    return nil
                }

                guard let name = $0["name"] else {
                    print("postCompileScripts name field not found")
                    return nil
                }

                return .init(name: name, script: script)
            }

            return .init(
                originalName: key,
                name: key,
                config: .init(
                    type: type,
                    platform: platform,
                    settings: configSettings,
                    sources: sources,
                    dependencies: dependencies,
                    postCompileScripts: postCompileScripts
                )
            )
        }

        return (lines, targetsStartLineNumber, outputTargets)
    }
}
