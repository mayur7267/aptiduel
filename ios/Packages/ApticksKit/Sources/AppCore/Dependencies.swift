import Networking

// Everything a feature needs from outside, handed in by the app (the
// composition root). Swap in NetworkingFakes for previews and tests.
public struct Dependencies {
    public let api: any APIClient
    public let account: any AccountClient

    public init(api: any APIClient, account: any AccountClient) {
        self.api = api
        self.account = account
    }
}
