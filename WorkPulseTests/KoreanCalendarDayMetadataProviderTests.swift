import Foundation
import Testing
@testable import WorkPulse

@Suite("KoreanCalendarDayMetadataProvider")
struct KoreanCalendarDayMetadataProviderTests {
    private let provider = KoreanCalendarDayMetadataProvider()

    @Test
    func weekendDateReturnsWeekendCategory() throws {
        let date = try #require(makeDate("2026-04-04T12:00:00+09:00"))

        let metadata = provider.metadata(for: date)

        #expect(metadata.category == .weekend)
        #expect(metadata.holiday == nil)
    }

    @Test
    func holidayOverridesWeekendCategory() throws {
        let date = try #require(makeDate("2026-03-01T12:00:00+09:00"))

        let metadata = provider.metadata(for: date)

        #expect(metadata.category == .holiday)
        #expect(metadata.holiday?.name == "3·1절")
    }

    @Test
    func substituteHolidayIncludesOriginalHolidayName() throws {
        let date = try #require(makeDate("2026-03-02T12:00:00+09:00"))

        let metadata = provider.metadata(for: date)

        #expect(metadata.category == .substituteHoliday)
        #expect(metadata.holiday?.substituteForName == "3·1절")
        #expect(metadata.holiday?.annotationText == "3·1절 대체공휴일")
    }

    @Test
    func overlappingHolidayDateCreatesSingleSubstituteAnnotation() throws {
        let holidayDate = try #require(makeDate("2025-05-05T12:00:00+09:00"))
        let substituteDate = try #require(makeDate("2025-05-06T12:00:00+09:00"))

        let holidayMetadata = provider.metadata(for: holidayDate)
        let substituteMetadata = provider.metadata(for: substituteDate)

        #expect(holidayMetadata.category == .holiday)
        #expect(holidayMetadata.holiday?.name.contains("어린이날") == true)
        #expect(holidayMetadata.holiday?.name.contains("부처님오신날") == true)
        #expect(substituteMetadata.category == .substituteHoliday)
        #expect(substituteMetadata.holiday?.substituteForName?.contains("어린이날") == true)
        #expect(substituteMetadata.holiday?.substituteForName?.contains("부처님오신날") == true)
    }

    @Test
    func utcDateNormalizesIntoSeoulHolidayBucket() throws {
        let formatter = ISO8601DateFormatter()
        let date = try #require(formatter.date(from: "2026-03-01T16:00:00Z"))

        let metadata = provider.metadata(for: date)

        #expect(metadata.category == .substituteHoliday)
        #expect(metadata.holiday?.annotationText == "3·1절 대체공휴일")
    }
}

private func makeDate(_ value: String) -> Date? {
    ISO8601DateFormatter().date(from: value)
}
