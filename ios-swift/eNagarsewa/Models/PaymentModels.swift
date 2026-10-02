import Foundation

// Ports of the payment / transaction models in lib/services/api_service.dart.

struct InitiateTransactionRequest {
    let mobileTransactionId: String
    let mobileTransactionTimestamp: String
    let billNo: String
    let propertyId: String
    let ulbId: String
    let financialYear: String
    let ownerName: String
    let fatherName: String
    let mobileNo: String
    let propertyTax: String
    let waterTax: String
    let sewerTax: String
    let otherTax: String
    let waterCharge: String
    let netDemand: String
    let netPayable: String
    let totalArv: String
    let userId: String
    let emailId: String

    var json: [String: Any] {
        [
            "mobile_transaction_id": mobileTransactionId,
            "mobile_transaction_timestamp": mobileTransactionTimestamp,
            "bill_no": billNo,
            "property_id": propertyId,
            "ulb_id": ulbId,
            "financial_year": financialYear,
            "ownerName": ownerName,
            "fatherName": fatherName,
            "mobileNo": mobileNo,
            "property_tax": propertyTax,
            "water_tax": waterTax,
            "sewer_tax": sewerTax,
            "other_tax": otherTax,
            "water_charge": waterCharge,
            "net_demand": netDemand,
            "net_payable": netPayable,
            "totalArv": totalArv,
            "user_id": userId,
            "email_id": emailId,
        ]
    }
}

struct CreateTransactionResponse {
    let data: PayUTransaction?
    let message: String?
    let status: Bool?

    init(json: JSON) {
        data = json["data"].object != nil ? PayUTransaction(json: json["data"]!) : nil
        message = json["message"].str
        status = json["status"].bool ?? json["success"].bool
    }
}

/// Dart `Transaction` — the server-issued PayU checkout parameters.
struct PayUTransaction {
    let amount: String?
    let firstname: String?
    let phone: String?
    let furl: String?
    let surl: String?
    let productinfo: String?
    let email: String?
    let key: String?
    let txnid: String?
    /// Raw value from API: 'p' = production, 't' = testing
    let payuEnv: String?
    let merchantName: String?
    let ulbId: String?

    init(json: JSON) {
        amount = json["amount"].str
        firstname = json["firstname"].str
        phone = json["phone"].str
        furl = json["furl"].str
        surl = json["surl"].str
        productinfo = json["productinfo"].str
        email = json["email"].str
        key = json["key"].str
        txnid = json["txnid"].str
        payuEnv = json["payu_env"].str
        merchantName = json["merchantName"].str
        ulbId = json["ulbId"].str ?? json["ulb_id"].str
    }

    /// PayU SDK environment: "0" production, "1" test.
    var resolvedPayuEnvironment: String { payuEnv == "t" ? "1" : "0" }
    var isTestEnvironment: Bool { payuEnv == "t" }
}

struct CreateSbiTransactionResponse {
    let status: Bool?
    let message: String?
    let data: SbiTransactionData?

    init(json: JSON) {
        status = json["status"].bool
        message = json["message"].str
        data = json["data"].object != nil ? SbiTransactionData(json: json["data"]!) : nil
    }
}

struct SbiTransactionData {
    let txnid: String?
    let merchantId: String?
    let encdata: String?
    let sbiPostUrl: String?
    let paymentPageHtml: String?

    init(json: JSON) {
        txnid = json["txnid"].str
        merchantId = json["merchant_id"].str
        encdata = json["encdata"].str
        sbiPostUrl = json["sbi_post_url"].str
        paymentPageHtml = json["payment_page_html"].str
    }
}

struct SbiTransactionDetailsResponse {
    let status: Bool?
    let message: String?
    let data: SbiPaymentDetails?

    init(json: JSON) {
        status = json["status"].bool
        message = json["message"].str
        data = json["data"].object != nil ? SbiPaymentDetails(json: json["data"]!) : nil
    }
}

struct SbiPaymentDetails {
    let paymentStatus: String?
    let txnid: String?
    let paymentMode: String?
    let netPayable: String?
    let ownerName: String?
    let mobileNo: String?
    let billNo: String?
    let propertyId: String?
    let financialYear: String?
    let propertyTaxPaid: String?
    let waterTaxPaid: String?
    let sewerTaxPaid: String?
    let otherTaxPaid: String?
    let waterChargePaid: String?
    let sbiPaymentTime: String?
    let payuPaymentTime: String?
    let mobileTransactionTimestamp: String?
    let transactionCreatedAt: String?

    init(json: JSON) {
        paymentStatus = json["payment_status"].str
        txnid = json["txnid"].str
        paymentMode = json["payment_mode"].str
        netPayable = json["net_payable"].str
        ownerName = json["owner_name"].str
        mobileNo = json["mobile_no"].str
        billNo = json["billNo"].str
        propertyId = json["propertyId"].str
        financialYear = json["financialYear"].str
        propertyTaxPaid = json["propertyTaxPaid"].str
        waterTaxPaid = json["waterTaxPaid"].str
        sewerTaxPaid = json["sewerTaxPaid"].str
        otherTaxPaid = json["otherTaxPaid"].str
        waterChargePaid = json["waterChargePaid"].str
        sbiPaymentTime = json["sbi_payment_time"].str
        payuPaymentTime = json["payu_payment_time"].str
        mobileTransactionTimestamp = json["mobile_transaction_timestamp"].str
        transactionCreatedAt = json["transaction_created_at"].str
    }
}

struct PayUTransactionDetailsResponse {
    let status: Bool?
    let message: String?
    let data: PayUTransactionDetails?

    init(json: JSON) {
        status = json["status"].bool
        message = json["message"].str
        data = json["data"].object != nil ? PayUTransactionDetails(json: json["data"]!) : nil
    }
}

struct PayUTransactionDetails {
    let paymentStatus: String?
    let txnid: String?
    /// Dart keeps this `dynamic` — it may be a string or an object; the string form is kept.
    let paymentMode: String?
    let netPayable: String?
    let ownerName: String?
    let mobileNo: String?
    let billNo: String?
    let propertyId: String?
    let financialYear: String?
    let propertyTaxPaid: String?
    let waterTaxPaid: String?
    let sewerTaxPaid: String?
    let otherTaxPaid: String?
    let waterChargePaid: String?
    let mobileTransactionTimestamp: String?
    let payuPaymentTime: String?
    let transactionCreatedAt: String?

    init(json: JSON) {
        paymentStatus = json["payment_status"].str
        txnid = json["txnid"].str
        paymentMode = json["payment_mode"].str
        netPayable = json["net_payable"].str
        ownerName = json["owner_name"].str
        mobileNo = json["mobile_no"].str
        billNo = json["billNo"].str
        propertyId = json["propertyId"].str
        financialYear = json["financialYear"].str
        propertyTaxPaid = json["propertyTaxPaid"].str
        waterTaxPaid = json["waterTaxPaid"].str
        sewerTaxPaid = json["sewerTaxPaid"].str
        otherTaxPaid = json["otherTaxPaid"].str
        waterChargePaid = json["waterChargePaid"].str
        mobileTransactionTimestamp = json["mobile_transaction_timestamp"].str
        payuPaymentTime = json["payu_payment_time"].str
        transactionCreatedAt = json["transaction_created_at"].str
    }
}

struct HashResponse {
    let data: String?
    let message: String?
    let status: Bool?

    init(json: JSON) {
        data = json["data"].str
        message = json["message"].str
        status = json["status"].bool ?? json["success"].bool
    }
}

struct TransactionsByEmailResponse {
    let status: Bool?
    let message: String?
    let data: [TransactionData]?

    init(json: JSON) {
        status = json["status"].bool
        message = json["message"].str
        data = json["data"].array.map { $0.map(TransactionData.init(json:)) }
    }
}

struct TransactionData {
    let paymentAmount: String?
    let billNo: String?
    let propertyId: String?
    let txnId: String?
    let dateTime: String?
    let financialYear: String?
    let paymentMode: String?
    let bankRefNo: String?
    let transactionStatus: String?
    let ownerName: String?
    let fatherName: String?
    let address: String?
    let mobileNo: String?
    let eNagarSewaRefNo: String?
    let userCode: String?
    let ulbName: String?
    let ulbType: String?
    let ulbId: String?
    let receiptNo: String?
    let billDate: String?

    init(json: JSON) {
        paymentAmount = json["payment_amount"].str
        billNo = json["bill_no"].str
        propertyId = json["property_id"].str
        txnId = json["txnid"].str
        dateTime = json["date_time"].str
        financialYear = json["financial_year"].str
        paymentMode = json["payment_mode"].str
        bankRefNo = json["bank_ref_no"].str
        transactionStatus = json["transaction_status"].str
        ownerName = json["owner_name"].str
        fatherName = json["father_name"].str
        address = json["address"].str
        mobileNo = json["mobile_no"].str
        eNagarSewaRefNo = json["e_nagarsewa_ref_no"].str
        userCode = json["user_code"].str
        ulbName = json["ulb_name"].str
        ulbType = json["ulb_type"].str
        ulbId = json["ulb_id"].str
        receiptNo = json["receiptNo"].str
        billDate = json["bill_date"].str
    }
}
