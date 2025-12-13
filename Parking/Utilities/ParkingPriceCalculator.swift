import Foundation

/// Calculates parking price based on duration
/// Tariffs:
/// - 30 minutes: 6 Lei
/// - 1 hour: 10 Lei
/// - 2 hours: 18 Lei
/// - 24 hours: 50 Lei
struct ParkingPriceCalculator {
    
    /// Calculate price based on start time to now (for active tickets)
    static func calculatePrice(from startTime: Date) -> Double {
        return calculatePrice(from: startTime, to: Date())
    }
    
    /// Calculate price based on duration between two times
    static func calculatePrice(from startTime: Date, to endTime: Date) -> Double {
        let minutes = endTime.timeIntervalSince(startTime) / 60
        
        if minutes <= 0 {
            return 0
        } else if minutes <= 30 {
            return 6  // 30 min: 6 Lei
        } else if minutes <= 60 {
            return 10  // 1 hour: 10 Lei
        } else if minutes <= 120 {
            return 18  // 2 hours: 18 Lei
        } else if minutes <= 1440 {  // Up to 24 hours
            return 50  // 24 hours: 50 Lei
        } else {
            // Over 24 hours: charge per day (ceiling)
            // 25 hours = 2 days = 100 Lei
            let hours = minutes / 60
            let days = ceil(hours / 24)
            return days * 50  // 50 Lei per day
        }
    }
    
    /// Format price in Lei currency
    static func formatPrice(_ amount: Double) -> String {
        return String(format: "%.0f Lei", amount)
    }
    
    /// Tariff display text for home screen
    static var tariffText: String {
        return "30 min: 6 Lei • 1h: 10 Lei • 2h: 18 Lei • 24h: 50 Lei"
    }
}
