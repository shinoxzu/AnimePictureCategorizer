//
//  DirectoryButton.swift
//  AnimePictureCategorizer
//
//  Created by Антон Романов on 03.01.2025.
//

import SwiftUI

struct DirectoryButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(
                    systemName: isSelected
                    ? "checkmark.circle.fill" : systemImage
                )
                .foregroundColor(isSelected ? .green : .blue)
                Text(title)
                Spacer()
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.darkGray))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
