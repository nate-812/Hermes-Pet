import SwiftUI

struct PikachuPetView: View {
    var state: AgentActivityState
    
    // 宠物精灵图的路径
    // 注意：在实际应用中可以将其设为配置项，现在直接指向之前下载的卡比兽
    let kabiSpritePath = NSHomeDirectory() + "/.codex/pets/kabi/spritesheet.webp"
    
    var body: some View {
        ZStack {
            // 背景层
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
            
            VideoPetEngine(state: state, videoGravity: .resizeAspectFill)
                .padding(4)
        }
        .frame(width: 80, height: 100) // 灵动岛左侧专用尺寸
    }
}

#Preview {
    HStack {
        PikachuPetView(state: .idle)
        PikachuPetView(state: .toolRunning)
    }
    .padding()
    .background(Color.black)
}
