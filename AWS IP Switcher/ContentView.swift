//
//  ContentView.swift
//  AWS IP Switcher
//
//  Created by Osbert Nephide Ngok on 9/12/2023.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var backend = Backend.single()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(backend.status)
            Text(backend.instanceID)
            Text(backend.publicAddress)
            Button("Change IP"){
                Task {
                    do {
                        try await backend.changeIPAsync()
                    } catch {
                        // do nothing
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
