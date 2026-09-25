# 「我车呢」AI 生图提示词记录

> 开源红线（PRD §6.2 第 4 条）：本项目全部设计素材由 AI 生图工具（火山方舟 Seedream）自行生成，
> 不引入第三方版权素材。此文件记录每张素材的提示词，便于复现、迭代与社区二次创作。

## 统一风格约定

- 主色：薄荷青绿 `#2BB673`，强调色：暖橙 `#FF8A3D`，底色：米白 `#FAFAF7`
- 风格关键词：扁平线条插画（flat line illustration）、浅色底、清新校园风、主色点缀、大量留白

## 素材清单

| 素材 | 用途 | 状态 | 提示词 |
|---|---|---|---|
| 空状态插图：一排自行车 | 首页/历史空状态 | ✅ 已生成 | flat line illustration, a neat row of three campus bicycles seen from the side, mint green `#2BB673` strokes with a warm orange `#FF8A3D` accent on one basket, off-white `#FAFAF7` background, lots of negative space, clean minimal campus style, no text, centered composition |
| 关于页插图：自行车 + 定位针 | 设置-关于页 | ✅ 已生成 | flat line illustration, a campus bicycle with a large location pin floating above the seat, mint green `#2BB673` and warm orange `#FF8A3D`, off-white `#FAFAF7` background, minimal, generous white space, no text |
| APP 图标 | 启动图标（Q1 已定方向：自行车剪影+定位针） | ✅ 已生成 | app icon, minimal bicycle silhouette combined with a location pin, solid mint green `#2BB673` on off-white `#FAFAF7`, thick friendly strokes, centered, flat, no gradient, no text |

## 生成记录

> 每生成一张图追加一行：素材名 / 生成日期 / 模型 / 实际使用提示词（中文，Seedream 对中文更稳）/ 后处理。

| # | 素材 | 生成日期 | 模型 | 实际提示词 | 后处理 |
|---|---|---|---|---|---|
| 1 | `images/empty_state_bikes.png` | 2026-09-23 | `doubao-seedream-5.0-lite` | 扁平线条插画，三辆并排停放的校园自行车侧面视图，细线条描边，主色薄荷青绿，其中一辆的车筐用暖橙色点缀，米白色背景，大量留白，清新校园风格，极简干净，无文字，居中构图，无渐变，无阴影 | 2048→720px，量化 128 色（2375KB→213KB） |
| 2 | `images/about_bike_pin.png` | 2026-09-23 | `doubao-seedream-5.0-lite` | 扁平线条插画，一辆校园自行车，车座上方悬浮一个大号定位针图标，细线条描边，薄荷青绿为主色，暖橙色点缀，米白色背景，极简，大量留白，清新校园风格，无文字，无渐变 | 2048→720px，量化 128 色（2359KB→222KB） |
| 3 | `images/app_icon.png` | 2026-09-23 | `doubao-seedream-5.0-lite` | 应用图标，极简自行车剪影与定位针结合成一个图形，实心薄荷青绿色，米白色背景，粗而友好的线条，居中，扁平化设计，无渐变，无文字，方形构图，四周留出安全边距 | 按「绿色主导」自动定位图形外接框 → 居中裁方形 → 1024×1024；另派生 Android 各密度 legacy 图标与自适应图标前景层（见下） |
| 4 | `images/marker_bike.png` | 2026-09-24 | `doubao-seedream-5.0-lite` | 一个移动端地图标记图钉图标：顶部是一块圆角水滴形标牌，牌中是一辆简约的自行车正侧面剪影；标牌下方收敛成一个短锥尖，锥尖正下方有一枚柔和的椭圆投影。配色：标牌底色薄荷青绿 `#2BB673`，自行车剪影与锥尖描线为纯白，锥尖主体与地面投影为暖橙 `#FF8A3D`。风格：扁平化矢量图标 flat vector icon，圆润边缘，无描边堆叠、无写实阴影、无渐变、极简现代 App 图标质感。构图：图标居中，四周留足安全边距。背景：纯白背景，不要任何装饰、不要边框、不要文字。画面中不要出现任何文字和字母。 | Seedream 2k → 透明底 floodfill 抠图（保留内部白色剪影）→ 按内容 bbox 重新对齐底部中心 → 180×180px，量化 128 色 |
| 5 | `images/home_parking_hero.png` | 2026-09-24 | `doubao-seedream-5.0-lite` | 一幅清新校园风的现代扁平插画：一辆薄荷青绿色的自行车停在大学教学楼旁的树荫下，车筐里放着一本书，车把上挂着一个小小的暖橙色定位图钉挂饰；地面是淡淡的米白色，有非常柔和的椭圆投影；远景是几笔低饱和的灰绿色教学楼轮廓、几棵简化的树和几朵白云。配色：米白底色 `#FAFAF7`，主色薄荷青绿 `#2BB673`，点睛暖橙 `#FF8A3D`，次要色灰绿 `#6B7B78`。风格：modern flat illustration，圆润几何造型，柔和自然光，克制的细节，大量留白，无描边，无写实阴影，无文字。构图：横幅构图，自行车主体居中偏左且略小，画面上方与右侧大面积留白，适合作为手机 App 页面顶部的主视觉横图。画面中不要出现任何文字。 | Seedream 2k → 居中裁切为 16:9 → 960×540px，量化 128 色 |
| 6 | `images/brand_mark.png` | 2026-09-24 | `doubao-seedream-5.0-lite` | 一个极简的 App 品牌徽标：一枚薄荷青绿 `#2BB673` 的圆角方形底板上，用纯白色线条画出一体成型的两笔——一辆简约自行车轮廓，车轮中心同时是一枚小小的暖橙 `#FF8A3D` 定位图钉，图形相互咬合、浑然一体。风格：扁平化矢量徽标 flat vector logo，极简，圆润端点，无渐变、无立体阴影、无文字。构图：徽标居中，四周留出均匀的安全边距。背景：纯白背景，不要边框、不要文字。画面中不要出现任何文字和字母。 | Seedream 2k → 透明底 floodfill 抠图 → 居中裁方形 → 256×256px，量化 128 色 |

## 图标派生资源（由 `app_icon.png` 自动加工）

`android/app/src/main/res/` 下：

| 文件 | 说明 |
|---|---|
| `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | legacy 图标（48/72/96/144/192px），含米白底色 |
| `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png` | 自适应图标前景层（108dp 画布，图形占 66dp 安全区，透明底） |
| `values/ic_launcher_background.xml` | 自适应图标背景色 `#FAFAF7` |
| `mipmap-anydpi-v26/ic_launcher.xml`、`ic_launcher_round.xml` | 自适应图标描述（Android 8.0+） |

> 加工脚本：`F:\WorkBuddy_data\wo-che-ne\.workbuddy\make_icons.py`（工作区工具，不入开源仓库）。
> 抠图判据：该图背景为暖调米白（R 通道主导），主图形为薄荷青绿（G 通道主导），
> 故用 `g > r + 15 and g > b + 15` 定位与抠图，比「接近固定底色」稳健得多。

<!-- 每生成一张图，在此追加一行：素材名 / 用途 / 生成日期 / 完整提示词 / Seedream 模型版本 -->

