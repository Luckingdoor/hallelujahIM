# 横向候选窗改造版

这是 [hallelujahIM](https://github.com/dongyuwei/hallelujahIM) 的改造版本，把候选词面板从系统自带的**单列纵向**列表换成了**自绘的横向菜单**，并支持按 `↓` 展开成多行网格。

其余功能（词库、拼写校正、Text-Expander、拼音输入中文、上下文预测等）与上游完全一致。

## 效果

**默认：横向一行**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/candidates-dark.png">
  <img alt="横向候选窗" src="docs/images/candidates-light.png" width="640">
</picture>

**按 `↓` 展开：5 列 × 最多 6 行**

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/candidates-dark-expanded.png">
  <img alt="展开后的候选窗" src="docs/images/candidates-light-expanded.png" width="640">
</picture>

深色模式跟随系统自动切换。

**菜单栏与切换提示的图标**

<img alt="与系统图标对比" src="docs/images/menubar-icon.png" width="260">

图标是「圆角方块挖空一个『英』字」的模板图标，跟系统自带输入法同一个画法——上图左起是系统的「拼」和「简」，最右是本输入法。圆角 0.152H、字形墨迹 0.6875H 都是量自系统图标的（那批图标藏在 `SCIM.app/Contents/PlugIns/SCIM_Extension.appex/Contents/Resources/` 下，不在 `.app/Contents/Resources`）。

位图本身做成 21×16pt 的横向长方形：系统渲染自带输入法时会给图标套一层固定宽度的容器，第三方输入法则按原比例显示，做成正方形并排看会明显窄一截。

**切换输入法时的气泡**用的是另一套资源。那个气泡渲染的是输入模式里 `TISIconLabels` 的内容，跟菜单栏图标无关：

<img alt="三种使用场景" src="docs/images/menubar-icon-states.png" width="330">

左起——输入法列表（深灰方块反白字）、菜单栏深色模式（系统自动反色）、切换气泡（蓝底白字）。

气泡这份必须是**不带方框的裸字形**（`himGlyph@2x.pdf`），不能复用带框的 `himTemplate.tiff`：气泡会把模板整个填成白色，方块糊成一片、字反而成了透明的洞，看起来就是个空白方框。系统 AinuIM 也是这么分开的——列表用 `Ainu.tiff`、气泡用 `Ainu@2x.pdf`。

## 按键

| 按键 | 收起状态（单行） | 展开状态（网格） |
| --- | --- | --- |
| `←` `→` | 左右换候选 | 左右换候选 |
| `↓` | 展开 | 下移一行 |
| `↑` | 不接管，交回应用 | 上移一行；已在首行则收起 |
| `Tab` | 展开 | 跳到下一行同列，末行循环回首行 |
| `1`~`9` | 选中当前行第 n 个 | 选中当前行第 n 个 |
| `Enter` / `Space` | 提交选中项 | 提交选中项 |
| 鼠标 | 点击选词，点末尾 `⌄` 展开 | 点击选词，点末尾 `⌃` 收起 |

## 安装

### 方式一：pkg 安装包（推荐）

从 [Releases](../../releases) 下载 `hallelujah-horizontal-*.pkg`，双击安装。安装脚本会自动注册并激活输入法，装完在 `系统设置 › 键盘 › 输入法` 里就能看到。

首次安装后如果输入法没反应，注销重登录一次。

pkg 是 ad-hoc 签名的（没有 Apple 开发者证书），首次打开若被 Gatekeeper 拦下，在 `系统设置 › 隐私与安全性` 里点「仍要打开」。

### 方式二：自己编译

只需要 Command Line Tools，**不需要装 Xcode**：

```bash
xcode-select --install          # 如果还没装过
git clone <本仓库地址>
cd hallelujahIM
bash build-standalone.sh        # 产物：build/hallelujah.app
bash install.sh                 # 装到 /Library/Input Methods/
```

`install.sh` 会先把系统里已有的 hallelujah 备份到 `hallelujah-原版备份.app`，想退回去就跑 `bash rollback.sh`。

想自己打 pkg：

```bash
bash package/build-package-noxcode.bash   # 产物：dist/*.pkg
```

## 改动了什么

| 文件 | 说明 |
| --- | --- |
| `src/CandidateWindow.h` `.m` | 新增。自绘候选窗的全部实现：布局、绘制、键盘导航、鼠标交互、展开/收起 |
| `src/InputController.h` `.mm` | 候选窗从 `IMKCandidates` 换成 `CandidateWindow`，重写方向键/数字键处理；修掉空格上屏截断词的 bug（见下） |
| `src/main.mm` | 去掉 `sharedCandidates` 和翻译窗 nib 的加载；`showTranslation` 默认关闭；`kSourceID` 跟随输入模式 |
| `Info.plist` | 菜单栏图标改用 `himTemplate.tiff`；声明输入模式，挂上切换气泡用的 `TISIconLabels` |
| `en.lproj/InfoPlist.strings` | 补输入模式的显示名，否则输入法列表里会显示成 mode key |
| `make-icon.m` | 新增。生成多分辨率模板图标 TIFF（带方框，列表和菜单栏用） |
| `make-hud-glyph.m` | 新增。生成切换气泡用的裸字形 PDF |
| `preview-candidates.m` | 新增。不装输入法就能预览候选窗渲染效果，上面几张图就是它生成的 |
| `build-standalone.sh` | 新增。不依赖 Xcode 的自包含构建 |
| `install.sh` | 安装前先注销旧输入源、刷 `cfprefsd`，避免残留注册 |
| `package/build-package-noxcode.bash` | 新增。基于上面的构建产物打 pkg |

为什么要自绘：`IMKCandidates` 的面板样式、尺寸和末尾控件行为都由系统定死，换不成「点击展开」，也调不了列数和宽度。

## 几个踩过的坑

**空格上屏的是截断词。** `InputController` 有两个缓冲区：`originalBuffer`（实际敲进去的字母）和 `composedBuffer`（选中的候选），而 `commitComposition` 优先提交后者、为空才回落到前者。问题是 `originalBufferAppend` 从不清 `composedBuffer`，`deleteBackward` 和 `didHighlightCandidate` 却会往里写值，`setCandidates:` 重置选中项时又不触发高亮回调。于是「敲 what → 退格删 t → 补回 t → 空格」会上屏 `wha`：第二步把 `composedBuffer` 写成了 `wha`，第三步只更新了 `originalBuffer`。现在敲新字母和退格时都会清掉 `composedBuffer`，让它只在确实选中候选时才有值。

**改了 Info.plist 却不生效。** TIS 按 `CFBundleVersion` 缓存输入源信息，版本号不变就不重新解析 `Info.plist`——新增的输入模式、图标声明统统读不到，表现为「装了但没反应」。`build-standalone.sh` 现在每次构建都写入时间戳版本号。

**声明输入模式后一个字也打不出来。** 输入模式的 `TISInputSourceID` 必须是「bundle ID + 模式后缀」。写成不带后缀的 bundle ID 会和 bundle 级的输入源撞车，注册乱掉、IMK 收不到按键。`src/main.mm` 里的 `kSourceID` 要跟着一起改，启用和选中输入源都靠它。

预览图重新生成：

```bash
clang -fobjc-arc -framework Cocoa preview-candidates.m src/CandidateWindow.m -Isrc -o /tmp/preview
/tmp/preview docs/images/candidates-light.png
/tmp/preview docs/images/candidates-light-expanded.png expanded
/tmp/preview docs/images/candidates-dark.png dark
/tmp/preview docs/images/candidates-dark-expanded.png expanded dark
```

## 许可

与上游一致，GPL v3。原作者 [dongyuwei](https://github.com/dongyuwei)。
