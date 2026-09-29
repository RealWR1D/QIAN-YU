//
//  PersonaDocView.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import SwiftUI

public struct PersonaDocView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings: AppSettings
    @State private var draftPrompt: String

    public init(settings: AppSettings = .shared) {
        self.settings = settings
        _draftPrompt = State(initialValue: settings.effectivePersonaPrompt)
    }

    private var defaultPrompt: String { EditorialCopy.text("persona.base") }
    private var trimmedDraft: String { draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDefaultDraft: Bool { trimmedDraft == defaultPrompt.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasUnsavedChanges: Bool {
        trimmedDraft != settings.effectivePersonaPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image("QianyuAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("陈千语")
                            .font(.title2.bold())
                        Text(settings.hasCustomPersonaPrompt ? "已保存自定义人设" : "使用默认人设")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("人设内容")
                            .font(.headline)
                        Spacer()
                        if hasUnsavedChanges {
                            Text("尚未保存")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("可以修改身份、性格、说话风格和回复规则。保存后，从下一条 AI 对话开始使用。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draftPrompt)
                        .font(.system(size: 14))
                        .frame(minHeight: 320)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }
                        .accessibilityLabel("人设内容")
                    if trimmedDraft.isEmpty {
                        Text("人设内容不能为空，可点击“恢复默认”重新填入默认设定。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Button("恢复默认") {
                            draftPrompt = defaultPrompt
                        }
                        .disabled(isDefaultDraft)
                        Spacer()
                        Text("恢复默认后也需要点击保存。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("离线固定回复与通知文案仍使用内置千语台词，不受此处修改影响。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("默认人设参考") {
                    defaultReference
                        .padding(.top, 16)
                }
            }
            .padding(20)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("角色人设")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    settings.customPersonaPrompt = isDefaultDraft ? "" : trimmedDraft
                    dismiss()
                }
                .disabled(trimmedDraft.isEmpty)
            }
        }
    }

    private var defaultReference: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 人物立绘卡片
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    Image("QianyuAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("陈千语 (Chen Qianyu)")
                        .font(.title2.bold())
                    Text("终末地特勤干员 · 双剑客 · 龙族")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("「当破即破，冲冲冲！」")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 身份与背景
            Group {
                Text("身份与背景")
                    .font(.headline)
                Text("""
                • 故乡：宏山城环形山，大院里长大的龙族姑娘，头上两角一条尾巴。
                • 发型：对准双角扎成细致对称的双辫（王奶奶独门秘诀）。
                • 武器：一对普通单手剑，趁手就行。曾纠结刻“当破即破”还是“当断即断”。
                • 经历：在谈剑堂提前毕业；在菈梵朵玛“碰碰杯杯”奶茶店待过三个月；与佩丽卡合力推驮兽车分吃一个馍加入终末地。
                """)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }

            Divider()

            // 说话的样子与人设规范
            Group {
                Text("说话的核心规范")
                    .font(.headline)
                Text("""
                1. 极其简短口语化：单次回复严格控制在 1~3 句话（30~80字，严禁超过100字），绝不发长篇大论。
                2. 高情商、充满亲和力：嘴甜、会夸人、给足情绪价值，绝不怼人不说教。
                3. 元气起头：常以「在呢在呢！」「走走走！」「交给我准没错！」「来啦！」热络起步。
                4. 真实日常闲暇：只有琢磨剑招差点撞柱子、擦剑、按穴位放松、假装打坐偷偷打瞌睡、看大炎武侠、喝奶茶。绝不使用吃货俗套。
                """)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            }

            Divider()

            // 经典语录
            Group {
                Text("千语原声调子")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    QuoteRow(text: String(localized: "「在呢在呢！找我啥好事呀？是不是要带我出任务啦？」"))
                    QuoteRow(text: String(localized: "「嘿嘿，帅不帅？在那边我一直是第一哦！哎呀夸得我都不好意思啦——再来两句！」"))
                    QuoteRow(text: String(localized: "「要不……我也帮你松松？我可是知道几个穴位哦！来嘛来嘛，外套脱了别客气！」"))
                    QuoteRow(text: String(localized: "「菈梵朵玛碰碰杯杯奶茶店？很简单嘛，喝够了奶茶，就走了。」"))
                }
            }
        }
    }
}

struct QuoteRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
