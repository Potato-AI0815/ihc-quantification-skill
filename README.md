# IHC Quantification Skill v2.2.2

面向 DAB/苏木精明场 IHC 图像的通用、可追溯、可复现 R/EBImage 定量工作流。它用于科研图像定量和方法学审计，不用于诊断、疗效判定或自动病理分类。

[English summary](README_EN.md) · [完整分析合同](SKILL.md) · [发布检查表](GITHUB_RELEASE_CHECKLIST.md) · [GitHub 上传说明](UPLOAD_TO_GITHUB.md)

## 作为 AI Skill 安装

**Skill 名称：** `ihc-quantification`

> 仓库名 ≠ Skill 名。Skill ID 是 `ihc-quantification`，仓库是 `Potato-AI0815/ihc-quantification-skill`。

**安装：**

```bash
npx skills add Potato-AI0815/ihc-quantification-skill \
  --skill ihc-quantification
```

Public GitHub installation: verified.

## 核心能力

- 默认执行排除已记录伪影后的 `GLOBAL` 全组织定量；
- 同时输出全局组织、细胞核、胞质和细胞外组织四个测量域；
- 支持经审核的 tumor、stroma、interface 和 custom ROI，但不会从单染 IHC 自动推断这些组织学身份；
- 自动生成 H-DAB 重建、八面板 QC、DAB OD 标尺、DAB 阳性阈值 mask、固定颜色域叠加和 ROI 小框证据图；
- 自动输出四张独立主图：全局 DAB 阳性面积率、核 H-score、胞质 H-score和细胞外 DAB 阳性面积率；
- 主图采用浅色条形背景、生物学单位原始点和重复单位连线；
- 发布图默认固定量程：面积率 0–100%，H-score 0–300；可选 zoomed 图仅作为 QC 诊断；
- 当每组 `n=1` 时，不绘制或声称 SE，并明确标注为描述性结果；
- 统计单位固定为 `biological_unit_id`，不把细胞、视野、切片或 ROI 当作独立样本。

## 环境

已获得的运行证据包括 Windows 11、R 4.5.3、EBImage 4.52.0 和 data.table 1.18.2.1。具体状态见 `RELEASE_STATUS.md` 和 `RUNTIME_COMPATIBILITY.md`。

安装依赖：

```powershell
Rscript .\scripts\install_dependencies.R --lib=.\Rlib
```

## 先运行合成测试

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_synthetic_smoke_test.ps1
```

Linux/macOS：

```bash
bash tests/run_synthetic_smoke_test.sh
```

测试会验证四域数值、八面板 QC、H-DAB、DAB 阳性 mask、固定纵轴、低样本量图注、配对状态和输出文件完整性。

## 真实数据一键运行

```powershell
.\run_one_click.ps1 `
  -Manifest ".\input\manifest.csv" `
  -Outdir ".\results\ihc_run" `
  -Roi ".\input\roi_annotations.csv" `
  -Config ".\references\templates\analysis_parameters_template.csv" `
  -ConditionOrder "control,treatment"
```

没有 ROI 文件时仍会完成 GLOBAL 分析。原图不会被覆盖。

## 默认主图规则

| 测量域 | 默认指标 | 发布纵轴 |
|---|---|---:|
| Global | tissue DAB-positive area fraction | 0–100% |
| Nucleus | nuclear H-score | 0–300 |
| Cytoplasm | cytoplasmic H-score | 0–300 |
| Extracellular | extracellular DAB-positive area fraction | 0–100% |

将配置中的 `generate_zoomed_plots` 改为 `true` 可额外输出数据缩放图，但文件名会带 `_zoomed`，且仅应用于阈值和分割复核。

## 数据隐私

公开仓库只应包含 `tests/synthetic_fixture/` 中的合成图像。不要提交真实 TIFF、WSI、样本编号、本地绝对路径、资产登记表或未经授权的 QC/结果图。发布前运行：

```bash
python scripts/preflight_public_release.py
```

## GitHub CI 前本地预检

```bash
cp .private_tokens.example .private_tokens.txt
# 在 .private_tokens.txt 中逐行加入本地样本编号、用户名、项目代号或私有目录名
python scripts/static_validate_package.py
python scripts/preflight_public_release.py
python scripts/verify_package_manifest.py
```

`.private_tokens.txt` 已被 `.gitignore` 排除。仓库中允许公开的图像仅限 `tests/synthetic_fixture/images/`（以及未来明确建立的 `docs/assets/synthetic/`）。

## 许可与引用

代码采用 MIT License。引用信息见 `CITATION.cff`。发表时还应按照 R 中 `citation("EBImage")` 的结果引用 EBImage。

## 关键边界

- 缺少 `pixel_size_um` 时会使用显式像素回退并产生 QC 警告；原图中可见的比例尺不等于程序获得了物理校准。
- 单染图像不能可靠决定 tumor/stroma/interface 或特定细胞身份。
- H-score 适用于经验证的细胞域，不适用于细胞外组织。
- marker-specific 阈值、染色向量、分割参数和批次稳定性仍需人工验证。
