import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for faster response on first use
        selectionGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    static func selection() {
        shared.selectionGenerator.selectionChanged()
        shared.selectionGenerator.prepare()
    }
    
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            shared.lightImpactGenerator.impactOccurred()
            shared.lightImpactGenerator.prepare()
        case .medium:
            shared.mediumImpactGenerator.impactOccurred()
            shared.mediumImpactGenerator.prepare()
        case .heavy:
            shared.heavyImpactGenerator.impactOccurred()
            shared.heavyImpactGenerator.prepare()
        default:
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        shared.notificationGenerator.notificationOccurred(type)
        shared.notificationGenerator.prepare()
    }
}
