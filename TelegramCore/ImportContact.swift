#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func importContact(account:Account, firstName: String, lastName: String, phoneNumber: String) -> Signal<PeerId?, NoError> {
    
    let input = Api.InputContact.inputPhoneContact(clientId: 1, phone: phoneNumber, firstName: firstName, lastName: lastName)
    
    return account.network.request(Api.functions.contacts.importContacts(contacts: [input]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<PeerId?, NoError> in
        return account.postbox.transaction { transaction -> PeerId? in
            if let result = result {
                switch result {
                    case let .importedContacts(_, _, _, users):
                        if let first = users.first {
                            let user = TelegramUser(user: first)
                            let peerId = user.id
                            updatePeers(transaction: transaction, peers: [user], update: { _, updated in
                                return updated
                            })
                            var peerIds = transaction.getContactPeerIds()
                            if !peerIds.contains(peerId) {
                                peerIds.insert(peerId)
                                transaction.replaceContactPeerIds(peerIds)
                            }
                            return peerId
                        }
                }
            }
            return nil
        }
    }
}
