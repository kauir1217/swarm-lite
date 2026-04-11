# 多智能体协作项目模板（Lite）

基于 OpenCode 的多智能体协作框架轻量版，提供完整的角色体系和通用技能，无记忆系统依赖。

> 与完整版模板（tmpl）的区别：去掉了跨 session 记忆系统（mem/），不需要 Python 依赖，更适合短期项目或不需要持久化状态管理的场景。

## 快速开始

### 1. 复制模板

```bash
cp -r tmpl-lite my-project
cd my-project
```

### 2. 初始化项目

#### 交互模式

```bash
bash scripts/init-project.sh
```

#### 非交互模式

```bash
bash scripts/init-project.sh --name MyProject --goal "项目目标描述"
```

可选参数：
- `--repo-path` — 代码仓库本地路径
- `--readonly` — 外部只读目录（逗号分隔）
- `--install` — 初始化后自动安装依赖

> `init-project.sh` 默认只负责初始化配置文件；交互模式下会询问是否顺便安装依赖。

### 3. 安装依赖

```bash
# 一键初始化 + 安装
bash scripts/bootstrap.sh

# 或单独安装
bash scripts/install-deps.sh
```

#### 全局工具（按需安装）

模板中的部分 Skill 依赖全局工具，按需安装：

```bash
# superpowers — 提供 brainstorming、TDD、debugging 等方法论 Skill
# 安装到 OpenCode 全局 package.json（~/.cache/opencode/package.json）
# 在该文件的 dependencies 中添加：
#   "superpowers": "git+https://github.com/obra/superpowers.git"
# 然后在 ~/.cache/opencode/ 目录下执行 npm install

# agent-browser — 浏览器自动化 CLI，供 browser-copilot 等 Skill 使用
npm install -g agent-browser
```

如果暂时不使用浏览器或方法论 Skill，可先跳过；后续需要时再安装即可。

### 4. 开始使用

用 OpenCode 打开项目目录即可开始多智能体协作。

## 项目结构

```
.
├── AGENTS.md                          # 统一基线规则
├── README.md                          # 本文件
├── package.json                       # npm scripts
├── opencode.jsonc                     # OpenCode 配置
├── .env.example                       # 环境变量模板
├── .gitignore
├── scripts/
│   ├── init-project.sh                # 初始化向导
│   ├── bootstrap.sh                   # 一键初始化+安装
│   └── install-deps.sh               # 依赖安装
├── docs/                              # 文档体系
│   ├── 文档导航.md                     # 文档索引
│   ├── guides/                        # 操作指南
│   ├── specs/                         # 设计规格
│   ├── plans/                         # 实施计划
│   ├── decisions/                     # 决策记录
│   ├── prototypes/                    # 原型文件
│   ├── reports/                       # 分析报告
│   └── notes/                         # 临时笔记
└── .opencode/
    ├── project-context.yaml           # 项目上下文配置
    ├── package.json                   # OpenCode 插件依赖
    ├── agents/                        # 9 个智能体角色
    │   ├── overmind.md                 # 主宰（调度中枢）
    │   ├── explorer.md                # 代码与配置定位
    │   ├── librarian.md               # API/文档考据
    │   ├── oracle.md                  # 高风险决策与权衡
    │   ├── designer.md                # 界面设计（多模态）
    │   ├── fixer.md                   # 明确规格下实施改动
    │   ├── council.md                 # 高争议双模型裁决
    │   ├── councillor-alpha.md        # 议员 Alpha（只读分析）
    │   └── councillor-beta.md         # 议员 Beta（只读分析）
    └── skills/                        # 通用技能
        ├── browser-copilot/           # 浏览器协同操作
        ├── outline-first-writing/     # 长文写作大纲优先
        ├── history-timeline-export/   # 历史对话导出
        ├── skills-catalog-export/     # 技能目录导出
        └── windows-vpn-localhost-proxy/ # VPN 本地代理
```

## 角色体系

模板预配置了 9 个智能体角色，分为 **主智能体**、**子智能体** 和 **隐藏智能体** 三层：

### 主智能体（Primary）

| 角色 | 代号 | 模型 | 说明 |
|------|------|------|------|
| 主宰 | overmind | claude-opus-4.6 | **调度中枢**。以最快路径自主推进任务，能内部消化的问题不打断用户。负责任务分解、子智能体委派、结果验证与汇报。决策升级路径：自判 → 咨询 @oracle → 才问用户 |
| 议会 | @council | claude-opus-4.6 | **并行裁决器**。仅在高争议问题需要双模型独立裁决时启用，同时调度两位议员下发相同证据包，收集独立分析后汇总裁决 |

### 子智能体（Subagent）

由主智能体按需委派，各自聚焦专业领域：

| 角色 | 代号 | 模型 | 说明 |
|------|------|------|------|
| 追风探子 | @explorer | gpt-5.4 | **代码与配置定位**。快速搜索代码库、配置文件和日志，输出高置信线索地图，不修改任何文件 |
| 藏经阁主 | @librarian | gpt-5.4 | **API/文档考据**。提供官方文档级的 API 用法、版本差异和最佳实践依据，降低误用风险 |
| 天机长老 | @oracle | gpt-5.4 | **高风险决策与权衡**。处理架构选型、性能/维护性取舍、失败恢复策略等复杂权衡，给出可执行、可解释的技术路径 |
| 妙手画师 | @designer | gemini-3.1-pro-preview | **界面设计**（多模态模型）。负责 UI 可用性与一致性审查，产出可验收的设计结论。原型修改需新建文件，不覆盖历史版本 |
| 神工匠徒 | @fixer | gpt-5.4 | **实施改动**。在明确规格下快速、准确地完成代码编写和修改，保证改动可验证。不做架构决策，不做需求解读 |

### 隐藏智能体（Hidden）

由 @council 专属调度，用户不直接交互。使用**异构模型**确保独立视角，且禁止编辑文件或执行命令（只读分析）：

| 角色 | 代号 | 模型 | 说明 |
|------|------|------|------|
| 议员 Alpha | @councillor-alpha | gpt-5.4 | 基于证据包独立分析，给出结论、依据、风险与置信度。不推测另一位议员观点 |
| 议员 Beta | @councillor-beta | claude-opus-4.6 | 同上，使用不同模型以保证分析独立性。两位议员收到相同证据但各自独立产出 |

### 协作流程

```
用户请求 → overmind 自主推进
              ├── 需要定位代码 → @explorer
              ├── 需要查文档 → @librarian
              ├── 需要技术决策 → @oracle
              ├── 需要界面设计 → @designer
              ├── 需要写代码 → @fixer
              └── 高争议裁决 → @council
                                 ├── @councillor-alpha (gpt-5.4)
                                 └── @councillor-beta  (claude-opus-4.6)
```

## 与完整版（tmpl）的区别

| 特性 | tmpl（完整版） | tmpl-lite（本模板） |
|------|---------------|-------------------|
| 角色体系 | ✅ 9 个角色 | ✅ 9 个角色 |
| 通用 Skill | ✅ 5 个 | ✅ 5 个 |
| 记忆系统 | ✅ 完整（mem/） | ❌ 无 |
| 跨 session 状态 | ✅ 自动交接 | ❌ 无（OpenCode 内置 autocompact 仅压缩当前会话上下文，不提供跨 session 持久状态） |
| Python 依赖 | ✅ 需要 3.8+ | ❌ 不需要 |
| 适用场景 | 长期项目、需要跨会话持久状态 | 短期项目、独立任务、快速验证 |

## 环境要求

- Node.js 18+
- Bash 4+
- OpenCode CLI ≥ 1.3.0
