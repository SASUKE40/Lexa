import AppKit
import SwiftUI

/// Sign-in rows for providers that support OAuth (OpenRouter, Nous Portal, GitHub).
/// A successful OpenRouter or GitHub sign-in fills the API key field.
struct ProviderSignInView: View {
    let state: AppState
    let provider: Provider
    @Binding var apiKey: String
    let onSignedIn: () -> Void

    private enum Phase: Equatable {
        case idle
        case browser
        case device(DeviceAuthorization, SignInMethod)
        case done(String)
        case failed(String)
    }

    @State private var phase: Phase = .idle
    @State private var task: Task<Void, Never>?
    @State private var nousSignedIn = NousOAuth.isSignedIn

    var body: some View {
        Group {
            switch phase {
            case .browser:
                waitRow("Complete the sign-in in your browser.")
            case .device(let authorization, let method):
                deviceRows(authorization, method: method)
            default:
                buttons
                if case .done(let message) = phase {
                    Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if case .failed(let message) = phase {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }
        }
        .onChange(of: provider.id) {
            cancel()
            phase = .idle
            nousSignedIn = NousOAuth.isSignedIn
        }
        .onDisappear(perform: cancel)
    }

    // MARK: - Rows

    @ViewBuilder
    private var buttons: some View {
        ForEach(methods, id: \.self) { method in
            switch method {
            case .openRouter:
                LabeledContent("Account") {
                    Button("Sign in with OpenRouter") { start(method) }
                        .buttonStyle(.borderedProminent)
                }
            case .nousPortal:
                LabeledContent("Subscription") {
                    if nousSignedIn {
                        HStack(spacing: 8) {
                            Label("Signed in", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            Button("Sign Out", action: signOutOfNous)
                        }
                    } else {
                        Button("Sign in with Nous Portal") { start(method) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            case .gitHub:
                LabeledContent("Account") {
                    Button("Sign in with GitHub") { start(method) }
                        .buttonStyle(.borderedProminent)
                }
            case .gitHubCLI:
                LabeledContent(methods.contains(.gitHub) ? "Or" : "Account") {
                    Button("Use the GitHub CLI Login") { start(method) }
                }
            }
        }
    }

    private func deviceRows(_ authorization: DeviceAuthorization, method: SignInMethod) -> some View {
        Group {
            LabeledContent("Code") {
                HStack(spacing: 8) {
                    Text(authorization.userCode)
                        .font(.title3.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                    Button {
                        copy(authorization.userCode)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy the code")
                }
            }
            LabeledContent(method == .nousPortal ? "Nous Portal" : "GitHub") {
                Button("Open the Sign-In Page") { NSWorkspace.shared.open(authorization.verificationURLComplete ?? authorization.verificationURL) }
            }
            waitRow(method == .nousPortal
                ? "Make sure that the page shows this code. Then give access."
                : "Paste the code on the GitHub page. Then give access.")
        }
    }

    private func waitRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") {
                cancel()
                phase = .idle
            }
        }
    }

    // MARK: - Actions

    private var methods: [SignInMethod] {
        provider.signIn.filter { $0 != .gitHub || GitHubOAuth.isConfigured }
    }

    private func start(_ method: SignInMethod) {
        cancel()
        task = Task {
            do {
                switch method {
                case .openRouter:
                    phase = .browser
                    let key = try await OpenRouterOAuth.signIn { NSWorkspace.shared.open($0) }
                    save(key, message: "Signed in. Lexa saved a new OpenRouter API key.")
                case .nousPortal:
                    let authorization = try await NousOAuth.startSignIn()
                    phase = .device(authorization, method)
                    NSWorkspace.shared.open(authorization.verificationURLComplete ?? authorization.verificationURL)
                    try await NousOAuth.completeSignIn(authorization)
                    nousSignedIn = true
                    phase = .done("Signed in to Nous Portal.")
                    onSignedIn()
                case .gitHub:
                    let authorization = try await GitHubOAuth.startSignIn()
                    phase = .device(authorization, method)
                    copy(authorization.userCode)
                    NSWorkspace.shared.open(authorization.verificationURL)
                    let token = try await GitHubOAuth.completeSignIn(authorization)
                    save(token, message: "Signed in. Lexa saved the GitHub token.")
                case .gitHubCLI:
                    let token = try await GitHubOAuth.tokenFromCLI()
                    save(token, message: "Lexa saved the token of the GitHub CLI.")
                }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { phase = .failed(error.localizedDescription) }
            }
        }
    }

    private func save(_ key: String, message: String) {
        apiKey = key
        state.setAPIKey(key, for: provider)
        phase = .done(message)
        onSignedIn()
    }

    private func signOutOfNous() {
        Task {
            await NousOAuth.signOut()
            nousSignedIn = false
            phase = .idle
        }
    }

    private func cancel() {
        task?.cancel()
        task = nil
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
