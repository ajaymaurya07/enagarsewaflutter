import Foundation

// MARK: - Create transaction (shared shape for PayU + SBI — matches Dart's InitiateTransactionRequest,
// reused as-is by both api/Payment/create_transaction and api/Payment/create_sbi_transaction).
// NOTE: the integrity token is NOT part of this body — it travels in the `X-Integrity-Token`
// header (see APIService.performWithIntegrity), matching Dart's `_makeIntegrityProtectedRequest`.

struct InitiateTransactionRequest: Encodable {
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

    enum CodingKeys: String, CodingKey {
        case mobileTransactionId = "mobile_transaction_id"
        case mobileTransactionTimestamp = "mobile_transaction_timestamp"
        case billNo = "bill_no"
        case propertyId = "property_id"
        case ulbId = "ulb_id"
        case financialYear = "financial_year"
        case ownerName
        case fatherName
        case mobileNo
        case propertyTax = "property_tax"
        case waterTax = "water_tax"
        case sewerTax = "sewer_tax"
        case otherTax = "other_tax"
        case waterCharge = "water_charge"
        case netDemand = "net_demand"
        case netPayable = "net_payable"
        case totalArv
        case userId = "user_id"
        case emailId = "email_id"
    }
}

/// Both endpoints accept the identical body shape in the real backend (matches Dart, which
/// literally reuses `InitiateTransactionRequest` for `createSbiTransaction`).
typealias CreateTransactionRequest = InitiateTransactionRequest
typealias CreateSbiTransactionRequest = InitiateTransactionRequest

struct CreateTransactionResponse: Decodable {
    let success: Bool
    let message: String?
    let data: PayUTransaction?

    private enum CodingKeys: String, CodingKey { case status, success, message, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Dart: `status: json['status'] ?? json['success']`
        let status = try c.decodeIfPresent(Bool.self, forKey: .status)
        let legacySuccess = try c.decodeIfPresent(Bool.self, forKey: .success)
        success = status ?? legacySuccess ?? false
        message = try c.decodeIfPresent(String.self, forKey: .message)
        data = try c.decodeIfPresent(PayUTransaction.self, forKey: .data)
    }
}

/// PayU transaction payload returned by create_transaction — matches Dart's `Transaction` class.
struct PayUTransaction: Decodable {
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

    enum CodingKeys: String, CodingKey {
        case amount, firstname, phone, furl, surl, productinfo, email, key, txnid
        case payuEnv = "payu_env"
        case merchantName
    }

    /// PayU SDK environment value: '0' = production, '1' = test. Mirrors Dart's `resolvedPayuEnvironment`.
    var resolvedPayuEnvironment: String { payuEnv == "t" ? "1" : "0" }
}

// MARK: - Hash generation (PayU SDK → backend round trip)
// Dart posts `hashName` + `hashString` as application/x-www-form-urlencoded — no JSON body/struct.
// See APIService.generateHash(hashName:hashString:).

struct HashResponse: Decodable {
    let status: Bool
    let data: String?
    let message: String?

    private enum CodingKeys: String, CodingKey { case status, success, data, message }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decodeIfPresent(Bool.self, forKey: .status)
        let success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.status = status ?? success ?? false
        data = try c.decodeIfPresent(String.self, forKey: .data)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }
}

// MARK: - PayU transaction details (cross-verify after SDK callback)
// POSTed as multipart/form-data with field `mobile_transaction_id` — see APIService.getTransactionDetails.

struct PayUTransactionDetailsResponse: Decodable {
    let status: Bool
    let data: PayUTransactionDetails?

    private enum CodingKeys: String, CodingKey { case status, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decodeIfPresent(Bool.self, forKey: .status) ?? false
        data = try c.decodeIfPresent(PayUTransactionDetails.self, forKey: .data)
    }
}

struct PayUTransactionDetails: Decodable {
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
    let mobileTransactionTimestamp: String?
    let payuPaymentTime: String?
    let transactionCreatedAt: String?

    enum CodingKeys: String, CodingKey {
        case paymentStatus = "payment_status"
        case txnid
        case paymentMode = "payment_mode"
        case netPayable = "net_payable"
        case ownerName = "owner_name"
        case mobileNo = "mobile_no"
        case billNo, propertyId, financialYear
        case propertyTaxPaid, waterTaxPaid, sewerTaxPaid, otherTaxPaid, waterChargePaid
        case mobileTransactionTimestamp = "mobile_transaction_timestamp"
        case payuPaymentTime = "payu_payment_time"
        case transactionCreatedAt = "transaction_created_at"
    }
}

// MARK: - SBI

struct CreateSbiTransactionResponse: Decodable {
    let success: Bool
    let message: String?
    let data: SbiTransactionData?

    private enum CodingKeys: String, CodingKey { case status, success, message, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decodeIfPresent(Bool.self, forKey: .status)
        let legacySuccess = try c.decodeIfPresent(Bool.self, forKey: .success)
        success = status ?? legacySuccess ?? false
        message = try c.decodeIfPresent(String.self, forKey: .message)
        data = try c.decodeIfPresent(SbiTransactionData.self, forKey: .data)
    }
}

struct SbiTransactionData: Decodable {
    let txnid: String?
    let merchantId: String?
    let encdata: String?
    let sbiPostUrl: String?
    let paymentPageHtml: String?

    enum CodingKeys: String, CodingKey {
        case txnid
        case merchantId = "merchant_id"
        case encdata
        case sbiPostUrl = "sbi_post_url"
        case paymentPageHtml = "payment_page_html"
    }
}

struct SbiTransactionDetailsResponse: Decodable {
    let status: Bool
    let data: SbiPaymentDetails?

    private enum CodingKeys: String, CodingKey { case status, success, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decodeIfPresent(Bool.self, forKey: .status)
        let success = try c.decodeIfPresent(Bool.self, forKey: .success)
        self.status = status ?? success ?? false
        data = try c.decodeIfPresent(SbiPaymentDetails.self, forKey: .data)
    }
}

struct SbiPaymentDetails: Decodable {
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

    enum CodingKeys: String, CodingKey {
        case paymentStatus = "payment_status"
        case txnid
        case paymentMode = "payment_mode"
        case netPayable = "net_payable"
        case ownerName = "owner_name"
        case mobileNo = "mobile_no"
        case billNo, propertyId, financialYear
        case propertyTaxPaid, waterTaxPaid, sewerTaxPaid, otherTaxPaid, waterChargePaid
        case sbiPaymentTime = "sbi_payment_time"
        case payuPaymentTime = "payu_payment_time"
        case mobileTransactionTimestamp = "mobile_transaction_timestamp"
        case transactionCreatedAt = "transaction_created_at"
    }
}

// MARK: - Transaction history

struct TransactionsByEmailRequest: Encodable {
    let emailId: String

    enum CodingKeys: String, CodingKey { case emailId = "email_id" }
}

struct TransactionsByEmailResponse: Decodable {
    let success: Bool
    let data: [TransactionData]

    private enum CodingKeys: String, CodingKey { case status, success, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decodeIfPresent(Bool.self, forKey: .status)
        let legacySuccess = try c.decodeIfPresent(Bool.self, forKey: .success)
        success = status ?? legacySuccess ?? false
        data = try c.decodeIfPresent([TransactionData].self, forKey: .data) ?? []
    }
}

/// Matches Dart's `TransactionData` — used by Payment History, Transaction History and
/// Transaction Details screens alike.
struct TransactionData: Decodable, Identifiable {
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
    let receiptNo: String?

    var id: String { txnId ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case paymentAmount = "payment_amount"
        case billNo = "bill_no"
        case propertyId = "property_id"
        case txnId = "txnid"
        case dateTime = "date_time"
        case financialYear = "financial_year"
        case paymentMode = "payment_mode"
        case bankRefNo = "bank_ref_no"
        case transactionStatus = "transaction_status"
        case ownerName = "owner_name"
        case fatherName = "father_name"
        case address
        case mobileNo = "mobile_no"
        case eNagarSewaRefNo = "e_nagarsewa_ref_no"
        case userCode = "user_code"
        case ulbName = "ulb_name"
        case ulbType = "ulb_type"
        case receiptNo
    }
}

// MARK: - Payment result context

enum PaymentGateway {
    case payU
    case sbi
}

enum PaymentStatus {
    case success
    case failure
    case pending
}
