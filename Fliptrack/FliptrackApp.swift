//
//  FliptrackApp.swift
//  Fliptrack
//
//  Created by Brandon Lackey on 6/12/26.
//

import SwiftData
import SwiftUI

@main
struct FliptrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Brand.self,
            Category.self,
            StorageLocation.self,
            SellingPlatform.self,
        ])

        do {
            let cloudConfiguration = ModelConfiguration(
                "FlipTrackCloud",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.golackey.Fliptrack")
            )
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            do {
                let localConfiguration = ModelConfiguration("FlipTrackLocal", schema: schema)
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.butterYellow)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
