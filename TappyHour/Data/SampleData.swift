import Foundation
import CoreLocation

var TODAY: DayKey {
    // Calendar weekday: Sunday = 1 … Saturday = 7
    switch Calendar.current.component(.weekday, from: Date()) {
    case 1: .su
    case 2: .mo
    case 3: .tu
    case 4: .we
    case 5: .th
    case 6: .fr
    default: .sa
    }
}

let NEIGHBORHOODS = [
    "West Loop", "Fulton Market", "River North", "Wicker Park",
    "Logan Square", "Streeterville", "Lincoln Park", "Lakeview",
    "Old Town", "Gold Coast", "Pilsen", "Bucktown",
]
let RECENT_SEARCHES = ["West Loop", "Rooftop bars", "Half-off wine"]

private func sched(_ hours: String, _ headline: String, _ items: [HappyHourItem]) -> DaySchedule {
    DaySchedule(hours: hours, headline: headline, menu: items)
}

let VENUES: [Venue] = [
    Venue(
        id: "v1", name: "The Copper Jug", neighborhood: "West Loop",
        cuisine: "American", vibe: "Cozy", rating: 4.6, reviews: 842,
        distance: 0.3, walk: 6, price: "$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8825, longitude: -87.6479),
        tags: ["Cocktails", "Beer"],
        schedule: [
            .mo: sched("3:00 – 6:00 PM", "$6 old fashioneds, $4 drafts", [
                HappyHourItem(item: "Old Fashioned", normal: 14, deal: 6),
                HappyHourItem(item: "Draft Beer (16oz)", normal: 8, deal: 4),
                HappyHourItem(item: "House Red / White", normal: 13, deal: 7),
            ]),
            .tu: sched("3:00 – 6:00 PM", "$6 old fashioneds, $4 drafts", [
                HappyHourItem(item: "Old Fashioned", normal: 14, deal: 6),
                HappyHourItem(item: "Draft Beer (16oz)", normal: 8, deal: 4),
                HappyHourItem(item: "House Red / White", normal: 13, deal: 7),
            ]),
            .we: sched("3:00 – 6:00 PM", "Whiskey Wednesday — $5 pours", [
                HappyHourItem(item: "Rye Pour (1oz)", normal: 12, deal: 5),
                HappyHourItem(item: "Bourbon Pour (1oz)", normal: 13, deal: 5),
                HappyHourItem(item: "Whiskey Sour", normal: 14, deal: 7),
                HappyHourItem(item: "Draft Beer (16oz)", normal: 8, deal: 4),
            ]),
            .th: sched("3:00 – 6:00 PM", "$6 old fashioneds, $4 drafts", [
                HappyHourItem(item: "Old Fashioned", normal: 14, deal: 6),
                HappyHourItem(item: "House Martini", normal: 15, deal: 8),
                HappyHourItem(item: "Draft Beer (16oz)", normal: 8, deal: 4),
            ]),
            .fr: sched("3:00 – 7:00 PM", "Friday happy hour — extra hour", [
                HappyHourItem(item: "Old Fashioned", normal: 14, deal: 6),
                HappyHourItem(item: "House Martini", normal: 15, deal: 8),
                HappyHourItem(item: "Draft Beer (16oz)", normal: 8, deal: 4),
                HappyHourItem(item: "House Red / White", normal: 13, deal: 7),
                HappyHourItem(item: "Bourbon Highball", normal: 12, deal: 6),
            ]),
            // Sa, Su: no happy hour (key absent)
        ]
    ),
    Venue(
        id: "v2", name: "Fulton & Fig", neighborhood: "Fulton Market",
        cuisine: "Mediterranean", vibe: "Date night", rating: 4.8, reviews: 1204,
        distance: 0.5, walk: 10, price: "$$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8866, longitude: -87.6498),
        tags: ["Wine", "Cocktails"],
        schedule: [
            .tu: sched("4:00 – 6:30 PM", "Half-off wine by the glass", [
                HappyHourItem(item: "Natural Wine (glass)", normal: 16, deal: 8),
                HappyHourItem(item: "Spritz of the Day", normal: 14, deal: 9),
                HappyHourItem(item: "Prosecco", normal: 12, deal: 6),
            ]),
            .we: sched("4:00 – 6:30 PM", "Half-off wine by the glass", [
                HappyHourItem(item: "Natural Wine (glass)", normal: 16, deal: 8),
                HappyHourItem(item: "Spritz of the Day", normal: 14, deal: 9),
                HappyHourItem(item: "Prosecco", normal: 12, deal: 6),
            ]),
            .th: sched("4:00 – 6:30 PM", "Industry Night — half-off all", [
                HappyHourItem(item: "Natural Wine (glass)", normal: 16, deal: 8),
                HappyHourItem(item: "Negroni Bianco", normal: 15, deal: 7),
                HappyHourItem(item: "Prosecco", normal: 12, deal: 6),
                HappyHourItem(item: "Amaro Pour", normal: 11, deal: 5),
            ]),
            .fr: sched("4:00 – 6:30 PM", "Half-off wine by the glass", [
                HappyHourItem(item: "Natural Wine (glass)", normal: 16, deal: 8),
                HappyHourItem(item: "Spritz of the Day", normal: 14, deal: 9),
                HappyHourItem(item: "Negroni Bianco", normal: 15, deal: 9),
                HappyHourItem(item: "Prosecco", normal: 12, deal: 6),
            ]),
            .sa: sched("3:00 – 5:00 PM", "Rosé hour — $7 glasses", [
                HappyHourItem(item: "Rosé (glass)", normal: 14, deal: 7),
                HappyHourItem(item: "Prosecco", normal: 12, deal: 6),
            ]),
        ]
    ),
    Venue(
        id: "v3", name: "Lower East Tap", neighborhood: "River North",
        cuisine: "Pub", vibe: "Lively", rating: 4.3, reviews: 562,
        distance: 0.8, walk: 14, price: "$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8905, longitude: -87.6325),
        tags: ["Beer"],
        schedule: Dictionary(uniqueKeysWithValues: DayKey.allCases.map { day in
            (day, sched("4:00 – 7:00 PM", "$3 drafts, $5 well drinks", [
                HappyHourItem(item: "Domestic Draft", normal: 7, deal: 3),
                HappyHourItem(item: "Craft Draft", normal: 9, deal: 5),
                HappyHourItem(item: "Well Cocktail", normal: 10, deal: 5),
                HappyHourItem(item: "Shot & a Beer", normal: 12, deal: 7),
            ]))
        })
    ),
    Venue(
        id: "v4", name: "Maison Verre", neighborhood: "West Loop",
        cuisine: "French", vibe: "Date night", rating: 4.7, reviews: 918,
        distance: 0.4, walk: 8, price: "$$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8810, longitude: -87.6462),
        tags: ["Wine", "Cocktails"],
        schedule: [
            .we: sched("5:00 – 7:00 PM", "$9 champagne, $10 martinis", [
                HappyHourItem(item: "Champagne (glass)", normal: 18, deal: 9),
                HappyHourItem(item: "Gin Martini", normal: 16, deal: 10),
                HappyHourItem(item: "Vermouth Spritz", normal: 13, deal: 8),
            ]),
            .th: sched("5:00 – 7:00 PM", "$9 champagne, $10 martinis", [
                HappyHourItem(item: "Champagne (glass)", normal: 18, deal: 9),
                HappyHourItem(item: "Gin Martini", normal: 16, deal: 10),
                HappyHourItem(item: "Vermouth Spritz", normal: 13, deal: 8),
                HappyHourItem(item: "Kir Royale", normal: 14, deal: 9),
            ]),
            .fr: sched("5:00 – 7:00 PM", "$9 champagne, $10 martinis", [
                HappyHourItem(item: "Champagne (glass)", normal: 18, deal: 9),
                HappyHourItem(item: "Gin Martini", normal: 16, deal: 10),
                HappyHourItem(item: "Vermouth Spritz", normal: 13, deal: 8),
                HappyHourItem(item: "Kir Royale", normal: 14, deal: 9),
            ]),
            .sa: sched("5:00 – 7:00 PM", "$9 champagne, $10 martinis", [
                HappyHourItem(item: "Champagne (glass)", normal: 18, deal: 9),
                HappyHourItem(item: "Gin Martini", normal: 16, deal: 10),
                HappyHourItem(item: "Kir Royale", normal: 14, deal: 9),
            ]),
            .su: sched("3:00 – 5:00 PM", "Sunday aperitif — $8 spritzes", [
                HappyHourItem(item: "Aperol Spritz", normal: 14, deal: 8),
                HappyHourItem(item: "Vermouth Spritz", normal: 13, deal: 8),
            ]),
        ]
    ),
    Venue(
        id: "v5", name: "Smokehouse 312", neighborhood: "Wicker Park",
        cuisine: "BBQ", vibe: "Lively", rating: 4.5, reviews: 1340,
        distance: 1.2, walk: 22, price: "$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.9081, longitude: -87.6779),
        tags: ["Beer", "Cocktails"],
        schedule: [
            .mo: sched("3:30 – 6:00 PM", "$5 whiskey, $4 local drafts", [
                HappyHourItem(item: "House Whiskey", normal: 11, deal: 5),
                HappyHourItem(item: "Local IPA", normal: 8, deal: 4),
                HappyHourItem(item: "Boilermaker", normal: 12, deal: 6),
            ]),
            .tu: sched("3:30 – 6:00 PM", "$5 whiskey, $4 local drafts", [
                HappyHourItem(item: "House Whiskey", normal: 11, deal: 5),
                HappyHourItem(item: "Local IPA", normal: 8, deal: 4),
                HappyHourItem(item: "Boilermaker", normal: 12, deal: 6),
            ]),
            .we: sched("3:30 – 6:00 PM", "$5 whiskey, $4 local drafts", [
                HappyHourItem(item: "House Whiskey", normal: 11, deal: 5),
                HappyHourItem(item: "Local IPA", normal: 8, deal: 4),
                HappyHourItem(item: "Whiskey Sour", normal: 13, deal: 7),
            ]),
            .th: sched("3:30 – 6:00 PM", "$5 whiskey, $4 local drafts", [
                HappyHourItem(item: "House Whiskey", normal: 11, deal: 5),
                HappyHourItem(item: "Local IPA", normal: 8, deal: 4),
                HappyHourItem(item: "Whiskey Sour", normal: 13, deal: 7),
                HappyHourItem(item: "Boilermaker", normal: 12, deal: 6),
            ]),
            // Fr, Sa, Su: no happy hour
        ]
    ),
    Venue(
        id: "v6", name: "Atlas Rooftop", neighborhood: "River North",
        cuisine: "New American", vibe: "Rooftop", rating: 4.4, reviews: 2107,
        distance: 0.9, walk: 16, price: "$$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8928, longitude: -87.6318),
        tags: ["Cocktails", "Wine"],
        schedule: Dictionary(uniqueKeysWithValues: DayKey.allCases.map { day in
            (day, sched("4:00 – 6:00 PM", "$8 signature cocktails", [
                HappyHourItem(item: "Paloma del Sol", normal: 16, deal: 8),
                HappyHourItem(item: "Smoked Manhattan", normal: 17, deal: 8),
                HappyHourItem(item: "Lychee Martini", normal: 16, deal: 8),
                HappyHourItem(item: "Rosé (glass)", normal: 14, deal: 7),
            ]))
        })
    ),
    Venue(
        id: "v7", name: "The Green Room", neighborhood: "Logan Square",
        cuisine: "Cocktail bar", vibe: "Cozy", rating: 4.9, reviews: 486,
        distance: 1.6, walk: 28, price: "$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.9215, longitude: -87.7046),
        tags: ["Cocktails", "Beer"],
        schedule: [
            .tu: sched("5:00 – 7:00 PM", "$7 classics, $5 beer", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Daiquiri", normal: 13, deal: 7),
                HappyHourItem(item: "Lager", normal: 8, deal: 5),
            ]),
            .we: sched("5:00 – 7:00 PM", "$7 classics, $5 beer", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Daiquiri", normal: 13, deal: 7),
                HappyHourItem(item: "Lager", normal: 8, deal: 5),
            ]),
            .th: sched("5:00 – 7:00 PM", "$7 classics, $5 beer", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Daiquiri", normal: 13, deal: 7),
                HappyHourItem(item: "Tiki Punch", normal: 15, deal: 8),
                HappyHourItem(item: "Lager", normal: 8, deal: 5),
            ]),
            .fr: sched("5:00 – 7:00 PM", "$7 classics, $5 beer", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Daiquiri", normal: 13, deal: 7),
                HappyHourItem(item: "Tiki Punch", normal: 15, deal: 8),
                HappyHourItem(item: "Lager", normal: 8, deal: 5),
            ]),
            .sa: sched("5:00 – 7:00 PM", "Late night — 10pm–midnight", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Lager", normal: 8, deal: 5),
            ]),
            .su: sched("5:00 – 7:00 PM", "$7 classics, $5 beer", [
                HappyHourItem(item: "Negroni", normal: 14, deal: 7),
                HappyHourItem(item: "Daiquiri", normal: 13, deal: 7),
            ]),
        ]
    ),
    Venue(
        id: "v8", name: "Pier & Pine", neighborhood: "Streeterville",
        cuisine: "Seafood", vibe: "Date night", rating: 4.5, reviews: 773,
        distance: 1.1, walk: 20, price: "$$$",
        coordinate: CLLocationCoordinate2D(latitude: 41.8918, longitude: -87.6208),
        tags: ["Wine", "Cocktails"],
        schedule: [
            .mo: sched("3:00 – 6:00 PM", "$6 oysters, $9 martinis", [
                HappyHourItem(item: "Dirty Martini", normal: 16, deal: 9),
                HappyHourItem(item: "Sauv Blanc (glass)", normal: 15, deal: 8),
            ]),
            .tu: sched("3:00 – 6:00 PM", "$6 oysters, $9 martinis", [
                HappyHourItem(item: "Dirty Martini", normal: 16, deal: 9),
                HappyHourItem(item: "Aperol Spritz", normal: 14, deal: 8),
                HappyHourItem(item: "Sauv Blanc (glass)", normal: 15, deal: 8),
            ]),
            .we: sched("3:00 – 6:00 PM", "$6 oysters, $9 martinis", [
                HappyHourItem(item: "Dirty Martini", normal: 16, deal: 9),
                HappyHourItem(item: "Aperol Spritz", normal: 14, deal: 8),
                HappyHourItem(item: "Sauv Blanc (glass)", normal: 15, deal: 8),
            ]),
            .th: sched("3:00 – 6:00 PM", "$6 oysters, $9 martinis", [
                HappyHourItem(item: "Dirty Martini", normal: 16, deal: 9),
                HappyHourItem(item: "Aperol Spritz", normal: 14, deal: 8),
                HappyHourItem(item: "Sauv Blanc (glass)", normal: 15, deal: 8),
            ]),
            .fr: sched("3:00 – 6:00 PM", "$6 oysters, $9 martinis", [
                HappyHourItem(item: "Dirty Martini", normal: 16, deal: 9),
                HappyHourItem(item: "Aperol Spritz", normal: 14, deal: 8),
                HappyHourItem(item: "Sauv Blanc (glass)", normal: 15, deal: 8),
            ]),
            // Sa, Su: no happy hour
        ]
    ),
]
