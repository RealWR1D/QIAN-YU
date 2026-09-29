//
//  QuickActionChipsView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct QuickActionChip: Identifiable {
    public let id = UUID()
    public let title: String
    public let prompt: String
}

public struct QuickActionChipsView: View {
    public var onSelect: (String) -> Void

    private var chips: [QuickActionChip] {
        EditorialCopy.quickActions.map { QuickActionChip(title: $0.title, prompt: $0.prompt) }
    }

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        onSelect(chip.prompt)
                    } label: {
                        Text(chip.title)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }
}
