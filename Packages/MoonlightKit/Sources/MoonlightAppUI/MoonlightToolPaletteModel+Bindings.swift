import MoonlightDomain
import SwiftUI

extension MoonlightToolPaletteModel {
    /// A binding for one of a tool's declared options.
    ///
    /// The selections are a dictionary keyed by parameter name, so there is no
    /// stored property to bind to directly. Building the binding here keeps it
    /// out of the view's `body`, which is re-evaluated on every change.
    func binding(for option: CommandOption) -> Binding<String> {
        Binding(
            get: { self.optionValue(option) },
            set: { self.setOptionValue($0, for: option) }
        )
    }
}
