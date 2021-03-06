import Foundation

protocol DiffInteractor {
	func diff(baseBranch: String, targetBranch: String, atPath path: String) throws -> String
}

public struct Diff: Equatable, CustomStringConvertible {
	public var addedFilePath: String? {
		return rawAddedFilePath != "/dev/null" ? rawAddedFilePath : nil
	}

	public var removedFilePath: String? {
		return rawRemovedFilePath != "/dev/null" ? rawRemovedFilePath : nil
	}

	var rawAddedFilePath: String
	var rawRemovedFilePath: String

	public var hunks: [Hunk]

	public var description: String {
		let header = """
		--- \(rawRemovedFilePath)
		+++ \(rawAddedFilePath)
		"""
		return hunks.reduce(into: header) {
			$0 += "\n\($1.description)"
		}
	}

	public init(rawDiffContent: String) throws {
		let parsingResults = try Diff.Parser(rawDiffContent: rawDiffContent).parse()
		self.init(
			addedFile: parsingResults.addedFile,
			removedFile: parsingResults.removedFile,
			hunks: parsingResults.hunks
		)
	}

	init(addedFile: String, removedFile: String, hunks: [Hunk]) {
		self.rawAddedFilePath = addedFile
		self.rawRemovedFilePath = removedFile
		self.hunks = hunks
	}
}

extension Diff {
	public struct Hunk: Equatable, CustomStringConvertible {
		public var oldLineStart: Int
		public var oldLineSpan: Int
		public var newLineStart: Int
		public var newLineSpan: Int
		public var lines: [Line]

		public var description: String {
			let header = "@@ -\(oldLineStart),\(oldLineSpan) +\(newLineStart),\(newLineSpan) @@"
			return lines.reduce(into: header) {
				$0 += "\n\($1.description)"
			}
		}

		init(oldLineStart: Int, oldLineSpan: Int, newLineStart: Int, newLineSpan: Int, lines: [Line]) {
			self.oldLineStart = oldLineStart
			self.oldLineSpan = oldLineSpan
			self.newLineStart = newLineStart
			self.newLineSpan = newLineSpan
			self.lines = lines
		}
	}
}

extension Diff.Hunk {
	public struct Line: Equatable, CustomStringConvertible {
		public enum Kind: Equatable {
			case unchanged
			case addition
			case deletion
		}

		public var kind: Kind
		public var text: String

		public var description: String {
			switch kind {
			case .addition:
				return "+\(text)"
			case .deletion:
				return "-\(text)"
			case .unchanged:
				return " \(text)"
			}
		}

		init(type: Kind, text: String) {
			self.kind = type
			self.text = text
		}
	}
}

extension Array where Element == Diff {
	public init(rawDiffContent: String) throws {
		self = rawDiffContent
			.components(separatedBy: "diff --git ")
			.filter { !$0.isEmpty }
			.compactMap { try? Diff(rawDiffContent: $0) }
	}
}

extension Diff {
	static var interactor: DiffInteractor = SwiftCLI()

	public init(baseBranch: Branch, targetBranch: Branch, atPath path: String) throws {
		let rawDiffContent = try Diff.interactor.diff(
			baseBranch: baseBranch.fullName,
			targetBranch: targetBranch.fullName,
			atPath: path
		)
		self = try Diff(rawDiffContent: rawDiffContent)
	}
}

extension Array where Element == Diff {
	public init(baseBranch: Branch, targetBranch: Branch, atPath path: String) throws {
		let rawDiffContent = try Diff.interactor.diff(
			baseBranch: baseBranch.fullName,
			targetBranch: targetBranch.fullName,
			atPath: path
		)
		self = try [Diff](rawDiffContent: rawDiffContent)
	}
}

extension Diff {
	public enum Error {
		case hunkHeaderMissing
		case filePathsNotFound
	}
}

extension Diff.Error: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .filePathsNotFound:
			return "Could not find +++ &/or --- files"
		case .hunkHeaderMissing:
			return "Found a diff line without a hunk header"
		}
	}
}
