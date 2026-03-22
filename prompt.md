1.  现在用户点击w/s->飞船移动这一套移动逻辑是如何做的?

2.  现在查看CM2下的main.xml的
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




1.  
我现在想做一个新武器。这个武器特点：
1.武器叫动能大炮。发射炮弹（但是不带追踪瞄准，不是瞬移。超过射程炮弹消失）
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

- 
需要修改：
摄像头改成两种模式：点击右键以后可以从后置摄像头改为前置摄像头(位置为飞船相对位置0,0,-3)，再点一次右键就能切换为后置摄像头。
每一次上飞船摄像头都默认是后置的。
在摄像头后置情况下，长按右键，可以切换为自由视角模式（此时移动摄像头将不会影响飞船转动方向）
摄像头前后切换，不能是直接瞬移，而必须是滑动切换位置

有什么不明确的边界条件?或者说潜在风险?

先说说你打算怎么改吧

- 
我要限制飞船模块(基本上所有模块吧)在飞船血量(就是船体值,不包括护盾值,装甲值这些)为0的时候,失效.你先罗列一下有哪些模块,然后由我来定哪些模块需要被限制

- 
新写一个渲染模块,在Content Mod 2\script\client\draw_modules下创建一个新脚本存储
当飞船船体值被揍到0以后,触发特效渲染:在飞船body中心位置渲染一个球形爆炸冲击波,冲击波为黄白色,范围较小;在飞船以body位置为圆心,xz为平面的位置用发光粒子渲染一个圆形爆炸冲击波范围较大,为白色

- 现在在前端页面中,TearDown默认摄像机的下方会展示一个"载具状态"血条.我想把它隐藏,应该如何做

- 对于不同武器,命中后产生的护盾特效规模应该是不一样的.比如被x槽武器击中,现在的效果已经可以了,但是如果被那种小炮弹(虽然还没实现)击中,护盾效果就应该再小个两三倍,因为炮弹数量多,飞船一直被命中的话渲染压力太大.这个如果要实现的话要怎么样调整架构?

- 添加一个新模块:Content Mod 2\script\data\ships\enigmaticCruiser.lua中目前还没有每帧回血的数值.我希望添加一下(可能这些新数值要在注册时写入registry中)

同时在Content Mod 2\script\server文件夹下创建一个新的文件夹(用来存储恢复相关的模块脚本).这个脚本要做的就是每固定时间(开发者可调整),根据Content Mod 2\script\data\ships\enigmaticCruiser.lua中的数值,给飞船恢复特定的血量.船体,装甲和护盾恢复是并行的,互相独立.
说说你的方案