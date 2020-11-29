// Elixer Space Tech - ASDS [version 1.3]

// Droneship Co-ordinates 

set droneshipTarget to latlng(1.16314949072621, -65.043410954876). // MINMUS - 1.16314949072621, -65.043410954876

// Variables for

set entryBurnAlt to 35000.
set entryBurnShutdown to -150.
set boosterHeight to 31.05.
set aoa to 20.
set errorScaling to 1.
set steeringManager:maxstoppingtime to 7.5.

// AOA

set entryBurnAOA to -5. // Re-entry burn AOA
set postEntryBurnAOA to 25. // Post Re-entry - 10 km
set tenKilometerAOA to 15. // 10 Kilometers
set fiveKilometerAOA to 10. // 5 Kilometers
set landingBurnAOA to -2. // Landing Burn Start
set landingBurnPart2AOA to -1. // Below 500 meters (powered guidance)

// Functions

function getImpact {
    if addons:tr:hasimpact {
        return addons:tr:impactpos.
    }

    return ship:geoposition.
}

function longitudeFunc {
    return getImpact():lng - droneshipTarget:lng.
}

function latitudeFunc {
    return getImpact():lat - droneshipTarget:lat.
}

function positioningFunc {
    return getImpact():position - droneshipTarget:position.
}

function boosterGuidance {
    local errorVector is positioningFunc().
    local velVector is -ship:velocity:surface.
    local result is velVector + errorVector * errorScaling.

    if vAng(result, velVector) > aoa {
        set result to velVector:normalized + tan(aoa) * errorVector:normalized.
    }

    return lookDirUp(result, facing:topvector).
}

// Pre Re-entry

rcs on.
toggle ag1.
lock steering to srfretrograde.

wait until verticalspeed < -1.
    brakes on.

// Re-entry

wait until ship:altitude < entryBurnAlt.
    lock throttle to 1.
    set aoa to entryBurnAOA.
    lock steering to boosterGuidance().
    toggle ag7. // Soot
    rcs off.

wait until ship:verticalspeed > entryBurnShutdown.
    lock throttle to 0.
    set aoa to postEntryBurnAOA.
    toggle ag1.
    rcs on.
    steeringManager:resettodefault().
    landingBurn().

// Descending AOA

when alt:radar < 10000 then {
    set aoa to tenKilometerAOA.
}

when alt:radar < 5000 then {
    set aoa to fiveKilometerAOA.
}

// Landing Burn 

function landingBurn {
    local g is body:mu / (body:radius + altitude) ^ 2.

    local t is missionTime + 0.1.
    local speed is airspeed.
    local gSurf is body:mu / body:radius ^ 2.

    local aNet is g.
    local prevQ is ship:q.

    set runmode to 1.

    until verticalSpeed > -0.01 {
        lock steering to boosterGuidance().

        if throttle > 0 {
            set aoa to landingBurnAOA.
        }

        if alt:radar < 250 {
            set aoa to landingBurnPart2AOA.
        }

        if alt:radar < 125 {
            gear on.
            lock steering to srfRetrograde  .
        }

        if missionTime - t > 0.1 {
            set g to body:mu / (body:radius + altitude) ^ 2.
            set aNet to (aNet + (airspeed - speed) / (missionTime - t) + throttle * maxThrust / ship:mass) / 2.
            set speed to airspeed.
            set t to missionTime.

            if prevQ > ship:q {
                set aNet to g.
            }

            set prevQ to ship:q.
        }

        if runmode = 1 {
            local aEst is (aNet - g) * 0.2 + gSurf.
            local a is maxThrust / ship:mass - aEst.
            local stopDist is (airspeed - 1) ^ 2 / (2 * a).

            if stopDist >= (alt:radar - boosterHeight) {
                set runmode to 2.
            }
        }

        if runmode = 2 {
            local targetAlt is (alt:radar - boosterHeight).

            local a is (airspeed - 1) ^ 2 / (2 * targetAlt).
            local thrust is (a + gSurf) * ship:mass.

            lock throttle to thrust / (maxThrust + 0.001).

            if throttle < 0.9 and alt:radar > 3000 {
                lock throttle to 0.
                set runmode to 1.
            }
        }
    }

    wait until verticalSpeed > -1.5.
        lock throttle to 0.
        lock steering to up.
        wait 60.
        shutdown.
}
