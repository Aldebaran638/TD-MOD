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

16. 
我现在想做一个新武器。这个武器特点：
1.武器叫动能大炮。发射炮弹（但是不带瞄准，不是瞬移。超过射程炮弹消失）
2.这个武器是按散热值计算的。假设大炮有100的“条”，开一炮这个条的数值+5，每过0.2秒这个条降低值3.当玩家开炮后，条+5得到的值>=100,则最后一炮条值计算为100(就是条值限制不超过100),同时进入大炮冷却期,必须等条值<=50才能继续发射;
接下来这一部分跟准星有点像.计算飞船前方,距离飞船 "武器射程值"的位置,然后大炮就对准这个点开火.如果飞船前方 射程内有障碍物,那么大炮调转角度,瞄准射程内的这个障碍物打.

炮弹如果进入飞船护盾范围内,可以直接被被护盾拦截.如果炮弹打到飞船,则只有特效,效果(给护盾或者装甲,船体减血)没有爆炸;如果打到非群星body,那么产生小范围爆炸.

你觉得如果要实现这样复杂的系统,有哪些难点?我们先探讨再决定是否下手


17. 
```lua
---@diagnostic disable: undefined-global

shipTypeRegistryData = shipTypeRegistryData or {}

-- 飞船类型定义：enigmaticCruiser
-- 说明：这里是“类型定义层”，用于注册到 Registry 的 definitions 区域。
shipTypeRegistryData.enigmaticCruiser = {
    shipType = "enigmaticCruiser",
    maxShieldHP = 5000,
    maxArmorHP = 3000,
    maxBodyHP = 2000,
    shieldRadius = 7,
    fx = {
        shieldHit = {
            ringParticleRadius = 0.1,
            ringRadiusStep = 1.0,
            ringRoundCount = 3,
            roundTime = 0.14,
            centerSpawnRadius = 0.5,
            centerSpawnCount = 20,
            baseParticleCount = 18,
        },
    },
    xSlots = {
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
    },
}
```
以上是我CM2这艘飞船的定义.我发现在他的根路径没有关于xslot槽位数量的数值,这我是不满意的.
有了这个数字,
```lua
    xSlots = {
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
        {
            weaponType = "tachyonLance",
            firePosOffset = { x = 0, y = 0, z = -4 },
            fireDirRelative = { x = 0, y = 0, z = -1 },
        },
    },
```
中的有效武器数量就有限制了.比如这个例子里面xSlot有俩武器,如果x槽武器数量为1,那么第二个武器就是无效的;如果为3,那么当前两个武器都有效,而且还能多添加一个武器.

现在是不是飞船注册会依据上述表单来注册飞船信息?还是说这个表单事实上是被忽略的

18. 
就目前为止,是不是GM中事实上已经没有有用的东西了?