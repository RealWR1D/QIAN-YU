# AI API 配置实现依据（2026-09-29）

设置页从兼容端点的 `GET /models` 读取当前密钥可见的模型 ID，仍保留手动输入；模型列表只证明可见性，不保证模型可聊天。用户点“测试当前配置”时会用所选模型发起一条短流式聊天请求，验证结果只适用于当时的地址、密钥、模型和思考选项。测试请求可能产生少量 API 费用。

思考参数按服务地址与已知模型映射；未确认支持的组合保持服务端默认值，不发送猜测的字段。UI 只展示当前模型已确认的档位。新版 `auto` 表示不传思考参数，绝不宣称关闭思考。旧版 `none` 曾只设置 `temperature=0.75`，迁移为 `auto`。

参考官方资料：

- [OpenAI Chat Completions API](https://developers.openai.com/api/reference/resources/chat)：`reasoning_effort` 的可用档位随模型而异。
- [OpenAI Models API](https://developers.openai.com/api/reference/resources/models)：模型列表与模型能力是两件事。
- [DeepSeek Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion/) 与 [Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/)：`thinking.type` 控制开关，`reasoning_effort` 支持 low / high / max。
- [DeepSeek 变更记录](https://api-docs.deepseek.com/updates/)：当前主要模型 ID 与旧别名状态。
- [小米 MiMo Deep Thinking](https://platform.xiaomimimo.com/docs/en-US/usage-guide/passing-back-reasoning_content)：文档明确列出的 MiMo V2.5 模型可用 `thinking.type` 控制开关；其他模型暂用服务端默认行为。
- [硅基流动 Chat Completions](https://docs.siliconflow.cn/docs/api/chat-completions-post)：`enable_thinking` 和部分模型的 `reasoning_effort`。
- [Apple 本地网络 ATS 配置](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)：本机 Ollama HTTP 接口允许本地网络访问。

流式回复按原始字节保留 SSE 的空行消息边界，支持 LF、CRLF、CR、UTF-8 BOM 和多行 data 字段。不能使用会跳过空行的 `URLSession.AsyncBytes.lines` 来驱动依赖空行的 SSE 解析器，否则正常回复会被拼接成无效 JSON（2026-10-03 修复）。

本地回归检查：`Scripts/check_api_configuration.sh`，使用内存钥匙串、独立 UserDefaults、模拟模型列表和 URLProtocol 流式响应，不读取真实 API Key，也不访问外部模型服务。覆盖连接测试与聊天的中文内容、思考内容、消息边界、分片、异常响应和中断检查。另以 Xcode 的 macOS、iOS 通用目标构建检查 SwiftUI 界面。
