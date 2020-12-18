// Zenith Launch Script

// Created by QuasyMoFo
// Licensed under APACHE 2.0

wait until ag6.
clearscreen.

// Mission Parameters

set tApoaps to 50000. // Apoapsis 
set tPeriaps to 0. // Periasis
set tInclination to 0. // Inclination (DEG)

set staticFire to false. 
set wetDress to false.
set hopTest to true.

runOncePath("0:/lib_lazcalc.ks").
runOncePath("0:/LIBRARY/libGNC.ks").

set terminalCount to 10.
set a to 80.
set errorScaling to 1.
set aoa to 10.
set landingZone to latlng(11.8411035439308, -43.1117041842542).
set steeringManager:rollts to 20.
set boosterHeight to 34.57.
set throt to 0.
lock throttle to throt.

// Initialisation

if staticFire = true {
    staticFireFunc().
}

if hopTest = true {
    hopTestFunc().
}

// Guidance Functions

function getImpact {
    if addons:tr:hasimpact {
        return addons:tr:impactpos.
    }

    return ship:geoposition.
}

function longitudeFunc {
    return getImpact():lng - landingZone:lng.
}

function latitudeFunc {
    return getImpact():lat - landingZone:lat.
}

function positioningFunc {
    return getImpact():position - landingZone:position.
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

// Static Fire

function staticFireFunc {
    set sfLength to 60.
    set missionElapsedTimer to 0.

    toggle ag3.
    set throt to 1.
    
    until missionElapsedTimer = sfLength {
        clearScreen.
        print "T+" + missionElapsedTimer.
        wait 1.
        set missionElapsedTimer to missionElapsedTimer + 1.
    }

    toggle ag3.
}

// Hop Test

function hopTestFunc {
    set hopApoaps to tApoaps.
    set extraEngShutdown to true.
    set shutdownEng1 to hopApoaps / 2.
    set g to body:mu / body:position:sqrmagnitude.
    lock p to 90 - vAng(ship:facing:vector, ship:up:vector).

    lock steering to up.
    set throt to 0.

    until terminalCount = 1.0 {
        clearscreen.
        print "T-" + terminalCount.
        set terminalCount to terminalCount - 1.
        wait 1.

        on ag9 {
            set throt to 0.
            ag9 off.
            ag6 off.
            ag8 off.
            wait 0.1.
            reboot.
        }
    }

    set done to false.
    when done = false then {
        switch to 0.
        clearscreen.

        print "MET: " + missionTime.
        print "_______________________".
        print "Altitude: " + round(alt:radar, 1).
        print "Apoapsis: " + round(apoapsis, 1).
        print "VSpeed: " + round(verticalSpeed, 1).
        print "Airspeed: " + round(airspeed, 1).
        print "Pitch: " + round(p, 1).
        print "Mass: " + round(ship:mass, 1).
        print "Dynamic Pressure: " + round(ship:q, 1).
        print "Status: " + status. 

        log "MET: " + round(missionTime, 1) + " | " + "Alt (AGL): " + round(alt:radar, 1) + " | " + "VSpeed: " + round(verticalSpeed, 1) + " | " + "Airspeed: " + round(airspeed, 1) + " | " + "Throttle: " + throttle + " | " + "PTCH: " + p + " | " + "MASS: " + round(ship:mass , 1) + " | " + "DPRESSURE: " + ship:q + " | " + "STATUS: " + ship:status to "hopTest.csv".
        wait 0.05.
        preserve.
    }

    hopLiftoff().
    hopAscent().
    //hopDeviate().
    hopDescent().
    //wait until alt:radar < 4000.
    //hopLanding().
}

function hopLiftoff {
    stage.
    set throt to 1.1 * ship:mass * g / ship:availablethrust.
    lock steering to heading(landingZone:heading, 89.75).

    wait 4.
    stage.
}

function hopAscent {
    
    if extraEngShutdown = true {
        wait until alt:radar > shutdownEng1.
        toggle ag2.
        lock steering to up.
    }

    wait until ship:apoapsis > hopApoaps.
    lock steering to up.
    set throt to 0.
    toggle ag1.
    //set throt to 0.1 * ship:mass * g / ship:availablethrust.
    rcs on.
}

function hopDescent {
    wait until verticalSpeed < -1 and alt:radar > boosterHeight + 100. 
    brakes on.

    set throt to 0.
    //set throt to 0.6 * ship:mass * g / ship:availablethrust.

    wait 3.

    lock steering to boosterGuidance().

    set aoa to 20.

    wait until alt:radar < 40000.
    set aoa to 30.

    wait until alt:radar < 20000.
    set aoa to 25.

    wait until alt:radar < 6000.
    set aoa to 10.
}

lock trueRadar to alt:radar - boosterHeight.
lock maxDecel to (ship:availableThrust / ship:mass) - g.
lock stopDist to ship:verticalspeed ^ 2 / (2 * maxDecel).
//lock landingThrot to stopDist / trueRadar.
lock impactTime to trueRadar / abs(ship:verticalspeed).

when impactTime <= 3.5 then {gear on.}
toggle ag1.
toggle ag2.

wait until trueRadar <= stopDist.
set throt to 1.
set aoa to -2.5.

wait until ship:verticalspeed > -10.
set throt to 0.983 * ship:mass * g / ship:availablethrust.
lock steering to up.

wait until ship:verticalspeed > -0.01.
set throt to 0.
lock steering to up.
wait 10.
shutdown.

// function hopLanding {
//     local g is body:mu / (body:radius + altitude) ^ 2.

//     local t is missionTime + 0.1.
//     local speed is airspeed.
//     local gSurf is body:mu / body:radius ^ 2.

//     local aNet is g.
//     local prevQ is ship:q.

//     set runmode to 1.

//     until verticalSpeed > -0.01 {
//         lock steering to boosterGuidance().

//         steeringManager:resettodefault().

//         if throt > 0 and alt:radar > 4000 {
//             set aoa to -15.
//         } else if throt > 0 and alt:radar < 4000 {
//             set aoa to -4.
//         }

//         if alt:radar < 250 and throt > 0 {
//             set aoa to -2.
//         }

//         if alt:radar < 175 {
//             gear on.
//             lock steering to up.
//         }

//         if missionTime - t > 0.1 {
//             set g to body:mu / (body:radius + altitude) ^ 2.
//             set aNet to (aNet + (airspeed - speed) / (missionTime - t) + throt * maxThrust / ship:mass) / 2.
//             set speed to airspeed.
//             set t to missionTime.

//             if prevQ > ship:q {
//                 set aNet to g.
//             }

//             set prevQ to ship:q.
//         }

//         if runmode = 1 {
//             local aEst is (aNet - g) * 0.2 + gSurf.
//             local a is maxThrust / ship:mass - aEst.
//             local stopDist is (airspeed - 1) ^ 2 / (2 * a).

//             if stopDist >= (alt:radar - boosterHeight) {
//                 set runmode to 2.
//             }
//         }

//         if runmode = 2 {
//             local targetAlt is (alt:radar- boosterHeight).

//             local a is (airspeed - 1) ^ 2 / (2 * targetAlt).
//             local thrust is (a + gSurf) * ship:mass.

//             set throt to thrust / (maxThrust + 0.001).

//             if throt < 0.9 and alt:radar > 3000 {
//                 set throt to 0.
//                 set runmode to 1.
//             }
//         }
//     }

//     wait until verticalSpeed > -0.05.
//         set throt to 0.
//         unlock steering.
//         wait 10.
//         set done to true.
//         shutdown.
// }