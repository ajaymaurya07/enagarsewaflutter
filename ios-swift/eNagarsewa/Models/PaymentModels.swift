import Foundation

// MARK: - PayU

struct CreateTransactionRequest: Encodable {
    let propertyId: String
    let billNo: String
    let amount: String
    let emailId: String
    let phoneNo: String
    let ownerName: String
    let ulbId: String
    let integrityToken: String
}

struct CreateTransactionResponse: Decodable {
    let success: Bool
    let message: String
    let data: PayUTransaction?
}

struct PayUTransaction: Decodable {
    let amount: String
    let firstname: String
    let phone: String
    let furl: String
    let surl: String
    let productinfo: String
    let email: String
    let key: String
    let txnid: String
    let payuEnv: String
    let hash: String?
}

struct HashRequest: Encodable {
    let txnid: String
    let amount: String
    let productinfo: String
    let firstname: String
    let email: String
    let key: String
}

struct HashResponse: Decodable {
    let success: Bool
    let hash: String?
}

struct PayUTransactionDetailsRequest: Encodable {
    let txnId: String
}

struct PayUTransactionDetailsResponse: Decodable {
    let success: Bool
    let data: PayUTransactionDetails?
}

struct PayUTransactionDetails: Decodable {
    let paymentAmount: String?
    let billNo: String?
    let propertyId: String?
    let txnId: String?
    let dateTime: String?
    let paymentMode: String?
    let transactionStatus: String?
    let ownerName: String?
    let mobileNo: String?
    let address: String?
}

// MARK: - SBI

struct CreateSbiTransactionRequest: Encodable {
    let propertyId: String
    let billNo: String
    let amount: String
    let emailId: String
    let phoneNo: String
    let ownerName: String
    let ulbId: String
    let integrityToken: String
}

struct CreateSbiTransactionResponse: Decodable {
    let success: Bool
    let message: String
    let data: SbiTransactionData?
}

struct SbiTransactionData: Decodable {
    let txnid: String?
    let merchantId: String?
    let encdata: String?
    let sbiPostUrl: String?
    let paymentPageHtml: String?
}

struct SbiTransactionDetailsResponse: Decodable {
    let success: Bool
    let data: SbiPaymentDetails?
}

struct SbiPaymentDetails: Decodable {
    let paymentStatus: String?
    let txnid: String?
    let paymentMode: String?
    let paymentAmount: String?
    let billNo: String?
    let propertyId: String?
    let paymentDate: String?
    let ownerName: String?
    let address: String?
    let wardName: String?
    let ulbName: String?
}

// MARK: - Transaction history

struct TransactionsByEmailRequest: Encodable {
    let emailId: String
}

struct TransactionsByEmailResponse: Decodable {
    let success: Bool
    let data: [TransactionData]
}

struct TransactionData: Decodable, Identifiable {
    let paymentAmount: String?
    let billNo: String?
    let propertyId: String?
    let txnId: String?
    let dateTime: String?
    let paymentMode: String?
    let transactionStatus: String?
    var id: String { txnId ?? UUID().uuidString }
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
