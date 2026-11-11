import Foundation

/// Deterministic Arabic-script pronunciation aid for adhkar whose reviewed
/// transliteration is not bundled. The interface labels generated output as an
/// approximation; reviewed transliterations in adhkar.json always take priority.
enum ArabicTransliterator {
    static func transliterate(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: "ﷲ", with: "الله")
            .replacingOccurrences(of: "ﷺ", with: " sallallāhu ʿalayhi wa-sallam ")

        let scalars = Array(normalized.unicodeScalars)
        let fatha: UnicodeScalar = "َ"
        let damma: UnicodeScalar = "ُ"
        let kasra: UnicodeScalar = "ِ"
        let sukun: UnicodeScalar = "ْ"
        let shadda: UnicodeScalar = "ّ"
        let tanwinFath: UnicodeScalar = "ً"
        let tanwinDamm: UnicodeScalar = "ٌ"
        let tanwinKass: UnicodeScalar = "ٍ"
        let daggerAlif: UnicodeScalar = "ٰ"
        let marks: Set<UInt32> = [0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0670, 0x0653, 0x0654, 0x0655]
        let consonants: [UInt32: String] = [
            0x0621:"ʾ", 0x0622:"ā", 0x0623:"ʾa", 0x0624:"ʾ", 0x0625:"ʾi", 0x0626:"ʾ", 0x0627:"ā",
            0x0628:"b", 0x0629:"h", 0x062A:"t", 0x062B:"th", 0x062C:"j", 0x062D:"ḥ", 0x062E:"kh",
            0x062F:"d", 0x0630:"dh", 0x0631:"r", 0x0632:"z", 0x0633:"s", 0x0634:"sh", 0x0635:"ṣ",
            0x0636:"ḍ", 0x0637:"ṭ", 0x0638:"ẓ", 0x0639:"ʿ", 0x063A:"gh", 0x0641:"f", 0x0642:"q",
            0x0643:"k", 0x0644:"l", 0x0645:"m", 0x0646:"n", 0x0647:"h", 0x0648:"w", 0x0649:"ā", 0x064A:"y"
        ]

        var output = ""
        var index = 0
        var previousLetter: UInt32?
        while index < scalars.count {
            let scalar = scalars[index]
            let value = scalar.value

            if value == 0x0020 || value == 0x000A || value == 0x0009 || [0x060C,0x002C,0x002E,0x061B,0x003B,0x003A,0x061F,0x0021,0x0028,0x0029].contains(value) {
                output.unicodeScalars.append(scalar)
                previousLetter = nil
                index += 1
                continue
            }
            // Recognize the divine name (alif + lam + lam + ha) as a word stem.
            // Skip the shadda/fatha attached to the second lam and the written ha;
            // its following vowel is processed normally (e.g. Allāhumma).
            if value == 0x0627, index + 2 < scalars.count,
               scalars[index + 1].value == 0x0644, scalars[index + 2].value == 0x0644 {
                var haIndex = index + 3
                while haIndex < scalars.count, marks.contains(scalars[haIndex].value) { haIndex += 1 }
                if haIndex < scalars.count, scalars[haIndex].value == 0x0647 {
                    output += "Allāh"
                    previousLetter = nil
                    index = haIndex + 1
                    continue
                }
            }

            if marks.contains(value) {
                switch value {
                case fatha.value: output += "a"
                case damma.value: output += "u"
                case kasra.value: output += "i"
                case tanwinFath.value: output += "an"
                case tanwinDamm.value: output += "un"
                case tanwinKass.value: output += "in"
                case daggerAlif.value: output += "ā"
                case shadda.value:
                    // Duplicate the preceding romanized consonant for shadda.
                    if let previousLetter, let token = consonants[previousLetter] { output += token }
                case sukun.value: break
                default: break
                }
                index += 1
                continue
            }

            if let token = consonants[value] {
                var rendered = token
                if value == 0x0648, index + 1 < scalars.count, scalars[index + 1] == damma {
                    rendered = "ū"
                    index += 1
                } else if value == 0x064A, index > 0, scalars[index - 1] == kasra {
                    rendered = "ī"
                } else if value == 0x0648, index > 0, scalars[index - 1] == damma {
                    rendered = "ū"
                }
                if value == 0x0629 { rendered = "ah" }
                output += rendered
                previousLetter = value
            } else if !CharacterSet.nonBaseCharacters.contains(scalar) {
                output.unicodeScalars.append(scalar)
                previousLetter = nil
            }
            index += 1
        }
        return output.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
