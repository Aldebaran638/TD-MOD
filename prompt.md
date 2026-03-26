

1.  现在查看CM2下的main.xml的
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

- 现在在前端页面中,TearDown默认摄像机的下方会展示一个"载具状态"血条.我想把它隐藏,应该如何做

- 对于不同武器,命中后产生的护盾特效规模应该是不一样的.比如被x槽武器击中,现在的效果已经可以了,但是如果被那种小炮弹(虽然还没实现)击中,护盾效果就应该再小个两三倍,因为炮弹数量多,飞船一直被命中的话渲染压力太大.这个如果要实现的话要怎么样调整架构?


