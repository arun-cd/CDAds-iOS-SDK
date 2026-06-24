import Foundation

/// Matches the legacy Tempo "secret code" used to reveal the in-app debug log
/// viewer — historically, typing `*##*` into the app's search bar would show a
/// hidden console. Host apps wire this into whatever text-entry callback they
/// already have (a search bar, a settings field, etc.) and present
/// `CDADebugLogViewController` on a match.
///
/// ```swift
/// func textFieldDidChange(_ textField: UITextField) {
///     guard let text = textField.text, CDADebugTrigger.matches(text) else { return }
///     present(UINavigationController(rootViewController: CDADebugLogViewController()), animated: true)
/// }
/// ```
public enum CDADebugTrigger {

    /// The legacy reveal code.
    public static let magicCode = "*##*"

    /// Returns `true` once `text` starts with the magic code.
    public static func matches(_ text: String) -> Bool {
        text.hasPrefix(magicCode)
    }
}
