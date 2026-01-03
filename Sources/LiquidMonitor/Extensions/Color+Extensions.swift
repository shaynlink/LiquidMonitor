import SwiftUI

extension Color {
    static func distinct(seed: String) -> Color {
        var total: Int = 0
        for u in seed.unicodeScalars {
            total += Int(u.value)
        }
        
        // Use HSB for vibrant colors
        // Hash determines Hue (0.0 - 1.0)
        let hash = Double(total * 2654435761 % 4294967296) / 4294967296.0 // Knuth's multiplicative hash for better distribution
        
        let hue = hash
        let saturation = 0.7 + (Double(total % 30) / 100.0) // 0.7 - 1.0
        let brightness = 0.8 + (Double(total % 20) / 100.0) // 0.8 - 1.0
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    // Fixed palette for Top 5 to ensure they look good together if preferred
    static let chartPalette: [Color] = [
        .blue, .purple, .pink, .orange, .cyan, .green, .yellow, .red
    ]
    
    static func fromIndex(_ index: Int) -> Color {
        return chartPalette[index % chartPalette.count]
    }
}
