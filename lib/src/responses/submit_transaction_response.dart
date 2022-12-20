// Copyright 2020 The Stellar Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'response.dart';
import 'dart:convert';
import '../xdr/xdr_data_io.dart';
import '../xdr/xdr_operation.dart';
import '../xdr/xdr_transaction.dart';
import '../util.dart';

/// Represents the horizon server response after submitting transaction.
class SubmitTransactionResponse extends Response {
  String? hash;
  int? ledger;
  String? strEnvelopeXdr;
  String? strResultXdr;
  String? strMetaXdr;
  SubmitTransactionResponseExtras? extras;

  SubmitTransactionResponse(this.extras, this.ledger, this.hash,
      this.strEnvelopeXdr, this.strResultXdr, this.strMetaXdr);

  bool get success => ledger != null;

  String? get envelopeXdr {
    if (this.success) {
      return this.strEnvelopeXdr;
    } else {
      if (this.extras != null) {
        return this.extras!.envelopeXdr;
      }
      return null;
    }
  }

  String? get resultXdr {
    if (this.success) {
      return this.strResultXdr;
    } else {
      if (this.extras != null) {
        return this.extras!.resultXdr;
      }
      return null;
    }
  }

  String? get resultMetaXdr {
    if (this.success) {
      return this.strMetaXdr;
    } else {
      if (this.extras != null) {
        return this.extras!.strMetaXdr;
      }
      return null;
    }
  }

  XdrTransactionResult? getTransactionResultXdr() {
    XdrDataInputStream xdrInputStream =
        XdrDataInputStream(base64Decode(this.resultXdr!));

    try {
      return XdrTransactionResult.decode(xdrInputStream);
    } catch (e) {
      return null;
    }
  }

  XdrTransactionMeta? getTransactionMetaResultXdr() {
    XdrDataInputStream xdrInputStream =
        XdrDataInputStream(base64Decode(this.resultMetaXdr!));

    try {
      return XdrTransactionMeta.decode(xdrInputStream);
    } catch (e) {
      return null;
    }
  }

  /// Helper method that returns Offer ID for ManageOffer from TransactionResult Xdr.
  /// This is helpful when you need the ID of an offer to update it later.
  int? getOfferIdFromResult(int position) {
    if (!this.success) {
      return null;
    }

    XdrDataInputStream xdrInputStream =
        XdrDataInputStream(base64Decode(this.resultXdr!));
    XdrTransactionResult result;

    try {
      result = XdrTransactionResult.decode(xdrInputStream);
    } catch (e) {
      return null;
    }

    if (result.result.results[position] == null) {
      return null;
    }

    XdrOperationType? disc =
        (result.result.results[position] as XdrOperationResult)
            .tr!
            .discriminant;
    if (disc != XdrOperationType.MANAGE_SELL_OFFER &&
        disc != XdrOperationType.MANAGE_BUY_OFFER) {
      return null;
    }

    if ((result.result.results[position] as XdrOperationResult?)
            ?.tr!
            .manageOfferResult!
            .success!
            .offer!
            .offer ==
        null) {
      return null;
    }

    return (result.result.results[position] as XdrOperationResult)
        .tr!
        .manageOfferResult!
        .success!
        .offer!
        .offer!
        .offerID
        .uint64;
  }

  /// Helper method that returns Claimable Balance Id for CreateClaimableBalance from TransactionResult Xdr.
  /// This is helpful when you need the created Claimable Balance ID to show it to the user
  String? getClaimableBalanceIdIdFromResult(int position) {
    if (!this.success) {
      return null;
    }

    XdrDataInputStream xdrInputStream =
        XdrDataInputStream(base64Decode(this.resultXdr!));
    XdrTransactionResult result;

    try {
      result = XdrTransactionResult.decode(xdrInputStream);
    } catch (e) {
      return null;
    }

    if (result.result.results[position] == null) {
      return null;
    }

    XdrOperationType? disc =
        (result.result.results[position] as XdrOperationResult)
            .tr!
            .discriminant;
    if (disc != XdrOperationType.CREATE_CLAIMABLE_BALANCE) {
      return null;
    }

    if ((result.result.results[position] as XdrOperationResult?)
            ?.tr!
            .createClaimableBalanceResult!
            .balanceID ==
        null) {
      return null;
    }

    return Util.bytesToHex((result.result.results[0] as XdrOperationResult)
        .tr!
        .createClaimableBalanceResult!
        .balanceID!
        .v0!
        .hash);
  }

  factory SubmitTransactionResponse.fromJson(Map<String, dynamic> json) =>
      SubmitTransactionResponse(
        json['extras'] == null
            ? null
            : SubmitTransactionResponseExtras.fromJson(json['extras']),
        convertInt(json['ledger']),
        json['hash'],
        json['envelope_xdr'],
        json['result_xdr'],
        json['result_meta_xdr'],
      )
        ..rateLimitLimit = convertInt(json['rateLimitLimit'])
        ..rateLimitRemaining = convertInt(json['rateLimitRemaining'])
        ..rateLimitReset = convertInt(json['rateLimitReset']);
}

/// Contains result codes for this transaction.
class ExtrasResultCodes {
  String? transactionResultCode;
  List<String?>? operationsResultCodes;

  ExtrasResultCodes(this.transactionResultCode, this.operationsResultCodes);

  factory ExtrasResultCodes.fromJson(Map<String, dynamic> json) =>
      ExtrasResultCodes(
        json['transaction'],
        json['operations'] != null
            ? List<String>.from(json['operations'].map((e) => e))
            : null,
      );
}

/// Additional information returned by the horizon server.
class SubmitTransactionResponseExtras {
  String envelopeXdr;
  String resultXdr;
  String? strMetaXdr;
  ExtrasResultCodes? resultCodes;

  SubmitTransactionResponseExtras(
      this.envelopeXdr, this.resultXdr, this.strMetaXdr, this.resultCodes);

  factory SubmitTransactionResponseExtras.fromJson(Map<String, dynamic> json) =>
      SubmitTransactionResponseExtras(
          json['envelope_xdr'],
          json['result_xdr'],
          json['result_meta_xdr'],
          json['result_codes'] == null
              ? null
              : ExtrasResultCodes.fromJson(json['result_codes']));
}

class SubmitTransactionTimeoutResponseException implements Exception {
  String toString() {
    return "Timeout. Please resubmit your transaction to receive submission status. More info: https://www.stellar.org/developers/horizon/reference/errors/timeout.html";
  }
}

class SubmitTransactionUnknownResponseException implements Exception {
  int _code;
  String _body;

  SubmitTransactionUnknownResponseException(this._code, this._body);

  String toString() {
    return "Unknown response from Horizon - code: $code - body:$body";
  }

  int get code => _code;
  String get body => _body;
}
