---
name: skills-catalog-export
description: Use when users ask to list, export, or refresh the full skills catalog table with category, bilingual names, description, trigger conditions, and file paths.
---

# skills-catalog-export

## Overview
用于导出并更新 Skills 目录文档。每次触发都执行一次重建，确保文档与当前技能文件同步。

## Trigger Phrases（固定口令）
- `更新 skills 目录`
- `导出 skills 清单`
- `刷新 skills catalog`

## Workflow
1. 运行命令：`npm run skills:catalog`
2. 确认输出文件：`docs/context/skills-catalog.md`
3. 返回更新结果（技能总数 + 文件路径）

## Script
- `./scripts/update-skills-catalog.mjs`

## Output
- `docs/context/skills-catalog.md`（自动生成）
