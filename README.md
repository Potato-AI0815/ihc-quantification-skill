# IHC & Immunofluorescence (IF) Quantification Skill v2.3.0-rc1

A reproducible, QC-first, auditable R/EBImage workflow for **brightfield DAB-IHC** and **multi-channel immunofluorescence (IF)** quantification.

> [!IMPORTANT]
> - **Brightfield DAB Workflow**: **Stable** (Full v2.2.2 backward compatibility maintained).
> - **Immunofluorescence (IF) Workflow**: **v2.3.0-rc1** (Multi-channel TIFF, 4-compartment MFI, Colocalization, Puncta detection, 8-panel QC).
> - **IF public-image runtime status**: **PASS_WITH_WARNINGS**; FluorescentCells uses a reviewed artifact-exclusion ROI and remains a teaching image rather than a biological replication benchmark.
> - **Current release gate**: **v2.3.0-rc1 READY**; exact main-commit Ubuntu/Windows CI pass ([Actions run 32555682952](https://github.com/Potato-AI0815/ihc-quantification-skill/actions/runs/32555682952)). Known limitation: OME-TIFF metadata workflows are not yet formally validated.
> - **Research Use Only (RUO)**: This tool is designed strictly for reproducible scientific image quantification and methodological auditing, not for clinical diagnosis, diagnostic screening, or treatment decision-making.

[English summary](README_EN.md) · [完整分析合同与规范 (SKILL.md)](SKILL.md) · [方法学与科学边界](docs/immunofluorescence_methodology.md) · [发布状态](RELEASE_STATUS.md)

---

## 核心特性与架构

```
                     ┌──────────────────────────────────────────────┐
                     │          manifest.csv (Input Router)         │
                     └──────────────────────┬───────────────────────┘
                                            │
                      ┌─────────────────────┴─────────────────────┐
                      ▼                                           ▼
         [modality: brightfield_dab]                 [modality: immunofluorescence]
                      │                                           │
                      ▼                                           ▼
           run_ihc_quantification.R                    run_if_quantification.R
       ┌───────────────────────────────┐           ┌────────────────────────────────┐
       │ • H-DAB Color Deconvolution   │           │ • Multi-channel TIFF & Z-stack │
       │ • DAB Optical Density (OD)    │           │ • Linear Fluorescence MFI/Int  │
       │ • Nuclear/Cyto H-scores (0-300│           │ • 4-Compartment Quantification │
       │ • Whole-tissue Burden %       │           │ • Colocalization (Pearson/M1/M2│
       │ • 4 Main Biological Figures   │           │ • Puncta / Foci Detection (DoG)│
       └───────────────────────────────┘           │ • 8-Panel IF QC Overviews      │
                                                   │ • 6 Main Publication Figures   │
                                                   └────────────────────────────────┘
```

---

## 核心能力

### 1. 明场 DAB-IHC 模态 (Stable v2.2.2)
- 默认执行排除已记录伪影后的 `GLOBAL` 全组织定量；
- 同时输出全局组织、细胞核、胞质和细胞外组织四个测量域；
- 自动生成 H-DAB 重建、八面板 QC、DAB OD 标尺、DAB 阳性阈值 mask、固定颜色域叠加和 ROI 证据切片；
- 自动输出四张独立主图（0–100% 阳性率或 0–300 H-score）。

### 2. 免疫荧光 IF 模态 (v2.3.0-rc1)
- Supports TIFF and ImageJ-compatible hyperstacks; OME-TIFF metadata workflows remain under validation;
- 已验证 8-bit、16-bit、32-bit 浮点及“12-bit 探测范围存于 16-bit 容器”的线性动态范围与饱和度 QC；原生打包 12-bit TIFF 尚未正式验证；
- 自动执行背景扣除（Rolling Ball / Top-hat）、通道配准与光照校正；
- 四域荧光定量：`GLOBAL`、`NUCLEUS`、`CYTOPLASM`、`EXTRACELLULAR`（严禁将自动细胞外区域标记为 stroma）；
- 单细胞 MFI、中位数强度、积分荧光强度（严格禁止称为 IOD）与核质比（N/C ratio）；
- 可选双标共定位模块（Pearson 相关系数 $r$、Manders $M_1/M_2$；colocalization does not establish molecular binding）；
- 可选亚细胞斑点/焦点计数（validated synthetic puncta counting workflow；$\gamma\text{H2AX}$、LC3、RNA-FISH）；
- 每张图自动生成标准化 8-Panel IF QC Overview。
- 可选的人工 IF 多边形 ROI：include 限定分析区域，exclude 排除烧录文字/伪影；原始图像不改写，并输出 ROI 像素审计表。

---

## 统计治理：生物学独立重复原则
- **生物学单位即统计单位**：所有主图与统计推断均以 `biological_unit_id`（患者、动物、独立样本）为单位（$n$），严禁将单细胞、视野或切片数目作为伪重复。
- 配对设计展示原始点与配对连线；样本量不足（$n < 2$）时自动标记 `NOT_EVALUABLE_N_LT_2`，拒绝伪显著性。

---

## 快速运行

### 运行合成集成测试 (DAB + IF + 共定位 + 焦点)
```bash
# Linux / macOS
bash tests/run_synthetic_smoke_test.sh

# Windows
powershell -ExecutionPolicy Bypass -File .\tests\run_synthetic_smoke_test.ps1
```

### 一键运行真实数据
```bash
# 自动根据 manifest.csv 中的 modality 列路由
bash run_one_click.sh \
  "input/manifest.csv" \
  "results/my_analysis_run" \
  "input/roi_annotations.csv" \
  "config/if_analysis_parameters_template.csv" \
  "Rlib" \
  "control,treatment"
```

---

## 详细文档指南
- [IF 方法学与科学边界](docs/immunofluorescence_methodology.md)
- [IF 图像输入与格式支持](docs/if_input_guide.md)
- [IF 通道映射与 Manifest 规范](docs/if_channel_mapping.md)
- [IF 分割与四域定义指南](docs/if_segmentation_guide.md)
- [IF 共定位分析指南](docs/if_colocalization_guide.md)
- [IF 斑点/焦点检测指南](docs/if_puncta_guide.md)
- [IF 质控与自动化 Flag 体系](docs/if_qc_guide.md)
- [公开 Benchmark 评测数据说明](docs/if_validation_datasets.md)
