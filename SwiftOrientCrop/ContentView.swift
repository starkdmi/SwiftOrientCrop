//
//  ContentView.swift
//  SwiftOrientCrop
//
//  Created by Dmitry Starkov on 24/08/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "crop")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("SwiftOrientCrop")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
