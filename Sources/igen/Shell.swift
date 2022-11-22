import Foundation

struct Shell {

    @discardableResult
    func perform(_ command: String) -> String {
        print("Executing: \(command )")
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.standardInput = nil
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

        return output
    }

    @discardableResult
    func mkdir(_ directory: String) -> String {
        perform("mkdir -p \(directory)")
    }

    @discardableResult
    func ls(_ filePath: String) -> String {
        perform("ls -d \(filePath)")
    }

    func isDirecory(_ filePath: String) -> Bool {
        let checkPhrase = "is directory"
        return perform("[ -d \(filePath) ] && echo \"\(checkPhrase)\"").trimmingCharacters(in: .newlines) == checkPhrase
    }

    func cp(recursive: Bool, _ source: String, _ destination: String) {
        perform("cp \(recursive ? "-R " : "")\(source) \(destination)")
    }
}

