import Foundation

struct PowermetricsSample: Codable {
    var processor: ProcessorInfo?
    var gpu: GPUInfo?
    var thermal_pressure: String?
    var cpu_power: Double?
    var gpu_power: Double?
    var combined_power: Double?
    var timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case processor
        case gpu
        case thermal_pressure
        case cpu_power
        case gpu_power
        case combined_power
        case timestamp
    }
}

struct ProcessorInfo: Codable {
    var packages: [PackageInfo]?
    var clusters: [ClusterInfo]? // M-series often puts clusters directly under processor
    var cpu_power: Double? // Total CPU power
    
    enum CodingKeys: String, CodingKey {
        case packages
        case clusters
        case cpu_power
    }
}

struct PackageInfo: Codable {
    var clusters: [ClusterInfo]?
    
    enum CodingKeys: String, CodingKey {
        case clusters
    }
}

struct ClusterInfo: Codable {
    var name: String? // "E-Cluster", "P-Cluster"
    var freq_hz: Double? // Current frequency
    
    enum CodingKeys: String, CodingKey {
        case name
        case freq_hz
    }
}

struct GPUInfo: Codable {
    var freq_hz: Double?
    var gpu_power: Double? // Watts? Check units. Often mW in some tools, but powermetrics usually mW.
     // "gpu_power": 123 (mW)
    
    enum CodingKeys: String, CodingKey {
        case freq_hz
        case gpu_power
    }
}

struct PowermetricsParser {
    // Takes the path to the plist file
    // Our command was `> file`
    // If powermetrics runs continuously with `-i 1000`, it streams multiple plist blocks.
    // Standard `>` with standard stream might result in a file growing indefinitely with concatenated plists.
    // Swift's PropertyListDecoder usually expects a SINGLE valid root object.
    // Strategy: We will read the *tail* of the file or just the last valid block.
    // A better approach for our RootService might be to write to a temp file per sample, but powermetrics doesn't support that easily.
    // Alternative: Read the file, try to find the last `<plist>...</plist>` block.
    
    func parse(content: String) -> PowermetricsSample? {
        // Naive extraction of the last XML plist block
        guard let range = content.range(of: "<plist version=\"1.0\">", options: .backwards) else {
            print("Parser DEBUG: Could not find <plist version=\"1.0\"> in content (size: \(content.count))")
            return nil
        }
        let suffix = content[range.lowerBound...]
        // Find the closing tag
        guard let closeRange = suffix.range(of: "</plist>") else {
             print("Parser DEBUG: Could not find </plist> closing tag")
             return nil
        }
        let plistString = String(suffix[...closeRange.upperBound])
        
        guard let data = plistString.data(using: .utf8) else {
            print("Parser DEBUG: UTF8 conversion failed")
            return nil
        }
        
        do {
            let decoder = PropertyListDecoder()
            let sample = try decoder.decode(PowermetricsSample.self, from: data)
            return sample
        } catch {
            print("Parser error: \(error)")
            // Dump a bit of data to see what we tried to parse
            print("Parser DEBUG: Failed XML snippet (first 100 chars): \(plistString.prefix(100))")
            return nil
        }
    }
}
