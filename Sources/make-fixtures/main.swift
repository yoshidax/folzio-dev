import Foundation
import FixtureKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-fixtures <output-directory>\n".utf8))
    exit(2)
}

let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FixtureSets.makeAll(in: directory)
    print("fixtures written to \(directory.path)")
} catch {
    FileHandle.standardError.write(Data("make-fixtures failed: \(error)\n".utf8))
    exit(1)
}
