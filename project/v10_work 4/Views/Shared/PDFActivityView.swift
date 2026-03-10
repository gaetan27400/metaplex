//
//  PDFActivityView.swift
//  Journal de trading 2025
//
import SwiftUI
import UIKit

struct PDFActivityView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Écrire en fichier tmp pour que l'aperçu PDF fonctionne dans le share sheet
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .assignToContact, .openInIBooks]
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
