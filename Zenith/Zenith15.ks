// Variables

set LandingZone to latlng(11.9367512718005, -42.7576438993974).
set BoosterHight to 20.74.
set targetApoapsis to 15000.

set steeringManager:maxstoppingtime to 2.
set steeringManager:rollts to 20.
// Launch

function Launch
{
    lock trueApoapsis to ship:apoapsis - BoosterHight.
    lock g to constant:g * body:mass / body:radius^2.
    set Cycled to true.
    set done to false.


    wait 1.
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
        print "Telemetry".

        wait 0.1.
        preserve.
    }

    stage.
    lock throttle to 1.
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
    lock steering to heading(LandingZone:heading, 90).
    lock throttle to 1.05 * ship:mass * g / ship:availablethrust.

    wait until throttle <= 0.5.
    toggle ag1.
    when throttle <= 0.65 then {toggle ag2. lock steering to heading(LandingZone:heading, 91).}
    wait until trueApoapsis > targetApoapsis.
    toggle ag3.
    lock throttle to 0.
    wait 1.
    DescentSetup().
}


// Decent

function DescentSetup
{
    lock LZHeading to LandingZone:heading.
    set aoa to -20.  
    set errorScaling to 1.
    lock trueRadar to alt:radar - BoosterHight.					
    lock g to constant:g * body:mass / body:radius^2.
    lock maxDecel to (ship:availablethrust / ship:mass) - g.	
    lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).		
    lock idealThrottle to stopDist / trueRadar.					
    lock impactTime to trueRadar / abs(ship:verticalspeed).

    toggle ag1.
    toggle ag2.

    lock LatErrorMulti to 250. // The 2 values that decide its fate 
    // LNG is fine its the LAT that is the issue

    lock LngErrorMulti to -200. // ^
    //lock DescentHeading to 90 + (latError * 500). // If you change this then death


    lock LatCorrection to (latError * LatErrorMulti * 3).
    lock LngCorrection to (lngError * LngerrorMulti * 3).

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
    when (trueRadar < 4000) then {
        lock LatErrorMulti to 6000.
        lock LatCorrection to (latError * LatErrorMulti * 4).
        lock LngCorrection to (lngError * LngErrorMulti * 4).
        }

    when (trueRadar < 2000) then {
        lock LatCorrection to (latError * LatErrorMulti * 7).
        lock LngCorrection to (lngError * LngErrorMulti * 7).
    }

    lock steering to heading(LZHeading, 0).
    rcs on.
    wait 2.
    ag6 on.
    wait 2.
    ag5 on.

    until (stopDist + 325 > trueRadar)
    {
        lock steering to heading(LZHeading, (0 + LngCorrection), (0 + LatCorrection)).
    }

    Landing().
}


// Landing 

function Landing
{
    when impactTime < 3 then {gear on.}
    when impactTime < 0.75 then {lock steering to up.}
    lock throttle to idealThrottle.
    toggle ag5.
    toggle ag6.
    lock steering to srfRetrograde + R(0, 330, 0).
    wait 4.
    lock steering to srfRetrograde.

    wait 1.
    lock steering to getSteering().
    set aoa to -4.

    wait until ship:verticalspeed > -30.
    set aoa to -2.

    wait until ship:verticalspeed > -0.01.
    lock throttle to 0.
    lock steering to up.  
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

