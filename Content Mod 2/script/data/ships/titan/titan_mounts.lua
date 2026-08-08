shipMountProfileData = shipMountProfileData or {}
shipMountProfileData.titan = {
    tTitanic = {
        { firePosOffset = { x = 0, y = 0, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    lTitanic = {
        { firePosOffset = { x = 6, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -6, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 6, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = -6, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    lTitanic2 = {
        { firePosOffset = { x = 6, y = 0, z = -1 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -6, y = 0, z = -1 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 6, z = -1 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = -6, z = -1 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    mTitanic = {
        { firePosOffset = { x = 2.7, y = 1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -2.7, y = 1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 2.7, y = -1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -2.7, y = -1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    hHangar = {
        { firePosOffset = { x = 6, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -6, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 6, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = -6, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
}

-- Titan weapon pools use the shared size-specific profile names.  Keep the
-- two groups of four L and four M hardpoints as the canonical geometry while
-- exposing those names to the normal loadout resolver.
local titanLargeMounts = shipMountProfileData.titan.lTitanic
local titanLargeMounts2 = shipMountProfileData.titan.lTitanic2
local titanMediumMounts = shipMountProfileData.titan.mTitanic
shipMountProfileData.titan.lLaser = titanLargeMounts
shipMountProfileData.titan.lEnergy = titanLargeMounts
shipMountProfileData.titan.lKinetic = titanLargeMounts
shipMountProfileData.titan.lAutocannon = titanLargeMounts
shipMountProfileData.titan.lLaser2 = titanLargeMounts2
shipMountProfileData.titan.lEnergy2 = titanLargeMounts2
shipMountProfileData.titan.lKinetic2 = titanLargeMounts2
shipMountProfileData.titan.lAutocannon2 = titanLargeMounts2
shipMountProfileData.titan.mLaser = titanMediumMounts
shipMountProfileData.titan.mEnergy = titanMediumMounts
shipMountProfileData.titan.mKinetic = titanMediumMounts
shipMountProfileData.titan.mAutocannon = titanMediumMounts
shipMountProfileData.titan.mSwarmer = titanMediumMounts
