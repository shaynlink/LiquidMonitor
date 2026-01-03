import SwiftUI

struct LiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Dark base
            Color.black.ignoresSafeArea()
            
            // Mesh Gradient simulation using multiple moving blobs
            GeometryReader { proxy in
                ZStack {
                    // Blob 1
                    Circle()
                        .fill(Color(red: 0.2, green: 0.2, blue: 0.8).opacity(0.6))
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: animate ? -100 : 100, y: animate ? -100 : 100)
                    
                    // Blob 2
                    Circle()
                        .fill(Color(red: 0.5, green: 0.1, blue: 0.8).opacity(0.5))
                        .frame(width: 350, height: 350)
                        .blur(radius: 60)
                        .offset(x: animate ? 150 : -150, y: animate ? 100 : -100)
                        
                    // Blob 3
                    Circle()
                        .fill(Color(red: 0.1, green: 0.6, blue: 0.7).opacity(0.5))
                        .frame(width: 300, height: 300)
                        .blur(radius: 70)
                        .offset(x: animate ? -100 : 100, y: animate ? 200 : -200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                        animate.toggle()
                    }
                }
            }
            // Glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.1)
                .ignoresSafeArea()
        }
    }
}
