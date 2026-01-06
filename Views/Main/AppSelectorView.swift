import SwiftUI

struct AppSelectorView: View {
    @Binding var selectedApp: AppInfo?
    let apps: [AppInfo]
    
    var body: some View {
        if apps.isEmpty {
            VStack {
                Image(systemName: "app.dashed")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No applications available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(apps) { app in
                        VStack(spacing: 2) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 36, height: 36)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(.secondary)
                            }
                            Text(app.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .frame(width: 56)
                        .padding(4)
                        .background(selectedApp == app ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            withAnimation {
                                selectedApp = app
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}
