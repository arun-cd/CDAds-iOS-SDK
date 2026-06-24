import UIKit
import CDAds

/// A settings screen for overriding location and IP values used in ad requests.
/// All values are persisted via `LocationOverrideSettings` (UserDefaults).
/// No SDK internals are touched — geo is passed via `CDAdsAdRequest.geoInfo` and
/// IP is written to the same UserDefaults key the SDK reads (`CDPublicIPKey`).
final class SettingsViewController: UITableViewController {

    // MARK: - Data model

    private enum Row {
        case toggle(label: String, getter: () -> Bool, setter: (Bool) -> Void)
        case textInput(label: String, placeholder: String, keyboardType: UIKeyboardType,
                       getter: () -> String?, setter: (String?) -> Void)
        case action(label: String, style: UITableViewCell.CellStyle = .default, tint: UIColor = .systemRed)
    }

    private struct Section {
        let header: String?
        let footer: String?
        let rows: [Row]
    }

    private lazy var sections: [Section] = [
        Section(
            header: nil,
            footer: "When enabled, the values below are injected into every ad request. The IP field overwrites the SDK's cached public IP.",
            rows: [
                .toggle(
                    label: "Enable Location Override",
                    getter: { LocationOverrideSettings.isEnabled },
                    setter: { LocationOverrideSettings.isEnabled = $0 }
                )
            ]
        ),
        Section(
            header: "Coordinates",
            footer: "Both latitude and longitude are required for the override to take effect.",
            rows: [
                .textInput(label: "Latitude",  placeholder: "e.g. 37.3318",  keyboardType: .decimalPad,
                           getter: { LocationOverrideSettings.latitude.map { String($0) } },
                           setter: { LocationOverrideSettings.latitude  = $0.flatMap(Double.init) }),
                .textInput(label: "Longitude", placeholder: "e.g. -122.0312", keyboardType: .decimalPad,
                           getter: { LocationOverrideSettings.longitude.map { String($0) } },
                           setter: { LocationOverrideSettings.longitude = $0.flatMap(Double.init) })
            ]
        ),
        Section(
            header: "Address",
            footer: nil,
            rows: [
                .textInput(label: "City",         placeholder: "e.g. Cupertino", keyboardType: .default,
                           getter: { LocationOverrideSettings.city },
                           setter: { LocationOverrideSettings.city = $0 }),
                .textInput(label: "Region/State", placeholder: "e.g. California", keyboardType: .default,
                           getter: { LocationOverrideSettings.region },
                           setter: { LocationOverrideSettings.region = $0 }),
                .textInput(label: "Zip/Postal",   placeholder: "e.g. 95014", keyboardType: .numbersAndPunctuation,
                           getter: { LocationOverrideSettings.zip },
                           setter: { LocationOverrideSettings.zip = $0 }),
                .textInput(label: "Country Code", placeholder: "e.g. USA", keyboardType: .asciiCapable,
                           getter: { LocationOverrideSettings.countryCode },
                           setter: { LocationOverrideSettings.countryCode = $0?.uppercased() })
            ]
        ),
        Section(
            header: "Network",
            footer: "Overwrites the SDK's cached public IP immediately.",
            rows: [
                .textInput(label: "IP Address", placeholder: "e.g. 203.0.113.42", keyboardType: .numbersAndPunctuation,
                           getter: { LocationOverrideSettings.ipAddress },
                           setter: { LocationOverrideSettings.ipAddress = $0 })
            ]
        ),
        Section(
            header: nil,
            footer: nil,
            rows: [
                .action(label: "Clear All Overrides", tint: .systemRed)
            ]
        )
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Test Location Override"
        tableView.keyboardDismissMode = .onDrag

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )

        tableView.register(TextInputCell.self, forCellReuseIdentifier: TextInputCell.reuseID)
    }

    @objc private func doneTapped() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case let .toggle(label, getter, setter):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = label
            cell.selectionStyle = .none
            let sw = UISwitch()
            sw.isOn = getter()
            sw.addAction(UIAction { _ in setter(sw.isOn) }, for: .valueChanged)
            cell.accessoryView = sw
            return cell

        case let .textInput(label, placeholder, keyboardType, getter, setter):
            let cell = tableView.dequeueReusableCell(withIdentifier: TextInputCell.reuseID, for: indexPath) as! TextInputCell
            cell.configure(label: label, placeholder: placeholder, keyboardType: keyboardType,
                           value: getter()) { [weak self] newValue in
                // Type "*##*" into any field here to reveal the SDK's in-app debug
                // log viewer — same reveal code Tempo used for its old console.
                if let text = newValue, CDADebugTrigger.matches(text) {
                    self?.presentDebugLogViewer()
                    return
                }
                setter(newValue)
            }
            return cell

        case let .action(label, _, tint):
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = label
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = tint
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        if case .action = row {
            confirmClear()
        }
    }

    private func presentDebugLogViewer() {
        view.endEditing(true)
        let vc = CDADebugLogViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    private func confirmClear() {
        let alert = UIAlertController(
            title: "Clear Overrides",
            message: "This will remove all saved location and IP overrides, including the cached public IP.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            LocationOverrideSettings.clear()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - TextInputCell

private final class TextInputCell: UITableViewCell {

    static let reuseID = "TextInputCell"

    private let fieldLabel = UILabel()
    let textField = UITextField()
    private var onChange: ((String?) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        fieldLabel.translatesAutoresizingMaskIntoConstraints = false
        fieldLabel.font = UIFont.preferredFont(forTextStyle: .body)
        fieldLabel.setContentHuggingPriority(.required, for: .horizontal)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textColor = .secondaryLabel
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(textChanged), for: .editingDidEnd)

        contentView.addSubview(fieldLabel)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            fieldLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            fieldLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: fieldLabel.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(label: String, placeholder: String, keyboardType: UIKeyboardType,
                   value: String?, onChange: @escaping (String?) -> Void) {
        fieldLabel.text = label
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.text = value
        self.onChange = onChange
        textField.inputAccessoryView = keyboardType == .decimalPad
            ? makeDecimalToolbar()
            : makeDoneToolbar()
    }

    private func makeDecimalToolbar() -> UIToolbar {
        let bar = UIToolbar()
        bar.sizeToFit()
        let negativeBtn = UIBarButtonItem(
            title: "+/−",
            style: .plain,
            target: self,
            action: #selector(toggleNegative)
        )
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done  = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        bar.items = [negativeBtn, space, done]
        return bar
    }

    private func makeDoneToolbar() -> UIToolbar {
        let bar = UIToolbar()
        bar.sizeToFit()
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done  = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        bar.items = [space, done]
        return bar
    }

    @objc private func toggleNegative() {
        guard var text = textField.text else { return }
        text = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
        textField.text = text
        textChanged()
    }

    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
        textField.text = nil
        textField.inputAccessoryView = nil
    }

    @objc private func textChanged() {
        let v = textField.text.flatMap { $0.isEmpty ? nil : $0 }
        onChange?(v)
    }
}
