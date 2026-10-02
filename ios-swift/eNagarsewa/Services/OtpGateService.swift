import UIKit

/// Port of lib/services/otp_gate_service.dart — the shared "responseCode 12" (expired / incorrect
/// session token) recovery for the assessment, reassessment, mutation, water, grievance and ARV
/// APIs: send an OTP to the property's registered mobile, verify it, then retry the call once.
@MainActor
enum OtpGateService {

    static func guardCall<T>(propertyId: String, mobileNo: String,
                             responseCode: (T) -> Int?,
                             call: () async throws -> T) async throws -> T {
        let response = try await call()
        guard responseCode(response) == 12 else { return response }
        guard await verify(propertyId: propertyId, mobileNo: mobileNo) else { return response }
        return try await call()
    }

    static func verify(propertyId: String, mobileNo: String) async -> Bool {
        let host = AppRouter.shared.topViewController
        var pid = propertyId, mobile = mobileNo
        // No clean pair in context (e.g. a brand-new assessment or a list fetch) → fall back to
        // the first saved property's id + mobile together.
        if pid.isEmpty || mobile.isEmpty, let first = await DatabaseService.shared.getAllProperties().first {
            pid = first.propertyId
            mobile = first.phoneNumber
        }
        guard !pid.isEmpty, !mobile.isEmpty else { return false }

        do {
            let sent = try await APIService.shared.sendOtp(mobileNo: mobile, propertyId: pid)
            guard sent.success == true else {
                host.snack(sent.message ?? "Failed to send OTP")
                return false
            }
            return await OtpVerificationSheet.present(on: AppRouter.shared.topViewController, propertyId: pid,
                                                      mobileNo: mobile, maskedMobile: sent.maskedMobile ?? mobile)
        } catch {
            host.snack(APIError.userMessage(error, fallback: "Unable to send OTP right now. Please try again."))
            return false
        }
    }
}

/// Port of lib/widgets/otp_verification_sheet.dart.
final class OtpVerificationSheet: BottomSheetController {

    private let propertyId: String
    private let mobileNo: String
    private let maskedMobile: String
    private var completion: ((Bool) -> Void)?

    private let otpField: ENSTextField = {
        var c = ENSTextField.Config()
        c.placeholder = "Enter OTP"
        c.icon = "number.square"
        c.iconColor = .grey600
        c.keyboard = .numberPad
        c.maxLength = 6
        c.digitsOnly = true
        c.fontSize = 15
        c.fill = .white
        return ENSTextField(c)
    }()
    private let resendButton = UIButton(type: .system)
    private let cancelButton = OutlineButton("Cancel", color: .grey700, borderColor: .grey400, height: 50, fontSize: 15)
    private let verifyButton = PrimaryButton("Verify", height: 50, radius: 12, fontSize: 15, weight: .semibold)

    init(propertyId: String, mobileNo: String, maskedMobile: String, completion: @escaping (Bool) -> Void) {
        self.propertyId = propertyId
        self.mobileNo = mobileNo
        self.maskedMobile = maskedMobile
        self.completion = completion
        super.init()
        isDismissible = false
        cornerRadius = 20
        contentInsets = UIEdgeInsets(top: 8, left: 20, bottom: 20, right: 20)
    }

    required init?(coder: NSCoder) { fatalError() }

    static func present(on vc: UIViewController, propertyId: String, mobileNo: String, maskedMobile: String) async -> Bool {
        await withCheckedContinuation { c in
            let sheet = OtpVerificationSheet(propertyId: propertyId, mobileNo: mobileNo, maskedMobile: maskedMobile) {
                c.resume(returning: $0)
            }
            vc.topPresented.present(sheet, animated: true)
        }
    }

    override func buildContent() {
        contentStack.add(UILabel("Verify OTP", font: .poppins(18, .bold), color: .black87))
        contentStack.addSpacer(8)
        contentStack.add(UILabel("For security, please verify the OTP sent to \(maskedMobile) to continue.",
                                 font: .poppins(13), color: .grey700, lines: 0))
        contentStack.addSpacer(18)
        otpField.box.layer.borderColor = UIColor.grey300.cgColor
        contentStack.add(otpField)
        resendButton.setTitle("Resend OTP", for: .normal)
        resendButton.setTitleColor(.appPrimary, for: .normal)
        resendButton.setTitleColor(.appPrimary.withAlphaComponent(0.5), for: .disabled)
        resendButton.titleLabel?.font = .poppins(12, .semibold)
        contentStack.add(UIStackView.h(0, [FlexSpacer(), resendButton]))
        contentStack.addSpacer(8)
        let buttons = UIStackView.h(12, alignment: .fill, [cancelButton, verifyButton])
        buttons.distribution = .fillEqually
        contentStack.add(buttons)

        resendButton.onEvent { [weak self] in self?.resend() }
        cancelButton.onEvent { [weak self] in self?.finish(false) }
        verifyButton.onEvent { [weak self] in self?.verify() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = otpField.becomeFirstResponder()
    }

    private func finish(_ ok: Bool) {
        let done = completion
        completion = nil
        close { done?(ok) }
    }

    private func verify() {
        let otp = otpField.trimmedText
        if otp.isEmpty { otpField.setError("Please enter OTP"); return }
        if otp.count < 4 { otpField.setError("Please enter valid OTP"); return }
        verifyButton.isLoading = true
        cancelButton.isEnabled = false
        otpField.setError(nil)
        Task {
            do {
                let res = try await APIService.shared.verifyOtp(mobileNo: mobileNo, otp: otp)
                if res.success == true { finish(true); return }
                otpField.setError(res.message ?? "Invalid OTP")
            } catch {
                otpField.setError(APIError.userMessage(error, fallback: "Unable to verify OTP. Please try again."))
            }
            verifyButton.isLoading = false
            cancelButton.isEnabled = true
        }
    }

    private func resend() {
        resendButton.isEnabled = false
        resendButton.setTitle("Resending...", for: .normal)
        otpField.setError(nil)
        Task {
            do {
                let res = try await APIService.shared.sendOtp(mobileNo: mobileNo, propertyId: propertyId)
                otpField.setError(res.success == true ? nil : (res.message ?? "Failed to resend OTP"))
            } catch {
                otpField.setError(APIError.userMessage(error, fallback: "Unable to resend OTP. Please try again."))
            }
            resendButton.isEnabled = true
            resendButton.setTitle("Resend OTP", for: .normal)
        }
    }
}
