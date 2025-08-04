import SwiftUI

struct DevToolsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🛠️")
                    .font(.system(size: 60))

                Text("SwiftUI Query DevTools")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("DevTools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DevToolsView()
}
