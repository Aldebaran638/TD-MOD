---@diagnostic disable: undefined-global

shipMountProfileData = shipMountProfileData or {}

shipMountProfileData.enigmaticCruiser = {
    xSpinal = {
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    lLaser = {
        { firePosOffset = { x = 3.3, y = 1.4, z = -2.6 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.3, y = 1.4, z = -2.6 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    lEnergy = {
        { firePosOffset = { x = 3.5, y = 0.6, z = -3.2 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.5, y = 0.6, z = -3.2 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    lKinetic = {
        { firePosOffset = { x = 3.8, y = 0, z = -3.4 }, fireDirRelative = { x = 0, y = 0, z = -1 }, fireDeviationAngle = 1, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.8, y = 0, z = -3.4 }, fireDirRelative = { x = 0, y = 0, z = -1 }, fireDeviationAngle = 1, aimMode = "forwardConvergeByRange" },
    },
    lAutocannon = {
        { firePosOffset = { x = 3.3, y = -1.5, z = -2.4 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.3, y = -1.5, z = -2.4 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    mLaser = {
        { firePosOffset = { x = 2.8, y = 1.2, z = -3.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -2.8, y = 1.2, z = -3.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = 2.8, y = -1.2, z = -3.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -2.8, y = -1.2, z = -3.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    mEnergy = {
        { firePosOffset = { x = 3.2, y = 0.8, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.2, y = 0.8, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = 3.2, y = -0.8, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.2, y = -0.8, z = -3.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    mKinetic = {
        { firePosOffset = { x = 3.8, y = 1.0, z = -4.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.8, y = 1.0, z = -4.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = 3.8, y = -1.0, z = -4.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.8, y = -1.0, z = -4.0 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    mAutocannon = {
        { firePosOffset = { x = 3.5, y = 1.8, z = -2.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.5, y = 1.8, z = -2.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = 3.5, y = -1.8, z = -2.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
        { firePosOffset = { x = -3.5, y = -1.8, z = -2.5 }, fireDirRelative = { x = 0, y = 0, z = -1 }, aimMode = "forwardConvergeByRange" },
    },
    mSwarmer = {
        { firePosOffset = { x = 0.3, y = 5, z = 2 }, fireDirRelative = { x = 600, y = 300, z = 0 } },
        { firePosOffset = { x = -0.3, y = 5, z = 2 }, fireDirRelative = { x = -600, y = 300, z = 0 } },
        { firePosOffset = { x = 0.3, y = -5, z = 2 }, fireDirRelative = { x = 600, y = -300, z = 0 } },
        { firePosOffset = { x = -0.3, y = -5, z = 2 }, fireDirRelative = { x = -600, y = -300, z = 0 } },
    },
    gRocket = {
        { firePosOffset = { x = 0, y = 0, z = -4.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4.8 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    gNeutron = {
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = 0, y = 0, z = -4 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    hHangar = {
        { firePosOffset = { x = 0.8, y = 6.5, z = -1.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
        { firePosOffset = { x = -0.8, y = 6.5, z = -1.0 }, fireDirRelative = { x = 0, y = 0, z = -1 } },
    },
    pDefense = {
        { firePosOffset = { x = 2.5, y = 1.1, z = -1.8 } },
        { firePosOffset = { x = -2.5, y = 1.1, z = -1.8 } },
    },
}
