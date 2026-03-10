//
//  ForexFactoryParser.swift
//  Journal de trading 2025
//
//  Parser robuste pour extraire les événements économiques depuis le HTML de ForexFactory
//  Utilise SwiftSoup pour un parsing HTML fiable basé sur la structure réelle du site
//

import Foundation
import SwiftSoup

final class ForexFactoryParser {
    static let shared = ForexFactoryParser()
    
    private let calendar = Calendar.current
    
    private init() {}
    
    /// Parse le HTML de ForexFactory et extrait les événements
    /// - Parameters:
    ///   - htmlContent: Le contenu HTML brut de la page ForexFactory
    ///   - referenceDate: Date de référence pour compléter les dates partielles (par défaut: aujourd'hui)
    /// - Returns: Tableau d'événements économiques parsés
    /// - Throws: Erreur de parsing si le HTML est invalide
    func parseEvents(from htmlContent: String, referenceDate: Date = Date()) throws -> [ForexFactoryEvent] {
        let doc = try SwiftSoup.parse(htmlContent)
        
        // Sélectionner toutes les lignes du tableau du calendrier
        // ForexFactory utilise des <tr> avec la classe "calendar__row" pour les événements
        // et "calendar__row--day" ou similaire pour les séparateurs de jour
        let rows = try doc.select("tr.calendar__row, tr[class*='calendar__row']")
        
        var events: [ForexFactoryEvent] = []
        var currentDate: Date? = nil // État : date courante héritée des lignes précédentes
        
        for row in rows {
            // Vérifier si c'est une ligne de séparateur de jour (met à jour currentDate)
            if let dayDate = try? parseDaySeparator(from: row, referenceDate: referenceDate) {
                currentDate = dayDate
                continue // Ignorer cette ligne, elle ne contient pas d'événement
            }
            
            // Parser l'événement avec la date courante
            if let event = try parseEventRow(from: row, currentDate: currentDate, referenceDate: referenceDate) {
                events.append(event)
                // Si l'événement a sa propre date, mettre à jour currentDate pour les suivants
                if event.date != currentDate {
                    currentDate = event.date
                }
            }
        }
        
        // Dédupliquer par nom + date + devise
        var seenEvents: Set<String> = []
        return events.filter { event in
            let key = "\(event.date.timeIntervalSince1970)-\(event.name)-\(event.currency)"
            if seenEvents.contains(key) {
                return false
            }
            seenEvents.insert(key)
            return true
        }
    }
    
    /// Parse une ligne de séparateur de jour (ex: "Monday, January 25")
    /// Ces lignes mettent à jour la date courante pour les événements suivants
    /// - Parameters:
    ///   - row: L'élément <tr> à analyser
    ///   - referenceDate: Date de référence pour compléter les dates partielles
    /// - Returns: La date extraite, ou nil si ce n'est pas un séparateur de jour
    private func parseDaySeparator(from row: Element, referenceDate: Date) throws -> Date? {
        // Les séparateurs de jour ont généralement une classe spécifique ou un colspan
        // Structure typique : <tr class="calendar__row--day"> ou <tr><td colspan="8">Monday, January 25</td></tr>
        
        // Vérifier si la ligne a un colspan (indicateur de ligne de séparateur)
        let cells = try row.select("td")
        if cells.count == 1 {
            let cell = cells.first!
            let colspan = try? cell.attr("colspan")
            if let colspan = colspan, !colspan.isEmpty {
                let text = try cell.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if let date = parseDate(from: text, referenceDate: referenceDate) {
                    return date
                }
            }
        }
        
        // Vérifier les classes CSS spécifiques aux séparateurs de jour
        let classAttr = try row.className()
        if classAttr.contains("day") || classAttr.contains("separator") {
            let text = try row.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = parseDate(from: text, referenceDate: referenceDate) {
                return date
            }
        }
        
        return nil
    }
    
    /// Parse une ligne d'événement économique
    /// - Parameters:
    ///   - row: L'élément <tr> contenant l'événement
    ///   - currentDate: Date courante héritée des lignes précédentes (peut être nil)
    ///   - referenceDate: Date de référence pour compléter les dates partielles
    /// - Returns: L'événement parsé, ou nil si la ligne n'est pas un événement valide
    private func parseEventRow(from row: Element, currentDate: Date?, referenceDate: Date) throws -> ForexFactoryEvent? {
        let cells = try row.select("td")
        
        // Un événement valide doit avoir au moins quelques cellules
        guard cells.count >= 4 else { return nil }
        
        // Identifier les colonnes par leurs classes CSS réelles
        var timeCell: Element?
        var currencyCell: Element?
        var eventCell: Element?
        var impactCell: Element?
        var previousCell: Element?
        var forecastCell: Element?
        var actualCell: Element?
        var dateCell: Element?
        
        for cell in cells {
            let classes = try cell.className()
            
            if classes.contains("calendar__time") {
                timeCell = cell
            } else if classes.contains("calendar__currency") {
                currencyCell = cell
            } else if classes.contains("calendar__event") {
                eventCell = cell
            } else if classes.contains("calendar__impact") {
                impactCell = cell
            } else if classes.contains("calendar__previous") {
                previousCell = cell
            } else if classes.contains("calendar__forecast") {
                forecastCell = cell
            } else if classes.contains("calendar__actual") {
                actualCell = cell
            } else if classes.contains("calendar__date") {
                dateCell = cell
            }
        }
        
        // Si aucune cellule n'a été identifiée par classe, essayer par position
        // (fallback pour compatibilité avec des structures HTML légèrement différentes)
        if timeCell == nil && cells.count > 1 {
            timeCell = cells[1] // Généralement la deuxième colonne
        }
        if currencyCell == nil && cells.count > 2 {
            currencyCell = cells[2] // Généralement la troisième colonne
        }
        eventCell = cells.max(by: {
            let lhsCount = (try? $0.text())?.count ?? 0
            let rhsCount = (try? $1.text())?.count ?? 0
            return lhsCount < rhsCount
        }) ?? cells[3]

        
        // Extraire les valeurs
        let timeStr = try timeCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyStr = try currencyCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let eventName = try eventCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let previousStr = try previousCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let forecastStr = try forecastCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let actualStr = try actualCell?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validation minimale
        guard let currency = currencyStr,
              !currency.isEmpty,
              let name = eventName,
              !name.isEmpty else {
            return nil
        }
        
        // Parser la date
        let eventDate: Date
        if let dateCell = dateCell {
            let dateText = try dateCell.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsedDate = parseDate(from: dateText, referenceDate: referenceDate) {
                eventDate = parsedDate
            } else if let current = currentDate {
                eventDate = current
            } else {
                // Pas de date disponible, utiliser la date de référence
                eventDate = referenceDate
            }
        } else if let current = currentDate {
            eventDate = current
        } else {
            // Pas de date disponible, utiliser la date de référence
            eventDate = referenceDate
        }
        
        // Parser l'heure
        let time: String?
        if let timeText = timeStr, !timeText.isEmpty {
            time = parseTime(from: timeText)
        } else {
            time = nil
        }
        
        // Détecter l'impact via les classes CSS (bulles de couleur)
        let impact = parseImpact(from: impactCell ?? row)
        
        // Détecter le type d'événement
        let isAllDay = detectAllDay(timeText: timeStr, row: row)
        let isTentative = detectTentative(timeText: timeStr, row: row)
        let isSpeech = detectSpeech(eventName: name, row: row)
        
        // Nettoyer les valeurs numériques
        // IMPORTANT: Tolérance maximale - ne pas dropper un événement valide si ces champs sont vides
        // Seul le couple {date + name + currency} est obligatoire
        let previous = cleanNumericValue(previousStr)
        let forecast = cleanNumericValue(forecastStr)
        let actual = cleanNumericValue(actualStr)
        
        return ForexFactoryEvent(
            date: eventDate,
            time: time,
            currency: currency.uppercased(),
            name: name,
            impact: impact,
            previous: previous,
            forecast: forecast,
            actual: actual,
            isAllDay: isAllDay,
            isTentative: isTentative,
            isSpeech: isSpeech
        )
    }
    
    /// Détecte l'impact depuis les classes CSS de la cellule d'impact ou de la ligne
    /// ForexFactory utilise des bulles de couleur avec des classes comme "high", "medium", "low"
    /// - Parameter element: L'élément à analyser (cellule d'impact ou ligne complète)
    /// - Returns: L'impact détecté (.high, .medium, ou .low)
    private func parseImpact(from element: Element) -> EventImpact {
        do {
            // Chercher dans les classes CSS de l'élément et de ses enfants
            let classes = try element.className()
            let allClasses = classes.lowercased()
            
            // Vérifier les classes d'impact directes
            if allClasses.contains("high") || allClasses.contains("red") {
                return .high
            } else if allClasses.contains("medium") || allClasses.contains("orange") || allClasses.contains("yellow") {
                return .medium
            } else if allClasses.contains("low") || allClasses.contains("green") {
                return .low
            }
            
            // Chercher dans les enfants (bulles de couleur)
            let impactElements = try element.select("[class*='high'], [class*='medium'], [class*='low'], [class*='red'], [class*='orange'], [class*='yellow'], [class*='green']")
            for impactEl in impactElements {
                let childClasses = try impactEl.className().lowercased()
                if childClasses.contains("high") || childClasses.contains("red") {
                    return .high
                } else if childClasses.contains("medium") || childClasses.contains("orange") || childClasses.contains("yellow") {
                    return .medium
                } else if childClasses.contains("low") || childClasses.contains("green") {
                    return .low
                }
            }
            
            // Chercher les attributs de style (couleur de fond)
            if let style = try? element.attr("style") {
                let styleLower = style.lowercased()
                if styleLower.contains("red") || styleLower.contains("#f") {
                    return .high
                } else if styleLower.contains("orange") || styleLower.contains("yellow") {
                    return .medium
                } else if styleLower.contains("green") {
                    return .low
                }
            }
        } catch {
            // En cas d'erreur, retourner .low par défaut
        }
        
        return .low // Par défaut
    }
    
    /// Détecte si l'événement est "All Day"
    /// - Parameters:
    ///   - timeText: Le texte de la cellule heure
    ///   - row: La ligne complète pour vérifier les classes CSS
    /// - Returns: true si l'événement est "All Day"
    private func detectAllDay(timeText: String?, row: Element) -> Bool {
        // Vérifier le texte de l'heure
        if let time = timeText?.lowercased() {
            if time.contains("all day") || time.contains("all-day") || time.isEmpty {
                return true
            }
        }
        
        // Vérifier les classes CSS
        do {
            let classes = try row.className().lowercased()
            if classes.contains("all-day") || classes.contains("allday") {
                return true
            }
        } catch {}
        
        return false
    }
    
    /// Détecte si l'événement est "Tentative"
    /// - Parameters:
    ///   - timeText: Le texte de la cellule heure
    ///   - row: La ligne complète pour vérifier les classes CSS
    /// - Returns: true si l'événement est "Tentative"
    private func detectTentative(timeText: String?, row: Element) -> Bool {
        // Vérifier le texte de l'heure
        if let time = timeText?.lowercased() {
            if time.contains("tentative") || time.contains("tbd") || time.contains("tba") {
                return true
            }
        }
        
        // Vérifier les classes CSS
        do {
            let classes = try row.className().lowercased()
            if classes.contains("tentative") {
                return true
            }
            
            // Chercher dans les cellules
            let cells = try row.select("td")
            for cell in cells {
                let cellText = try cell.text().lowercased()
                if cellText.contains("tentative") || cellText.contains("tbd") || cellText.contains("tba") {
                    return true
                }
            }
        } catch {}
        
        return false
    }
    
    /// Détecte si l'événement est un "Speech" (discours)
    /// - Parameters:
    ///   - eventName: Le nom de l'événement
    ///   - row: La ligne complète pour vérifier les classes CSS
    /// - Returns: true si l'événement est un discours
    private func detectSpeech(eventName: String, row: Element) -> Bool {
        let nameLower = eventName.lowercased()
        
        // Mots-clés typiques des discours
        if nameLower.contains("speech") ||
           nameLower.contains("speaks") ||
           nameLower.contains("testimony") ||
           nameLower.contains("testifies") ||
           nameLower.contains("testimony") ||
           nameLower.contains("hearing") {
            return true
        }
        
        // Vérifier les classes CSS
        do {
            let classes = try row.className().lowercased()
            if classes.contains("speech") {
                return true
            }
        } catch {}
        
        return false
    }
    
    /// Nettoie une valeur numérique (supprime les espaces, formate, etc.)
    /// - Parameter value: La valeur brute à nettoyer
    /// - Returns: La valeur nettoyée, ou nil si ce n'est pas une valeur valide
    /// 
    /// Tolérance maximale : accepte les valeurs vides, "—", "N/A", etc.
    /// Ne doit JAMAIS causer le rejet d'un événement valide.
    private func cleanNumericValue(_ value: String?) -> String? {
        guard let value = value else { return nil }
        
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ignorer les valeurs vides, "N/A", "—", etc.
        // Ces valeurs sont normales pour certains événements (speeches, all-day, etc.)
        if cleaned.isEmpty ||
           cleaned.lowercased() == "n/a" ||
           cleaned.lowercased() == "na" ||
           cleaned == "—" ||
           cleaned == "-" ||
           cleaned.lowercased() == "tbd" ||
           cleaned.lowercased() == "tba" {
            return nil
        }
        
        return cleaned
    }
    
    /// Parse une date depuis un texte
    /// - Parameters:
    ///   - text: Le texte contenant la date
    ///   - referenceDate: Date de référence pour compléter les dates partielles
    /// - Returns: La date parsée, ou nil si le parsing échoue
    private func parseDate(from text: String, referenceDate: Date) -> Date? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        // Formats possibles de ForexFactory
        let formats = [
            "EEEE, MMMM d, yyyy",  // "Monday, January 25, 2026"
            "EEEE, MMMM d",        // "Monday, January 25"
            "EEEE, d MMMM",        // "Monday, 25 January"
            "MMMM d, yyyy",       // "January 25, 2026"
            "MMM d, yyyy",         // "Jan 25, 2026"
            "d MMMM yyyy",         // "25 January 2026"
            "d MMM yyyy",          // "25 Jan 2026"
            "yyyy-MM-dd",          // "2026-01-25"
            "MM/dd/yyyy",          // "01/25/2026"
            "dd/MM/yyyy",          // "25/01/2026"
            "EEE dd",              // "Mon 25"
            "EEE, dd MMM"          // "Mon, 25 Jan"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: cleaned) {
                // Si la date n'a pas d'année, utiliser l'année de référence
                if !format.contains("yyyy") {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    let refComponents = calendar.dateComponents([.year], from: referenceDate)
                    components.year = refComponents.year
                    if let adjustedDate = calendar.date(from: components) {
                        return adjustedDate
                    }
                }
                return date
            }
        }
        
        return nil
    }
    
    /// Parse une heure depuis un texte
    /// - Parameter text: Le texte contenant l'heure
    /// - Returns: L'heure au format HH:MM, ou nil si le parsing échoue ou si c'est "All Day"/"Tentative"
    private func parseTime(from text: String?) -> String? {
        guard let text = text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Ignorer "All Day", "Tentative", etc.
        if cleaned.contains("all day") ||
           cleaned.contains("all-day") ||
           cleaned.contains("tentative") ||
           cleaned.contains("tbd") ||
           cleaned.contains("tba") ||
           cleaned.isEmpty {
            return nil
        }
        
        // Extraire l'heure (format HH:MM ou H:MM)
        // Pattern pour trouver une heure au format 24h ou 12h
        let timePattern = #"(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?"#
        
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text),
           let hour = Int(String(text[hourRange])),
           let minute = Int(String(text[minuteRange])) {
            
            var finalHour = hour
            
            // Gérer le format 12h (AM/PM)
            if match.numberOfRanges > 3 {
                let ampmRange = match.range(at: 3)
                if ampmRange.location != NSNotFound,
                   let ampmStr = Range(ampmRange, in: text) {
                    let ampm = String(text[ampmStr]).uppercased()
                    if ampm == "PM" && hour != 12 {
                        finalHour = hour + 12
                    } else if ampm == "AM" && hour == 12 {
                        finalHour = 0
                    }
                }
            }
            
            // Normaliser en HH:MM
            return String(format: "%02d:%02d", finalHour, minute)
        }
        
        return nil
    }
}

// MARK: - ForexFactory Event Model

struct ForexFactoryEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let time: String?  // Format HH:MM en UTC
    let currency: String
    let name: String
    let impact: EventImpact
    let previous: String?
    let forecast: String?
    let actual: String?
    let isAllDay: Bool
    let isTentative: Bool
    let isSpeech: Bool
    
    init(
        date: Date,
        time: String?,
        currency: String,
        name: String,
        impact: EventImpact,
        previous: String?,
        forecast: String?,
        actual: String?,
        isAllDay: Bool = false,
        isTentative: Bool = false,
        isSpeech: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.time = time
        self.currency = currency
        self.name = name
        self.impact = impact
        self.previous = previous
        self.forecast = forecast
        self.actual = actual
        self.isAllDay = isAllDay
        self.isTentative = isTentative
        self.isSpeech = isSpeech
    }
}
