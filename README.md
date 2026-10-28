# 逃离鸭科夫 · 合集 MOD 一键启用 & 排序

> 对应 Steam 创意工坊合集：<https://steamcommunity.com/sharedfiles/filedetails/?id=3828630088>（74 个 mod）
> 适用游戏版本：2.3.30 ｜ 顺序生成时间：2026-10-28

不用打开游戏，一键把合集里的 74 个 mod 设为「已启用」，并按推荐顺序写好加载优先级（前置在前、功能居中、HUD/显示在后、管理器最后）。

## 使用步骤

1. 在 Steam 订阅上面的合集，等 Steam 把所有 mod 下载完（下载列表清空）。
2. **完全退出游戏**（任务管理器里确认 `Duckov.exe` 已结束）。
3. 下载本仓库：页面右上角 **Code → Download ZIP**，解压到任意文件夹。
4. 双击 **`一键应用.bat`**。
   或在 PowerShell 里运行：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1
   ```
5. 启动游戏即可生效。**不需要额外重启游戏**：脚本是在游戏关闭时写入，游戏下次启动直接读取新顺序。
   想确认的话，进游戏后打开 Mods 列表，应该能看到这些 mod 都是勾选状态、顺序与 `mod-order.json` 一致。

## 还原

双击 **`一键还原.bat`**，会还原**最近一次**备份；也可以在游戏关闭时运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Apply-DuckovModOrder.ps1 -Restore
```

每次应用前的备份在：
`%USERPROFILE%\AppData\LocalLow\TeamSoda\Duckov\Saves\ModOrderBackup-<时间>`

## 它改了什么

只改两个本地文件（不改 mod 文件、不改游戏文件、不联网）：

| 文件 | 改动 |
|---|---|
| `Saves\Mods.ES3` | 写入每个 mod 的 `priority_<内部名>`（0 = 最先加载） |
| `Saves\Global.json` | 把合集内 mod 的 `ModActive_<内部名>` 设为 `true`，并把 `AllowLoadingMod` 设为 `true` |

- 顺序表以外的 mod：会被排到合集之后；它们的启用状态保持你原来的设置，不会被动。
- `AllowLoadingMod=true` 相当于替你在游戏 Mods 菜单里点了「同意加载 MOD」。如果不想这样，可以应用后自己进一次 Mods 菜单调整。
- 游戏可能会提示「当前启用的 MOD 与存档记录不一致」——这是正常现象（启用清单变了），点继续游戏即可。

## 常见问题

**Q：没进过游戏可以用吗？**
建议至少启动过一次游戏到主菜单，让游戏建好 `Saves` 配置目录。脚本也能自动创建目录，但第一次用游戏内配置更稳。

**Q：以后合集更新了怎么办？**
本仓库需要同步更新 `mod-order.json`；只订阅合集不会自动调整顺序。

**Q：安全吗？**
脚本开源可审查：纯本地读写两个存档配置文件，不下载、不上传、不改 mod。写入前自动备份，可用 `一键还原.bat` 回滚。

**Q：能不能只启用不排序？**
不建议——这份顺序是按 mod 的前置依赖（HarmonyLib、ModConfig、ModSetting、JmcModLib 等）整理的，排序乱可能导致部分 mod 不显示/不生效。

## English

Apply the enabled state and load order of the 74 mods from the Steam collection, without launching the game.

1. Subscribe to the collection and wait until Steam finishes downloading.
2. Fully close the game.
3. Download this repo (Code → Download ZIP) and extract it.
4. Run `一键应用.bat` (or the PowerShell command above).
5. Launch the game. **No extra restart is required.**

Revert with `一键还原.bat`. Only `Saves\Mods.ES3` and `Saves\Global.json` are modified; backups are created automatically. No mod files, game files or network access are touched.

## 文件说明

| 文件 | 用途 |
|---|---|
| `Apply-DuckovModOrder.ps1` | 主脚本（应用 / `-Restore` 还原 / `-DryRun` 预览） |
| `mod-order.json` | 74 个 mod 的内部名顺序表（合集更新时只需改这个文件） |
| `一键应用.bat` | 双击应用 |
| `一键还原.bat` | 双击还原最近一次备份 |
