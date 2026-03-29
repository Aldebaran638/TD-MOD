server.defaultShipType = "titan"

shipData = shipData or {}

shipData.titan = {
    shipType = "titan",
    firePosOffsetShip = Vec(0, 0, -4),
    fireDirRelative = Vec(0, 0, -1),
    shieldRadius = 10,
    shieldHP = 10000,
    armorHP = 6000,
    bodyHP = 4000,
    shieldRecoveryRate = 50,
    armorRecoveryRate = 20,
    tSlotNum = 2,
}
