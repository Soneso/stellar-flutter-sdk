// Copyright 2023 The Stellar Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';
import '../key_pair.dart';
import '../network.dart';
import '../util.dart';
import '../xdr/xdr_contract.dart';
import '../xdr/xdr_transaction.dart';
import '../xdr/xdr_type.dart';
import '../xdr/xdr_data_io.dart';

/// Represents a single address in the Stellar network.
///
/// An address can represent an account or a contract.
/// To create an address, call [Address.new]
/// or use [Address.forAccountId] to create an Address for a given accountId
/// or use [Address.forContractId] to create an Address for a given contractId
/// or use [Address.fromXdr] to create an Address for a given [XdrSCAddress].
class Address {
  static const int TYPE_ACCOUNT = 0;
  static const int TYPE_CONTRACT = 1;

  int _type;

  /// The type of the Address (TYPE_ACCOUNT or TYPE_CONTRACT).
  get type => _type;

  /// The id of the account if type is TYPE_ACCOUNT otherwise null.
  String? accountId;

  /// The id of the contract if type is TYPE_CONTRACT otherwise null.
  String? contractId;

  /// Constructs an [Address] for the given [type] which can be [Address.TYPE_ACCOUNT] or [Address.TYPE_CONTRACT].
  ///
  /// If [Address.TYPE_ACCOUNT] one must provide [accountId].
  /// If [Address.TYPE_CONTRACT] one must provide [contractId].
  Address(this._type, {this.accountId, this.contractId}) {
    if (this._type != TYPE_ACCOUNT && this._type != TYPE_CONTRACT) {
      throw new Exception("unknown type");
    }

    if (this._type == TYPE_ACCOUNT && this.accountId == null) {
      throw new Exception("invalid arguments");
    }

    if (this._type == TYPE_CONTRACT && this.contractId == null) {
      throw new Exception("invalid arguments");
    }
  }

  /// Constructs an [Address] of type [Address.TYPE_ACCOUNT] for the given [accountId].
  static Address forAccountId(String accountId) {
    return Address(TYPE_ACCOUNT, accountId: accountId);
  }

  /// Constructs an [Address] of type [Address.TYPE_CONTRACT] for the given [contractId].
  static Address forContractId(String contractId) {
    return Address(TYPE_CONTRACT, contractId: contractId);
  }

  /// Constructs an [Address] from the given [xdr].
  static Address fromXdr(XdrSCAddress xdr) {
    if (xdr.discriminant == XdrSCAddressType.SC_ADDRESS_TYPE_ACCOUNT) {
      KeyPair kp = KeyPair.fromXdrPublicKey(xdr.accountId!.accountID);
      return Address(TYPE_ACCOUNT, accountId: kp.accountId);
    } else if (xdr.discriminant == XdrSCAddressType.SC_ADDRESS_TYPE_CONTRACT) {
      return Address(TYPE_CONTRACT,
          contractId: Util.bytesToHex(xdr.contractId!.hash));
    } else {
      throw Exception("unknown address type " + xdr.discriminant.toString());
    }
  }

  /// Returns a [XdrSCAddress] object created from this [Address] object.
  XdrSCAddress toXdr() {
    if (_type == TYPE_ACCOUNT) {
      if (accountId == null) {
        throw Exception("invalid address, has no account id");
      }
      return XdrSCAddress.forAccountId(accountId!);
    } else if (_type == TYPE_CONTRACT) {
      if (contractId == null) {
        throw Exception("invalid address, has no contract id");
      }
      return XdrSCAddress.forContractId(contractId!);
    } else {
      throw Exception("unknown address type " + _type.toString());
    }
  }

  /// Returns a [XdrSCVal] containing an [XdrSCObject] for this [Address].
  XdrSCVal toXdrSCVal() {
    return XdrSCVal.forAddress(toXdr());
  }
}

class SorobanAddressCredentials {
  Address address;
  int nonce;
  int signatureExpirationLedger;
  List<XdrSCVal> signatureArgs = List<XdrSCVal>.empty(growable: true);

  SorobanAddressCredentials(
      this.address, this.nonce, this.signatureExpirationLedger,
      {List<XdrSCVal>? signatureArgs}) {
    if (signatureArgs != null) {
      this.signatureArgs = signatureArgs;
    }
  }

  static SorobanAddressCredentials fromXdr(XdrSorobanAddressCredentials xdr) {
    return SorobanAddressCredentials(Address.fromXdr(xdr.address),
        xdr.nonce.int64, xdr.signatureExpirationLedger.uint32,
        signatureArgs: xdr.signaturArgs);
  }

  XdrSorobanAddressCredentials toXdr() {
    return new XdrSorobanAddressCredentials(address.toXdr(), XdrInt64(nonce),
        XdrUint32(signatureExpirationLedger), signatureArgs);
  }
}

class SorobanCredentials {
  SorobanAddressCredentials? addressCredentials;

  SorobanCredentials({SorobanAddressCredentials? addressCredentials}) {
    if (addressCredentials != null) {
      this.addressCredentials = addressCredentials;
    }
  }

  static SorobanCredentials forSourceAccount() {
    return SorobanCredentials();
  }

  static SorobanCredentials forAddress(
      Address address, int nonce, int signatureExpirationLedger,
      {List<XdrSCVal>? signatureArgs}) {
    SorobanAddressCredentials addressCredentials = SorobanAddressCredentials(
        address, nonce, signatureExpirationLedger,
        signatureArgs: signatureArgs);
    return SorobanCredentials(addressCredentials: addressCredentials);
  }

  static SorobanCredentials forAddressCredentials(
      SorobanAddressCredentials addressCredentials) {
    return SorobanCredentials(addressCredentials: addressCredentials);
  }

  static SorobanCredentials fromXdr(XdrSorobanCredentials xdr) {
    if (xdr.type == XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS &&
        xdr.address != null) {
      return SorobanCredentials.forAddressCredentials(
          SorobanAddressCredentials.fromXdr(xdr.address!));
    }
    return SorobanCredentials();
  }

  XdrSorobanCredentials toXdr() {
    if (addressCredentials != null) {
      XdrSorobanCredentials cred = XdrSorobanCredentials(
          XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS);
      cred.address = addressCredentials!.toXdr();
      return cred;
    }
    return XdrSorobanCredentials(
        XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_SOURCE_ACCOUNT);
  }
}

class SorobanAuthorizedContractFunction {
  Address contractAddress;
  String functionName;
  List<XdrSCVal> args = List<XdrSCVal>.empty(growable: true);

  SorobanAuthorizedContractFunction(this.contractAddress, this.functionName,
      {List<XdrSCVal>? args}) {
    if (args != null) {
      this.args = args;
    }
  }

  static SorobanAuthorizedContractFunction fromXdr(
      XdrSorobanAuthorizedContractFunction xdr) {
    return SorobanAuthorizedContractFunction(
        Address.fromXdr(xdr.contractAddress), xdr.functionName,
        args: xdr.args);
  }

  XdrSorobanAuthorizedContractFunction toXdr() {
    return XdrSorobanAuthorizedContractFunction(
        contractAddress.toXdr(), functionName, args);
  }
}

class SorobanAuthorizedFunction {
  SorobanAuthorizedContractFunction? contractFn;
  XdrCreateContractArgs? createContractHostFn;

  SorobanAuthorizedFunction(
      {SorobanAuthorizedContractFunction? contractFn,
      XdrCreateContractArgs? createContractHostFn}) {
    if (contractFn == null && createContractHostFn == null) {
      throw ArgumentError("invalid arguments");
    }
    if (contractFn != null && createContractHostFn != null) {
      throw ArgumentError("invalid arguments");
    }
    this.contractFn = contractFn;
    this.createContractHostFn = createContractHostFn;
  }

  static SorobanAuthorizedFunction forContractFunction(
      Address contractAddress, String functionName,
      {List<XdrSCVal>? args}) {
    SorobanAuthorizedContractFunction cfn = SorobanAuthorizedContractFunction(
        contractAddress, functionName,
        args: args);
    return SorobanAuthorizedFunction(contractFn: cfn);
  }

  static SorobanAuthorizedFunction forCreateContractHostFunction(
      XdrCreateContractArgs createContractHostFn) {
    return SorobanAuthorizedFunction(
        createContractHostFn: createContractHostFn);
  }

  static SorobanAuthorizedFunction fromXdr(XdrSorobanAuthorizedFunction xdr) {
    if (xdr.type ==
            XdrSorobanAuthorizedFunctionType
                .SOROBAN_AUTHORIZED_FUNCTION_TYPE_CONTRACT_FN &&
        xdr.contractFn != null) {
      return SorobanAuthorizedFunction(
          contractFn:
              SorobanAuthorizedContractFunction.fromXdr(xdr.contractFn!));
    } else {
      return SorobanAuthorizedFunction(
          createContractHostFn: xdr.createContractHostFn);
    }
  }

  XdrSorobanAuthorizedFunction toXdr() {
    if (contractFn != null) {
      XdrSorobanAuthorizedFunction cfn = XdrSorobanAuthorizedFunction(
          XdrSorobanAuthorizedFunctionType
              .SOROBAN_AUTHORIZED_FUNCTION_TYPE_CONTRACT_FN);
      cfn.contractFn = contractFn!.toXdr();
      return cfn;
    }
    XdrSorobanAuthorizedFunction cfn = XdrSorobanAuthorizedFunction(
        XdrSorobanAuthorizedFunctionType
            .SOROBAN_AUTHORIZED_FUNCTION_TYPE_CREATE_CONTRACT_HOST_FN);
    cfn.createContractHostFn = createContractHostFn!;
    return cfn;
  }
}

class SorobanAuthorizedInvocation {
  SorobanAuthorizedFunction function;
  List<SorobanAuthorizedInvocation> subInvocations =
      List<SorobanAuthorizedInvocation>.empty(growable: true);

  SorobanAuthorizedInvocation(this.function,
      {List<SorobanAuthorizedInvocation>? subInvocations}) {
    if (subInvocations != null) {
      this.subInvocations = subInvocations;
    }
  }

  static SorobanAuthorizedInvocation fromXdr(
      XdrSorobanAuthorizedInvocation xdr) {
    List<SorobanAuthorizedInvocation> subInvocations =
        List<SorobanAuthorizedInvocation>.empty(growable: true);
    for (XdrSorobanAuthorizedInvocation subXdr in xdr.subInvocations) {
      subInvocations.add(SorobanAuthorizedInvocation.fromXdr(subXdr));
    }
    return SorobanAuthorizedInvocation(
        SorobanAuthorizedFunction.fromXdr(xdr.function),
        subInvocations: subInvocations);
  }

  XdrSorobanAuthorizedInvocation toXdr() {
    List<XdrSorobanAuthorizedInvocation> xdrSubInvocations =
        List<XdrSorobanAuthorizedInvocation>.empty(growable: true);
    for (SorobanAuthorizedInvocation sub in this.subInvocations) {
      xdrSubInvocations.add(sub.toXdr());
    }
    return XdrSorobanAuthorizedInvocation(
        this.function.toXdr(), xdrSubInvocations);
  }
}

class SorobanAuthorizationEntry {
  SorobanCredentials credentials;
  SorobanAuthorizedInvocation rootInvocation;
  SorobanAuthorizationEntry(this.credentials, this.rootInvocation);

  static SorobanAuthorizationEntry fromXdr(XdrSorobanAuthorizationEntry xdr) {
    return SorobanAuthorizationEntry(
        SorobanCredentials.fromXdr(xdr.credentials),
        SorobanAuthorizedInvocation.fromXdr(xdr.rootInvocation));
  }

  XdrSorobanAuthorizationEntry toXdr() {
    return XdrSorobanAuthorizationEntry(
        this.credentials.toXdr(), this.rootInvocation.toXdr());
  }

  static SorobanAuthorizationEntry fromBase64EncodedXdr(String xdr) {
    Uint8List bytes = base64Decode(xdr);
    return SorobanAuthorizationEntry.fromXdr(
        XdrSorobanAuthorizationEntry.decode(XdrDataInputStream(bytes)));
  }

  String toBase64EncodedXdrString() {
    XdrDataOutputStream xdrOutputStream = XdrDataOutputStream();
    XdrSorobanAuthorizationEntry.encode(xdrOutputStream, this.toXdr());
    return base64Encode(xdrOutputStream.bytes);
  }

  /// Signs the authorization entry.
  ///
  /// The signature will be added to the [signatureArgs] of the soroban credentials
  void sign(KeyPair signer, Network network) {
    XdrSorobanCredentials xdrCredentials = credentials.toXdr();
    if (credentials.addressCredentials == null ||
        xdrCredentials.type !=
            XdrSorobanCredentialsType.SOROBAN_CREDENTIALS_ADDRESS ||
        xdrCredentials.address == null) {
      throw Exception("no soroban address credentials found");
    }

    XdrHashIDPreimageSorobanAuthorization authPreimageXdr =
        XdrHashIDPreimageSorobanAuthorization(
            XdrHash(network.networkId!),
            xdrCredentials.address!.nonce,
            xdrCredentials.address!.signatureExpirationLedger,
            rootInvocation.toXdr());
    XdrHashIDPreimage rootInvocationPreimage =
        XdrHashIDPreimage(XdrEnvelopeType.ENVELOPE_TYPE_SOROBAN_AUTHORIZATION);
    rootInvocationPreimage.sorobanAuthorization = authPreimageXdr;
    XdrDataOutputStream xdrOutputStream = XdrDataOutputStream();
    XdrHashIDPreimage.encode(xdrOutputStream, rootInvocationPreimage);
    Uint8List payload = Util.hash(Uint8List.fromList(xdrOutputStream.bytes));
    Uint8List signatureBytes = signer.sign(payload);
    AccountEd25519Signature signature =
        AccountEd25519Signature(signer.xdrPublicKey, signatureBytes);
    credentials.addressCredentials!.signatureArgs.add(signature.toXdrSCVal());
  }
}

/// Represents a signature used by [SorobanAuthorizationEntry].
class AccountEd25519Signature {
  XdrPublicKey publicKey;
  Uint8List signatureBytes;

  AccountEd25519Signature(this.publicKey, this.signatureBytes);

  XdrSCVal toXdrSCVal() {
    XdrSCVal pkVal = XdrSCVal.forBytes(publicKey.getEd25519()!.uint256);
    XdrSCVal sigVal = XdrSCVal.forBytes(signatureBytes);
    XdrSCMapEntry pkEntry =
        XdrSCMapEntry(XdrSCVal.forSymbol("public_key"), pkVal);
    XdrSCMapEntry sigEntry =
        XdrSCMapEntry(XdrSCVal.forSymbol("signature"), sigVal);
    return XdrSCVal.forMap([pkEntry, sigEntry]);
  }
}
