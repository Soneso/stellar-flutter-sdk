// Copyright 2020 The Stellar Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/src/muxed_account.dart';

import 'operation.dart';
import 'assets.dart';
import 'util.dart';
import 'xdr/xdr_asset.dart';
import 'xdr/xdr_payment.dart';
import 'xdr/xdr_operation.dart';
import 'xdr/xdr_type.dart';

/// Represents <a href="https://developers.stellar.org/docs/start/list-of-operations/#path-payment-strict-send" target="_blank">PathPaymentStrictSend</a> operation.
/// @see <a href="https://developers.stellar.org/docs/start/list-of-operations/" target="_blank">List of Operations</a>
class PathPaymentStrictSendOperation extends Operation {
  Asset _sendAsset;
  String _sendAmount;
  MuxedAccount _destination;
  Asset _destAsset;
  String _destMin;
  late List<Asset> _path;

  PathPaymentStrictSendOperation(this._sendAsset, this._sendAmount,
      this._destination, this._destAsset, this._destMin, List<Asset>? path) {
    if (path == null) {
      this._path = List<Asset>.empty(growable: true);
    } else {
      checkArgument(
          path.length <= 5, "The maximum number of assets in the path is 5");
      this._path = path;
    }
  }

  /// The asset deducted from the sender's account.
  Asset get sendAsset => _sendAsset;

  /// The amount of send asset to deduct (excluding fees)
  String get sendAmount => _sendAmount;

  /// Account that receives the payment.
  MuxedAccount get destination => _destination;

  /// The asset the destination account receives.
  Asset get destAsset => _destAsset;

  /// The minimum amount of destination asset the destination account receives.
  String get destMin => _destMin;

  /// The assets (other than send asset and destination asset) involved in the offers the path takes. For example, if you can only find a path from USD to EUR through XLM and BTC, the path would be USD -&raquo; XLM -&raquo; BTC -&raquo; EUR and the path would contain XLM and BTC.
  List<Asset> get path => _path;

  @override
  XdrOperationBody toOperationBody() {
    // sendMax
    XdrInt64 sendMax = XdrInt64(Operation.toXdrAmount(this.sendAmount));

    // destAmount
    XdrInt64 destAmount = XdrInt64(Operation.toXdrAmount(this.destMin));

    // path
    List<XdrAsset> path = List<XdrAsset>.empty(growable: true);
    for (int i = 0; i < this.path.length; i++) {
      path.add(this.path[i].toXdr());
    }
    XdrPathPaymentStrictSendOp op = XdrPathPaymentStrictSendOp(
        sendAsset.toXdr(),
        sendMax,
        this._destination.toXdr(),
        destAsset.toXdr(),
        destAmount,
        path);

    XdrOperationBody body =
        XdrOperationBody(XdrOperationType.PATH_PAYMENT_STRICT_SEND);
    body.pathPaymentStrictSendOp = op;
    return body;
  }

  /// Builds PathPayment operation.
  static PathPaymentStrictSendOperationBuilder builder(
      XdrPathPaymentStrictSendOp op) {
    List<Asset> path = List<Asset>.empty(growable: true);
    for (int i = 0; i < op.path.length; i++) {
      path.add(Asset.fromXdr(op.path[i]));
    }
    return PathPaymentStrictSendOperationBuilder.forMuxedDestinationAccount(
            Asset.fromXdr(op.sendAsset),
            Operation.fromXdrAmount(op.sendMax.int64),
            MuxedAccount.fromXdr(op.destination),
            Asset.fromXdr(op.destAsset),
            Operation.fromXdrAmount(op.destAmount.int64))
        .setPath(path);
  }
}

class PathPaymentStrictSendOperationBuilder {
  Asset _sendAsset;
  String _sendAmount;
  late MuxedAccount _destination;
  Asset _destAsset;
  String _destMin;
  List<Asset> _path = List<Asset>.empty(growable: true);
  MuxedAccount? _mSourceAccount;

  /// Creates a PathPaymentStrictSendOperation builder.
  PathPaymentStrictSendOperationBuilder(this._sendAsset, this._sendAmount,
      String destinationAccountId, this._destAsset, this._destMin) {
    MuxedAccount? da = MuxedAccount.fromAccountId(destinationAccountId);
    checkNotNull(da, "invalid destinationAccountId");
    this._destination = da!;
  }

  /// Creates a PathPaymentStrictSendOperation builder for a MuxedAccount as a destination.
  PathPaymentStrictSendOperationBuilder.forMuxedDestinationAccount(
      this._sendAsset,
      this._sendAmount,
      this._destination,
      this._destAsset,
      this._destMin);

  /// Sets path for this operation
  PathPaymentStrictSendOperationBuilder setPath(List<Asset> path) {
    checkArgument(
        path.length <= 5, "The maximum number of assets in the path is 5");
    this._path = path;
    return this;
  }

  /// Sets the source account for this operation.
  PathPaymentStrictSendOperationBuilder setSourceAccount(
      String sourceAccountId) {
    MuxedAccount? sa = MuxedAccount.fromAccountId(sourceAccountId);
    _mSourceAccount = checkNotNull(sa, "invalid sourceAccountId");
    return this;
  }

  /// Sets the muxed source account for this operation.
  PathPaymentStrictSendOperationBuilder setMuxedSourceAccount(
      MuxedAccount sourceAccount) {
    _mSourceAccount = sourceAccount;
    return this;
  }

  /// Builds a PathPaymentStrictSendOperation.
  PathPaymentStrictSendOperation build() {
    PathPaymentStrictSendOperation operation = PathPaymentStrictSendOperation(
        _sendAsset, _sendAmount, _destination, _destAsset, _destMin, _path);
    if (_mSourceAccount != null) {
      operation.sourceAccount = _mSourceAccount;
    }
    return operation;
  }
}
