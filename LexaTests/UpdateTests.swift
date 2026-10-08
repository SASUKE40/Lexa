import Foundation
import Testing
@testable import Lexa

struct SemanticVersionTests {
    @Test func parsesTagsAndVersions() {
        #expect(SemanticVersion("v1.0.2")?.description == "1.0.2")
        #expect(SemanticVersion("1.2")?.description == "1.2")
        #expect(SemanticVersion("2.0.0-beta.1")?.description == "2.0.0")
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("v1.x") == nil)
    }

    @Test func comparesNumerically() throws {
        let v = { (s: String) in try #require(SemanticVersion(s)) }
        #expect(try v("1.0.2") < v("1.0.10"))
        #expect(try v("1.9.9") < v("2.0.0"))
        #expect(try v("1.0") == v("1.0.0"))
        #expect(try !(v("1.0.3") < v("1.0.2")))
    }
}

struct ReleaseInfoTests {
    @Test func parsesTheLatestReleaseWithItsAssets() throws {
        let json = #"""
        {"tag_name":"v1.0.3","html_url":"https://github.com/SASUKE40/Lexa/releases/tag/v1.0.3",
         "assets":[
          {"name":"Lexa-1.0.3.zip","browser_download_url":"https://github.com/SASUKE40/Lexa/releases/download/v1.0.3/Lexa-1.0.3.zip"},
          {"name":"Lexa-1.0.3.zip.sha256","browser_download_url":"https://github.com/SASUKE40/Lexa/releases/download/v1.0.3/Lexa-1.0.3.zip.sha256"}]}
        """#
        let release = try ReleaseInfo.parse(Data(json.utf8))
        #expect(release.version.description == "1.0.3")
        #expect(release.tag == "v1.0.3")
        #expect(release.zipURL?.lastPathComponent == "Lexa-1.0.3.zip")
        #expect(release.checksumURL?.lastPathComponent == "Lexa-1.0.3.zip.sha256")
    }

    @Test func toleratesMissingAssets() throws {
        let release = try ReleaseInfo.parse(Data(#"{"tag_name":"v2.0.0","assets":[]}"#.utf8))
        #expect(release.zipURL == nil)
        #expect(release.pageURL == ReleaseInfo.releasesPage)
    }

    @Test func rejectsOtherResponses() {
        #expect(throws: LLMError.self) { try ReleaseInfo.parse(Data(#"{"message":"Not Found"}"#.utf8)) }
    }
}

struct UpdateInstallerTests {
    @Test func parsesShasumOutput() {
        let hash = "d228dba65414422d8d401a1814aa06ded5c04349508792feb438bb4e43e9ed15"
        #expect(UpdateInstaller.parseChecksum("\(hash)  Lexa-1.0.2.zip\n") == hash)
        #expect(UpdateInstaller.parseChecksum(hash.uppercased()) == hash)
        #expect(UpdateInstaller.parseChecksum("not a hash") == nil)
    }

    @Test func hashesFiles() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "lexa-sha-test.txt")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try UpdateInstaller.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func acceptsOnlyAppsWithTheSameSignature() {
        #expect(UpdateInstaller.hasSameSignature(Bundle.main.bundleURL))
        #expect(!UpdateInstaller.hasSameSignature(URL(fileURLWithPath: "/System/Applications/Calculator.app")))
    }
}
