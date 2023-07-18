// Copyright 2023 The Stellar Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'package:pinenacl/tweetnacl.dart';
import 'xdr/xdr_transaction.dart';
import 'operation.dart';
import 'muxed_account.dart';
import 'util.dart';
import 'assets.dart';
import 'xdr/xdr_operation.dart';
import 'xdr/xdr_contract.dart';
import 'xdr/xdr_type.dart';
import 'soroban/soroban_auth.dart';

abstract class HostFunction {
  HostFunction();

  XdrHostFunction toXdr();

  factory HostFunction.fromXdr(XdrHostFunction xdr) {
    XdrHostFunctionType type = xdr.type;
    switch (type) {
      // Account effects
      case XdrHostFunctionType.HOST_FUNCTION_TYPE_UPLOAD_CONTRACT_WASM:
        if (xdr.wasm != null) {
          return UploadContractWasmHostFunction(xdr.wasm!.dataValue);
        }
        break;
      case XdrHostFunctionType.HOST_FUNCTION_TYPE_INVOKE_CONTRACT:
        if (xdr.invokeContract != null) {
          List<XdrSCVal> invokeArgsList = xdr.invokeContract!;
          if (invokeArgsList.length < 2 ||
              invokeArgsList.elementAt(0).discriminant !=
                  XdrSCValType.SCV_ADDRESS ||
              invokeArgsList.elementAt(0).address?.contractId == null ||
              invokeArgsList.elementAt(1).discriminant !=
                  XdrSCValType.SCV_SYMBOL ||
              invokeArgsList.elementAt(1).sym == null) {
            throw UnimplementedError();
          }
          String contractID = Util.bytesToHex(
              invokeArgsList.elementAt(0).address!.contractId!.hash);
          String functionName = invokeArgsList.elementAt(1).sym!;
          List<XdrSCVal>? funcArgs;
          if (invokeArgsList.length > 2) {
            funcArgs = List<XdrSCVal>.empty(growable: true);
            for (int i = 2; i < invokeArgsList.length; i++) {
              funcArgs.add(invokeArgsList[i]);
            }
          }
          return InvokeContractHostFunction(contractID, functionName,
              arguments: funcArgs);
        }
        break;
      case XdrHostFunctionType.HOST_FUNCTION_TYPE_CREATE_CONTRACT:
        if (xdr.createContract != null) {
          if (xdr.createContract!.contractIDPreimage.type ==
              XdrContractIDPreimageType.CONTRACT_ID_PREIMAGE_FROM_ADDRESS) {
            if (xdr.createContract!.executable.type ==
                    XdrContractExecutableType.CONTRACT_EXECUTABLE_WASM &&
                xdr.createContract!.executable.wasmHash != null) {
              String wasmId = Util.bytesToHex(
                  xdr.createContract!.executable.wasmHash!.hash);
              return CreateContractHostFunction(
                  Address.fromXdr(
                      xdr.createContract!.contractIDPreimage.address!),
                  wasmId,
                  salt: xdr.createContract!.contractIDPreimage.salt!);
            } else if (xdr.createContract!.executable.type ==
                XdrContractExecutableType.CONTRACT_EXECUTABLE_TOKEN) {
              return DeploySACWithSourceAccountHostFunction(
                  Address.fromXdr(
                      xdr.createContract!.contractIDPreimage.address!),
                  salt: xdr.createContract!.contractIDPreimage.salt!);
            }
          } else if (xdr.createContract!.contractIDPreimage.type ==
                  XdrContractIDPreimageType.CONTRACT_ID_PREIMAGE_FROM_ASSET &&
              xdr.createContract!.executable.type ==
                  XdrContractExecutableType.CONTRACT_EXECUTABLE_TOKEN) {
            return DeploySACWithAssetHostFunction(Asset.fromXdr(
                xdr.createContract!.contractIDPreimage.fromAsset!));
          }
        }
        break;
    }
    throw UnimplementedError();
  }
}

class UploadContractWasmHostFunction extends HostFunction {
  Uint8List _contractCode;
  Uint8List get contractCode => this._contractCode;
  set contractCode(Uint8List value) => this._contractCode = value;

  UploadContractWasmHostFunction(this._contractCode);

  @override
  XdrHostFunction toXdr() {
    return XdrHostFunction.forUploadContractWasm(contractCode);
  }
}

class CreateContractHostFunction extends HostFunction {
  Address _address;
  Address get address => this._address;
  set address(Address value) => this._address = value;

  String _wasmId;
  String get wasmId => this._wasmId;
  set wasmId(String value) => this._wasmId = value;

  late XdrUint256 _salt;
  XdrUint256 get salt => this._salt;
  set salt(XdrUint256 value) => this._salt = value;

  CreateContractHostFunction(this._address, this._wasmId, {XdrUint256? salt}) {
    if (salt != null) {
      this._salt = salt;
    } else {
      this._salt = new XdrUint256(TweetNaCl.randombytes(32));
    }
  }

  @override
  XdrHostFunction toXdr() {
    return XdrHostFunction.forCreatingContract(address.toXdr(), salt, wasmId);
  }
}

class DeploySACWithSourceAccountHostFunction extends HostFunction {
  Address _address;
  Address get address => this._address;
  set address(Address value) => this._address = value;

  late XdrUint256 _salt;
  XdrUint256 get salt => this._salt;
  set salt(XdrUint256 value) => this._salt = value;

  DeploySACWithSourceAccountHostFunction(this._address, {XdrUint256? salt}) {
    if (salt != null) {
      this._salt = salt;
    } else {
      this._salt = new XdrUint256(TweetNaCl.randombytes(32));
    }
  }

  @override
  XdrHostFunction toXdr() {
    return XdrHostFunction.forDeploySACWithSourceAccount(address.toXdr(), salt);
  }
}

class DeploySACWithAssetHostFunction extends HostFunction {
  Asset _asset;
  Asset get asset => this._asset;
  set asset(Asset value) => this._asset = value;

  DeploySACWithAssetHostFunction(this._asset);

  @override
  XdrHostFunction toXdr() {
    return XdrHostFunction.forDeploySACWithAsset(asset.toXdr());
  }
}

class InvokeContractHostFunction extends HostFunction {
  String _contractID;
  String get contractID => this._contractID;
  set contractID(String value) => this._contractID = value;

  String _functionName;
  String get functionName => this._functionName;
  set functionName(String value) => this._functionName = value;

  List<XdrSCVal>? arguments;

  InvokeContractHostFunction(this._contractID, this._functionName,
      {this.arguments});

  @override
  XdrHostFunction toXdr() {
    List<XdrSCVal> invokeArgsList = List<XdrSCVal>.empty(growable: true);

    // contract id
    XdrSCVal contractIDScVal =
        Address.forContractId(this._contractID).toXdrSCVal();
    invokeArgsList.add(contractIDScVal);

    // function name
    XdrSCVal functionNameScVal = XdrSCVal(XdrSCValType.SCV_SYMBOL);
    functionNameScVal.sym = this._functionName;
    invokeArgsList.add(functionNameScVal);

    // arguments for the function call
    if (this.arguments != null) {
      invokeArgsList.addAll(this.arguments!);
    }

    return XdrHostFunction.forInvokingContractWithArgs(invokeArgsList);
  }
}

class InvokeHostFuncOpBuilder {
  MuxedAccount? _mSourceAccount;

  HostFunction _function;
  HostFunction get function => this._function;
  set function(HostFunction value) => this._function = value;

  List<SorobanAuthorizationEntry> auth =
      List<SorobanAuthorizationEntry>.empty(growable: true);

  InvokeHostFuncOpBuilder(this._function,
      {List<SorobanAuthorizationEntry>? auth}) {
    if (auth != null) {
      this.auth = auth;
    }
  }

  /// Sets the source account for this operation represented by [sourceAccountId].
  InvokeHostFuncOpBuilder setSourceAccount(String sourceAccountId) {
    MuxedAccount? sa = MuxedAccount.fromAccountId(sourceAccountId);
    _mSourceAccount = checkNotNull(sa, "invalid sourceAccountId");
    return this;
  }

  /// Sets the muxed source account for this operation represented by [sourceAccount].
  InvokeHostFuncOpBuilder setMuxedSourceAccount(MuxedAccount sourceAccount) {
    _mSourceAccount = sourceAccount;
    return this;
  }

  ///Builds an operation
  InvokeHostFunctionOperation build() {
    InvokeHostFunctionOperation op =
        InvokeHostFunctionOperation(function, auth: auth);
    op.sourceAccount = _mSourceAccount;
    return op;
  }
}

class InvokeHostFunctionOperation extends Operation {
  HostFunction _function;
  HostFunction get function => this._function;
  set function(HostFunction value) => this._function = value;

  List<SorobanAuthorizationEntry> auth =
      List<SorobanAuthorizationEntry>.empty(growable: true);

  InvokeHostFunctionOperation(this._function,
      {List<SorobanAuthorizationEntry>? auth}) {
    if (auth != null) {
      this.auth = auth;
    }
  }

  static InvokeHostFuncOpBuilder builder(XdrInvokeHostFunctionOp op) {
    List<SorobanAuthorizationEntry> auth =
        List<SorobanAuthorizationEntry>.empty(growable: true);
    for (XdrSorobanAuthorizationEntry aXdr in op.auth) {
      auth.add(SorobanAuthorizationEntry.fromXdr(aXdr));
    }
    return InvokeHostFuncOpBuilder(HostFunction.fromXdr(op.function),
        auth: auth);
  }

  @override
  XdrOperationBody toOperationBody() {
    List<XdrSorobanAuthorizationEntry> xdrAuth =
        List<XdrSorobanAuthorizationEntry>.empty(growable: true);
    for (SorobanAuthorizationEntry a in auth) {
      xdrAuth.add(a.toXdr());
    }
    XdrInvokeHostFunctionOp xdrOp =
        XdrInvokeHostFunctionOp(function.toXdr(), xdrAuth);
    XdrOperationBody body =
        XdrOperationBody(XdrOperationType.INVOKE_HOST_FUNCTION);
    body.invokeHostFunctionOp = xdrOp;
    return body;
  }
}
