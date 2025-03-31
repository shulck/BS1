//
//  SetlistDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  SetlistDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct SetlistDetailView: View {
    @State var setlist: Setlist

    var body: some View {
        List {
            ForEach(setlist.songs) { song in
                HStack {
                    VStack(alignment: .leading) {
                        Text(song.title)
                            .font(.headline)
                        Text("BPM: \(song.bpm)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(song.formattedDuration)
                        .monospacedDigit()
                }
            }

            if setlist.songs.isEmpty {
                Text("Сетлист пустой")
                    .foregroundColor(.gray)
            }

            Section {
                HStack {
                    Text("Общая длительность")
                    Spacer()
                    Text(setlist.formattedTotalDuration)
                        .bold()
                        .monospacedDigit()
                }
            }
        }
        .navigationTitle(setlist.name)
    }
}
