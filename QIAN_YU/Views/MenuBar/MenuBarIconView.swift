//
//  MenuBarIconView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (macOS MenuBar Extra)
//

import SwiftUI

#if os(macOS)
/// 专为 macOS 菜单栏定制的纯字方块图标
/// 特性：
/// 1. 两行字（QIAN / YU）等大
/// 2. 每行严格向左对齐
/// 3. 紧凑小字间距
/// 4. 上下零间距紧密相切
/// 5. 整体偏在 1:1 正方形的左下角
/// 6. macOS 原生 SF Pro Heavy 系统字体，支持系统深浅色自动反色 (Template 机制)
public struct QianYuMenuBarIconView: View {
    public var size: CGFloat = 18.0

    public init(size: CGFloat = 18.0) {
        self.size = size
    }

    public var body: some View {
        // 白底方块背景 + 字体透明镂空 (Knockout)
        ZStack(alignment: .bottomLeading) {
            // 纯白方形背景（克制微圆角 12%，硬朗高级，不要太大）
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(Color.white)

            // 两行严格相同字号、向左对齐、极小字间距、零行间距，偏在左下角
            // 使用 destinationOut 将文字在白色背景中彻底挖空为透明
            VStack(alignment: .leading, spacing: -size * 0.11) {
                Text("QIAN")
                    .font(.system(size: size * 0.30, weight: .heavy, design: .default))
                    .tracking(-0.3)

                Text("YU")
                    .font(.system(size: size * 0.30, weight: .heavy, design: .default))
                    .tracking(-0.3)
            }
            .padding(.leading, size * 0.10)
            .padding(.bottom, size * 0.10)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        // 深色菜单栏模拟
        VStack {
            Text("深色菜单栏")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                QianYuMenuBarIconView(size: 18)
                Text("访达")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.black.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(4)
        }

        // 浅色菜单栏模拟
        VStack {
            Text("浅色菜单栏")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                QianYuMenuBarIconView(size: 18)
                Text("访达")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
    .padding()
}
#endif
