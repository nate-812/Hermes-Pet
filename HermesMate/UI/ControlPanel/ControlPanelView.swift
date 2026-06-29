import SwiftUI

struct ControlPanelView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // 左侧边导航栏
            SideNavigationBar()
            
            // 主面板
            ZStack(alignment: .bottom) {
                // 主背板: 浅色系高级透光玻璃
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.2)) // 提亮底色，增加白透感
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0.2), .white.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    // 在浅色下使用更轻柔弥散的阴影
                    .shadow(color: Color.black.opacity(0.15), radius: 40, x: 0, y: 20)
                
                // 内部网格布局
                VStack(spacing: 16) {
                    // 第一排
                    HStack(spacing: 16) {
                        SmartLampWidget()
                        PowerChartWidget()
                        ThermostatWidget()
                    }
                    
                    // 第二排
                    HStack(spacing: 16) {
                        MetricWidget(title: "Current Consumption", value: "1.5 kWh")
                        MetricWidget(title: "Humidity", value: "48.2 %")
                        MetricWidget(title: "Temperature", value: "68° F")
                    }
                    
                    // 第三排
                    HStack(spacing: 16) {
                        SmallToggleWidget(title: "Humidifier", subtitle: "Gaabor", isOn: true)
                        SmallToggleWidget(title: "Speaker", subtitle: "Amazon Echo", isOn: false)
                        SmallToggleWidget(title: "Smart Lamp", subtitle: "Bardi", isOn: true)
                        SmallToggleWidget(title: "Camera", subtitle: "Xiaomi", isOn: false)
                    }
                }
                .padding(24)
                .padding(.bottom, 24) // 为底部 TabBar 留出空间
                
                // 悬浮底部 TabBar
                BottomTabBar()
                    .offset(y: 16) // 悬浮在主面板底部边缘
            }
            .frame(width: 760, height: 460)
        }
        .padding(40) // 留出窗口安全区与阴影空间
        .environment(\.colorScheme, .light) // 强制浅色模式，呈现明亮的玻璃质感
    }
}

// MARK: - Smart Lamp Widget (Top Left)
struct SmartLampWidget: View {
    var body: some View {
        GlassCard(height: 200) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Device")
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.6))
                        Text("Luminens Standing Lamp")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.black.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer()
                    Circle().fill(Color.white.opacity(0.6)).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "circle.grid.2x2.fill").font(.system(size: 9)).foregroundColor(.black.opacity(0.5)))
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("4H 20M").font(.headline).bold().foregroundColor(.black.opacity(0.9))
                        Text("Time Usage").font(.system(size: 9)).foregroundColor(.black.opacity(0.6))
                    }
                    Divider().background(Color.black.opacity(0.1)).frame(height: 30)
                    VStack(alignment: .leading) {
                        Text("72 W").font(.headline).bold().foregroundColor(.black.opacity(0.9))
                        Text("Energy").font(.system(size: 9)).foregroundColor(.black.opacity(0.6))
                    }
                }
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("On from").font(.system(size: 9)).foregroundColor(.black.opacity(0.6))
                        Text("06:00 PM").font(.caption).foregroundColor(.black.opacity(0.9))
                    }
                    .padding(8).background(Color.white.opacity(0.4)).cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text("Off at").font(.system(size: 9)).foregroundColor(.black.opacity(0.6))
                        Text("05:00 AM").font(.caption).foregroundColor(.black.opacity(0.9))
                    }
                    .padding(8).background(Color.white.opacity(0.4)).cornerRadius(8)
                }
                
                Spacer()
                
                // 亮度条
                HStack {
                    Image(systemName: "sun.min.fill").font(.system(size: 10)).foregroundColor(.black.opacity(0.7))
                    Capsule().fill(Color.blue).frame(height: 6)
                        .overlay(Capsule().fill(Color.black.opacity(0.1)).padding(.leading, 60), alignment: .trailing)
                }
                .padding(8).background(Color.white.opacity(0.4)).cornerRadius(8)
            }
        }
    }
}

// MARK: - Power Chart Widget (Top Center)
struct PowerChartWidget: View {
    let data: [CGFloat] = [40, 70, 110, 60, 80, 50]
    let labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
    
    var body: some View {
        GlassCard(height: 200) {
            VStack(alignment: .leading) {
                Text("Power (kWh)")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
                
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 14) {
                        Text("170").font(.system(size: 8)).foregroundColor(.black.opacity(0.5))
                        Text("130").font(.system(size: 8)).foregroundColor(.black.opacity(0.5))
                        Text("90").font(.system(size: 8)).foregroundColor(.black.opacity(0.5))
                        Text("50").font(.system(size: 8)).foregroundColor(.black.opacity(0.5))
                        Text("0").font(.system(size: 8)).foregroundColor(.black.opacity(0.5))
                    }
                    
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(0..<data.count, id: \.self) { index in
                            VStack {
                                Capsule()
                                    .fill(index == 2 ? Color.blue : Color.white.opacity(0.6))
                                    .frame(width: 12, height: data[index])
                                Text(labels[index])
                                    .font(.system(size: 8))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                        }
                    }
                }
            }
        }
    }
}
