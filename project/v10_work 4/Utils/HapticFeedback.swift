//
//  HapticFeedback.swift
//  Journal de trading 2025
//

import UIKit

enum HapticType {
    case impact(style: UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(style: UINotificationFeedbackGenerator.FeedbackType)
    case selection
}

struct HapticFeedback {
    static func trigger(_ type: HapticType) {
        switch type {
        case .impact(let style):
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
            
        case .notification(let feedbackType):
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(feedbackType)
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    // Convenience methods
    static func light() {
        trigger(.impact(style: .light))
    }
    
    static func medium() {
        trigger(.impact(style: .medium))
    }
    
    static func heavy() {
        trigger(.impact(style: .heavy))
    }
    
    static func success() {
        trigger(.notification(style: .success))
    }
    
    static func warning() {
        trigger(.notification(style: .warning))
    }
    
    static func error() {
        trigger(.notification(style: .error))
    }
    
    static func selection() {
        trigger(.selection)
    }
}





