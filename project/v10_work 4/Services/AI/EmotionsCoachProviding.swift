import Foundation

/// Hook IA (pas de logique IA ici) — interface stable pour brancher un coach plus tard.
protocol EmotionsCoachProviding {
    /// Recommandation courte (1–2 lignes max) à afficher en UI.
    func recommendation(
        emotionalState: EmotionalState,
        intensity: Int,
        context: MoodContext,
        trigger: MoodTrigger?
    ) -> String

    /// Action rapide suggérée (optionnelle).
    func suggestedQuickAction(
        emotionalState: EmotionalState,
        intensity: Int,
        context: MoodContext,
        trigger: MoodTrigger?
    ) -> MoodQuickAction?

    /// Checklist pré-trade suggérée (3 items max) — uniquement si beforeTrade.
    func suggestedMiniChecklist(
        emotionalState: EmotionalState,
        intensity: Int,
        context: MoodContext,
        trigger: MoodTrigger?
    ) -> MiniPreTradeChecklist?
}

/// Mock local (heuristiques simples) — remplaçable par IA plus tard.
final class LocalEmotionsCoachMock: EmotionsCoachProviding {
    func recommendation(emotionalState: EmotionalState, intensity: Int, context: MoodContext, trigger: MoodTrigger?) -> String {
        // 1–2 lignes, sans analyse complexe.
        if context == .afterLoss || trigger == .revenge || trigger == .previousLoss {
            return "Ralentis. Fais une pause et reviens au plan avant de reprendre."
        }
        if emotionalState == .stressed || emotionalState == .fearful {
            return "Respire 30s et réduis l’exposition. Priorité à la discipline."
        }
        if emotionalState == .confident && intensity >= 7 {
            return "OK si plan clair. Vérifie taille/stop et exécute proprement."
        }
        return "Note rapide OK. Reste simple : plan → taille → stop."
    }

    func suggestedQuickAction(emotionalState: EmotionalState, intensity: Int, context: MoodContext, trigger: MoodTrigger?) -> MoodQuickAction? {
        if context == .afterLoss || trigger == .revenge || trigger == .previousLoss { return .pause2min }
        if emotionalState == .stressed || emotionalState == .fearful || intensity >= 8 { return .breathing30s }
        return .mentalChecklist
    }

    func suggestedMiniChecklist(emotionalState: EmotionalState, intensity: Int, context: MoodContext, trigger: MoodTrigger?) -> MiniPreTradeChecklist? {
        guard context == .beforeTrade else { return nil }
        // Suggestions auto: si émotion "à risque", pousser stop/plan.
        if trigger == .revenge || trigger == .previousLoss || trigger == .loss {
            return MiniPreTradeChecklist(planOK: true, sizeOK: false, stopDefined: true)
        }
        if emotionalState == .stressed || emotionalState == .fearful || emotionalState == .impatient {
            return MiniPreTradeChecklist(planOK: true, sizeOK: false, stopDefined: true)
        }
        return MiniPreTradeChecklist(planOK: true, sizeOK: true, stopDefined: true)
    }
}


