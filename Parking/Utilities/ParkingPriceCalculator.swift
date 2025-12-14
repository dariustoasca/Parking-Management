/*
 * ParkingPriceCalculator.swift
 * Smart Parking System
 * Author: Darius Toasca
 * 
 * This utility handles all the pricing logic for parking tickets.
 * Prices are in Romanian Lei (RON).
 * 
 * TARIFF STRUCTURE:
 * - Up to 30 minutes: 6 Lei
 * - Up to 1 hour: 10 Lei  
 * - Up to 2 hours: 18 Lei
 * - Up to 24 hours: 50 Lei
 * - Over 24 hours: 50 Lei per day (rounded up)
 *   Example: 25 hours = 2 days = 100 Lei
 */

import Foundation

struct ParkingPriceCalculator {
    
    // Calculate price from start time until now (for active tickets)
    static func calculatePrice(from startTime: Date) -> Double {
        return calculatePrice(from: startTime, to: Date())
    }
    
    // Calculate price based on total parking duration
    static func calculatePrice(from startTime: Date, to endTime: Date) -> Double {
        let minutes = endTime.timeIntervalSince(startTime) / 60
        
        if minutes <= 0 {
            return 0
        } else if minutes <= 30 {
            return 6  // 30 min
        } else if minutes <= 60 {
            return 10  // 1 hour
        } else if minutes <= 120 {
            return 18  // 2 hours
        } else if minutes <= 1440 {  // 24 hours = 1440 minutes
            return 50  // full day rate
        } else {
            // Multi-day parking - charge per day
            let hours = minutes / 60
            let days = ceil(hours / 24)
            return days * 50
        }
    }
    
    // Formats the amount with "Lei" suffix
    static func formatPrice(_ amount: Double) -> String {
        return String(format: "%.0f Lei", amount)
    }
    
    // Text displayed on the home screen showing all tariffs
    static var tariffText: String {
        return "30 min: 6 Lei • 1h: 10 Lei • 2h: 18 Lei • 24h: 50 Lei"
    }
}
