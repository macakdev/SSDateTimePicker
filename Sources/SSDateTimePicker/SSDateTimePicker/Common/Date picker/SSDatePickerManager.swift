//
//  SSCalendarManager.swift
//  DateTimePicker
//
//  Created by Rizwana Desai on 27/11/23.
//

import Foundation
import SwiftUI
import Combine

/// A manager class for handling the state and behavior of the SSDatePicker.
final class SSDatePickerManager: ObservableObject, DatePickerConfigurationDirectAccess {
    
    // MARK: - Properties
    
    /// The current month displayed in the date picker.
    /// Setting this property will determine the month whose calendar dates will be displayed when the picker is opened.
    @Published var currentMonth: Date
    
    /// The selected date in the date picker. Set this property to pre-select a specific date.
    @Published var selectedDate: Date? = nil
    
    /// The selected dates in the date picker when multiple selection is allowed. Set this property to pre-select a specific dates.
    @Published var selectedDates: [Date]? = nil
    
    /// The start date for range selection in the date picker.
    @Published var startDate: Date? = nil
    
    /// The end date for range selection in the date picker.
    @Published var endDate: Date? = nil
    
    /// List of dates that needs to be disabled
    var disableDates: [Date]?
    
    /// The configuration for the SSDatePicker.
    public var configuration: SSDatePickerConfiguration
    
    /// The year range displayed in the year selection view.
    @Published private(set) var yearRange = [Int]()
    
    /// The last known current month for canceling selection.
    private var lastCurrentMonth: Date
    
    /// The last known selected date for canceling selection.
    private var lastSelectedDate: Date?
    
    var dateRangeSelectionCallback: (DateRange) -> () = {_ in}
    var multiDateSelectionCallback: ([Date]) -> () = {_ in}
    var dateSelectionCallback: (Date) -> () = {_ in}
    
    // MARK: - Initializer
    
    /// Initializes the SSDatePickerManager with the provided configuration.
    ///
    /// - Parameters:
    ///   - currentMonth: The initial current month to be displayed in the date picker.
    ///   - selectedDate: The initially selected date to be displayed in the date picker.
    ///   - configuration: The style configuration for the SSDatePicker.
    init(currentMonth: Date = Date(), selectedDate: Date? = nil, configuration: SSDatePickerConfiguration = SSDatePickerConfiguration()) {
        self.currentMonth = currentMonth
        self.selectedDate = selectedDate
        self.configuration = configuration
        self.lastCurrentMonth = currentMonth
        self.lastSelectedDate = selectedDate
    }
    
    // MARK: - Methods
    
    /// Advances to the next month, year based on the current view (date, month, or year).
    func actionNext(for view: SelectionView) {
        switch view {
        case .date:
            currentMonth = currentMonth.getNextMonth(calendar) ?? currentMonth
        case .month:
            currentMonth = currentMonth.getNextYear(calendar) ?? currentMonth
            updateYearSelection(date: currentMonth)
        case .year:
            guard let year = self.yearRange.last else { return }
            self.updateYearRange(year: year+12)
        }
    }
    
    /// Moves back to the previous month, year based on the current view (date, month, or year).
    func actionPrev(for view: SelectionView) {
        switch view {
        case .date:
            currentMonth = currentMonth.getPreviousMonth(calendar) ?? currentMonth
        case .month:
            currentMonth = currentMonth.getPreviousYear(calendar) ?? currentMonth
            updateYearSelection(date: currentMonth)
        case .year:
            guard let year = self.yearRange.first else { return }
            self.updateYearRange(year: year-1)
        }
    }

    /// Updates the year selection based on the chosen year.
    func updateYearSelection(date: Date) {
        updateYearSelection(year: date.year(calendar))
    }

    /// Checks if a given month is currently selected in the date picker.
    func isSelected(_ month: String) -> Bool {
        let date = selectedDate ?? currentMonth
        return month.lowercased() == date.fullMonth.lowercased() && date.year(calendar) == currentMonth.year(calendar)
    }
    
    /// Checks if a given year is currently selected in the date picker.
    func isSelected(_ year: Int) -> Bool {
        year == (selectedDate ?? currentMonth).year(calendar)
    }
    
    /// Updates the date selection based on the chosen date.
    func updateDateSelection(date: Date) {
        if configuration.allowMultipleSelection {
            if selectedDates == nil  {
                self.selectedDates = []
            }
            updateMultipleSelection(date: date)
        } else if configuration.allowRangeSelection {
            self.updateRangeSelection(date: date)
        } else {
            self.selectedDate = date
        }
    }
    
    func updateMultipleSelection(date: Date) {
        // Find the index of the selected date in the array, if it exists
        if let existingIndex = selectedDates?.firstIndex(where: { selectedDate in
            calendar.isDate(date, equalTo: selectedDate, toGranularities: [.day, .month, .year])
        }) {
            // If the date is already selected, remove it to support deselection
            selectedDates?.remove(at: existingIndex)
        } else {
            // If the date is not selected, add it to the selected dates array
            selectedDates?.append(date)
        }
    }
    
    func handleMultiDateDeselection(date: Date) {
        
    }
    
    /// Updates the range selection based on the chosen date.
    func updateRangeSelection(date: Date) {
        if let startDate = startDate , date >= configuration.calendar.startOfDay(for: startDate) {
            endDate = date
        } else {
            startDate = date
        }
    }
    
    /// Updates the month selection based on the chosen month.
    func updateMonthSelection(month: Int) {
        var component = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: selectedDate ?? currentMonth)
        component.month = month
        applySelection(component)
    }
    
    /// Updates the year selection based on the chosen year.
    func updateYearSelection(year: Int) {
        var component = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: selectedDate ?? currentMonth)
        component.year = year
        applySelection(component)
    }
    
    func isMonthInRange(_ month: Int) -> Bool {
        var component = calendar.dateComponents([.year], from: currentMonth)
        component.month = month
        component.day = 1
        guard let date = calendar.date(from: component), let interval = calendar.dateInterval(of: .month, for: date) else { return true }
        return isIntervalInRange(interval)
    }
    
    func isYearInRange(_ year: Int) -> Bool {
        guard let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let interval = calendar.dateInterval(of: .year, for: date) else { return true }
        return isIntervalInRange(interval)
    }
    
    func isDateInRange(_ date: Date) -> Bool {
        if let minimumDate, date < calendar.startOfDay(for: minimumDate) { return false }
        if let maximumDate, date > maximumDate { return false }
        return true
    }
    
    /// Updates the displayed year range in the year selection view.
    func updateYearRange(year: Int) {
        let lowerBound = year - 11
        let upperBound = year
        self.yearRange = Array(lowerBound...upperBound)
    }
    
    /// Reverts the selection to the last known values before the user's interaction.
    ///
    /// - Parameter view: The view (date, month, or year) for which the selection is being canceled.
    func selectionCanceled(for view: SelectionView) {
        switch view {
        case .date:
            self.selectedDate = lastSelectedDate
        case .month, .year:
            self.currentMonth = lastCurrentMonth
        }
    }
    
    /// Confirms the selection and notifies the delegate.
    ///
    /// - Parameter view: The view (date, month, or year) for which the selection is being confirmed.
    func selectionConfirmed(for view: SelectionView) {
        switch view {
        case .date:
            lastSelectedDate = self.selectedDate
            handleCallback()
        case .month, .year:
            lastCurrentMonth = self.currentMonth
        }
    }
    
    /// Notifies the delegate about the selected dates based on the configuration.
    func handleCallback() {
        if configuration.allowMultipleSelection {
            guard let selectedDates else { return }
            multiDateSelectionCallback(selectedDates)
        } else if configuration.allowRangeSelection {
            guard let startDate, let endDate else { return }
            dateRangeSelectionCallback(DateRange(startDate, endDate))
        } else {
            guard let selectedDate else { return }
            dateSelectionCallback(selectedDate)
        }
    }
    
    /// Determines if a given date can be selected based on a list of disabled dates.
    /// - Parameters:
    ///   - date: The date to be checked for selectability.
    /// - Returns: `true` if the date is selectable, `false` if it is disabled.
    func canSelectDate(_ date: Date) -> Bool {
        guard let disableDates = disableDates else {
            return true // all dates are selectable if disableDates is nil
        }
        
        return !disableDates.contains { disableDate in
            calendar.isDate(date, equalTo: disableDate, toGranularities: [.day, .month, .year])
        }
    }
    
    private func applySelection(_ components: DateComponents) {
        var component = components
        let day = component.day ?? 1
        component.day = 1
        guard let firstDayOfMonth = calendar.date(from: component),
              let daysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else { return }
        component.day = min(day, daysInMonth.count)
        guard let date = calendar.date(from: component) else { return }
        
        guard selectedDate != nil else {
            currentMonth = date
            return
        }
        let clampedDate = clampedToRange(date)
        selectedDate = canSelectDate(clampedDate) ? clampedDate : nil
        currentMonth = clampedDate
    }
    
    private func clampedToRange(_ date: Date) -> Date {
        if let minimumDate, date < calendar.startOfDay(for: minimumDate) { return minimumDate }
        if let maximumDate, date > maximumDate { return maximumDate }
        return date
    }
    
    private func isIntervalInRange(_ interval: DateInterval) -> Bool {
        if let minimumDate, interval.end <= calendar.startOfDay(for: minimumDate) { return false }
        if let maximumDate, interval.start > maximumDate { return false }
        return true
    }
    
}
