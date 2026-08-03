shipMountProfileData = shipMountProfileData or {}
shipMountProfileData.titan = {
    tTitanic = {
        { firePosOffset = { x = 0, y = 0, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    lTitanic = {
        { firePosOffset = { x = 5.5, y = 2.2, z = -6.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -5.5, y = 2.2, z = -6.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 5.5, y = -2.2, z = -6.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -5.5, y = -2.2, z = -6.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 4.2, y = 0, z = 2.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -4.2, y = 0, z = 2.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 3.2, y = 1.8, z = 5.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -3.2, y = 1.8, z = 5.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    mTitanic = {
        { firePosOffset = { x = 2.7, y = 1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -2.7, y = 1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 2.7, y = -1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -2.7, y = -1.4, z = -1.2 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
}

-- Titan weapon pools use the shared size-specific profile names.  Keep the
-- Titan's eight L and four M hardpoints as the canonical geometry while
-- exposing those names to the normal loadout resolver.
local titanLargeMounts = shipMountProfileData.titan.lTitanic
local titanMediumMounts = shipMountProfileData.titan.mTitanic
shipMountProfileData.titan.lLaser = titanLargeMounts
shipMountProfileData.titan.lEnergy = titanLargeMounts
shipMountProfileData.titan.lKinetic = titanLargeMounts
shipMountProfileData.titan.lAutocannon = titanLargeMounts
shipMountProfileData.titan.mLaser = titanMediumMounts
shipMountProfileData.titan.mEnergy = titanMediumMounts
shipMountProfileData.titan.mKinetic = titanMediumMounts
shipMountProfileData.titan.mAutocannon = titanMediumMounts
shipMountProfileData.titan.mSwarmer = titanMediumMounts
