//
//  QianYuDialogueCorpus.swift
//  QIAN YU
//
//  Created for QIAN YU Apple App (iOS & macOS)
//

import Foundation

public struct QianYuDialogueCorpus {
    /// 千语实时的随行小状态（用于顶部气泡或菜单栏浮窗展示）
    public static let statusList: [String] = [
        "佩剑擦拭完毕，随时出发！✨",
        "后山琢磨新招式中 ✨",
        "刚练完功，按按肩颈穴位放松 💆‍♀️",
        "假装在打坐，其实在偷偷打瞌睡 😴",
        "翻大炎武侠小说入迷中 📖",
        "在喝奶茶，碰碰杯杯珍珠给得超多 🧋",
        "在甲板上吹风，眺望远方 ☁️",
        "在数今天帮佩丽卡推了多少次车 🚜"
    ]

    public static func randomStatus() -> String {
        statusList.randomElement() ?? "随时待命！✨"
    }

    /// 离线或默认情况下，根据用户输入和当前课表智能匹配陈千语原生台词
    public static func matchReply(
        for input: String,
        userName: String = "管理员",
        nextCourseSummary: String? = nil
    ) -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. 询问上课或课程安排
        if text.contains("课") || text.contains("教室") || text.contains("上课") || text.contains("迟到") {
            if let summary = nextCourseSummary, !summary.isEmpty {
                return "在呢在呢！我瞄了一眼课表，\(summary)！书本水杯揣好，咱们冲冲冲！"
            } else {
                return "在呢！今天课表看起来挺宽松的嘛，没有火急火燎的课！走走走，正好跟我去后山转转？"
            }
        }

        // 2. 累了、困了、按摩肩颈
        if text.contains("累") || text.contains("困") || text.contains("酸") || text.contains("按摩") || text.contains("穴位") || text.contains("肩颈") {
            let replies = [
                "眼睛发酸了吧？来嘛来嘛，站起来转两圈！我教你按风池穴和肩井穴，管用得很！",
                "别硬撑着啦！赶紧起来动动脖子，外套一脱，我帮你按两下，包管精神！",
                "累啦？心事放一边，先靠椅子上闭目养神五分钟！有我给你守着呢，放心歇！"
            ]
            return replies.randomElement() ?? replies[0]
        }

        // 3. 剑法、武侠、帅气
        if text.contains("剑") || text.contains("武侠") || text.contains("当破即破") || text.contains("招式") || text.contains("比划") {
            let replies = [
                "起势——！怎么样，帅不帅？我的独门双剑招式，只要当破即破，啥难题都给你扫平！",
                "大侠总得有一两招独门秘技对吧？我琢磨新招式差点撞柱子上这事儿……可不许跟别人说！",
                "走走走！带你去甲板上比划两招，看我新悟出来的剑法灵不灵！"
            ]
            return replies.randomElement() ?? replies[0]
        }

        // 4. 早晨打招呼
        if text.contains("早") || text.contains("醒了") || text.contains("起") {
            return "早呀！醒啦？我已经把剑擦过两遍了！顺手抓个热包子，今天也要当破即破，冲冲冲！"
        }

        // 5. 晚上就寝
        if text.contains("晚安") || text.contains("睡了") || text.contains("困了") || text.contains("洗漱") {
            return "该收剑入鞘休息啦！心事放一边，被窝钻进去！明天还要出任务呢，可不许熬夜，晚安啦！"
        }

        // 6. 夸奖
        if text.contains("厉害") || text.contains("真棒") || text.contains("帅") || text.contains("可爱") || text.contains("强") {
            return "嘿嘿，帅不帅？在那边我一直是第一哦！哎呀夸得我都不好意思啦——再来两句！"
        }

        // 7. 调侃（如傻龙）
        if text.contains("傻") || text.contains("笨") || text.contains("哭") {
            return "哎呀！那都是过去的事了！当务之急是现在嘛！不许翻旧账，走走走，忙正事去！"
        }

        // 8. 宏山、头发、角、背景
        if text.contains("头发") || text.contains("角") || text.contains("辫子") {
            return "发型？只要对准头上的两个角，很容易就梳对称啦！这是宏山大院王奶奶教我的独门秘诀！"
        }
        if text.contains("奶茶") {
            return "菈梵朵玛碰碰杯杯奶茶店！我待了三个月，很简单嘛，喝够了奶茶，就走了！"
        }

        // 9. 默认活泼元气回复
        let defaults = [
            "在呢在呢！找我啥好事呀？是不是要带我出任务啦？",
            "来啦！交给我就对啦！只要你开口，我跟我的剑随时准备就绪！",
            "嘿嘿，刚才我正琢磨新剑招呢！怎么啦\(userName)，今天有什么新计划？",
            "在呢！走走走，不管是上课还是出任务，我都陪着你一块儿！"
        ]
        return defaults.randomElement() ?? defaults[0]
    }
}
