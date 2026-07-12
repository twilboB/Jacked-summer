import Foundation
import UIKit
import FoundationModels

/// Structured nutrition estimate. Guided generation gives reliable output and
/// removes the fragile JSON parsing the prototype suffered from.
@Generable
struct NutritionEstimate {
    @Guide(description: "Short food name, five words max")
    var name: String
    @Guide(description: "Total calories in kcal, whole number")
    var calories: Int
    @Guide(description: "Protein in grams, whole number")
    var protein: Int
    @Guide(description: "Carbohydrate in grams, whole number")
    var carbs: Int
    @Guide(description: "Fat in grams, whole number")
    var fat: Int
    @Guide(description: "One of: low, med, high")
    var confidence: String
    @Guide(description: "One short note on the main assumption or biggest calorie driver, twelve words max")
    var note: String
}

/// The four input paths all produce the same `NutritionEstimate` on device.
///
/// VERIFY against the iOS 27 SDK: `LanguageModelSession(tools:instructions:)`,
/// the `Prompt { ... }` image-attachment syntax, `GenerationOptions.ToolCallingMode`,
/// `BarcodeReaderTool`, `OCRTool`, and `PrivateCloudComputeLanguageModel`.
enum NutritionEstimator {

    static let instructions = """
    You estimate the nutrition of a meal. Identify each food and drink item, \
    estimate each portion using realistic home and restaurant sizes, estimate \
    calories and macros per item, then sum. If genuinely unsure, lean slightly \
    high on calories rather than low. Keep the name short. Respect any explicit \
    quantity given.
    """

    // MARK: Text
    static func estimate(text: String) async throws -> NutritionEstimate {
        let session = LanguageModelSession(instructions: instructions)
        let result = try await session.respond(
            to: "Food eaten: \(text). Estimate its nutrition.",
            generating: NutritionEstimate.self
        )
        return result.content
    }

    // MARK: Photo (image passed straight into the prompt — no Vision preprocessing)
    static func estimate(photo: UIImage) async throws -> NutritionEstimate {
        let session = LanguageModelSession(instructions: instructions)
        let result = try await session.respond(
            to: Prompt {
                "Estimate the nutrition of the food in this image."
                photo
            },
            generating: NutritionEstimate.self
        )
        return result.content
    }

    // MARK: Barcode (ready-made Vision tool, tool use forced)
    static func estimate(barcodeImage: UIImage) async throws -> NutritionEstimate {
        let session = LanguageModelSession(tools: [BarcodeReaderTool()], instructions: instructions)
        let options = GenerationOptions(toolCallingMode: .required)
        let result = try await session.respond(
            to: Prompt {
                "Read the barcode in this image and estimate the nutrition for one serving."
                barcodeImage
            },
            generating: NutritionEstimate.self,
            options: options
        )
        return result.content
    }

    // MARK: Nutrition label (ready-made OCR tool, tool use forced)
    static func estimate(labelImage: UIImage) async throws -> NutritionEstimate {
        let session = LanguageModelSession(tools: [OCRTool()], instructions: instructions)
        let options = GenerationOptions(toolCallingMode: .required)
        let result = try await session.respond(
            to: Prompt {
                "Read the nutrition label in this image and return the values for one serving. Prefer the printed numbers over estimation."
                labelImage
            },
            generating: NutritionEstimate.self,
            options: options
        )
        return result.content
    }

    // MARK: Opt-in escalation to Private Cloud Compute (network, never the default)
    static func escalate(photo: UIImage) async throws -> NutritionEstimate {
        let session = LanguageModelSession(
            model: PrivateCloudComputeLanguageModel(),
            instructions: instructions
        )
        let result = try await session.respond(
            to: Prompt {
                "Estimate the nutrition of the food in this image as accurately as possible."
                photo
            },
            generating: NutritionEstimate.self
        )
        return result.content
    }
}

extension NutritionEstimate {
    /// Maps the estimate onto a persistable food entry for the given day/source.
    func makeEntry(date: Date, source: FoodSource, now: Date) -> FoodEntryRecord {
        FoodEntryRecord(
            date: date.startOfDay,
            name: name,
            kcal: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            note: note,
            confidence: confidence.lowercased(),
            source: source.rawValue,
            createdAt: now
        )
    }

    var isLowConfidence: Bool { confidence.lowercased() == Confidence.low.rawValue }
}
