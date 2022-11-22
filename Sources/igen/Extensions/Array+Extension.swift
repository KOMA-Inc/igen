extension Array where Element == String {
    var asPath: String {
        self.joined(separator: "/")
    }
}
