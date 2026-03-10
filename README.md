# Nida Flutter

Flutter port of the Nida Adhan **homepage** and **CustomNavigationBar**, same layout and design as the React Native app.

## Structure (mirrors RN app)

- **Contexts**: `ThemeProvider`, `NavigationBarProvider` (nav bar visibility)
- **Widgets**: `CustomNavigationBar` (bottom bar, 5 tabs), `HomeHeader`, `PrayerTimeCard`, `HomeContentCards`
- **Screens**: `HomeScreen` (main homepage), placeholder screens for Prayer, Quran, Qibla, Settings

## Design

- Background: `#F8FAFC`
- Primary / active: `#6366F1` (indigo)
- Bottom bar: white, rounded top 24px, height 80px, safe area aware
- Header: gradient (indigo), next prayer, hijri/gregorian dates, location
- Prayer row: 5 cards (Fajr, Dhuhr, Asr, Maghrib, Isha) with current/next highlight
- Content cards: Dua, Hadith, Esmaul Husna, Remote content (placeholders)

## Run

```bash
cd nida-flutter
flutter pub get
flutter run
```

## Notes

- Homepage uses **mock data** (prayer times, location, dates). Replace with your services/API when ready.
- Nav bar icons use Material Icons; you can swap for custom assets (e.g. from `../assets/`) to match RN exactly.
