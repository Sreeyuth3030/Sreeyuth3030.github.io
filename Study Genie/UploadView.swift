//
//  UploadView.swift
//  Study Appp
//
//  Created by Sreeyuth Jakka on 11/23/25.
//


//
//  UploadView.swift
//  Study Genie
//

internal import SwiftUI
import PDFKit
import UniformTypeIdentifiers
@preconcurrency import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct UploadView: View {
    @EnvironmentObject var store: FlashcardStore

    @State private var showFileImporter = false

    @State private var extractedText: String = ""
    @State private var manualText: String = ""

    @State private var statusMessage: String = ""
    @State private var isGenerating = false

    // OCR progress + settings
    @State private var isOCRRunning = false
    @State private var ocrProgressText: String = ""
    @State private var maxPagesToOCR: Int = 6   // 1...20

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.88, green: 0.93, blue: 1.0)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        buttonRow

                        if isOCRRunning {
                            ocrProgressView
                        }

                        filePreviewSection
                        manualPasteSection
                        statusSection

                        Spacer(minLength: 16)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Upload")
            .preferredColorScheme(.light)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
        }
    }

    // MARK: - UI

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)

            HStack(spacing: 14) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Study Genie")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    Text("Upload PDFs (typed OR scanned) or paste notes. Then generate flashcards + quizzes.")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.65))
                }
            }
            .padding(18)
        }
        .padding(.horizontal)
    }

    private var buttonRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Upload", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                }

                Button {
                    generateFlashcards()
                } label: {
                    if isGenerating {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Label("Generate", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                    }
                }
                .background(Color.blue)
                .cornerRadius(14)
                .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                .opacity(sourceText.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal)

            HStack {
                Text("OCR pages:")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.65))

                Stepper("", value: $maxPagesToOCR, in: 1...20)
                    .labelsHidden()

                Text("\(maxPagesToOCR)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var ocrProgressView: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(ocrProgressText.isEmpty ? "Running OCR…" : ocrProgressText)
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal)
    }

    private var filePreviewSection: some View {
        Group {
            if !extractedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("File Preview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)

                    Text("Text extracted from your file.")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.65))

                    ScrollView {
                        Text(extractedText)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .padding()
                    }
                    .frame(maxHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.96))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.horizontal)
            } else {
                Text("Upload a PDF or .txt. If it’s scanned, OCR will try to read it (increase OCR pages if needed).")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }
        }
    }

    private var manualPasteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste Notes (works even if OCR fails)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)

            Text("Formats supported: `Question?` + next line, or `Term: definition`, or `Term - definition`.")
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.65))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                if manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Example:\nWhat is photosynthesis?\nProcess plants use to convert light to energy.\n\nMitochondria: Powerhouse of the cell.\nOsmosis - Water moves from low solute → high solute.")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.35))
                        .padding(14)
                }

                TextEditor(text: $manualText)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .frame(height: 170)
        }
        .padding(.horizontal)
    }

    private var statusSection: some View {
        Group {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.75))
                    .padding(.horizontal)
            }
        }
    }

    private var sourceText: String {
        (extractedText + "\n" + manualText).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Import

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                statusMessage = "No file selected."
                return
            }

            extractedText = ""
            statusMessage = "Reading file…"

            Task {
                do {
                    let text = try await extractTextFromImportedFile(url: url)
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

                    await MainActor.run {
                        if cleaned.isEmpty {
                            statusMessage = """
                            Still couldn’t read text from that file.

                            Try:
                            • Increase OCR pages
                            • Use a clearer PDF (less blurry, higher contrast)
                            • Or paste notes below (always works)
                            """
                            extractedText = ""
                        } else {
                            extractedText = cleaned
                            statusMessage = "✅ Extracted text. Tap Generate."
                        }
                    }
                } catch {
                    await MainActor.run {
                        statusMessage = "Failed to read: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Extraction

    private func extractTextFromImportedFile(url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        if ext == "txt" {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }

        if ext == "pdf" {
            // 1) selectable text
            let fast = extractPDFSelectableText(url: url)
            if !fast.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return fast
            }

            // 2) OCR fallback
            await MainActor.run {
                isOCRRunning = true
                ocrProgressText = "Preparing OCR…"
            }

            let ocr = try await ocrPDF(url: url, maxPages: maxPagesToOCR)

            await MainActor.run {
                isOCRRunning = false
                ocrProgressText = ""
            }
            return ocr
        }

        return ""
    }

    private func extractPDFSelectableText(url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var out = ""
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let str = page.string else { continue }
            out += str + "\n"
        }
        return out
    }

    // MARK: - OCR

    private func ocrPDF(url: URL, maxPages: Int) async throws -> String {
        guard let doc = PDFDocument(url: url) else { return "" }

        let count = min(doc.pageCount, maxPages)
        var finalText = ""

        for pageIndex in 0..<count {
            await MainActor.run {
                ocrProgressText = "OCR page \(pageIndex + 1) of \(count)…"
            }

            guard let page = doc.page(at: pageIndex) else { continue }
            let image = renderPageAsImage(page: page, scale: 3.0)
            let processed = preprocessForOCR(image: image)

            let pageText = try await recognizeText(image: processed)
            finalText += pageText + "\n\n"
        }

        return finalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renderPageAsImage(page: PDFPage, scale: CGFloat) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)

            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private func preprocessForOCR(image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }

        let ci = CIImage(cgImage: cg)
        let context = CIContext()

        let mono = CIFilter.colorControls()
        mono.inputImage = ci
        mono.saturation = 0
        mono.contrast = 1.25
        mono.brightness = 0.03

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = mono.outputImage
        sharpen.sharpness = 0.6

        guard let output = sharpen.outputImage,
              let outCG = context.createCGImage(output, from: output.extent) else {
            return image
        }
        return UIImage(cgImage: outCG)
    }

    private func recognizeText(image: UIImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, err in
                if let err = err {
                    continuation.resume(throwing: err)
                    return
                }

                let obs = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = obs.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.004

            guard let cg = image.cgImage else {
                continuation.resume(returning: "")
                return
            }

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    // MARK: - Generate

    private func generateFlashcards() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "Nothing to generate. Upload or paste notes."
            return
        }

        isGenerating = true
        statusMessage = "Creating flashcards…"

        DispatchQueue.global(qos: .userInitiated).async {
            let cards = parseFlashcards(from: text)

            DispatchQueue.main.async {
                if cards.isEmpty {
                    self.statusMessage = "I couldn’t detect flashcards. Try `Term: definition` or `Question?` then answer."
                } else {
                    self.store.flashcards.append(contentsOf: cards)
                    self.statusMessage = "✨ Generated \(cards.count) flashcard(s)!"
                }
                self.isGenerating = false
            }
        }
    }

    private func parseFlashcards(from text: String) -> [Flashcard] {
        let cleaned = normalizeOCR(text)

        let rawLines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\t", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }

        var lines = rawLines
            .filter { !$0.isEmpty }
            .filter { !looksLikeJunk($0) }
            .filter { !looksLikeSectionHeader($0) }

        var cards: [Flashcard] = []

        // 1) Definitions: Term: definition / Term - definition
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if let split = splitDefinitionLine(line) {
                let term = cleanupTerm(split.term)
                var defParts: [String] = [cleanupAnswer(split.definition)]

                var j = i + 1
                while j < lines.count && defParts.count < 4 {
                    let next = lines[j]
                    if looksLikeSectionHeader(next) { break }
                    if looksLikeJunk(next) { break }
                    if splitDefinitionLine(next) != nil { break }
                    if next.hasSuffix("?") { break }
                    if isProbablyNewTerm(next) { break }
                    defParts.append(cleanupAnswer(next))
                    j += 1
                }

                let definition = defParts.joined(separator: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if isValidTerm(term) && isValidDefinition(definition) {
                    cards.append(Flashcard(question: "Define: \(term)", answer: definition))
                }

                i = j
                continue
            }
            i += 1
        }

        // 2) Q/A cards: Question? then answer lines
        i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasSuffix("?") && line.count >= 6 {
                let q = cleanupQuestion(line)
                var answerParts: [String] = []
                var j = i + 1

                while j < lines.count && answerParts.count < 5 {
                    let next = lines[j]
                    if next.hasSuffix("?") { break }
                    if splitDefinitionLine(next) != nil { break }
                    if looksLikeSectionHeader(next) { break }
                    if isProbablyNewTerm(next) { break }
                    answerParts.append(cleanupAnswer(next))
                    j += 1
                }

                let a = answerParts.joined(separator: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !q.isEmpty && a.count >= 5 {
                    cards.append(Flashcard(question: q, answer: a))
                }

                i = j
                continue
            }
            i += 1
        }

        // 3) Fact cards from paragraphs
        let paragraphChunks = buildParagraphChunks(from: rawLines).filter { $0.count >= 80 }
        for chunk in paragraphChunks.prefix(20) {
            for s in splitIntoSentences(chunk) {
                if let fact = makeFactCard(from: s) {
                    cards.append(fact)
                }
            }
        }

        // 4) Explain/Summarize cards
        if cards.count < 60 {
            for chunk in paragraphChunks.prefix(12) {
                let compact = chunk
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard compact.count >= 140 else { continue }

                let topic = guessTopic(from: compact)
                if isValidTerm(topic) {
                    cards.append(Flashcard(question: "Explain: \(topic)", answer: compact))
                } else {
                    cards.append(Flashcard(question: "Summarize this section", answer: compact))
                }
            }
        }

        return Array(dedupeCards(cards).prefix(120))
    }

    // MARK: - Helpers

    private func normalizeOCR(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "‐", with: "-")
        t = t.replacingOccurrences(of: "–", with: " - ")
        t = t.replacingOccurrences(of: "—", with: " - ")
        t = t.replacingOccurrences(of: "\r", with: "\n")
        t = t.replacingOccurrences(of: "-\n", with: "")
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t
    }

    private func cleanupQuestion(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\d+[\).\s]+"#, with: "", options: .regularExpression)
    }

    private func cleanupTerm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\d+[\).\s]+"#, with: "", options: .regularExpression)
    }

    private func cleanupAnswer(_ s: String) -> String {
        var a = s.trimmingCharacters(in: .whitespacesAndNewlines)
        a = a.replacingOccurrences(of: #"^\d+[\).\s]+"#, with: "", options: .regularExpression)
        a = a.replacingOccurrences(of: "\n", with: " ")
        while a.contains("  ") { a = a.replacingOccurrences(of: "  ", with: " ") }
        return a
    }

    private func looksLikeSectionHeader(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix(":") { return true }
        let letters = t.filter { $0.isLetter }
        if letters.count >= 6 && letters.allSatisfy({ $0.isUppercase }) { return true }
        return false
    }

    private func looksLikeJunk(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.count <= 1 { return true }
        if t == "name" || t == "date" { return true }
        if t.range(of: #"^page\s*\d+"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil { return true }
        if t.contains("copyright") { return true }
        return false
    }

    private func splitDefinitionLine(_ line: String) -> (term: String, definition: String)? {
        let s = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if let idx = s.firstIndex(of: ":") {
            let term = String(s[..<idx]).trimmingCharacters(in: .whitespaces)
            let def = String(s[s.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            if !term.isEmpty && !def.isEmpty { return (term, def) }
        }

        for d in [" - ", " – ", " — "] {
            if let range = s.range(of: d) {
                let term = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let def  = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !term.isEmpty && !def.isEmpty { return (term, def) }
            }
        }

        return nil
    }

    private func isProbablyNewTerm(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if splitDefinitionLine(t) != nil { return true }

        let words = t.split(separator: " ")
        if words.count <= 5 && t.count <= 30 {
            let letterCount = t.filter { $0.isLetter }.count
            let capsCount = t.filter { $0.isUppercase }.count
            if letterCount >= 4 && capsCount >= 2 { return true }
        }
        return false
    }

    private func isValidTerm(_ term: String) -> Bool {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count < 2 { return false }
        if t.count > 60 { return false }
        if t.lowercased().contains("http") { return false }
        if t.filter({ $0.isLetter }).count < 2 { return false }
        return true
    }

    private func isValidDefinition(_ def: String) -> Bool {
        let d = def.trimmingCharacters(in: .whitespacesAndNewlines)
        if d.count < 8 { return false }
        if d.filter({ $0.isLetter }).count < 6 { return false }
        return true
    }

    private func dedupeCards(_ cards: [Flashcard]) -> [Flashcard] {
        var seen = Set<String>()
        var out: [Flashcard] = []

        for c in cards {
            let key = (c.question + "|" + c.answer)
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
            if !seen.contains(key) {
                seen.insert(key)
                out.append(c)
            }
        }
        return out
    }

    private func buildParagraphChunks(from lines: [String]) -> [String] {
        var chunks: [String] = []
        var current: [String] = []

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                if !current.isEmpty {
                    let chunk = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chunk.isEmpty { chunks.append(chunk) }
                    current.removeAll()
                }
                continue
            }
            current.append(line)
        }

        if !current.isEmpty {
            let chunk = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { chunks.append(chunk) }
        }

        return chunks
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        let parts = compact.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 25 }
    }

    private func makeFactCard(from sentence: String) -> Flashcard? {
        let s = sentence.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count >= 25 else { return nil }
        guard s.filter({ $0.isLetter }).count >= 12 else { return nil }

        let patterns: [(key: String, kind: String)] = [
            (" refers to ", "mean"),
            (" means ", "mean"),
            (" is ", "is"),
            (" are ", "is"),
            (" causes ", "cause"),
            (" leads to ", "lead"),
            (" results in ", "result")
        ]

        for p in patterns {
            if let range = s.range(of: p.key, options: .caseInsensitive) {
                let left = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

                let term = cleanupTerm(left)
                let answer = cleanupAnswer(right)

                guard isValidTerm(term), isValidDefinition(answer) else { continue }

                switch p.kind {
                case "is":
                    return Flashcard(question: "What is \(term)?", answer: answer)
                case "mean":
                    return Flashcard(question: "What does \(term) mean?", answer: answer)
                case "cause":
                    return Flashcard(question: "What does \(term) cause?", answer: answer)
                case "lead":
                    return Flashcard(question: "What does \(term) lead to?", answer: answer)
                case "result":
                    return Flashcard(question: "What results from \(term)?", answer: answer)
                default:
                    return Flashcard(question: "Explain \(term)", answer: answer)
                }
            }
        }

        return nil
    }

    private func guessTopic(from paragraph: String) -> String {
        let words = paragraph
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .prefix(6)
            .map(String.init)
            .joined(separator: " ")
        return cleanupTerm(words)
    }
}

#Preview {
    UploadView()
        .environmentObject(FlashcardStore())
}
