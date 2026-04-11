#!/usr/bin/env node
/**
 * Update Skills Catalog
 * 
 * Scans project and global skills, extracts metadata from SKILL.md files,
 * and generates a markdown table in docs/context/skills-catalog.md
 * 
 * 特性：
 * - 优先使用 skill 内容中的 Trigger/Trigger Phrases/口令/触发
 * - 内置高质量中文映射表覆盖所有全局 skill
 * - 不截断，保持语义完整
 * - 全局技能优先排序
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = process.cwd();

// 全局 skill 路径：基于 HOME 目录动态推导，支持环境变量覆盖
const HOME = process.env.HOME || process.env.USERPROFILE || '/home/user';
const GLOBAL_SKILL_PATHS = (process.env.GLOBAL_SKILL_PATHS || '').split(':').filter(Boolean).length > 0
  ? process.env.GLOBAL_SKILL_PATHS.split(':').filter(Boolean)
  : [
      path.join(HOME, '.agents/skills'),
      path.join(HOME, '.cache/opencode/node_modules/superpowers/skills')
    ];

const PROJECT_SKILL_PATH = path.join(PROJECT_ROOT, '.opencode/skills');
const OUTPUT_PATH = path.join(PROJECT_ROOT, '.opencode/context/skills-catalog.md');

/**
 * 内置高质量中文映射表
 * 覆盖所有全局 skill，提供中文名、简介、触发条件
 * 仅当 skill 内容无法提取时使用
 */
const SKILL_OVERRIDES = {
  // 全局技能
  'skill-creator': {
    chineseName: '技能创建器',
    description: '创建、优化、评测技能',
    trigger: '需要新建/改造 skill 时'
  },
  'brainstorming': {
    chineseName: '头脑风暴',
    description: '通过协作对话将想法转化为完整的设计和规格文档',
    trigger: '需要进行功能设计、组件构建、行为修改等创造性工作时'
  },
  'systematic-debugging': {
    chineseName: '系统化调试',
    description: '通过根因分析、系统化方法定位和修复 bug',
    trigger: '遇到任何 bug、测试失败或意外行为时'
  },
  'using-superpowers': {
    chineseName: '使用超级技能',
    description: '建立如何查找和使用技能的框架，在任何响应前必须检查并调用相关 skill',
    trigger: '开启任何对话时'
  },
  'verification-before-completion': {
    chineseName: '完成前验证',
    description: '在声称工作完成、修复成功或测试通过前进行验证检查',
    trigger: '准备提交工作或创建 PR 前'
  },
  'writing-plans': {
    chineseName: '编写计划',
    description: '将需求或规格转化为多步骤实现计划',
    trigger: '有多步骤任务的需求或规格时'
  },
  'writing-skills': {
    chineseName: '编写技能',
    description: '创建新 skill、编辑现有 skill 或验证 skill 部署',
    trigger: '需要创建、改造或验证 skill 时'
  },
  'using-git-worktrees': {
    chineseName: '使用Git Worktree',
    description: '使用 git worktree 创建隔离的工作环境进行特性开发',
    trigger: '需要进行与当前工作区隔离的特性开发时'
  },
  'subagent-driven-development': {
    chineseName: '子智能体驱动开发',
    description: '使用子智能体执行独立任务的实现计划',
    trigger: '需要在当前会话中执行具有独立任务的实现计划时'
  },
  'receiving-code-review': {
    chineseName: '接收代码审查',
    description: '在实现审查建议前进行系统性分析和反馈处理',
    trigger: '收到代码审查反馈时'
  },
  'requesting-code-review': {
    chineseName: '请求代码审查',
    description: '在完成任务或实现主要功能后请求审查验证',
    trigger: '完成任务、准备合并代码或需要验证是否符合要求时'
  },
  'test-driven-development': {
    chineseName: '测试驱动开发',
    description: '先写失败测试，再写实现代码的开发模式',
    trigger: '实现任何功能或修复 bug 前'
  },
  'executing-plans': {
    chineseName: '执行计划',
    description: '在独立会话中执行书面实现计划，包含审查检查点',
    trigger: '有书面实现计划需要在单独会话中执行时'
  },
  'dispatching-parallel-agents': {
    chineseName: '并行任务分发',
    description: '同时分发多个子智能体处理相互独立的任务',
    trigger: '面临 2 个或以上可并行处理的独立任务时'
  },
  'finishing-a-development-branch': {
    chineseName: '完成开发分支',
    description: '在实现完成、测试通过后决定如何集成工作成果',
    trigger: '实现完成且所有测试通过时'
  },
  
  // 项目技能中文名映射（辅助）
  'skill01': {
    chineseName: '测试技能01'
  },
  'skill02': {
    chineseName: '可视化验收'
  },
  'history-timeline-export': {
    chineseName: '历史对话导出',
    description: '按指定时间范围导出会话任务摘要与时间线，并同步更新工作总结',
    trigger: '用户提出导出历史对话、按时间线导出会话、生成问答归档时'
  },
  'visual-acceptance': {
    chineseName: '可视化验收',
    description: '通过 Playwright 做页面视觉巡检并给出改进建议',
    trigger: '用户提出可视化验收、看效果、验收视觉/UI是否对齐时'
  },
  'skills-catalog-export': {
    chineseName: '技能目录导出',
    description: '导出并刷新 skills 目录文档，生成统一表格清单',
    trigger: '用户提出更新 skills 目录、导出 skills 清单、刷新 skills catalog 时'
  },
  'skill02': {
    chineseName: '可视化验收',
    description: '使用 YAML 用例驱动 Playwright 执行验收，输出报告与截图',
    trigger: '用户提出可视化验收、看效果、验收视觉/UI是否对齐时'
  }
};

/**
 * Parse YAML frontmatter from file content
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};
  
  const frontmatter = {};
  const lines = match[1].split('\n');
  
  for (const line of lines) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    
    const key = line.slice(0, colonIdx).trim();
    let value = line.slice(colonIdx + 1).trim();
    
    // Remove quotes if present
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    
    frontmatter[key] = value;
  }
  
  return frontmatter;
}

/**
 * Extract Chinese name from title line
 * e.g., "# skill02（可视化验收）" -> "可视化验收"
 */
function extractChineseName(content) {
  const titleMatch = content.match(/^#\s+\S+[（\(]([）\)]+)[）\)]\s*$/m);
  if (titleMatch) {
    return titleMatch[1];
  }
  return null;
}

/**
 * Extract trigger phrases from skill content
 * 支持: Trigger / Trigger Phrases / 口令 / 触发
 * 
 * 项目 skill：可从 Trigger/触发/When to Use 章节提取
 * 全局 skill：仅从 Trigger/触发章节提取（跳过 When to Use 避免提取 markdown）
 */
function extractTrigger(content, isProjectSkill = false) {
  const lines = content.split('\n');
  let inTriggerSection = false;
  const phrases = [];
  
  // 匹配各种触发字段标题（不区分大小写）
  // 项目 skill：包含 "When to Use" / "使用场景"
  // 全局 skill：只包含真正的触发章节
  const triggerHeadersProject = [
    /^##\s+[Tt]rigger[^\s]*/i,
    /^##\s+[Tt]rigger\s+[Pp]hrases/i,
    /^##\s+[Tt]rigger\s+[Cc]onditions/i,
    /^##\s+触发$/,
    /^##\s+口令$/,
    /^##\s+触发条件$/,
    /^##\s+Activation/i,
    /^##\s+[Ww]hen\s+to\s+[Uu]se/i,
    /^##\s+使用场景/i,
    /^#\s+[Tt]rigger/i,
    /^#\s+触发/i
  ];
  
  const triggerHeadersGlobal = [
    /^##\s+[Tt]rigger[^\s]*/i,
    /^##\s+[Tt]rigger\s+[Pp]hrases/i,
    /^##\s+[Tt]rigger\s+[Cc]onditions/i,
    /^##\s+触发$/,
    /^##\s+口令$/,
    /^##\s+触发条件$/,
    /^##\s+Activation/i,
    /^#\s+[Tt]rigger/i,
    /^#\s+触发/i
  ];
  
  const triggerHeaders = isProjectSkill ? triggerHeadersProject : triggerHeadersGlobal;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // 检查是否是触发相关 section 标题
    const isTriggerHeader = triggerHeaders.some(regex => regex.test(line));
    
    if (isTriggerHeader) {
      inTriggerSection = true;
      continue;
    }
    
    // 如果在触发 section 内，遇到新标题则退出
    if (inTriggerSection && /^##?\s+/.test(line) && !triggerHeaders.some(regex => regex.test(line))) {
      break;
    }
    
    // 收集触发项
    if (inTriggerSection) {
      // 跳过 markdown 代码块
      if (line.trim().startsWith('```') || line.trim() === '```') {
        continue;
      }
      
      // 处理列表项
      const listMatch = line.match(/^[-*`]\s*(.+)$/);
      if (listMatch) {
        const cleaned = listMatch[1].trim();
        // 全局 skill：过滤掉包含 markdown 格式的项（*、``、`）
        // 项目 skill：不过滤，保留中文触发条件
        const shouldFilter = !isProjectSkill;
        if (cleaned && !cleaned.startsWith('#') && 
            (!shouldFilter || (!cleaned.includes('*') && !cleaned.includes('``'))) &&
            cleaned.length > 2) {
          phrases.push(cleaned);
        }
      }
    }
  }
  
  if (phrases.length > 0) {
    return phrases.join('；');
  }
  
  return null;
}

/**
 * Scan a directory for SKILL.md files
 */
function scanSkillDirectory(dirPath) {
  const skills = [];
  
  if (!fs.existsSync(dirPath)) {
    return skills;
  }
  
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    
    const skillPath = path.join(dirPath, entry.name, 'SKILL.md');
    
    if (fs.existsSync(skillPath)) {
      skills.push({
        name: entry.name,
        path: skillPath
      });
    }
  }
  
  return skills;
}

/**
 * 翻译英文描述为中文（用于无覆盖的情况）
 */
function translateDescription(desc) {
  // 常见英文描述的中文翻译
  const translations = {
    'You MUST use this before any creative work': '在任何创造性工作之前必须使用',
    'Use when facing 2+ independent tasks': '当面临 2 个或以上独立任务时使用',
    'Use when you have a written implementation plan': '当有书面实现计划时使用',
    'Use when implementation is complete': '当实现完成时使用',
    'Use when receiving code review feedback': '收到代码审查反馈时使用',
    'Use when completing tasks': '完成任务时使用',
    'Use when executing implementation plans': '执行实现计划时使用',
    'Use when encountering any bug': '遇到任何 bug 时使用',
    'Use when implementing any feature': '实现任何功能时使用',
    'Use when starting feature work': '开始特性工作时使用',
    'Use when starting any conversation': '开启任何对话时使用',
    'Use when about to claim work is complete': '准备声称工作完成时使用',
    'Use when you have a spec': '有规格文档时使用',
    'Use when creating new skills': '创建新 skill 时使用',
    'Use when users ask to': '当用户要求',
    'Use when reviewing prototype': '审查原型时使用'
  };
  
  for (const [en, zh] of Object.entries(translations)) {
    if (desc.includes(en)) {
      return zh;
    }
  }
  
  return null; // 无法翻译
}

/**
 * Process a single skill file and extract metadata
 */
function processSkill(skillPath, category) {
  const content = fs.readFileSync(skillPath, 'utf-8');
  const frontmatter = parseFrontmatter(content);
  
  const name = frontmatter.name || path.basename(path.dirname(skillPath));
  let description = frontmatter.description || '';
  
  const isProjectSkill = category === '本项目';
  
  // 1. 优先从内容提取中文名
  let chineseName = extractChineseName(content);
  
  // 2. 检查覆盖表
  if (!chineseName && SKILL_OVERRIDES[name]?.chineseName) {
    chineseName = SKILL_OVERRIDES[name].chineseName;
  }
  chineseName = chineseName || name;
  
  // 3. 提取触发条件（优先从内容，根据 skill 类型选择提取逻辑）
  let trigger = extractTrigger(content, isProjectSkill);
  
  // 4. 如果内容没有触发条件，使用覆盖表
  if (!trigger && SKILL_OVERRIDES[name]?.trigger) {
    trigger = SKILL_OVERRIDES[name].trigger;
  }
  
  // 5. 如果是全局 skill 且无触发条件，标记为需要查看 skill 描述
  if (!trigger && category === '全局') {
    trigger = '见 skill 描述';
  }
  
  // 6. 处理描述
  let finalDescription = description;
  
  // 如果描述是英文且有覆盖表的中文，使用中文
  if (SKILL_OVERRIDES[name]?.description) {
    finalDescription = SKILL_OVERRIDES[name].description;
  } else if (description && !/[\u4e00-\u9fa5]/.test(description)) {
    // 英文描述，尝试翻译
    const translated = translateDescription(description);
    if (translated) {
      finalDescription = translated;
    }
  }
  
  // 如果还是没有描述，使用英文但不加截断
  if (!finalDescription) {
    finalDescription = description || '无简介';
  }
  
  return {
    name,
    chineseName,
    description: finalDescription,
    trigger: trigger || '见 skill 描述',
    path: skillPath,
    category
  };
}

/**
 * Generate markdown table (不截断)
 */
function generateTable(skills) {
  // 排序：全局优先，然后按英文名排序
  skills.sort((a, b) => {
    if (a.category !== b.category) {
      return a.category === '全局' ? -1 : 1;
    }
    return a.name.localeCompare(b.name, 'en');
  });
  
  const header = `| 分类 | 中文名 | 英文名 | 简介 | 触发条件 | 文件路径 |
|------|--------|--------|------|----------|----------|
`;
  
  const rows = skills.map(s => {
    // 不截断，保持语义完整
    const desc = s.description;
    const trigger = s.trigger;
    
    return `| ${s.category} | ${s.chineseName} | ${s.name} | ${desc} | ${trigger} | ${s.path} |`;
  }).join('\n');
  
  return header + rows;
}

/**
 * Main function
 */
function main() {
  console.log('Updating skills catalog...\n');
  
  const allSkills = [];
  
  // Scan project skills
  console.log(`Scanning project skills: ${PROJECT_SKILL_PATH}`);
  const projectSkills = scanSkillDirectory(PROJECT_SKILL_PATH);
  for (const skill of projectSkills) {
    try {
      const metadata = processSkill(skill.path, '本项目');
      allSkills.push(metadata);
      console.log(`  ✓ ${skill.name}`);
    } catch (err) {
      console.error(`  ✗ ${skill.name}: ${err.message}`);
    }
  }
  
  // Scan global skills
  for (const globalPath of GLOBAL_SKILL_PATHS) {
    console.log(`\nScanning global skills: ${globalPath}`);
    
    if (!fs.existsSync(globalPath)) {
      console.log(`  Path does not exist, skipping`);
      continue;
    }
    
    const globalSkills = scanSkillDirectory(globalPath);
    for (const skill of globalSkills) {
      try {
        const metadata = processSkill(skill.path, '全局');
        
        // 避免重复（优先项目版本）
        const existing = allSkills.find(s => s.name === metadata.name);
        if (existing) {
          console.log(`  - ${skill.name} (skipped, project version exists)`);
          continue;
        }
        
        allSkills.push(metadata);
        console.log(`  ✓ ${skill.name}`);
      } catch (err) {
        console.error(`  ✗ ${skill.name}: ${err.message}`);
      }
    }
  }
  
  // Generate output
  const table = generateTable(allSkills);
  const output = `# Skills Catalog

> 自动生成，请勿手动编辑
> 生成时间: ${new Date().toISOString()}

${table}

---
*本目录由 .opencode/skills/skills-catalog-export/scripts/update-skills-catalog.mjs 自动维护*
`;
  
  // Ensure output directory exists
  const outputDir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  fs.writeFileSync(OUTPUT_PATH, output, 'utf-8');
  
  console.log(`\n✓ Generated: ${OUTPUT_PATH}`);
  console.log(`  Total skills: ${allSkills.length}`);
}

main();
