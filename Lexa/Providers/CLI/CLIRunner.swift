import Foundation

nonisolated struct CLIResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    /// stderr if present, otherwise stdout: whichever explains a failure.
    var diagnostics: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return err.isEmpty ? stdout.trimmingCharacters(in: .whitespacesAndNewlines) : err
    }
}

nonisolated struct CLIProcessError: LocalizedError, Sendable {
    let result: CLIResult

    var errorDescription: String? {
        let detail = String(result.diagnostics.suffix(400))
        return detail.isEmpty ? "The command exited with status \(result.status)." : detail
    }
}

/// Runs a subprocess, feeding stdin and streaming stdout line by line.
/// Cancelling the calling task terminates the process.
nonisolated enum CLIRunner {
    static func run(
        _ executable: URL,
        _ arguments: [String],
        stdin: String? = nil,
        workingDirectory: URL? = nil,
        timeout: Duration = .seconds(120),
        onLine: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> CLIResult {
        let process = ProcessHandle(executable: executable, arguments: arguments, workingDirectory: workingDirectory)
        return try await withTaskCancellationHandler {
            try process.start()
            if let stdin { process.write(stdin) }
            process.closeInput()

            let timer = Task {
                try await Task.sleep(for: timeout)
                process.terminate(timedOut: true)
            }
            defer { timer.cancel() }

            var lines: [String] = []
            for try await line in process.stdout.fileHandleForReading.bytes.lines {
                lines.append(line)
                onLine(line)
            }
            let status = await process.waitForExit()
            try Task.checkCancellation()
            if status != 0 { try? await Task.sleep(for: .milliseconds(50)) }
            if process.timedOut {
                throw LLMError("\(executable.lastPathComponent) didn't finish within \(timeout.components.seconds) seconds.")
            }
            return CLIResult(status: status, stdout: lines.joined(separator: "\n"), stderr: process.stderrText)
        } onCancel: {
            process.terminate()
        }
    }

    /// Streams stdout lines; finishes with `CLIProcessError` on a non-zero exit.
    static func lines(
        _ executable: URL,
        _ arguments: [String],
        stdin: String? = nil,
        workingDirectory: URL? = nil,
        timeout: Duration = .seconds(120)
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await run(executable, arguments, stdin: stdin, workingDirectory: workingDirectory,
                                               timeout: timeout) { continuation.yield($0) }
                    if result.status != 0 { throw CLIProcessError(result: result) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Thread-safe wrapper around `Process` and its pipes.
private nonisolated final class ProcessHandle: @unchecked Sendable {
    let stdout = Pipe()
    private let process = Process()
    private let stderr = Pipe()
    private let stdin = Pipe()
    private let lock = NSLock()
    private var stderrData = Data()
    private var exitStatus: Int32?
    private var waiters: [CheckedContinuation<Int32, Never>] = []
    private var didTimeOut = false

    init(executable: URL, arguments: [String], workingDirectory: URL?) {
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory ?? FileManager.default.temporaryDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = CLILocator.environmentPATH(including: executable.deletingLastPathComponent().path)
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                self?.lock.withLock { self?.stderrData.append(data) }
            }
        }
        process.terminationHandler = { [weak self] process in
            self?.finish(process.terminationStatus)
        }
    }

    var timedOut: Bool { lock.withLock { didTimeOut } }

    var stderrText: String {
        lock.withLock { String(decoding: stderrData, as: UTF8.self) }
    }

    func start() throws {
        do {
            try process.run()
        } catch {
            throw LLMError("Couldn't launch \(process.executableURL?.path ?? "process"): \(error.localizedDescription)")
        }
    }

    func write(_ text: String) {
        try? stdin.fileHandleForWriting.write(contentsOf: Data(text.utf8))
    }

    func closeInput() {
        try? stdin.fileHandleForWriting.close()
    }

    func terminate(timedOut: Bool = false) {
        lock.withLock { if timedOut { didTimeOut = true } }
        if process.isRunning { process.terminate() }
    }

    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let status = exitStatus {
                lock.unlock()
                continuation.resume(returning: status)
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    private func finish(_ status: Int32) {
        let pending: [CheckedContinuation<Int32, Never>] = lock.withLock {
            exitStatus = status
            defer { waiters.removeAll() }
            return waiters
        }
        pending.forEach { $0.resume(returning: status) }
    }
}
