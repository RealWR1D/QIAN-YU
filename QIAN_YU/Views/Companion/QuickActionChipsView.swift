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

    private let chips: [QuickActionChip] = [
        QuickActionChip(title: "💆 按按肩颈", prompt: "千语，最近低头看书看电脑肩膀好酸，教我按按穴位呗！"),
        QuickActionChip(title: "🏫 下节什么课？", prompt: "千语，帮我瞧一眼课表，下一节是什么课在哪个教室？"),
        QuickActionChip(title: "📖 讲讲大院故事", prompt: "千语，给我讲讲你小时候在宏山大院的趣事呗！"),
        QuickActionChip(title: "⚡️ 当破即破！", prompt: "千语，今天遇到点卡壳的事，借你的大侠豪气用用！"),
        QuickActionChip(title: "🧋 碰碰杯杯", prompt: "听说你在菈梵朵玛碰碰杯杯奶茶店待过三个月？"),
        QuickActionChip(title: "✨ 随行日常", prompt: "今天又在后山琢磨出什么厉害的新招式没有？")
    ]

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
