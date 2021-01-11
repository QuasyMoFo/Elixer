// Variables

set LandingZone to latlng(11.9367512718005, -42.7576438993974).
set BoosterHeight to 20.74.
set targetApoapsis to 20000.

set steeringManager:maxstoppingtime to 2.
set steeringManager:rollts to 20.
// Launch

function Launch
{
    lock trueApoapsis to ship:apoapsis - BoosterHeight.
    lock g to constant:g * body:mass / body:radius^2.
    lock trueRadar to alt:radar - BoosterHeight.
    lock p to 90 - vAng(ship:facing:vector, ship:up:vector).
    set done to false.

    set count to 10.
    
    until count = 0 {
        clearscreen.
        print "T-" + count.
        wait 1.
        set count to count - 1.

        on ag9 {
            ag10 off.
            ag9 off.
            lock throttle to 0.
            wait 0.1.
            reboot.
        }
    }

    when done = false then {
        clearscreen.
        print "MET: " + round(missionTime, 1).
        print "Apoapsis: " + round(trueApoapsis, 1).
        print "Altitude: " + round(trueRadar, 1).
        print "Vertical Speed: " + round(verticalSpeed, 1).
        print "Ground Speed: " + round(ship:groundspeed, 1). 
        print "Pitch: " + round(p, 1).
        print "Status: " + status.

        switch to 0.
        //log "MET: " + round(missionTime, 1) + " | " + "Apoapsis: " + round(apoapsis, 1) + " | " + "Altitude: " + round(trueRadar, 1) + " | " + "VSpeed: " + round(ship:verticalspeed, 1) + " | " + "Groundspeed: " + round(ship:groundspeed, 1) + " | " + "Pitch: " + round(p, 1) + " | " + "Throttle: " + throttle to testflight.csv.

        wait 0.5.
        preserve.
    }

    stage.
    lock throttle to 1.05 * ship:mass * g / ship:availablethrust.
    set cf to facing.
    lock steering to cf.
    wait 2.
    stage.
    wait 3.
    Ascent().
}


// Ascent

function Ascent
{
    wait 2.
    lock steering to heading(LandingZone:heading, 95).

    wait until throttle <= 0.5.
    toggle ag1.
    when throttle <= 0.4 then {toggle ag2. lock steering to heading(LandingZone:heading, 90.75).}
    wait until trueApoapsis > targetApoapsis - 275.
    lock throttle to 0.5 * ship:mass * g / ship:availablethrust.
    wait until trueApoapsis > targetApoapsis.
    lock steering to heading(LandingZone:heading, 0).
    toggle ag3.
    lock throttle to 0.
    wait 1.
    DescentSetup().
}


// Decent

function DescentSetup
{
    lock LZHeading to LandingZone:heading.
    set aoa to 0.
    set errorScaling to 1.					
    lock g to constant:g * body:mass / body:radius^2.
    lock maxDecel to (ship:availablethrust / ship:mass) - g.	
    lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		
    lock idealThrottle to stopDist / trueRadar.					
    lock impactTime to trueRadar / abs(ship:verticalspeed).

    toggle ag1.
    toggle ag2.

    set LatErrorMulti to 50.

    set LngErrorMulti to 125. // -125
    //lock DescentHeading to 90 + (latError * 500).


    lock LatCorrection to (latError * LatErrorMulti).
    lock LngCorrection to (lngError * LngerrorMulti).

    Descent().
}


function getImpact {
    if addons:tr:hasimpact { return addons:tr:impactpos. }
    return ship:geoposition.
}

function lngError {
    return getImpact():lng - LandingZone:lng.
}

function latError {
    return getImpact():lat - LandingZone:lat.
}

function errorVector {
    return getImpact():position - LandingZone:position.
}

function getSteering {

    local errorVector is errorVector().
    local velVector is -ship:velocity:surface.
    local result is velVector + errorVector*errorScaling.

    if vang(result, velVector) > aoa
    {
        set result to velVector:normalized + tan(aoa) * errorVector:normalized.
    }

    return lookdirup(result, facing:topvector).
}


function Descent
{
    when (trueRadar < 8000) then {
        set LatErrorMulti to 10.
        lock LatCorrection to (latError * LatErrorMulti * 2.5).
        lock LngCorrection to (lngError * LngErrorMulti * 2.5).
        }

    when (trueRadar < 2000) then {
        set LatErrorMulti to 7.5.
        lock LatCorrection to (latError * LatErrorMulti * 4.5).
        lock LngCorrection to (lngError * LngErrorMulti * 4.5).
    }

    rcs on.
    wait 2.
    ag6 on.
    wait 2.
    ag5 on.

    until (stopDist +  175 > trueRadar)
    {
        lock steering to heading(LZHeading, (0 + LngCorrection), (0 + LatCorrection)).
    }

    set steeringManager:maxstoppingtime to 10.

    Landing().
}


// Landing 

function Landing
{


    when impactTime < 3 then {gear on.}
    when impactTime < 1.75 then {lock steering to up.}
    lock throttle to 0.9.
    lock steering to srfRetrograde + R(0, 330, 0).
    toggle ag5.
    wait 3.25.
    set aoa to -1.5.
    lock steering to getSteering().

    lock throttle to idealThrottle.

    wait until ship:verticalspeed > -0.01.
    lock throttle to 0.
    toggle ag6.
    wait 10.
    rcs off.
    shutdown.
}


// Master

function Master
{
   Launch().
}  

wait until ag10. // 0 key
Master().