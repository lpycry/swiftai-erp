# swiftAI ERP 系统：物料清单（BOM）主数据开发需求说明书 (FSD)

---

## 一、 文档概述

### 1.1 目的
本文档旨在详细定义 **swiftAI ERP** 系统中**物料清单（Bill of Material, 简称 BOM）**主数据的底层数据库建模、后端（Go）业务逻辑校验、API 接口规范以及前端（Flutter）的交互需求。

### 1.2 业务背景与设计愿景
BOM 是制造、仓储和财务的绝对核心数据。销售模块（SD）根据 BOM 评估定制化产品的成本；生产模块（PP）依赖 BOM 进行 **MRP 需求爆炸**与车间投料；仓储模块（iWMS）根据 BOM 组件进行**物料预留（Reservation）与拣货组单**。
本模块设计追求**高并发读取、严密的版本控制（Version Control）以及防止无限递归的防错机制**，为后续智能化供应链打下坚实基础。

---

## 二、 业务场景与核心规则定义

### 2.1 基础概念说明
* **父项物料（Header Material）**：通常是成品（Finished Goods）或半成品（Half Finished Goods）。
* **子项组件（Component/Child Material）**：制造父项所需的原材料（Raw material）、半成品或辅料。
* **BOM 用途（BOM Usage）**：同一物料在不同部门有不同结构。本系统首期聚焦于 **生产 BOM（Production BOM）**。
* **BOM 版本（BOM Version/Alternative BOM）**：同一成品由于工艺改进或配方替代，可存在多个并存的有效版本。

### 2.2 核心业务控制逻辑
1.  **物料属性校验**：只有物料主数据中Procurement Type为“In House”或“Mixed”的物料，才允许创建为 BOM 的父项。纯“Purchase”不允许创建 BOM 抬头。
2.  **严禁循环引用（Anti-Loop Checking）**：系统在保存或更新 BOM 时，必须进行递归拓扑校验。**绝对禁止出现“A 包含 B，B 包含 C，C 又包含 A”的闭环结构**，否则会导致 MRP 引擎死锁崩溃。
3.  **有效期控制**：BOM 抬头和子项必须包含 `valid_from`（生效日期）和 `valid_to`（失效日期）。MRP 和生产订单在引入 BOM 时，必须根据“计划开工时间”抓取处于有效期内的活动版本。

---

## 三、 底层数据架构需求 (PostgreSQL)

BOM 是一种典型的树状拓扑结构，在关系型数据库中，我们通过**抬头表（Header）**与**项目表（Item）**的一对多关联来实现。

### 3.1 BOM 抬头表 (`bom_headers`)

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `bom_id` | UUID | PRIMARY KEY | BOM全局唯一标识 (默认 gen_random_uuid()) |
| `tenant_id` | UUID | NOT NULL | 多租户隔离 ID |
| `material_id` | UUID | NOT NULL | 父项物料ID (关联 materials 表) |
| `bom_version` | VARCHAR(10) | NOT NULL | BOM 版本号 (如 V1.0, V1.1) |
| `bom_usage` | VARCHAR(10) | DEFAULT 'PRODUCTION' | 用途：PRODUCTION(生产), COSTING(成本) |
| `status` | VARCHAR(10) | DEFAULT 'NEW' | 状态：NEW(草稿), ACTIVE(激活), INACTIVE(失效) |
| `base_qty` | DECIMAL(18, 4)| DEFAULT 1.0000 | 基本数量 (如生产 1 个成品需要...) |
| `valid_from` | TIMESTAMP | NOT NULL | 生效日期 |
| `valid_to` | TIMESTAMP | NOT NULL | 失效日期 |
| `created_at` | TIMESTAMP | DEFAULT NOW() | 创建时间 |
| `created_by` | UUID | - | 创建人 ID |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | 更新时间 |
| `updated_by` | UUID | - | 更新人 ID |


> **联合唯一索引**：`UNIQUE(tenant_id, material_id, bom_version)`

### 3.2 BOM 行项目表 (`bom_items`)

| 字段名 | 类型 | 约束 | 描述 |
| :--- | :--- | :--- | :--- |
| `item_id` | UUID | PRIMARY KEY | 行项目全局唯一标识 |
| `bom_id` | UUID | FK, NOT NULL | 关联 bom_headers(bom_id) ON DELETE CASCADE |
| `item_position` | INT | NOT NULL | 行号 (如 10, 20, 30) |
| `component_id` | UUID | NOT NULL | 子项物料ID (关联 materials 表) |
| `quantity` | DECIMAL(18,4)| NOT NULL | 组件消耗数量 |
| `unit_of_measure`| VARCHAR(10) | NOT NULL | 单位 |
| `scrap_factor` | DECIMAL(5, 4) | DEFAULT 0.0000 | 物料损耗率 (如 0.02 代表 2% 损耗) |
| `is_phantom_item`| BOOLEAN | DEFAULT FALSE | 是否为虚拟件 (不产生物理仓储，直接穿透) |
| `valid_from` | TIMESTAMP | NOT NULL | 子项独有的生命周期开始时间 |
| `valid_to` | TIMESTAMP | NOT NULL | 子项独有的生命周期结束时间 |
| `remark` | TEXT | - | 备注备注 |

---

## 四、 后端功能与算法需求 (Go Engine)

### 4.1 创建 BOM (Create) 与死循环校验算法
当用户或外部系统提交一个 BOM 的 JSON 结构时，Go 后端必须执行以下逻辑流：
1.  **主数据前置校验**：查询父项 `material_id` 的属性，确保可制。
2.  **死循环拓扑校验（关键算法）**：
    * 在写入数据库前，必须在内存中构建临时有向图（Directed Graph）。
    * **算法逻辑**：从当前准备添加的所有 `component_id` 出发，深度优先遍历（DFS）它们各自已有的底层 BOM 结构。如果在其任意一条下游子孙链路中，发现任何子节点的 `material_id` 等于当前准备创建的父项 `material_id`，则判定存在**循环引用漏洞**。
    * **异常处理**：中断事务，强行抛出错误代码 `409_BOM_LOOP_DETECTED`，并返回造成死循环的链路路径（如：`A -> B -> C -> A`）。

### 4.2 读取 BOM (Read) —— 支持单层与多层展平（BOM Explosion）
读取接口除了支持标准的分页查询和详情级联返回外，必须额外提供一个高级计算接口：**BOM 爆炸接口 (`/api/v1/bom/explode`)**。
* **输入参数**：`material_id`, `bom_version`, `explosion_type` (`single` 单层 / `multi` 多层展平), `requirement_qty` (需求数量)。
* **后端行为**：若为 `multi`，后端通过 Go 协程（Goroutine）或递归高效查询 PostgreSQL，将多层嵌套树打平。自动将每一层的数量乘以累加系数，并应用损耗率计算公式：
  $$\text{实际组件计算需求量} = \frac{\text{上层父项数量} \times \text{BOM组件用量}}{1 - \text{scrap\_factor}}$$
* **输出格式**：返回带有层级（`level`: 1, 2, 3...）的扁平化 JSON 数组，供 WMS 或生产订单直接调用。

### 4.3 更新 BOM (Update) 控制
* **状态锁**：如果当前 BOM 的状态已被标记为 `ACTIVE`，且已经被任何处于 `REL（已下达）` 或 `PCNF（部分报工）` 状态的生产订单（Production Order）所引用，则**禁止直接修改任何行项目（BOM Items）的数量和组件物料**。
* **正确变更方式**：用户必须将原版本标记为 `INACTIVE` 或截断其 `valid_to` 日期，然后复制创建一个全新的 `bom_version`（如从 V1.0 升级到 V2.0）。

### 4.4 删除 BOM (Delete)
* **一律采用逻辑删除（Soft Delete）**：禁止物理擦除数据。更新 `bom_headers.status = 'INACTIVE'` 且 `valid_to = NOW()`。
* **引用检查**：如果该 BOM 正在被其他半成品或成品作为子项组件使用（即在其他 BOM 的 `bom_items` 中作为 `component_id` 存在且在有效期内），系统应阻止删除，提示：“*该物料正在被成品 X 引用，请先在成品 X 的 BOM 中移除该组件。*”

---

## 五、 前端 UI/UX 交互设计需求 (Flutter)

### 5.1 BOM 编辑器界面设计（双栏或抽屉式）
* **表单录入网格（Grid Tool）**：子项录入摒弃传统的弹窗确认，采用类似 Excel 的行内编辑网格。
* **快捷键与模糊搜索支持**：在行尾点击 `Enter` 直接在下方插入新行；在组件编码输入框中支持 **模糊联想搜索**（输入拼音或部分编码自动异步拉取前 10 条物料主数据并带出单位）。
* **自动算账**：当用户修改某一行组件的“损耗率”或“单机用量”时，界面实时计算出该组件在标准批产数量下的**实际应拨总量**。

### 5.2 树形多层动态可视化看板（Tree View）
* 针对已激活的多层 BOM，提供专门的 **树形结构视图组件（Flutter TreeView）**。
* **交互规范**：节点支持展开与折叠；不同物料属性（如半成品、原材料、虚拟件）在树节点上显示不同的高亮图标；点击任何一个子节点，右侧侧边栏（Drawer）优雅滑出，展示该子项的当前仓储库存、主供应商以及近期采购价格。

---

## 六、 接口规范示例 (API Definition)

### 6.1 创建 BOM 接口
* **Endpoint**: `POST /api/v1/bom`
* **Request Body**:
```json
{
  "material_id": "8f3b9c2a-7e14-41d3-b183-1c390508a111",
  "bom_version": "V1.0",
  "base_qty": 1.0,
  "valid_from": "2026-06-10T00:00:00Z",
  "valid_to": "2099-12-31T23:59:59Z",
  "items": [
    {
      "item_position": 10,
      "component_id": "4a5c8e1d-2b3c-4d5e-6f7a-8b9c0d1e2f3a",
      "quantity": 2.5000,
      "unit_of_measure": "PCS",
      "scrap_factor": 0.0100
    },
    {
      "item_position": 20,
      "component_id": "3f5b7c1a-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
      "quantity": 0.1500,
      "unit_of_measure": "KG",
      "scrap_factor": 0.0000
    }
  ]
}