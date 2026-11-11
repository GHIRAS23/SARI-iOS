import Foundation

extension Bundle {
    func sariResourceURL(
        name: String,
        extension fileExtension: String,
        subdirectory: String? = nil
    ) -> URL? {
        if let subdirectory,
           let url = url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
           ) {
            return url
        }

        return url(
            forResource: name,
            withExtension: fileExtension
        )
    }
}
