/*
Copyright (c) 2023 European Commission

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Modified by AUTHADA GmbH
Copyright (c) 2024 AUTHADA GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation
import CryptoKit
import MdocDataModel18013

extension Cose {
	/// Create a detached COSE-Sign1 structure according to https://datatracker.ietf.org/doc/html/rfc8152#section-4.4
	/// - Parameters:
	///   - payloadData: Payload to be signed
	///   - deviceKey: static device private key (encoded with ANSI x.963 or stored in SE)
	///   - alg: The algorithm to sign with
	/// - Returns: a detached COSE-Sign1 structure
	public static func makeDetachedCoseSign1(payloadData: Data, deviceKey: CoseKeyPrivate, alg: Cose.VerifyAlgorithm) throws-> Cose {
		let coseIn = Cose(type: .sign1, algorithm: alg.rawValue, payloadData: payloadData)
		let dataToSign = coseIn.signatureStruct!
		let signature: Data
		if let keyID = deviceKey.secureEnclaveKeyID {
			let signingKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyID)
			signature = (try! signingKey.signature(for: dataToSign)).rawRepresentation
		} else {
			signature = try computeSignatureValue(dataToSign, deviceKey_x963: deviceKey.getx963Representation(), alg: alg)
		}
		// return COSE_SIGN1 struct
		return Cose(type: .sign1, algorithm: alg.rawValue, signature: signature)
	}
	
	/// Generates an Elliptic Curve Digital Signature Algorithm (ECDSA) signature of the provide data over an elliptic curve. Apple Crypto implementation is used
	/// - Parameters:
	///   - dataToSign: Data to create the signature for (payload)
	///   - deviceKey_x963: x963 representation of the private key
	///   - alg: ``MdocDataModel18013/Cose.VerifyAlgorithm``
	/// - Returns: The signature corresponding to the data
	public static func computeSignatureValue(_ dataToSign: Data, deviceKey_x963: Data, alg: Cose.VerifyAlgorithm) throws -> Data {
		let sign1Value: Data
		switch alg {
		case .es256:
			let signingKey = try P256.Signing.PrivateKey(x963Representation: deviceKey_x963)
			sign1Value = (try! signingKey.signature(for: dataToSign)).rawRepresentation
		case .es384:
			let signingKey = try P384.Signing.PrivateKey(x963Representation: deviceKey_x963)
			sign1Value = (try! signingKey.signature(for: dataToSign)).rawRepresentation
		case .es512:
			let signingKey = try P521.Signing.PrivateKey(x963Representation: deviceKey_x963)
			sign1Value = (try! signingKey.signature(for: dataToSign)).rawRepresentation
        case .dvsp256, .dvsp384, .dvsp512:
            throw NSError(domain: "CoseSignature", code: 0, userInfo: [NSLocalizedDescriptionKey : "computeSignatureValue not implemented for \(alg)"])
		}
		return sign1Value
	}
	
	
	/// Validate (verify) a detached COSE-Sign1 structure according to https://datatracker.ietf.org/doc/html/rfc8152#section-4.4
	/// - Parameters:
	///   - payloadData: Payload data signed
	///   - publicKey_x963: public key corresponding the private key used to sign the data
	/// - Returns: True if validation of signature succeeds
	public func validateDetachedCoseSign1(payloadData: Data, publicKey_x963: Data) throws -> Bool {
		let b: Bool
		guard type == .sign1 else { logger.error("Cose must have type sign1"); return false}
		guard let verifyAlgorithm = verifyAlgorithm else { logger.error("Cose signature algorithm not found"); return false}
		let coseWithPayload = Cose(other: self, payloadData: payloadData)
		guard let signatureStruct = coseWithPayload.signatureStruct else { logger.error("Cose signature struct cannot be computed"); return false}
		switch verifyAlgorithm {
		case .es256:
			let signingPubKey = try P256.Signing.PublicKey(x963Representation: publicKey_x963)
			let ecdsa_signature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
			b = signingPubKey.isValidSignature(ecdsa_signature, for: signatureStruct)
		case .es384:
			let signingPubKey = try P384.Signing.PublicKey(x963Representation: publicKey_x963)
			let ecdsa_signature = try P384.Signing.ECDSASignature(rawRepresentation: signature)
			b = signingPubKey.isValidSignature(ecdsa_signature, for: signatureStruct)
		case .es512:
			let signingPubKey = try P521.Signing.PublicKey(x963Representation: publicKey_x963)
			let ecdsa_signature = try P521.Signing.ECDSASignature(rawRepresentation: signature)
			b = signingPubKey.isValidSignature(ecdsa_signature, for: signatureStruct)
        case .dvsp256, .dvsp384, .dvsp512:
            throw NSError(domain: "CoseSignature", code: 0, userInfo: [NSLocalizedDescriptionKey : "validateDetachedCoseSign1 not implemented for \(verifyAlgorithm)"])
		}
		return b
	}
}
