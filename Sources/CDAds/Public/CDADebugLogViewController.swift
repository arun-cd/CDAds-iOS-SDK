import UIKit

/// Drop-in in-app log viewer — the modern equivalent of Tempo's old `*##*`
/// debug console. Wrap in a `UINavigationController` and present it once
/// `CDADebugTrigger.matches(_:)` returns true for some text input.
///
/// ```swift
/// let vc = UINavigationController(rootViewController: CDADebugLogViewController())
/// present(vc, animated: true)
/// ```
@MainActor
public final class CDADebugLogViewController: UIViewController {

    private let textView = UITextView()
    private var observer: NSObjectProtocol?
    private lazy var enableButton = UIBarButtonItem(
        title: "", style: .plain, target: self, action: #selector(enableTapped)
    )

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "CDAds Debug Log"
        view.backgroundColor = .systemBackground

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .systemBackground
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearTapped)),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareTapped)),
            enableButton,
        ]
        updateEnableButtonTitle()

        observer = NotificationCenter.default.addObserver(
            forName: CDALogger.logsUpdatedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reload() }
        }
        reload()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func reload() {
        let text = CDAds.debugLogs()
        textView.text = text
        textView.scrollRangeToVisible(NSRange(location: text.count, length: 0))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearTapped() {
        CDAds.clearDebugLogs()
    }

    @objc private func shareTapped() {
        let activity = UIActivityViewController(activityItems: [CDAds.debugLogFileURL], applicationActivities: nil)
        present(activity, animated: true)
    }

    /// Toggles file/buffer capture on or off — independent of `logLevel`.
    /// Off by default; flip it on here to start capturing without a rebuild.
    @objc private func enableTapped() {
        CDAds.isDebugFileLoggingEnabled.toggle()
        updateEnableButtonTitle()
    }

    private func updateEnableButtonTitle() {
        enableButton.title = CDAds.isDebugFileLoggingEnabled ? "Disable" : "Enable"
    }
}
