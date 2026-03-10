//
//  PnLCalculator.swift
//  Journal de trading 2025
//
//  Calcul des frais et du PnL net (après frais maker/taker)
//

import Foundation

// MARK: - PnL Calculator

struct PnLCalculator {

    // MARK: - Fees

    /// Résultat des frais calculés
    struct FeeResult {
        let entryFee: Double
        let exitFee:  Double
        var total: Double { entryFee + exitFee }
    }

    /// Calcule les frais d'entrée et de sortie selon le rôle (maker/taker)
    static func fees(
        entryPrice: Double,
        exitPrice:  Double,
        quantity:   Double,
        makerRate:  Double,
        takerRate:  Double,
        role:       OrderRole
    ) -> FeeResult {
        let entryNotional = entryPrice * quantity
        let exitNotional  = exitPrice  * quantity

        let rate: Double
        switch role {
        case .maker: rate = makerRate
        case .taker: rate = takerRate
        }

        let entryFee = entryNotional * rate
        let exitFee  = exitNotional  * rate
        return FeeResult(entryFee: entryFee, exitFee: exitFee)
    }

    // MARK: - Net PnL

    /// Calcule le PnL net après frais pour un trade fermé
    static func netPnL(
        entryPrice: Double,
        exitPrice:  Double,
        quantity:   Double,
        type:       TradeType,
        leverage:   Double,
        makerRate:  Double,
        takerRate:  Double,
        role:       OrderRole
    ) -> Double {
        // PnL brut
        let grossPnL: Double
        switch type {
        case .long:
            grossPnL = (exitPrice - entryPrice) * quantity * leverage
        case .short:
            grossPnL = (entryPrice - exitPrice) * quantity * leverage
        }

        // Frais
        let feeTuple = fees(
            entryPrice: entryPrice,
            exitPrice:  exitPrice,
            quantity:   quantity,
            makerRate:  makerRate,
            takerRate:  takerRate,
            role:       role
        )

        return grossPnL - feeTuple.total
    }
}
