11. 现在我点击左键,我发现x槽武器发射点和发射方向都和飞船朝向相反.检查原因,我来排版是否修复
12. 现在用户点击左键->武器发射->蓄力->命中点判定(是否命中,是否命中群星飞船,是否打到护盾等)->命中效果结算(给对面的群星body减血等)->特效绘制  等这一套武器逻辑是如何做的?详细说说,我需要你来修复问题改代码了

13. 现在用户点击w/s->飞船移动这一套移动逻辑是如何做的?

14. 现在查看CM2下的main.xml的
```xml
	<script pos="-15.2 7.9 12.8" file="MOD/script/shipMain.lua">
		<vehicle name="ship" tags="stellarisShip" pos="0.0 0.0 0.0" driven="true" sound=" " spring="0.5" damping="0" topspeed="0" acceleration="0" strength="0" friction="0.5">
			<body name="body" tags="stellarisShip" pos="0.0 0.0 0.0" dynamic="true">
				<vox tags="missileLauncher" pos="0.5 7.0 1.1" file="MOD/vox/missileLauncher.vox"/>
				<vox tags="missileLauncher" pos="-0.5 -7.0 1.1" rot="0 0 180" file="MOD/vox/missileLauncher.vox"/>
				<vox tags="missileLauncher" pos="-0.5 7.0 1.1" file="MOD/vox/missileLauncher.vox" mirrorx="true"/>
				<vox tags="missileLauncher" pos="0.5 -7.0 1.1" rot="0 0 180" file="MOD/vox/missileLauncher.vox" mirrorx="true"/>
				<vox tags="primaryWeaponLauncher" pos="0.0 0.0 0.0" file="MOD/vox/primaryWeaponLauncher.vox"/>
				<vox tags="hull" pos="0.0 0.0 0.0" file="MOD/vox/hull.vox"/>
				<vox tags="thruster" pos="-1.1 0.4 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="1.1 0.4 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="-1.1 -0.5 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="thruster" pos="1.1 -0.5 1.3" file="MOD/vox/thruster.vox"/>
				<vox tags="engine" pos="-0.5 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="-0.2 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.1 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.4 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="engine" pos="0.7 -0.4 0.0" file="MOD/vox/engine.vox"/>
				<vox tags="smallThruster" pos="2.1 0.1 0.0" rot="0 0 180" file="MOD/vox/smallThruster.vox"/>
				<vox tags="smallThruster" pos="-2.1 -0.1 0.0" file="MOD/vox/smallThruster.vox"/>
				<vox tags="secondaryLightSystem" pos="0.0 0.0 0.0" file="MOD/vox/secondaryLightSystem.vox"/>
				<vox tags="mainLightSystem" pos="0.0 0.0 0.0" file="MOD/vox/mainLightSystem.vox"/>
				<vox tags="armor" pos="0.0 0.0 0.0" file="MOD/vox/armor.vox"/>
			</body>
			<location name="Player" tags="player" pos="0.0 -0.1 -0.3" rot="0 180 180"/>
			<location name="exit" tags="exit" pos="0.0 0.2 -2.6"/>
		</vehicle>
	</script>
```

对所有engine的shape都添加特效.冒火的特效(类似引擎燃烧).这需要一个新模块,写在CM2 client下的draw_modules文件夹下

顺带一问.现在点击w,secondaryLightSystem就暗,s就亮.系统看起来把secondaryLightSystem当尾灯了.我怎么保证secondaryLightSystem所有方块始终亮呢?当然有人上船才亮,没有人就灭

13. 现在将GM下移动相关的内容全都迁移到CM2模组下面去.需要迁移:Global Mod\client\input_handling\bodyMoveInput.lua这个脚本进入CM2中.先说说你的方案,然后由我来拍板如何迁移

现在开始迁移移动模块，

14. 现在将GM下x槽武器开火相关的内容全都迁移到CM2模组下面去.需要迁移:Global Mod\client\input_handling\xSlotInput.lua这个脚本以及所有相关文件进入CM2中.先说说你的方案,然后由我来拍板如何迁移

15. 添加内容：现在在CM2 client部分添加一类新模块。你先阅读阅读项目根目录下的sound文件夹，有哪些类型的声音文件
