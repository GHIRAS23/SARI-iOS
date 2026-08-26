import SwiftUI

struct TravelView: View {
    @StateObject private var profile = TravelProfileStore()
    @StateObject private var destinationWeather = WeatherStore()
    @State private var showProfile = false
    @State private var showHelp = false
    @State private var showChecklist = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors:[Color(.systemBackground), Color.accentColor.opacity(0.07), Color(.systemBackground)], startPoint:.top, endPoint:.bottom).ignoresSafeArea()
                ScrollView(showsIndicators:false) {
                    VStack(spacing:16) {
                        destinationHeader
                        preTripCard
                        countryInfo
                        destinationWeatherCard
                        missionAndEmergency
                        localApps
                        muslimTools
                        foodCard
                        helpButton
                        dataSafetyNote
                    }
                    .padding(18).padding(.bottom,30)
                }
            }
            .navigationTitle(SariStrings.t("travel"))
            .toolbar { ToolbarItem(placement:.topBarLeading) { Button { showProfile = true } label: { Image(systemName:"person.crop.circle") } } }
            .sheet(isPresented:$showProfile) { TravelProfileSheet(profile:profile) }
            .sheet(isPresented:$showHelp) { TravelHelpView(profile:profile) }
            .sheet(isPresented:$showChecklist) { PreTripChecklistView(profile:profile) }
            .task(id: profile.destinationCode) { let d = profile.destination; await destinationWeather.load(latitude:d.latitude, longitude:d.longitude) }
        }
        .environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
    }

    private var destinationHeader: some View {
        VStack(alignment:.trailing, spacing:14) {
            HStack { Text(profile.destination.flag).font(.system(size:42)); Spacer(); VStack(alignment:.trailing, spacing:3) { Text(SariUIStrings.text("destination", SariLanguage.selected)).font(.caption.bold()).foregroundStyle(.secondary); Text(profile.destination.nameArabic).font(.system(size:30,weight:.black,design:.rounded)); Text(profile.destination.capitalArabic).foregroundStyle(.secondary) } }
            Picker(SariUIStrings.text("destination", SariLanguage.selected), selection:$profile.destinationCode) { ForEach(TravelCatalog.destinations) { Text("\($0.flag) \($0.nameArabic)").tag($0.code) } }.pickerStyle(.menu).tint(.accentColor)
        }.padding(22).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28,style:.continuous))
    }

    private var preTripCard: some View {
        Button { showChecklist = true } label: {
            HStack(spacing:14) { Image(systemName:"checklist.checked").font(.title2).foregroundStyle(Color.accentColor); Spacer(); VStack(alignment:.trailing,spacing:5) { Text(SariUIStrings.text("before_travel", SariLanguage.selected)).font(.headline).foregroundStyle(.primary); Text(SariUIStrings.text("travel_prepare_desc", SariLanguage.selected)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing) } }
            .padding(18).background(Color.accentColor.opacity(0.09),in:RoundedRectangle(cornerRadius:22))
        }.buttonStyle(.plain)
    }

    private var countryInfo: some View {
        VStack(alignment:.trailing,spacing:12) {
            Text(SariStrings.t("countryInfo")).font(.title3.bold())
            infoRow(SariUIStrings.text("currency", SariLanguage.selected), profile.destination.currency, "creditcard.fill")
            infoRow(SariUIStrings.text("language", SariLanguage.selected), profile.destination.languagesArabic, "character.bubble.fill")
            infoRow(SariUIStrings.text("timing", SariLanguage.selected), profile.destination.timeZoneNoteArabic, "clock.fill")
            infoRow(SariUIStrings.text("electricity", SariLanguage.selected), profile.destination.plugsArabic, "powerplug.fill")
        }.card()
    }

    @ViewBuilder private var destinationWeatherCard: some View {
        VStack(alignment:.trailing,spacing:12) {
            HStack { Text(SariUIStrings.text("destination_weather", SariLanguage.selected)).font(.title3.bold()); Spacer(); Image(systemName:"cloud.sun.fill").symbolRenderingMode(.multicolor) }
            if let w = destinationWeather.snapshot {
                HStack { Text("\(Int(w.temperature.rounded()))°").font(.system(size:40,weight:.black)); Text(w.conditionArabic).foregroundStyle(.secondary); Spacer(); Text(SariUIStrings.format("feels_like", SariLanguage.selected, ["value":"\(Int(w.apparentTemperature.rounded()))"])).font(.subheadline) }
                Label(w.clothingAdviceArabic, systemImage:"tshirt.fill").font(.subheadline).foregroundStyle(.secondary)
                if let alert = w.smartAlertArabic { Label(alert,systemImage:"exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
            } else if destinationWeather.isLoading { HStack { ProgressView(); Text(SariUIStrings.text("updating_destination_weather", SariLanguage.selected)) } }
            else { Text(SariUIStrings.text("weather_unavailable", SariLanguage.selected)).foregroundStyle(.secondary) }
        }.card()
    }

    private var missionAndEmergency: some View {
        VStack(alignment:.trailing,spacing:13) {
            Text(SariUIStrings.text("important_numbers2", SariLanguage.selected)).font(.title3.bold())
            if let nationality = profile.nationality {
                HStack { Text(nationality.flag).font(.title2); Spacer(); VStack(alignment:.trailing) { Text(SariUIStrings.format("embassy_of", SariLanguage.selected, ["country":nationality.nameArabic])).font(.headline); if let m = TravelCatalog.mission(for:nationality.code,in:profile.destination.code) { Text(m.titleArabic).foregroundStyle(.secondary) } else { Text(SariUIStrings.text("no_verified_mission_cached",SariLanguage.selected)).font(.caption).foregroundStyle(.secondary) } } }
            } else {
                Button { showProfile = true } label: { Label(SariUIStrings.text("travel_nationality_hint", SariLanguage.selected),systemImage:"flag.fill").frame(maxWidth:.infinity,alignment:.trailing) }
            }
            Divider()
            HStack { Image(systemName:"cross.case.fill").foregroundStyle(.red); Spacer(); VStack(alignment:.trailing) { Text(SariUIStrings.format("emergency_in",SariLanguage.selected,["country":profile.destination.nameArabic])).font(.headline); if let n = profile.destination.emergencyGeneral { Text(SariUIStrings.format("general_emergency",SariLanguage.selected,["number":n])).font(.title3.bold()) } ; Text(profile.destination.emergencyNoteArabic).font(.caption).foregroundStyle(.secondary) } }
        }.card()
    }

    private var localApps: some View {
        VStack(alignment:.trailing,spacing:12) {
            Text(SariStrings.t("localApps")).font(.title3.bold())
            ForEach(profile.destination.apps) { app in HStack(spacing:12) { Image(systemName:app.systemImage).foregroundStyle(Color.accentColor).frame(width:32); Spacer(); VStack(alignment:.trailing,spacing:3) { HStack { Text(app.category).font(.caption).foregroundStyle(.secondary); Text(app.name).font(.headline) }; Text(app.noteArabic).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing) } }.padding(.vertical,4) }
            Text(SariUIStrings.text("verify_app_publisher", SariLanguage.selected)).font(.caption2).foregroundStyle(.secondary)
        }.card()
    }

    private var muslimTools: some View {
        VStack(alignment:.trailing,spacing:12) {
            Text(SariUIStrings.text("travel_muslim_tools", SariLanguage.selected)).font(.title3.bold())
            NavigationLink(destination:PrayerTimesView()) { travelLink(SariUIStrings.text("prayer_times", SariLanguage.selected), "clock.fill") }
            NavigationLink(destination:QiblaView()) { travelLink(SariUIStrings.text("qibla", SariLanguage.selected), "location.north.circle.fill") }
            NavigationLink(destination:AdhkarView()) { travelLink(SariUIStrings.text("travel_adhkar", SariLanguage.selected), "hands.sparkles.fill") }
            NavigationLink(destination:FiqhAssistantView()) { travelLink(SariUIStrings.text("travel_fiqh_ask", SariLanguage.selected), "sparkles") }
        }.card()
    }

    private var foodCard: some View {
        NavigationLink(destination:PlacesLocalView(destination:profile.destination)) {
            HStack(spacing:14) {
                Image(systemName:"fork.knife.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
                Spacer()
                VStack(alignment:.trailing,spacing:5) {
                    Text(profile.destination.muslimMajority ? SariUIStrings.text("featured_restaurants",SariLanguage.selected):SariUIStrings.text("halal_nearby", SariLanguage.selected)).font(.headline).foregroundStyle(.primary)
                    Text(SariUIStrings.text("places_live_desc", SariLanguage.selected)).font(.subheadline).foregroundStyle(.secondary)
                }
                Image(systemName:"chevron.left").font(.caption).foregroundStyle(.secondary)
            }.card()
        }.buttonStyle(.plain)
    }

    private var helpButton: some View { Button { showHelp = true } label: { Label(SariUIStrings.text("need_help", SariLanguage.selected),systemImage:"sos.circle.fill").font(.headline).frame(maxWidth:.infinity).padding(.vertical,15) }.buttonStyle(.borderedProminent).tint(.red) }
    private var dataSafetyNote: some View { Text(SariUIStrings.text("sensitive_data_note", SariLanguage.selected)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal,8) }

    private func infoRow(_ title:String,_ value:String,_ icon:String) -> some View { HStack { Image(systemName:icon).foregroundStyle(Color.accentColor); Spacer(); VStack(alignment:.trailing) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.bold()) } } }
    private func travelLink(_ title:String,_ icon:String) -> some View { HStack { Image(systemName:icon).foregroundStyle(Color.accentColor); Spacer(); Text(title).fontWeight(.semibold).foregroundStyle(.primary); Image(systemName:"chevron.left").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,5) }
}

private extension View { func card() -> some View { self.frame(maxWidth:.infinity,alignment:.trailing).padding(18).background(.regularMaterial,in:RoundedRectangle(cornerRadius:22,style:.continuous)) } }


private struct TravelProfileSheet: View {
    @ObservedObject var profile: TravelProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(SariUIStrings.text("nationality", SariLanguage.selected)) {
                    Picker(SariUIStrings.text("nationality", SariLanguage.selected), selection: $profile.nationalityCode) {
                        Text(SariUIStrings.text("choose_nationality", SariLanguage.selected)).tag("")
                        ForEach(TravelCatalog.nationalities) { item in
                            Text("\(item.flag) \(item.nameArabic)").tag(item.code)
                        }
                    }
                }
                Section(SariUIStrings.text("trip", SariLanguage.selected)) {
                    Picker(SariUIStrings.text("destination", SariLanguage.selected), selection: $profile.destinationCode) {
                        ForEach(TravelCatalog.destinations) { item in
                            Text("\(item.flag) \(item.nameArabic)").tag(item.code)
                        }
                    }
                    DatePicker(
                        SariUIStrings.text("trip_date", SariLanguage.selected),
                        selection: Binding(get: { profile.tripDate ?? Date() }, set: { profile.tripDate = $0 }),
                        displayedComponents: .date
                    )
                    Button(SariUIStrings.text("remove_trip_date", SariLanguage.selected), role: .destructive) { profile.tripDate = nil }
                }
                Section {
                    Text(SariUIStrings.text("nationality_privacy", SariLanguage.selected))
                        .font(.caption)
                }
            }
            .navigationTitle(SariUIStrings.text("travel_setup", SariLanguage.selected))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(SariUIStrings.text("done", SariLanguage.selected)) { dismiss() } } }
        }
        .environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
    }
}

private struct PreTripChecklistView: View {
    @ObservedObject var profile: TravelProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(TravelCatalog.checklist(nationality: profile.nationality, destination: profile.destination, tripDate: profile.tripDate)) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.systemImage).foregroundStyle(Color.accentColor).frame(width: 32)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle(SariUIStrings.text("before_travel", SariLanguage.selected))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(SariUIStrings.text("done", SariLanguage.selected)) { dismiss() } } }
        }
        .environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
    }
}

private struct TravelHelpView: View {
    @ObservedObject var profile: TravelProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Label(SariUIStrings.format("emergency_in", SariLanguage.selected, ["country":profile.destination.nameArabic]), systemImage: "sos.circle.fill")
                        .font(.title2.bold()).foregroundStyle(.red)
                    if let number = profile.destination.emergencyGeneral,
                       let url = URL(string: "tel:\(number)") {
                        Link(destination: url) {
                            Label(SariUIStrings.format("emergency_call",SariLanguage.selected,["number":number]), systemImage: "phone.fill")
                                .frame(maxWidth: .infinity).padding()
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                    }
                    Text(profile.destination.emergencyNoteArabic).font(.subheadline).foregroundStyle(.secondary)
                    Divider()
                    if let nationality = profile.nationality {
                        Text(SariUIStrings.format("embassy_of",SariLanguage.selected,["country":"\(nationality.nameArabic) \(nationality.flag)"])).font(.headline)
                        if TravelCatalog.mission(for: nationality.code, in: profile.destination.code) == nil {
                            Text(SariUIStrings.text("no_verified_mission", SariLanguage.selected))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(SariUIStrings.text("select_nationality_first", SariLanguage.selected)).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle(SariUIStrings.text("need_help", SariLanguage.selected))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(SariUIStrings.text("close", SariLanguage.selected)) { dismiss() } } }
        }
        .environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
    }
}
