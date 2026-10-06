//
//  MonthSelectionView.swift
//  DateTimePicker
//
//  Created by Rizwana Desai on 24/11/23.
//

import SwiftUI

struct SSMonthSelectionView: View, DatePickerConfigurationDirectAccess {
    
    // MARK: - Properties

    @EnvironmentObject private var calendarManager: SSDatePickerManager
    @Binding var currentView: SelectionView
    @State private var monthList: [String] = DateFormatter.monthsList
    private var gridItem: [GridItem] = Array(repeating: .init(.flexible()), count: SSPickerConstants.monthYearGridRows)
    
    internal var configuration: SSDatePickerConfiguration {
        calendarManager.configuration
    }

    init(currentView: Binding<SelectionView>) {
        _currentView = currentView
    }

    //MARK: - Body

    var body: some View {
        monthsGridView
            .padding(.top, SSPickerConstants.monthYearViewTopSpace)
            .padding(.bottom, SSPickerConstants.monthYearViewBottomSpace)
    }
    
    //MARK: - Sub views

    private var monthsGridView: some View {
        HStack {
            LazyVGrid(columns: gridItem, spacing: SSPickerConstants.monthYearGridSpacing) {
                ForEach(monthList, id: \.self) {  month in
                    btnMonth(for: month)
                }
            }
        }
    }
    
    @ViewBuilder
    private func btnMonth(for month: String) -> some View {
        let monthName = month
        let isMonthInRange = monthList.firstIndex(of: month).map { calendarManager.isMonthInRange($0 + 1) } ?? true
        let isSelectedMonth = isMonthInRange && calendarManager.isSelected(monthName)
        Button {
            withAnimation {
                updateMonth(month: month)
                currentView = .date
            }
        } label: {
            Text(monthName)
                .font(isSelectedMonth ? selectedMonthTextFont : monthTextFont)
                .foregroundColor(isSelectedMonth ? buttonsForegroundColor : dateMonthYearTextColor)
        }
        .disabled(!isMonthInRange)
        .opacity(isMonthInRange ? 1 : 0.25)
    }
    
    //MARK: - Methods

    private func updateMonth(month: String) {
        guard let month = monthList.firstIndex(where: { $0 == month}) else { return }
        calendarManager.updateMonthSelection(month: month+1)
    }
        
}
