//
//  QianYuDialogueCorpus.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation

public struct QianYuDialogueCorpus {
    /// 千语实时的随行小状态（用于顶部气泡或菜单栏浮窗展示）
    public static var statusList: [String] { EditorialCopy.list("dialogue.status") }

    public static func randomStatus() -> String {
        statusList.randomElement() ?? EditorialCopy.text("dialogue.status.fallback")
    }

    /// 离线或默认情况下，根据用户输入和当前课表智能匹配陈千语原生台词
    public static func matchReply(
        for input: String,
        userName: String = "管理员",
        nextCourseSummary: String? = nil,
        scheduleContext: String? = nil
    ) -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func containsAny(_ phrases: [String]) -> Bool {
            phrases.contains { text.contains($0) }
        }

        // 1. 询问上课或课程安排
        if text.contains("课") || text.contains("教室") || text.contains("上课") || text.contains("迟到") {
            if let schedule = scheduleContext, !schedule.isEmpty {
                let lines = schedule.components(separatedBy: "\n")
                let queried = lines.filter { $0.hasPrefix("查询日期：") }
                let courses = lines.filter { $0.hasPrefix("课程：") }
                if !queried.isEmpty {
                    return EditorialCopy.text("dialogue.course.schedule", ["schedule": queried.joined(separator: "\n")])
                }
                if !containsAny(["下一节", "下节", "迟到"]), !courses.isEmpty {
                    return EditorialCopy.text("dialogue.course.schedule", ["schedule": courses.joined(separator: "\n")])
                }
            }
            if let summary = nextCourseSummary, !summary.isEmpty {
                return EditorialCopy.text("dialogue.course.next", ["summary": summary])
            } else {
                return EditorialCopy.text("dialogue.course.none")
            }
        }

        // 2. 晚间休息意图优先于一般疲劳，避免“困了”被当成按摩请求。
        if containsAny(["晚安", "睡了", "困了", "困啦", "睡觉", "洗漱", "该睡", "要睡"]) {
            return EditorialCopy.text("dialogue.sleep")
        }

        // 3. 累了、困倦、按摩肩颈
        if containsAny(["累", "犯困", "困倦", "困得", "打瞌睡", "酸痛", "腰酸", "肩酸", "按摩", "穴位", "肩颈"]) {
            let replies = EditorialCopy.list("dialogue.tired")
            return replies.randomElement() ?? replies[0]
        }

        // 4. 剑法、武侠、帅气
        if text.contains("剑") || text.contains("武侠") || text.contains("当破即破") || text.contains("招式") || text.contains("比划") {
            let replies = EditorialCopy.list("dialogue.sword")
            return replies.randomElement() ?? replies[0]
        }

        // 5. 早晨打招呼。不要用单字“起”匹配“对不起”“一起”等普通表达。
        if containsAny(["早安", "早上好", "早晨好", "早呀", "早啊", "醒了", "醒啦", "起床", "起了吗"]) {
            return EditorialCopy.text("dialogue.morning")
        }

        // 6. 夸奖。避免单字“强”误命中“增强”“强迫”等词。
        if containsAny(["厉害", "真棒", "很棒", "帅", "可爱", "好强", "很强", "超强", "太强", "真强", "强大"]) {
            return EditorialCopy.text("dialogue.praise")
        }

        // 7. 调侃（如傻龙）
        if text.contains("傻") || text.contains("笨") || text.contains("哭") {
            return EditorialCopy.text("dialogue.tease")
        }

        // 8. 宏山、头发、角、背景
        if text.contains("头发") || text.contains("角") || text.contains("辫子") {
            return EditorialCopy.text("dialogue.hair")
        }
        if text.contains("奶茶") {
            return EditorialCopy.text("dialogue.milkTea")
        }

        // 9. 默认活泼元气回复
        let defaults = EditorialCopy.list("dialogue.default")
        let reply = defaults.randomElement() ?? defaults[0]
        return reply.replacingOccurrences(of: "{userName}", with: userName)
    }
}
