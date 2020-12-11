// Elixer E2 Launch Script [version 1.8]

// Elixer's public launch script, used on E2 for orbital launches with contracted payloads.
// Mission parameters can be changed through the variables below, the script detects if it needs to use RTLS / ASDS.
// 
// isMaven DOES NOT WORK as of this time, do not attempt to use it as it will break.
// 
// Code is under APACHE 2.0 License. 


// Launch Variables

SET tApoaps TO 140. // Apoapsis (KM) ~ Freedom: 140
SET tPeriaps TO 140. // Periapsis (KM) ~ Freedom: 140
SET tInclination TO -10. // Inclination (DEG) ~ Freedom: -10

// Script Mode

SET dryRun to false. // Countdown (No Launch)
SET staticFire to false. // Static Fire (No Liftoff)
SET abortTest to false. // Aborts at T-2 (No Launch)
SET isMaven to true. // Maven Crew Capsule
SET isHeavy to false. // EHeavy Flight

wait until ag6.
clearscreen.

// Library Runs

runOncePath("0:/lib_lazcalc.ks").
runOncePath("0:/LIBRARY/libGNC.ks").

// Ascent Variables

set countdown to 10. // T- Countdown | 60-launchday
set ftl to 1625. // 1625 - ASDS | 2200 - RTLS
set sideBoosterFtl to 10000. // 10000 - RTLS
set a to 85. // 85 - ASDS | 120 - RTLS
set hasFairings to false. // Fairing Status
set fairingSepAlt to 55000. // Fairing Seperation Altitude (M)
set azimuthData to LAZcalc_init(tApoaps * 1000, tInclination). // Azimuth Calculation
set steeringManager:rollts to 20. // Counteracting Engine Twists
set steeringManager:maxstoppingtime to 1. // Steady Turns
set throt to 0.
lock throttle to throt. 

if isMaven = true {
    mavenStartup().
}
if isHeavy = true {
    heavyStartup().
}

// Required Launch Functions

function fuelLevel {
    return stage:resourcesLex["LiquidFuel"]:amount.

}

function pitchOfVector {
    parameter vecT.

    return 90 - vAng(ship:up:vector, vecT).
}

// function fairingSeperation {
//     for item in ship:modulesnamed("ModuleDecouple") {
//         IF item:part:name = "TE_19_F9_Fairing" {
//             m:doevent("Decouple").
//         }
//     }
// }

function engineSpool {
    parameter tgt, ullage is false.
    local startTime is time:seconds.
    local throttleStep is 0.00666.

    if (ullage) {
        rcs on.
        set ship:control:fore to 0.5.

        when (time:seconds > startTime + 2) then {
            set ship:control:neutralize to true.
            rcs off.
        }
    }

    if (throt < tgt) {
        if (ullage) {
            set throt to 0.025. 
            wait 0.5.
        }
        until throttle >= tgt {
            set throt to throt + throttleStep.
        } 
    } else {
        until throttle <= tgt {
            set throt to throt - throttleStep.
        }
    }

    lock throt to tgt.
}

function azimuthPitchSteer {
    local slope is (0 - 90) / (1000 * (a - 10 - a * 0.05) - 0).

    local pitch is slope * ship:apoapsis + 90.

    if isHeavy {
        when fuelLevel() <= ftl then {
            set throt to 0.
            wait 0.5.
            stage.
            wait 4.
            set throt to 1.
        }
    }

    if pitch < 0 {
        set pitch to 0.
    }

    if hasFairings = true and not isMaven {
        if ship:altitude > fairingSepAlt {
            stage.
            set hasFairings to false.
        }
    }

    set azimuth to LAZcalc(azimuthData).

    lock steering to heading(azimuth, pitch).
}

function GOVAP {
    parameter _apoapsis. // in km
    parameter _periapsis. // in km

    local sm_axis is body:radius + (_apoapsis * 1000 + _periapsis * 1000) / 2.
    local v is (body:mu * ((2/(_periapsis * 1000)) - (1/sm_axis)))^0.5.
    return v.
}

function GOVAA {
    parameter _apoapsis. // in km
    parameter _periapsis. // in km

    local sm_axis is body:radius + (_apoapsis * 1000 + _periapsis * 1000) / 2.
    local v is (body:mu * ((2/(_apoapsis * 1000)) - (1/sm_axis)))^0.5.
    return v.
}

function abort {
    set throt to 0.
    lock steering to up.
    rcs off.
    brakes off.
    sas off.
    lights on.

    shutdown.
}

// Initialisation

if dryRun = true { // Wet Dress Rehearsal
    launchDryRun(). // Runs through the countdown, for finding bugs
}

if staticFire = true { // Static Fire Test
    staticFireTest(). // Static Fire Length | Gimbal Tests
}

if abortTest = true { // Abort Test
    abortTestRun(). // Aborts at T-2 seconds
}

if dryRun = false and staticFire = false and abortTest = false { // Launch Mode
    launchProgram(). // Standard Launch Sequence
}


// Standard Launch Sequence

function launchProgram { // Base For Launch

    preLaunch(). // Abort System & Countdown
    set done to false.

    when done = false then {
        clearscreen.
        print "| Elixer E2 Telemetry".
        print "| ~~~~~~~~~~~~~~~~~~~~~".
        print "| Ship: " + ship:name.
        print "| Status: " + ship:status.
        print "| MET: " + round(missionTime, 1).
        print "| ~~~~~~~Target~~~~~~~".
        print "| Tgt Ap (Km): " + tApoaps.
        print "| Tgt Pe (Km): " + tPeriaps.
        print "| Tgt Inc (Deg): " + tInclination.
        print "| Fairing Sep (M): " + fairingSepAlt.
        print "| MECO Fuel (U): " + ftl.
        print "| ~~~~~~~Orbital~~~~~~~".
        print "| Alt (Km): " + round(altitude / 1000, 1).
        print "| Ap (Km): " + round(apoapsis / 1000, 1).
        print "| Pe (Km): " + round(periapsis / 1000, 1).
        print "| Inc (Deg): " + round(orbit:inclination, 1).
        print "| ~~~~~~~Vessel~~~~~~~".
        print "| Airspeed (M/s): " + round(airspeed, 1).
        print "| VSpeed (M/s): " + round(verticalSpeed, 1).
        print "| Mass (T): " + round(ship:mass, 1).
        print "| Q (Kpa): " + round(ship:dynamicpressure, 1).
        print "| Thrust (Kn): " + round(ship:availablethrust, 1).
        print "| Liquid Fuel (U): " + round(stage:LiquidFuel, 1).
        print "| Oxidizer (U): " + round(stage:oxidizer, 1).
        print "| ~~~~~~~Capsule/Payload~~~~~~~".
        print "| Crew (Cap): " + ship:crewcapacity.
        print "| Latitude: " + round(ship:latitude, 1).
        print "| Longitude: "+ round(ship:longitude, 1).
        print "| ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~".
        
        preserve.
    }

    liftoff(). // Ignition
    ascent(). // PP & Meco

}


function preLaunch {

    // Launch Readiness Checks

    // Countdown

    if isMaven = false {
        until countdown = 3 {
            print countdown.
            wait 1.
            clearscreen.
            set countdown to countdown - 1.

            if countdown = 120 {
                toggle ag2.
            }

            if countdown = 60 {
                set V0 to getVoice(0).
                V0:play(note(700, 0.1)).
            }

            on ag9 {
                print "Hold Hold Hold".
                ag9 off.
                ag6 off.
                ag8 off.
                reboot.
            }           
        }
    }

}

function liftoff {

    stage.
    set throt to 1.
    wait 2.
    lock steering to up.
    stage.
    wait 8.

}

function ascent { // Pitch Program

    local slope is (0 - 90) / (1000 * (a - 10 - a * 0.05) - 0).

    until fuelLevel() <= ftl + 25 {
        local pitch is slope * ship:apoapsis + 90.

        if pitch < 0 {
            set pitch to 0.
        }

        if pitch > pitchOfVector(velocity:surface) + 5 {
            set pitch to pitchOfVector(velocity:surface) + 5.
        } else if pitch < pitchOfVector(velocity:surface) - 5 {
            set pitch to pitchOfVector(velocity:surface) - 5.
        }

        set azimuth to LAZcalc(azimuthData).

        lock steering to heading(azimuth, pitch).
    }

    set cf to facing.
    lock steering to cf.

    wait 0.25.

    engineSpool(0). // MECO
    wait 0.5.
    toggle ag8.
    stage. // Stage Seperation
    wait 3.
    engineSpool(1). // SES1

    wait 1.5.
    secondstage().

}

function secondstage { // Orbital Insertion Burn

    until ship:apoapsis >= ((tApoaps - 0.5) * 1000) {
        azimuthPitchSteer().
    }

    set throt to 0. 
    lock steering to prograde + R(0, 0, 180).

    oib().

    if isMaven = true {
        wait 5.
        stage.
        wait 5.
        runoncepath("0:/E2/Maven.ks").
    }

}

function oib { 
    local targetV is GOVAP(tApoaps, tPeriaps).
    local currentV is GOVAA(ship:apoapsis / 1000, ship:periapsis / 1000).

    local vgo is targetV - currentV.

    local maxAcc is ship:maxthrust / ship:mass.
    local burnTime is vgo / maxAcc.

    lock steering to heading(LAZcalc(azimuthData), 0).
    wait until eta:apoapsis - 1 <= (burnTime / 2).
    engineSpool(1).

    until ship:periapsis >= ((tPeriaps - 0.5) * 1000) {
        azimuthPitchSteer().
        wait 0.
    }
        
    set throt to 0.

    lock steering to ship:prograde.

    wait 5.
    set done to true.
}

// Maven 

function mavenStartup {
    set target to vessel("Station Freedom").
    wait 0.1.

    global hasWindow is true.
    global goForLaunch is false.
    global windowOffset is 1.
    runOncePath("0:/LIBRARY/launchWindow.ks").  

    wait until goForLaunch = true.
    set done to false.

    when done = false then {
        clearscreen.
        print "| Elixer E2 Telemetry".
        print "| ~~~~~~~~~~~~~~~~~~~~~".
        print "| Ship: " + ship:name.
        print "| Status: " + ship:status.
        print "| MET: " + round(missionTime, 1).
        print "| ~~~~~~~Target~~~~~~~".
        print "| Tgt Ap (Km): " + tApoaps.
        print "| Tgt Pe (Km): " + tPeriaps.
        print "| Tgt Inc (Deg): " + tInclination.
        print "| Fairing Sep (M): " + fairingSepAlt.
        print "| MECO Fuel (U): " + ftl.
        print "| ~~~~~~~Orbital~~~~~~~".
        print "| Alt (Km): " + round(altitude / 1000, 1).
        print "| Ap (Km): " + round(apoapsis / 1000, 1).
        print "| Pe (Km): " + round(periapsis / 1000, 1).
        print "| Inc (Deg): " + round(orbit:inclination, 1).
        print "| ~~~~~~~Vessel~~~~~~~".
        print "| Airspeed (M/s): " + round(airspeed, 1).
        print "| VSpeed (M/s): " + round(verticalSpeed, 1).
        print "| Mass (T): " + round(ship:mass, 1).
        print "| Q (Kpa): " + round(ship:dynamicpressure, 1).
        print "| Thrust (Kn): " + round(ship:availablethrust, 1).
        print "| Liquid Fuel (U): " + round(stage:LiquidFuel, 1).
        print "| Oxidizer (U): " + round(stage:oxidizer, 1).
        print "| ~~~~~~~Capsule/Payload~~~~~~~".
        print "| Crew (Cap): " + ship:crewcapacity.
        print "| Latitude: " + round(ship:latitude, 1).
        print "| Longitude: "+ round(ship:longitude, 1).
        print "| ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~".

        preserve.
    }

    liftoff().
    ascent().

}


// EHeavy

function heavyStartup {

    // Engine setup
    set centerCore to ship:partstagged("CC").
    set sideBoosters to ship:partstagged("SB").

    // Thrust limits
    set centerCoreTL to 70. // Initial thrust limits
    set sideCoreTL to 100. // ^

    for eng in centerCore {
        if eng:tag = "CC" {
            set eng:thrustlimit to centerCoreTL.
        }
    }

    for eng in sideBoosters {
        if eng:tag = "SB" {
            set eng:thrustlimit to sideCoreTL.
        }
    }

    // Other variables
    lights on. sas off. brakes off. gear off. rcs off.
    set steeringManager:rollts to 25.
    set steeringManager:maxstoppingtime to 10.
    
    // Countdown
    until countdown = 5 {
        print countdown.
        wait 1.
        clearscreen.
        set countdown to countdown -1.

        if countdown = 120 {
            toggle ag2.
        }

        if countdown = 60 {
            set V0 to getVoice(0).
            V0:play(note(700, 0.1)).
        }

        on ag9 {
            print "Hold Hold Hold".
            ag9 off.
            ag6 off.
            ag8 off.
            reboot.
        }
    }

    // Post Count
    set throt to 1.
    stage.
    wait 3.
    stage.

    // Function calling
    heavyAscent().
}

function heavyAscent {  
    local slope is (0 - 90) / (1000 * (a - 10 - a * 0.05) - 0).

    until ship:liquidfuel <= sideBoosterFtl + 25 {
        local pitch is slope * ship:apoapsis + 90.

        if fuelLevel() <= sideBoosterFtl + 300 {
            set sideCoreTL to 40.
        }

        if pitch < 0 {
            set pitch to 0.
        }

        if pitch > pitchOfVector(velocity:surface) + 5 {
            set pitch to pitchOfVector(velocity:surface) + 5.
        } else if pitch < pitchOfVector(velocity:surface) - 5 {
            set pitch to pitchOfVector(velocity:surface) - 5.
        }

        set azimuth to LAZcalc(azimuthData).

        lock steering to heading(azimuth, pitch).
    }

    set cf to facing.
    lock steering to cf.

    wait until ship:liquidfuel <= sideBoosterFtl.
    set sideCoreTL to 100.
    wait 0.1.
    toggle ag2. // BECO
    stage.
    wait 3.
    set centerCoreTL to 100. // Throttle up

    wait 3.
    heavyBurnToAp().
}

function heavyBurnToAp {
    until ship:apoapsis >= ((tApoaps - 2) * 1000) {
        azimuthPitchSteer().
    }

    lock steering to prograde + R(0, 0, 180).

    heavyOib().
}

function heavyOib {
    local targetV is GOVAP(tApoaps, tPeriaps).
    local currentV is GOVAA(ship:apoapsis / 1000, ship:periapsis / 1000).

    local vgo is targetV - currentV.

    local maxAcc is ship:maxthrust / ship:mass.
    local burnTime is vgo / maxAcc.

    lock steering to heading(LAZcalc(azimuthData), 0).
    wait until eta:apoapsis - 1 <= (burnTime / 2).
    set throt to 1.

    wait until ship:periapsis >= tApoaps - 2 * 1000.
    set throt to 0.

    lock steering to ship:prograde.

    wait 5.
}

// Dry Run

function launchDryRun {

    countdownDry().

}


function countdownDry {

    until countdown = 3 {
        print "Dry Run".
        print countdown.
        wait 1.
        clearscreen.
        set countdown to countdown - 1.

        if countdown = 120 {
            toggle ag2.
        }

        if countdown = 60 {
            set V0 to getVoice(0).
            V0:play(note(700, 0.1)).
        }

        if countdown < 3 {
            print "Dry Run Complete".
            shutdown.
        }

        if abort {
            print "Hold Hold Hold".
            shutdown.
        }
    }

}


// Static Fire

function staticFireTest{

    when abort then {staticFireAbort().}
    
    until countdown = 0 {
        PreFire().
        print countdown.
        wait 1.
        clearscreen.
        set countdown to countdown - 1.

        if countdown < 1 {
            print "Ignition".
            break.
        }
    }

    ThrottleUp().
    Fire().
    ThrottleUp().
    PostFire().
}


function PreFire{

    print "Ready".

    // Abort

    function StaticFireAbort{

        set throt to 0.
        lock steering to up.
        rcs off.
        brakes off.
        sas off.
        lights on.

        shutdown.

    }

    set GimbalTestsDone to 0.
    
    function GTest{
        
        
    set GimbalTestsDone to GimbalTestsDone + 1.
    print GimbalTestsDone.

    
    unlock steering.
    wait 0.2.
    lock steering to heading(90,80).
    wait 0.2.
    lock steering to heading(270,80).
    wait 0.2.
    lock steering to heading(180,80).
    wait 0.2.
    lock steering to heading(0,80).
    wait 0.2.
    unlock steering.
        
        
    }

    

}

function ThrottleUp{
    
    until throt = 1 {
        set throt to throttle + 0.1.
        wait 0.1.
    }

}

function Fire{
    set AmmountOfGimbals to length / 2.
    until AmmoungOfGimbals <= 0 {
        print "hello".
    }
}

function ThrottleDown{
    until throttle = 0 {
        set throt to throttle - 0.1.
        wait 0.1.
    }
}

function PostFire{
    sas on.
    rcs off.
    brakes off.
    wait 2.
    shutdown.
}


// Abort Test Run

function abortTestRun {

    until countdown = 0 {
        PreFire().
        print countdown.
        wait 1.
        clearscreen.
        set countdown to countdown - 1.

        if ag10 {
            abort().
        }

        if countdown < 1 {
            print "False Ignition".
            break.
        }
    }

}