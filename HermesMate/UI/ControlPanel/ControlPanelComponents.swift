import SwiftUI

// MARK: - Reusable Glass Card
struct GlassCard<Content: View>: View {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = 20
    let content: () -> Content
    
    init(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        ZStack {
            // 浅色主题：使用高透光的纯白色，避免嵌套材质带来的性能问题
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.8), .white.opacity(0.2), .white.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            content()
                .padding(16)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Thermostat Widget
struct ThermostatWidget: View {
    @State private var isOn: Bool = true
    @State private var activeMode: String = "Hot"
    
    var body: some View {
        GlassCard(width: 220, height: 200) {
            VStack(spacing: 12) {
                HStack {
                    Text("Thermostat")
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.7))
                    Spacer()
                    Toggle("", isOn: $isOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 6)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0.1, to: 0.7)
                        .stroke(isOn ? Color.blue : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(120))
                        .animation(.easeInOut, value: isOn)
                    
                    VStack(spacing: 2) {
                        Text(isOn ? "64°" : "--")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                    }
                }
                
                HStack(spacing: 12) {
                    ThermostatModeButton(icon: "flame.fill", label: "Hot", isActive: activeMode == "Hot") { activeMode = "Hot" }
                    ThermostatModeButton(icon: "leaf.fill", label: "Eco", isActive: activeMode == "Eco") { activeMode = "Eco" }
                    ThermostatModeButton(icon: "wind", label: "Fan", isActive: activeMode == "Fan") { activeMode = "Fan" }
                    ThermostatModeButton(icon: "snowflake", label: "Cold", isActive: activeMode == "Cold") { activeMode = "Cold" }
                }
                .opacity(isOn ? 1.0 : 0.5)
            }
        }
    }
}

struct ThermostatModeButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? .blue : .black.opacity(0.5))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(isActive ? .blue : .black.opacity(0.5))
            }
            .frame(width: 36, height: 40)
            .background(isActive ? Color.blue.opacity(0.15) : Color.white.opacity(0.4))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Metric Widget
struct MetricWidget: View {
    let title: String
    let value: String
    
    var body: some View {
        GlassCard(height: 80) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Small Toggle Widget
struct SmallToggleWidget: View {
    let title: String
    let subtitle: String
    @State var isOn: Bool
    
    var body: some View {
        GlassCard(height: 90) {
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "circle.grid.2x2.fill").foregroundColor(isOn ? .blue : .black.opacity(0.5)).font(.system(size: 10)))
                    Spacer()
                    Toggle("", isOn: $isOn)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                        .scaleEffect(0.6)
                }
                Spacer()
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.5))
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.8))
            }
        }
        .onTapGesture {
            withAnimation {
                isOn.toggle()
            }
        }
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    let tabs = ["Living Room", "Bedroom", "Kitchen", "Backyard", "Garage"]
    @State private var selectedTab = "Living Room"
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(tabs, id: \.self) { tab in
                Button(action: {
                    withAnimation { selectedTab = tab }
                }) {
                    Text(tab)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .black.opacity(0.9) : .black.opacity(0.5))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(selectedTab == tab ? Color.white.opacity(0.6) : Color.clear)
                        .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: {
                // Add action here
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 8)
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.4))
        )
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [.white.opacity(0.8), .white.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Side Navigation Bar
struct SideNavigationBar: View {
    let icons = ["square.grid.2x2", "desktopcomputer", "chart.bar", "plus.app", "switch.2"]
    @State private var selectedIcon = "square.grid.2x2"
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(icons, id: \.self) { icon in
                Button(action: {
                    selectedIcon = icon
                }) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(selectedIcon == icon ? .blue : .black.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(selectedIcon == icon ? Color.white.opacity(0.5) : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
            Button(action: {
                
            }) {
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: "person.fill").foregroundColor(.black.opacity(0.7)).font(.system(size: 14)))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24).stroke(
                LinearGradient(
                    colors: [.white.opacity(0.8), .white.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .frame(height: 320)
    }
}
