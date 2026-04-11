---
name: history-timeline-export
description: Use when users ask to export conversation history for a specified time range as summary and timeline documents, keeping user requests and assistant responses while excluding intermediate execution details.
---

# history-timeline-export

## Overview
将指定时间范围会话导出为两份文档：
- 任务摘要（总结性）
- 时间线（按“需求-动作-结果”）

内容层面仅保留用户提问与助手回答语义，不包含中间执行细节（工具调用、命令日志、思考过程）。

## Trigger Phrases
- `导出历史对话`
- `按时间线导出会话`
- `生成问答归档`
- `导出最近7天对话`
- `导出指定时间范围对话`

## Output Files
默认输出到 `docs/context/`：
- `session-summary-range.md`（指定范围任务摘要）
- `session-timeline-range.md`（指定范围时间线）
- `工作总结.md`（总结性归档）

## Workflow
1. 确认时间范围（默认最近7天；也可用户指定起止日期）。
2. 收集该范围内用户问题与助手回答要点。
3. 生成任务摘要文档：`session-summary-range.md`。
4. 生成时间线文档：`session-timeline-range.md`（时间点 + 需求/动作/结果）。
5. 返回导出范围与文档路径。
6. 同步更新 `docs/context/工作总结.md`（汇总本周期完成项与下一步）。

## Formatting Rules
- 摘要文档：按主题分块（目标、产出、验证、风险、下一步）。
- 时间线文档：每条必须包含时间点、需求、动作、结果。
- 允许概述式压缩，但语义需保持一致。
- 对关键里程碑附带文件路径。
- `工作总结.md` 使用周报模板，且必须包含“团队表现点评（表格）”章节。
