import SwiftUI

struct ToolGuardOverlay: View {
    var onApprove: () -> Void = {}
    var onDeny: () -> Void = {}
    
    var body: some View {
        ZStack {
            // Background blur to dim underlying content
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Dialog Box
            VStack(spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Approval Request")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("An action requires your explicit permission before proceeding.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: onDeny) {
                        Text("Deny")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                            // Button border
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onApprove) {
                        Text("Approve")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
            .padding(32)
            .frame(width: 360)
            // Ultra-thin material for frosted glass effect
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            // Glossy shine overlay
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            // Specular highlight border
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.1), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            // Elevation shadow
            .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
        }
    }
}

#Preview {
    ToolGuardOverlay()
}
