//
//  Calendar.swift
//  OldOS
//

import SwiftUI
import EventKit

struct CalendarView: View {
    @State var current_nav_view: String = "Main"
    @State var forward_or_backward: Bool = false
    @State var selectedDate: Date = Date()
    @State var currentMonth: Date = {
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month], from: Date())
        c.day = 1
        return cal.date(from: c) ?? Date()
    }()
    @State var events: [EKEvent] = []
    @State var selectedEvent: EKEvent? = nil
    @State var calendarAccessGranted: Bool = false
    let eventStore = EKEventStore()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                settings_main_list()
                switch current_nav_view {
                case "Detail":
                    if let event = selectedEvent {
                        VStack(spacing: 0) {
                            status_bar_in_app().frame(minHeight: 24, maxHeight: 24).zIndex(1)
                            cal_detail_title_bar(
                                title: event.title ?? "Event",
                                back_action: {
                                    forward_or_backward = true
                                    withAnimation(.linear(duration: 0.28)) { current_nav_view = "Main" }
                                }
                            ).frame(height: 60)
                            cal_event_detail_body(event: event)
                        }
                        .transition(AnyTransition.asymmetric(
                            insertion: .move(edge: forward_or_backward == false ? .trailing : .leading),
                            removal: .move(edge: forward_or_backward == false ? .leading : .trailing)
                        ))
                    }
                default:
                    VStack(spacing: 0) {
                        status_bar_in_app().frame(minHeight: 24, maxHeight: 24).zIndex(1)
                        cal_month_title_bar(
                            currentMonth: currentMonth,
                            prev_action: { changeMonth(by: -1) },
                            next_action: { changeMonth(by: 1) }
                        ).frame(height: 60)
                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 10)
                                cal_month_grid(currentMonth: currentMonth, selectedDate: $selectedDate, events: events)
                                Spacer().frame(height: 15)
                                cal_day_events_section(
                                    selectedDate: selectedDate,
                                    events: eventsForDay,
                                    onSelect: { event in
                                        selectedEvent = event
                                        forward_or_backward = false
                                        withAnimation(.linear(duration: 0.28)) { current_nav_view = "Detail" }
                                    }
                                )
                            }
                        }
                    }
                    .transition(AnyTransition.asymmetric(
                        insertion: .move(edge: forward_or_backward == false ? .trailing : .leading),
                        removal: .move(edge: forward_or_backward == false ? .leading : .trailing)
                    ))
                }
            }
            .compositingGroup()
            .clipped()
        }
        .onAppear {
            UIScrollView.appearance().bounces = true
            requestCalendarAccess()
        }
        .onDisappear {
            UIScrollView.appearance().bounces = false
        }
    }

    var eventsForDay: [EKEvent] {
        let cal = Calendar.current
        return events
            .filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            Task {
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    await MainActor.run {
                        calendarAccessGranted = granted
                        if granted { loadEvents() }
                    }
                } catch {}
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    calendarAccessGranted = granted
                    if granted { loadEvents() }
                }
            }
        }
    }

    func loadEvents() {
        let cal = Calendar.current
        var sc = cal.dateComponents([.year, .month], from: currentMonth)
        sc.day = 1
        let start = cal.date(from: sc) ?? currentMonth
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        let pred = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = eventStore.events(matching: pred)
    }

    func changeMonth(by value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = next
            events = []
            if calendarAccessGranted { loadEvents() }
        }
    }
}

// MARK: - Navigation Bars

struct cal_month_title_bar: View {
    var currentMonth: Date
    var prev_action: () -> Void
    var next_action: () -> Void

    private var monthYear: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: currentMonth)
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color(red: 180/255, green: 191/255, blue: 205/255), location: 0.0),
                .init(color: Color(red: 136/255, green: 155/255, blue: 179/255), location: 0.49),
                .init(color: Color(red: 128/255, green: 149/255, blue: 175/255), location: 0.49),
                .init(color: Color(red: 110/255, green: 133/255, blue: 162/255), location: 1.0)
            ]), startPoint: .top, endPoint: .bottom)
            .border_bottom(width: 1, edges: [.bottom], color: Color(red: 45/255, green: 48/255, blue: 51/255))
            .innerShadowBottom(color: Color(red: 230/255, green: 230/255, blue: 230/255), radius: 0.025)

            HStack {
                Button(action: prev_action) {
                    ZStack {
                        Image("Button2").resizable().aspectRatio(contentMode: .fit).frame(width: 77)
                        HStack {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.leading, 18)
                            Spacer()
                        }
                    }
                }.padding(.leading, 6)

                Spacer()

                Text(monthYear)
                    .ps_innerShadow(Color.white, radius: 0, offset: 1, angle: 180.degrees, intensity: 0.07)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 20))
                    .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0.0, y: -1)

                Spacer()

                Button(action: next_action) {
                    ZStack {
                        Image("Button2").resizable().aspectRatio(contentMode: .fit).frame(width: 77)
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.trailing, 18)
                        }
                    }
                }.padding(.trailing, 6)
            }
        }
    }
}

struct cal_detail_title_bar: View {
    var title: String
    var back_action: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color(red: 180/255, green: 191/255, blue: 205/255), location: 0.0),
                .init(color: Color(red: 136/255, green: 155/255, blue: 179/255), location: 0.49),
                .init(color: Color(red: 128/255, green: 149/255, blue: 175/255), location: 0.49),
                .init(color: Color(red: 110/255, green: 133/255, blue: 162/255), location: 1.0)
            ]), startPoint: .top, endPoint: .bottom)
            .border_bottom(width: 1, edges: [.bottom], color: Color(red: 45/255, green: 48/255, blue: 51/255))
            .innerShadowBottom(color: Color(red: 230/255, green: 230/255, blue: 230/255), radius: 0.025)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(title)
                        .ps_innerShadow(Color.white, radius: 0, offset: 1, angle: 180.degrees, intensity: 0.07)
                        .font(.custom("Helvetica Neue Bold", fixedSize: 20))
                        .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0.0, y: -1)
                        .lineLimit(1)
                        .frame(maxWidth: 200)
                    Spacer()
                }
                Spacer()
            }

            HStack {
                Button(action: back_action) {
                    ZStack {
                        Image("Button2").resizable().aspectRatio(contentMode: .fit).frame(width: 77)
                        HStack {
                            Text("Calendar")
                                .foregroundColor(.white)
                                .font(.custom("Helvetica Neue Bold", fixedSize: 13))
                                .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -0.6)
                                .padding(.leading, 5)
                                .offset(y: -1.1)
                        }
                    }
                }.padding(.leading, 6)
                Spacer()
            }
        }
    }
}

// MARK: - Month Grid

struct cal_month_grid: View {
    var currentMonth: Date
    @Binding var selectedDate: Date
    var events: [EKEvent]

    private let cal = Calendar.current
    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let grid = buildGrid()
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { col in
                    Text(dayNames[col])
                        .font(.custom("Helvetica Neue Bold", fixedSize: 12))
                        .foregroundColor(Color(red: 76/255, green: 86/255, blue: 108/255))
                        .frame(maxWidth: .infinity, minHeight: 26)
                }
            }
            .background(Color(red: 230/255, green: 234/255, blue: 240/255))

            Rectangle()
                .fill(Color(red: 171/255, green: 171/255, blue: 171/255))
                .frame(height: 0.5)

            ForEach(0..<grid.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = grid[row][col]
                        if let d = day {
                            cal_day_cell(
                                date: d,
                                isSelected: cal.isDate(d, inSameDayAs: selectedDate),
                                isToday: cal.isDateInToday(d),
                                hasEvents: events.contains { cal.isDate($0.startDate, inSameDayAs: d) }
                            ) { selectedDate = d }
                        } else {
                            Color(red: 245/255, green: 245/255, blue: 247/255)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                if row < grid.count - 1 {
                    Rectangle()
                        .fill(Color(red: 217/255, green: 217/255, blue: 217/255))
                        .frame(height: 0.5)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(8)
        .strokeRoundedRectangle(8, Color(red: 171/255, green: 171/255, blue: 171/255), lineWidth: 1)
        .padding([.leading, .trailing], 12)
    }

    func buildGrid() -> [[Date?]] {
        var c = cal.dateComponents([.year, .month], from: currentMonth)
        c.day = 1
        guard let first = cal.date(from: c) else { return [] }
        let offset = (cal.component(.weekday, from: first) - 1 + 7) % 7
        let range = cal.range(of: .day, in: .month, for: first)!
        var flat: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            c.day = day
            flat.append(cal.date(from: c))
        }
        while flat.count % 7 != 0 { flat.append(nil) }
        return stride(from: 0, to: flat.count, by: 7).map { Array(flat[$0..<$0+7]) }
    }
}

struct cal_day_cell: View {
    var date: Date
    var isSelected: Bool
    var isToday: Bool
    var hasEvents: Bool
    var onTap: () -> Void
    private let cal = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: Color(red: 100/255, green: 140/255, blue: 240/255), location: 0),
                        .init(color: Color(red: 56/255, green: 95/255, blue: 210/255), location: 1)
                    ]), startPoint: .top, endPoint: .bottom)
                } else {
                    Color.white
                }
                VStack(spacing: 2) {
                    Text("\(cal.component(.day, from: date))")
                        .font(.custom(isToday ? "Helvetica Neue Bold" : "Helvetica Neue Regular", fixedSize: 17))
                        .foregroundColor(
                            isSelected ? .white :
                            isToday ? Color(red: 56/255, green: 95/255, blue: 210/255) :
                            .black
                        )
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Color(red: 56/255, green: 95/255, blue: 210/255))
                            .frame(width: 5, height: 5)
                    } else {
                        Spacer().frame(height: 5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Day Events List

struct cal_day_events_section: View {
    var selectedDate: Date
    var events: [EKEvent]
    var onSelect: (EKEvent) -> Void

    private var headerText: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d"
        return df.string(from: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(headerText)
                    .foregroundColor(Color(red: 76/255, green: 86/255, blue: 108/255))
                    .font(.custom("Helvetica Neue Bold", fixedSize: 17))
                    .shadow(color: Color.white.opacity(0.9), radius: 0, x: 0.0, y: 0.9)
                    .padding([.leading, .trailing], 24)
                Spacer()
            }
            .padding(.bottom, 8)

            if events.isEmpty {
                HStack {
                    Spacer()
                    Text("No Events")
                        .font(.custom("Helvetica Neue Regular", fixedSize: 16))
                        .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                        .shadow(color: Color.white.opacity(0.9), radius: 0, x: 0.0, y: 0.9)
                    Spacer()
                }
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(10)
                .strokeRoundedRectangle(10, Color(red: 171/255, green: 171/255, blue: 171/255), lineWidth: 1)
                .padding([.leading, .trailing], 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(events.indices, id: \.self) { idx in
                        let event = events[idx]
                        Button(action: { onSelect(event) }) {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color(cgColor: event.calendar.cgColor))
                                    .frame(width: 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title ?? "No Title")
                                        .font(.custom("Helvetica Neue Bold", fixedSize: 15))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                    Text(event.isAllDay ? "All-day" : eventTimeString(event))
                                        .font(.custom("Helvetica Neue Regular", fixedSize: 12))
                                        .foregroundColor(Color(red: 103/255, green: 109/255, blue: 115/255))
                                }
                                .padding(.leading, 8)
                                .padding(.vertical, 8)
                                Spacer()
                                Image("ABTableNextButton").padding(.trailing, 12)
                            }
                            .frame(minHeight: 50)
                            .background(Color.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if idx < events.count - 1 {
                            Rectangle()
                                .fill(Color(red: 224/255, green: 224/255, blue: 224/255))
                                .frame(height: 1)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(10)
                .strokeRoundedRectangle(10, Color(red: 171/255, green: 171/255, blue: 171/255), lineWidth: 1)
                .padding([.leading, .trailing], 12)
            }
            Spacer().frame(height: 20)
        }
    }

    func eventTimeString(_ event: EKEvent) -> String {
        let tf = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        return "\(tf.string(from: event.startDate)) – \(tf.string(from: event.endDate))"
    }
}

// MARK: - Event Detail

struct cal_event_detail_body: View {
    var event: EKEvent

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 0) {
                Spacer().frame(height: 15)
                VStack(spacing: 0) {
                    cal_detail_field(label: "", value: event.title ?? "No Title", bold: true)
                    Rectangle().fill(Color(red: 224/255, green: 224/255, blue: 224/255)).frame(height: 1)
                    if event.isAllDay {
                        cal_detail_field(label: "Date", value: dayStr(event.startDate))
                    } else {
                        cal_detail_field(label: "Starts", value: fullStr(event.startDate))
                        Rectangle().fill(Color(red: 224/255, green: 224/255, blue: 224/255)).frame(height: 1)
                        cal_detail_field(label: "Ends", value: fullStr(event.endDate))
                    }
                    Rectangle().fill(Color(red: 224/255, green: 224/255, blue: 224/255)).frame(height: 1)
                    HStack(alignment: .center) {
                        Text("Calendar")
                            .font(.custom("Helvetica Neue Bold", fixedSize: 14))
                            .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                            .frame(width: 80, alignment: .trailing)
                            .padding(.trailing, 8)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(event.calendar.title)
                                .font(.custom("Helvetica Neue Regular", fixedSize: 14))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding([.top, .bottom], 10)
                    .padding(.leading, 12)
                    if let loc = event.location, !loc.isEmpty {
                        Rectangle().fill(Color(red: 224/255, green: 224/255, blue: 224/255)).frame(height: 1)
                        cal_detail_field(label: "Location", value: loc)
                    }
                    if let notes = event.notes, !notes.isEmpty {
                        Rectangle().fill(Color(red: 224/255, green: 224/255, blue: 224/255)).frame(height: 1)
                        cal_detail_field(label: "Notes", value: notes)
                    }
                }
                .background(Color.white)
                .cornerRadius(10)
                .strokeRoundedRectangle(10, Color(red: 171/255, green: 171/255, blue: 171/255), lineWidth: 1)
                .padding([.leading, .trailing], 12)
                Spacer().frame(height: 20)
            }
        }
        .background(settings_main_list().ignoresSafeArea())
    }

    func fullStr(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: d)
    }

    func dayStr(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: d)
    }
}

struct cal_detail_field: View {
    var label: String
    var value: String
    var bold: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            if label.isEmpty {
                Text(value)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 16))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                Spacer()
            } else {
                Text(label)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 14))
                    .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 8)
                Text(value)
                    .font(.custom(bold ? "Helvetica Neue Bold" : "Helvetica Neue Regular", fixedSize: 14))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .padding([.top, .bottom], 10)
        .padding(.leading, 12)
    }
}
