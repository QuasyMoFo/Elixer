// Elixer E2 Launch Script [version 1.3]

// Elixer's public launch script, used on E2 for orbital launches with contracted payloads.
// Mission parameters can be changed through the variables below, the script detects if it needs to use RTLS / ASDS.
// 
// isMaven DOES NOT WORK as of this time, do not attempt to use it as it will break.
// 
// Code is under APACHE 2.0 License. 


// Launch Variables

SET TARGETAPOAPSIS TO 140. // Apoapsis (KM) 5000 
SET TARGETPERIAPSIS TO 130. // Periapsis (KM) 4900
SET TARGETINCLINATION TO 0. // Inclination (DEG) 6

// Script Mode

SET dryRun to false. // Countdown (No Launch)
SET staticFire to false. // Static Fire (No Liftoff)
SET abortTest to false. // Aborts at T-2 (No Launch)
SET isMaven to false.

// Library Runs

runOncePath("0:/lib_lazcalc").

// Ascent Variables

set countdown to 10. // T- Countdown | 180-launchday
set ftl to 2300. // 1800 - ASDS E2 | 2300 - RTLS E2
set a to 120. // 100 - asds ~ 120 rtls
set hasFairings to true. // Fairing Status
set fairingSepAlt to 55000. // Fairing Seperation Altitude (M)
set deployedFairings to false. // Deployed Status
set azimuthData to LAZcalc_init(TARGETPERIAPSIS * 1000, TARGETINCLINATION). // Azimuth Calculation
set steeringManager:rollts to 20. // Counteracting Engine Twists
set steeringManager:maxstoppingtime to 1. // Steady Turns
if isMaven {
    set target to vessel("Station Freedom").
    set window to true.
    global hasWindow is window.
    global windowOffset is 2.
    global goForLaunch is false.
    runOncePath("0:/LIBRARY/launchWindow.ks").
}

// Required Launch Functions

function fuelLevel {

    return stage:resourcesLex["LiquidFuel"]:amount.

}

function pitchOfVector {

    parameter vecT.

    return 90 - vAng(ship:up:vector, vecT).

}

function azimuthPitchSteer {
  
    set a to 85.
    local slope is (0 - 90) / (1000 * (a - 10 - a * 0.05) - 0).

    local pitch is slope * ship:apoapsis + 90.

    if pitch < 0 {
        set pitch to 0.
    }

    if hasFairings = true and deployedFairings = false {
        if ship:altitude > fairingSepAlt {
            stage.
            set deployedFairings to true.
        }
    }

    set azimuth to LAZcalc(azimuthData).

    lock steering to heading(azimuth, pitch).

}

function abort {

        lock throttle to 0.
        lock steering to up.
        rcs off.
        brakes off.
        sas off.
        lights on.

        shutdown.

    }

// Initialisation

wait until ag6.
clearscreen.

if dryRun = true {
    launchDryRun(). // Runs through the countdown, for finding bugs
}

if staticFire = true {
    staticFireTest(). // Static Fire Length | Gimbal Tests
}

if abortTest = true {
    abortTestRun(). // Aborts at T-2 seconds
}

if dryRun = false and staticFire = false and abortTest = false { 
    launchProgram(). // Standard Launch Sequence
}


// Standard Launch Sequence

function launchProgram { // Base For Launch

    preLaunch(). // Abort System & Countdown
    liftoff(). // Ignition
    ascent(). // PP & Meco

}


function preLaunch {

    // Launch Readiness Checks



    // Countdown

    if isMaven = false {
        until countdown = 0 {
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
                print "Ignition".
                break.
            }
        }
    }

    if isMaven {
        wait until goForLaunch = true.
    }

}

function liftoff {

    lock throttle to 1.
    stage.
    wait 2.
    stage.

}

function ascent { // Pitch Program

    set a to 85.
    local slope is (0 - 90) / (1000 * (a - 10 - a * 0.05) - 0).

    until fuelLevel() <= ftl + 100 {
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
    
    wait 3.5.

    lock throttle to 0. // MECO
    wait 0.5.
    toggle ag8.
    stage. // Stage Seperation
    wait 3.
    lock throttle to 1. // SES1

    wait 3.
    secondstage().

}

function secondstage { // Orbital Insertion Burn

    until ship:apoapsis >= ((TARGETAPOAPSIS - 1) * 1000) {
        azimuthPitchSteer().
    }

    lock throttle to 0. // SECO1
    lock steering to prograde.

    wait until eta:apoapsis < 5.
    lock throttle to 1. // SES2
    wait until ship:Periapsis > TARGETPERIAPSIS.
    lock throttle to 0. // SECO2.
    wait 10.
    stage.

    if isMaven {
        runoncepath("0:/E2/Maven.ks").
    }

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

        lock throttle to 0.
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
    
    until throttle = 1 {
        lock throttle to throttle + 0.1.
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
        lock throttle to throttle - 0.1.
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