import UIKit
import PhotosUI
import Combine

final class ApplyGrievanceViewController: UIViewController {

    private let viewModel: ApplyGrievanceViewModel
    weak var coordinator: (AnyObject & GrievanceCoordinatorProtocol)?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ApplyGrievanceViewModel, coordinator: AnyObject & GrievanceCoordinatorProtocol) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let categoryButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "Select Category"
        let b = UIButton(configuration: cfg)
        b.contentHorizontalAlignment = .left; b.translatesAutoresizingMaskIntoConstraints = false; return b
    }()
    private let subCategoryButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "Select Sub-Category"
        let b = UIButton(configuration: cfg)
        b.contentHorizontalAlignment = .left; b.translatesAutoresizingMaskIntoConstraints = false
        b.isEnabled = false; return b
    }()
    private lazy var descriptionField: UITextView = {
        let tv = UITextView(); tv.font = .systemFont(ofSize: 16)
        tv.layer.borderColor = UIColor.separator.cgColor; tv.layer.borderWidth = 1; tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false; return tv
    }()
    private lazy var mobileField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Mobile number")
        tf.keyboardType = .phonePad; return tf
    }()
    private let imageView: UIImageView = {
        let iv = UIImageView(); iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
        iv.layer.cornerRadius = 8; iv.backgroundColor = .appSurface; iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false; return iv
    }()
    private lazy var addImageButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "Add Photo (Optional)"; cfg.image = UIImage(systemName: "camera")
        let b = UIButton(configuration: cfg); b.translatesAutoresizingMaskIntoConstraints = false; return b
    }()
    private lazy var submitButton = UIButton.primaryButton(title: "Submit Grievance")
    private lazy var otpField: UITextField = { let tf = UITextField.styledTextField(placeholder: "Enter OTP"); tf.isHidden = true; return tf }()
    private lazy var verifyOtpButton: UIButton = { let b = UIButton.primaryButton(title: "Verify OTP"); b.isHidden = true; return b }()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Apply Grievance"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        viewModel.coordinator = coordinator
        viewModel.onViewAppear()
        categoryButton.addTarget(self, action: #selector(showCategories), for: .touchUpInside)
        subCategoryButton.addTarget(self, action: #selector(showSubCategories), for: .touchUpInside)
        addImageButton.addTarget(self, action: #selector(showImagePicker), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        verifyOtpButton.addTarget(self, action: #selector(verifyOtpTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        activityIndicator.hidesWhenStopped = true; activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); let content = UIView()
        scroll.translatesAutoresizingMaskIntoConstraints = false; content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(content); scroll.pinToEdges(of: view)
        NSLayoutConstraint.activate([content.topAnchor.constraint(equalTo: scroll.topAnchor), content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor), content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor), content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor), content.widthAnchor.constraint(equalTo: scroll.widthAnchor)])

        let stack = UIStackView(arrangedSubviews: [
            makeLabel("Category"), categoryButton, makeLabel("Sub-Category"), subCategoryButton,
            makeLabel("Description"), descriptionField, makeLabel("Mobile Number"), mobileField,
            addImageButton, imageView, submitButton, otpField, verifyOtpButton, activityIndicator
        ])
        stack.axis = .vertical; stack.spacing = 12; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([
            descriptionField.heightAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 180),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
            verifyOtpButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.submitButton.isEnabled = !l
        }.store(in: &cancellables)

        viewModel.$requiresOtp.receive(on: DispatchQueue.main).sink { [weak self] needed in
            self?.otpField.isHidden     = !needed
            self?.verifyOtpButton.isHidden = !needed
            self?.submitButton.isHidden  = needed
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)

        viewModel.$selectedCategory.receive(on: DispatchQueue.main).sink { [weak self] cat in
            self?.categoryButton.setTitle(cat?.serviceName ?? "Select Category", for: .normal)
            self?.subCategoryButton.isEnabled = cat != nil
        }.store(in: &cancellables)

        viewModel.$selectedSubCategory.receive(on: DispatchQueue.main).sink { [weak self] sub in
            self?.subCategoryButton.setTitle(sub?.subCategoryName ?? "Select Sub-Category", for: .normal)
        }.store(in: &cancellables)

        viewModel.$selectedImage.receive(on: DispatchQueue.main).sink { [weak self] img in
            self?.imageView.image  = img
            self?.imageView.isHidden = img == nil
        }.store(in: &cancellables)
    }

    @objc private func showCategories() {
        let alert = UIAlertController(title: "Select Category", message: nil, preferredStyle: .actionSheet)
        viewModel.categories.forEach { cat in
            alert.addAction(UIAlertAction(title: cat.serviceName, style: .default) { [weak self] _ in
                self?.viewModel.selectedCategory = cat
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func showSubCategories() {
        guard let subs = viewModel.selectedCategory?.subCategories else { return }
        let alert = UIAlertController(title: "Select Sub-Category", message: nil, preferredStyle: .actionSheet)
        subs.forEach { sub in
            alert.addAction(UIAlertAction(title: sub.subCategoryName, style: .default) { [weak self] _ in
                self?.viewModel.selectedSubCategory = sub
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func showImagePicker() {
        let alert = UIAlertController(title: "Select Photo", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in self?.openCamera() })
        alert.addAction(UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in self?.openGallery() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera; picker.delegate = self; present(picker, animated: true)
    }

    private func openGallery() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1; config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self; present(picker, animated: true)
    }

    @objc private func submitTapped() {
        viewModel.description  = descriptionField.text
        viewModel.mobileNumber = mobileField.text ?? ""
        viewModel.submit()
    }

    @objc private func verifyOtpTapped() {
        viewModel.otp = otpField.text ?? ""
        viewModel.verifyOtp()
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel(); l.text = text; l.font = .boldSystemFont(ofSize: 13); l.textColor = .secondaryLabel; return l
    }
}

// MARK: - Image picker delegates

extension ApplyGrievanceViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        viewModel.selectedImage = info[.originalImage] as? UIImage
        picker.dismiss(animated: true)
    }
}

extension ApplyGrievanceViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async { self?.viewModel.selectedImage = object as? UIImage }
        }
    }
}
