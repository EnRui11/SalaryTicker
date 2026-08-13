import SwiftUI
import SalaryShared

/// The configuration as a QR code, for pointing a phone at.
///
/// Deliberately a picture and not a copyable string. The payload carries the salary, and a
/// picture on a screen goes into a camera and nowhere else — the moment it becomes text in
/// a share sheet it has a chance of ending up somewhere it was never meant to be.
struct SendToPhoneSheet: View {
    let link: URL
    let text: Strings
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(text.sendToPhone)
                .font(.headline)

            if let code = QRCode.image(for: link.absoluteString, scale: 8) {
                Image(decorative: code, scale: 1)
                    .interpolation(.none)                 // smoothing the modules breaks it
                    .resizable()
                    .frame(width: 240, height: 240)
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(text.sendToPhone)
            } else {
                Label(text.importUnreadable, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .frame(width: 240, height: 240)
            }

            Text(text.sendToPhoneCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260)

            Button(text.doneAction, action: onClose)
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }
}
