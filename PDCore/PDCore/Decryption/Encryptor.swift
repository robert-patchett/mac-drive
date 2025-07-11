// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation
import ProtonCoreCryptoGoInterface
import ProtonCoreKeyManager

public struct RevisionContentKeys {
    public let contentSessionKey: SessionKey
    public let contentKeyPacket: KeyPacket
    public let contentKeyPacketBase64: ArmoredMessage
    public let contentKeyPacketSignature: ArmoredSignature
}

/// ProtonCore_KeyManager framework provides a number of static methods - high-level API to work with Crypto.xcframework
/// This class gives us space to override that functional
public class Encryptor {

    typealias CoreEncryptor = ProtonCoreKeyManager.Encryptor
    typealias EncryptedBinary = CoreEncryptor.EncryptedBlock
    typealias Errors = CoreEncryptor.Errors

    public init() {}

    static func hmac(filename: String, parentHashKey: String) throws -> String {
        try CoreEncryptor.hmac(filename: filename, parentHashKey: parentHashKey)
    }

    static func encrypt(_ cleartext: String, key: String) throws -> String {
        try CoreEncryptor.encrypt(cleartext, key: key)
    }

    public static func encryptAndSign(_ cleartext: String,
                                      key: String,
                                      addressPassphrase: String,
                                      addressPrivateKey: String) throws -> String
    {
        try CoreEncryptor.encryptAndSign(cleartext, key: key, addressPassphrase: addressPassphrase, addressPrivateKey: addressPrivateKey)
    }

    static func encryptBinary(chunk: Data,
                              contentKeyPacket: Data,
                              nodeKey: String,
                              nodePassphrase: String) throws -> EncryptedBinary
    {
        try CoreEncryptor.encryptBinary(chunk: chunk, contentKeyPacket: contentKeyPacket, nodeKey: nodeKey, nodePassphrase: nodePassphrase)
    }

    static func sign(list: Data,
                     addressKey: String,
                     addressPassphrase: String) throws -> String
    {
        try CoreEncryptor.sign(list: list, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }

    static func signcrypt(plaintext: Data,
                          nodeKey: String,
                          addressKey: String,
                          addressPassphrase: String) throws -> String
    {
        try CoreEncryptor.signcrypt(plaintext: plaintext, nodeKey: nodeKey, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }

    static func encryptSessionKey(_ sessionKey: CryptoSessionKey, withKey key: String) throws -> String {
        try CoreEncryptor.encryptSessionKey(sessionKey, withKey: key)
    }
    
    static func encryptSessionKey(sessionKey: SessionKey, with key: String) throws -> String {
        let sessionKey = try unwrap { CryptoGo.CryptoNewSessionKeyFromToken(sessionKey, CryptoGo.ConstantsAES256) }
        return try encryptSessionKey(sessionKey, withKey: key)
    }

    // swiftlint:disable function_parameter_count
    static func encryptAndSignBinary(clearData: Data, contentKeyPacket: Data, privateKey: String, passphrase: String, addressKey: String, addressPassphrase: String) throws -> EncryptedBinary {
        try CoreEncryptor.encryptAndSignBinary(clearData: clearData, contentKeyPacket: contentKeyPacket, privateKey: privateKey, passphrase: passphrase, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }

    static func encryptAndSignBinaryWithSessionKey(clearData: Data, sessionKey: SessionKey, signingKeyRing: CryptoKeyRing) throws -> Data {
        let sessionKey = try unwrap { CryptoGo.CryptoNewSessionKeyFromToken(sessionKey, CryptoGo.ConstantsAES256) }
        let plainMessage = try unwrap { CryptoGo.CryptoNewPlainMessage(clearData) }
        return try sessionKey.encryptAndSign(plainMessage, sign: signingKeyRing)
    }
    // swiftlint:enable function_parameter_count

    static func encryptAndSign(_ plainData: Data, encryptionKey: ArmoredKey, signingKey: ArmoredKey, passphrase: String) throws -> String {
        let (plainMessage, encryptionKeyRing, signingKeyRing) = try encryptAndSignKeyElements(from: plainData, encryptionKey, signingKey, passphrase)
        defer { signingKeyRing.clearPrivateParams() }

        let cryptoPGPMessage = try encryptionKeyRing.encrypt(plainMessage, privateKey: signingKeyRing)
        let armoredMessage = try executeAndUnwrap { cryptoPGPMessage.getArmored(&$0) }

        return armoredMessage
    }

    static func encryptAndSignWithCompression(_ plainData: Data, encryptionKey: ArmoredKey, signingKey: ArmoredKey, passphrase: String) throws -> String {
        let (plainMessage, encryptionKeyRing, signingKeyRing) = try encryptAndSignKeyElements(from: plainData, encryptionKey, signingKey, passphrase)
        defer { signingKeyRing.clearPrivateParams() }

        let cryptoPGPMessage = try encryptionKeyRing.encrypt(withCompression: plainMessage, privateKey: signingKeyRing)
        let armoredMessage = try executeAndUnwrap { cryptoPGPMessage.getArmored(&$0) }

        return armoredMessage
    }

    private static func encryptAndSignKeyElements(
        from plainData: Data,
        _ encryptionKey: ArmoredKey,
        _ signingKey: ArmoredKey,
        _ passphrase: String
    ) throws -> (plainMessage: CryptoPlainMessage, encryptionKeyRing: CryptoKeyRing, signingKeyRing: CryptoKeyRing) {
        let encryptionKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(encryptionKey, &$0) }
        let encryptionKeyRing = try executeAndUnwrap { CryptoGo.CryptoNewKeyRing(encryptionKey, &$0) }

        let signingKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(signingKey, &$0) }
        let unlockedSigningKey = try signingKey.unlock(passphrase.data(using: .utf8))
        let signingKeyRing = try executeAndUnwrap { CryptoGo.CryptoNewKeyRing(unlockedSigningKey, &$0) }

        let plainMessage = CryptoGo.CryptoNewPlainMessage(plainData)!
        return (plainMessage, encryptionKeyRing, signingKeyRing)
    }

    static func getPublicKey(fromPrivateKey privateKey: ArmoredKey) throws -> ArmoredKey {
        let privateKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(privateKey, &$0) }
        let publicArmoredKey = try executeAndUnwrap { privateKey.getArmoredPublicKey(&$0) }
        return publicArmoredKey
    }

    static func reencryptKeyPacket(
        of encryptedMessage: String,
        oldParentKey: String,
        oldParentPassphrase: String,
        newParentKey: String
    ) throws -> String {
        let oldSplitMessage = try Encryptor.splitPGPMessage(encryptedMessage)

        let decKeyRing = try Decryptor.buildPrivateKeyRing(decryptionKeys: [
            .init(privateKey: oldParentKey, passphrase: oldParentPassphrase)
        ])
        let sessionKey = try execute { try decKeyRing.decryptSessionKey(oldSplitMessage.keyPacket) }

        let encKeyRing = try Decryptor.buildPublicKeyRing(armoredKeys: [newParentKey])
        let newKeyPacket = try encKeyRing.encryptSessionKey(sessionKey)

        let newSplitMessage = CryptoGo.CryptoPGPSplitMessage(newKeyPacket, dataPacket: oldSplitMessage.dataPacket)

        return try executeAndUnwrap { newSplitMessage?.getArmored(&$0) }
    }

    /// Appends new KeyPacket to a PGPMessage using a new encryption key.
    ///
    /// This method takes an encrypted message, the initial encrypting key, the passphrase for
    /// the initial encrypting key, and the new encrypting key. It decrypts the SessionKey
    /// using the initial encrypting key and passphrase, then reencrypts the session key
    /// with the new encrypting key. Then it combines both key packets and returns a new PGP message
    /// containing both key packets and the original data packet
    static func encryptPGPMessageToAdditionalKey(
        _ encryptedMessage: String,
        oldEncryptingKey: String,
        oldEncryptingKeyPassphrase: String,
        newEncryptingKey: String
    ) throws -> ArmoredMessage {
        let initialSplitMessage = try Encryptor.splitPGPMessage(encryptedMessage)

        let initialKeyPacket = try unwrap { initialSplitMessage.keyPacket }
        let initialDataPacket = try unwrap { initialSplitMessage.dataPacket }

        let decKeyRing = try Decryptor.buildPrivateKeyRing(decryptionKeys: [
            .init(privateKey: oldEncryptingKey, passphrase: oldEncryptingKeyPassphrase)
        ])
        let sessionKey = try execute { try decKeyRing.decryptSessionKey(initialKeyPacket) }
        let newKeyPacket = try executeAndUnwrap { CryptoGo.HelperEncryptSessionKey(newEncryptingKey, sessionKey, &$0) }
        let composedKeyPacket = newKeyPacket + initialKeyPacket
        let newSplitMessage = try unwrap { CryptoGo.CryptoPGPSplitMessage(composedKeyPacket, dataPacket: initialDataPacket) }

        return try execute { newSplitMessage.getArmored(&$0) }
    }

    public static func sign(
        _ input: KeyPacket,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data {
        return try DriveCrypto.sign(input, context: context, privateKey: privateKey, passphrase: passphrase)
    }
}

public struct NodeUpdatedCredentials {
    public let nodePassphrase: String
    public let signature: String

    public init(nodePassphrase: String, signature: String) {
        self.nodePassphrase = nodePassphrase
        self.signature = signature
    }
}

extension Encryptor {

    static func generateNodeKeys(addressPassphrase: String,
                                 addressPrivateKey: String,
                                 parentKey: String) throws -> KeyCredentials
    {
        var error: NSError?

        // length is hardcoded in proton-shared/lib/keys/calendarKeys.ts
        let passphraseByteLength = 32
        let passphraseRaw1 = CryptoGo.CryptoRandomToken(passphraseByteLength, &error)
        guard error == nil else { throw error! }

        let passphraseString = passphraseRaw1!.base64EncodedString()
        let passphraseRaw = passphraseString.data(using: .utf8)

        // 1. NodeKey
        // all hardcoded values are from proton-shared/lib/keys/driveKeys.ts
        // bits are unused for x25519 type keys
        let privateKeyArmored = CryptoGo.HelperGenerateKey("Drive key", "noreply@protonmail.com", passphraseRaw, "x25519", 0, &error)
        guard error == nil else { throw error! }

        // 2. NodePassphrase
        let encryptedAndSignedPassphrase = try updateNodeKeys(passphraseString: passphraseString,
                                                              addressPassphrase: addressPassphrase,
                                                              addressPrivateKey: addressPrivateKey,
                                                              parentKey: parentKey)
        guard error == nil else { throw error! }

        let encryptedPassphrase = encryptedAndSignedPassphrase.nodePassphrase
        let signature = encryptedAndSignedPassphrase.signature

        return KeyCredentials(
            key: privateKeyArmored,
            passphrase: encryptedPassphrase,
            signature: signature,
            passphraseRaw: passphraseString
        )
    }

    static func updateNodeKeys(passphraseString: String,
                               addressPassphrase: String,
                               addressPrivateKey: String,
                               parentKey: String) throws -> NodeUpdatedCredentials
    {
        var error: NSError?

        // 1. NodePassphrase gets encrypted by the parent key
        let encryptedPassphrase = CryptoGo.HelperEncryptMessageArmored(parentKey, passphraseString, &error)
        guard error == nil else { throw error! }

        // 2. NodePassphrase Signature
        let keyAddress = CryptoGo.CryptoNewKeyFromArmored(addressPrivateKey, &error)
        guard error == nil else { throw error! }

        let unlockedKey = try keyAddress?.unlock(addressPassphrase.data(using: .utf8))
        let keyRing = CryptoGo.CryptoNewKeyRing(unlockedKey, &error)
        guard error == nil else { throw error! }

        let message = CryptoGo.CryptoPlainMessage(from: passphraseString)
        let signature = try keyRing?.signDetached(message).getArmored(&error)
        keyRing?.clearPrivateParams()

        return .init(nodePassphrase: encryptedPassphrase,
                     signature: signature!)
    }

    static func encrypt(_ plainMessage: String, using sesionKey: CryptoSessionKey, encryptingKeyRing: CryptoKeyRing) throws -> CryptoPGPSplitMessage {
        let cryptoMessage = CryptoGo.CryptoPlainMessage(from: plainMessage)
        let dataPacket = try sesionKey.encrypt(cryptoMessage)
        let keyPacket = try encryptingKeyRing.encryptSessionKey(sesionKey)
        return try execute { CryptoGo.CryptoNewPGPSplitMessage(keyPacket, dataPacket) }
    }

    static func encryptAndSign(_ plainMessage: String, using sessionKey: CryptoSessionKey, encryptingKeyRing: CryptoKeyRing, signingKeyRing: CryptoKeyRing) throws -> CryptoPGPSplitMessage {
        let cryptoMessage = CryptoGo.CryptoPlainMessage(from: plainMessage)
        let dataPacket = try sessionKey.encryptAndSign(cryptoMessage, sign: signingKeyRing)
        let keyPacket = try encryptingKeyRing.encryptSessionKey(sessionKey)
        return try execute { CryptoGo.CryptoNewPGPSplitMessage(keyPacket, dataPacket) }
    }

    static func generateNodeHashKey(nodeKey: String, passphrase: String) throws -> String {
        // 1. create hash key
        let rawHashKey = try executeAndUnwrap { CryptoGo.CryptoRandomToken(32, &$0) }

        // 2. Encrypt the rawHashKey with the public nodeKey (private -> public done by the Helper) and sign it
        let nodeHashKey = try execute {
            CryptoGo.HelperEncryptSignMessageArmored(
                nodeKey,
                nodeKey,
                passphrase.data(using: .utf8),
                rawHashKey.base64EncodedString(),
                &$0
            )
        }

        return nodeHashKey
    }

    // MARK: - Drive Helpers
    static func splitPGPMessage(_ message: String) throws -> (keyPacket: KeyPacket?, dataPacket: DataPacket?) {
        let splitMessage = try unwrap { CryptoGo.CryptoPGPSplitMessage(fromArmored: message) }
        return (splitMessage.keyPacket, splitMessage.dataPacket)
    }

    public static func generateContentKeys(
        nodeKey: ArmoredKey,
        nodePassphrase: Passphrase
    ) throws -> RevisionContentKeys {

        let cryptoContentSessionKey = try executeAndUnwrap { CryptoGo.CryptoGenerateSessionKeyAlgo(CryptoGo.ConstantsAES256, &$0) }
        let contentSessionKey = try unwrap { cryptoContentSessionKey.key }
        let contentKeyPacket = try executeAndUnwrap { CryptoGo.HelperEncryptSessionKey(nodeKey, cryptoContentSessionKey, &$0) }
        let contentKeyPacketBase64 = contentKeyPacket.base64EncodedString()

        let signingKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(nodeKey, &$0) }
        let unlockedSigningKey = try signingKey.unlock(nodePassphrase.data(using: .utf8))
        let signingKeyRing = try executeAndUnwrap { CryptoGo.CryptoNewKeyRing(unlockedSigningKey, &$0) }
        defer { signingKeyRing.clearPrivateParams() }

        let message = CryptoGo.CryptoNewPlainMessage(contentSessionKey)
        let cryptoContentKeyPacketSignature = try signingKeyRing.signDetached(message)
        let contentKeyPacketSignature = try executeAndUnwrap { cryptoContentKeyPacketSignature.getArmored(&$0) }

        return RevisionContentKeys(
            contentSessionKey: contentSessionKey,
            contentKeyPacket: contentKeyPacket,
            contentKeyPacketBase64: contentKeyPacketBase64,
            contentKeyPacketSignature: contentKeyPacketSignature
        )
    }
}

private extension Int64 {
    static var cryptoTime: Int64 { CryptoGo.CryptoGetUnixTime() }
}

extension Encryptor: EncryptionResource {
    public func encryptAndSign(_ cleartext: String, key: String, addressPassphrase: String, addressPrivateKey: String) throws -> String {
        return try Encryptor.encryptAndSign(cleartext, key: key, addressPassphrase: addressPassphrase, addressPrivateKey: addressPrivateKey)
    }

    public func makeHmac(string: String, hashKey: String) throws -> String {
        return try Encryptor.hmac(filename: string, parentHashKey: hashKey)
    }
    
    public func generateNodeKeys(addressPassphrase: String, addressPrivateKey: String, parentKey: String) throws -> KeyCredentials {
        return try Encryptor.generateNodeKeys(addressPassphrase: addressPassphrase, addressPrivateKey: addressPrivateKey, parentKey: parentKey)
    }

    public func updateNodeKeys(
        passphrase: String,
        addressPassphrase: String,
        addressPrivateKey: String,
        parentKey: String
    ) throws -> NodeUpdatedCredentials {
        return try Encryptor.updateNodeKeys(passphraseString: passphrase, addressPassphrase: addressPassphrase, addressPrivateKey: addressPrivateKey, parentKey: parentKey)
    }

    public func generateNodeHashKey(nodeKey: String, passphrase: String) throws -> String {
        return try Encryptor.generateNodeHashKey(nodeKey: nodeKey, passphrase: passphrase)
    }

    public func generateContentKeys(nodeKey: ArmoredKey, nodePassphrase: Passphrase) throws -> RevisionContentKeys {
        return try Encryptor.generateContentKeys(nodeKey: nodeKey, nodePassphrase: nodePassphrase)
    }

    public func sign(data: Data, addressKey: String, addressPassphrase: String) throws -> String {
        return try Encryptor.sign(list: data, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }
    
    /// - Returns: Base64 encoded data
    public func encryptSessionKey(sessionKey: SessionKey, with key: String) throws -> KeyPacket {
        let sessionKey = try unwrap { CryptoGo.CryptoNewSessionKeyFromToken(sessionKey, CryptoGo.ConstantsAES256) }
        let keyPacket = try Self.encryptSessionKey(sessionKey, withKey: key)
        return try unwrap { Data(base64Encoded: keyPacket) }
    }
    
    public func sign(
        _ input: KeyPacket,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data {
        return try DriveCrypto.sign(input, context: context, privateKey: privateKey, passphrase: passphrase)
    }
    
    public func sign(
        text: String,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data {
        return try DriveCrypto.sign(text, context: .init(value: context, isCritical: true), privateKey: privateKey, passphrase: passphrase)
    }

    public func reencryptKeyPacket(
        of encryptedMessage: String,
        oldParentKey: String,
        oldParentPassphrase: String,
        newParentKey: String
    ) throws -> String {
        try Encryptor.reencryptKeyPacket(
            of: encryptedMessage,
            oldParentKey: oldParentKey,
            oldParentPassphrase: oldParentPassphrase,
            newParentKey: newParentKey
        )
    }
}
