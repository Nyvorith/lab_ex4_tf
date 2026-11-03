# 名画展陈音视频导览系统

基于安路 EG4S20 / HX4S20C 的脱机 HDMI 展陈终端，主题为“光与色：从自然到思想”。图片读取、缩放、SDRAM 缓存、交互、字幕与音频处理由 FPGA 完成。

## 下载与素材

固件：`release/final_subtitlewave_20261101/exhibition_final_subtitlewave.bit`。

TF 卡采用 FAT32，将 `release/final_subtitlewave_20261101/tf_card` 内的四张 BMP 和四个 PCM 文件复制到根目录。显示器连接 HDMI B。视频输出为640×480，画作按原比例适配；显示器的宽屏拉伸由显示器设置决定。默认亮度220、对比度128、静音。

## 操作

| 按键 | 短按 | 长按 |
| --- | --- | --- |
| KEY1 | 复位 | — |
| KEY2 | 下一张；预览时移动选择 | 全图调节亮度 |
| KEY3 | 预览／返回 | 开关解说 |
| KEY4 | 开关自动轮播；预览时确认 | 全图调节对比度 |

手动翻页淡出淡入，自动轮播停留119帧（约2秒）后横向翻页。进入自动模式停止解说，退出后按解说开关状态从头播放当前作品；静音状态保持静音。手动解说时显示同步滚动字幕及真实PCM时域波形，横向为时间采样顺序、纵向为正负采样幅度。解说结束后隐藏，重新开关解说可重听。

预览界面提供四宫格、画名、作者年代和观看提示。四幅全图常驻SDRAM，预热后翻页复用缓存。参数调节后短暂显示数值，不常驻遮挡画作。

## 作品

| 文件 | 作品 | 素材像素 | 主题 |
| --- | --- | --- | --- |
| PIC1.BMP | 莫奈《埃特勒塔的大拱门》 | 640×480 | 光影初见 |
| PIC2.BMP | 北斋《神奈川冲浪里》 | 960×645 | 浪潮律动 |
| PIC3.BMP | 梵高《麦田与柏树》 | 960×764 | 色彩情绪 |
| PIC4.BMP | 大卫《苏格拉底之死》 | 960×639 | 理性回响 |

AUDIO1.PCM～AUDIO4.PCM分别对应四幅画，格式为48kHz、16位有符号小端、单声道原始PCM。图片来源与授权说明见 `doc/素材来源.json`。

## 工程

- `src/user_source`：RTL、约束和器件IP。
- `src/td_project`：综合、布局布线工程配置。
- `src/sim`：功能及像素仿真。
- `assets/exhibition`：字幕字库、解说文稿与时间表。
- `tools/exhibition`：素材生成与字幕验证工具。
- `doc/verification`：功能验证和最终时序记录。
- `release/final_subtitlewave_20261101`：固件、TF素材与版本清单。

TD界面打开 `src/td_project/exhibition_terminal.al`，运行综合、布局布线和位流生成。该工程包含完整新增模块列表。

工具版本：Tang Dynasty 6.2.168116、Icarus Verilog。工程顶层为 `top`，器件为 `EG4S20BG256`。在 TD 中打开上述工程，依次运行综合、布局布线和位流生成。

典型验证命令：

```powershell
powershell -ExecutionPolicy Bypass -File src/sim/run_narration.ps1
powershell -ExecutionPolicy Bypass -File src/sim/run_exhibit_caption.ps1
powershell -ExecutionPolicy Bypass -File src/sim/run_resident_cache.ps1
```

脚本默认使用 `D:\iverilog\bin`，可通过 `-IverilogBin` 指定安装位置。资源统计：LUT12126/19600、寄存器6660/19600、BRAM9K61/64、BRAM32K2/16、DSP13/29。最终Setup WNS +0.056ns、Hold WNS +0.011ns，失败端点0；构建明细见 `release/final_subtitlewave_20261101/manifest.json`。

保留第三方IP的版权、许可和必要工具指令。供应商加密模块沿用原工程授权条件。完整文件校验清单见 `SHA256.json`。

## 音频波形

波形位于字幕条x528～623、y434～445，共96×12像素，正文仍位于y448～463。每12个有效PCM样点取一个有符号高8位样点，共32点，以双缓存按帧发布；48kHz下相邻点间隔0.25ms，首末点跨度7.75ms。正负幅度围绕中线绘制并以单像素折线连接相邻点，完整波形就绪前隐藏；缺样或转场清除旧波形。采用分档显示增益和正负4像素限幅，适合定性观察，不作为校准示波器或频谱分析仪。

只在匹配当前画作的手动解说中显示，自动总览、预览、静音、结束及转场时隐藏。波形表示系统输出的数字音频采样，不检测扬声器实际发声。
