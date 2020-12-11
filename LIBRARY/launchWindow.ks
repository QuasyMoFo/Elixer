// INSTANTANEOUS LAUNCH WINDOW SEQUENCE

// core:part:getmodule("kOSProcessor"):doEvent("Open Terminal").
// print "WAITING TO YEET THE ROCKET" + hasWindow + " " + goForLaunch + " " + hasTarget at (0, 13).
print "INCLINATION DELTA: " + (Azimuth(DirCorr() * tInclination, tApoaps) - (abs(tInclination) + 90)) at (0, 13).

if (Azimuth(DirCorr() * tInclination, tApoaps) - (abs(tInclination) + 90)) < 0.1 {
    set correctInc to false.
} else {
    set correctInc to true.
}

if (hasWindow = true and goForLaunch = false and hasTarget = true and target:orbit:inclination > 1 or target:orbit:tInclination < 1 and correctInc = true) {
    on ag9 {
        ag9 off.
        ag8 off.
        ag6 off.
        reboot.
    }
    DirCorr().
    WaitTime().
} else { global goForLaunch is true. }
    
wait until (goForLaunch = true).

function WaitTime {
    if (AngToRAN() > 0)
        kuniverse:timewarp:warpto(time:seconds + TMinus("AN") - 1000).
    else
        kuniverse:timewarp:warpto(time:seconds + TMinus("DN") - 1000).

    until (UpcomingNodeAngle() < windowOffset) {
        wait 0.
        DirCorr().
    }

    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled = true.

    global goForLaunch is true.
}

//returns angle, whichever is upcoming
function UpcomingNodeAngle {   
    if (AngToRAN() > 0) { TMinus("AN"). return AngToRAN(). }
    else { TMinus("DN"). return AngToRDN(). }
}

//returns seconds (returns a positive value)
// real TMinus is time:seconds - time:seconds + TMinus()
function TMinus {
    parameter node.

    if (node = "AN") {  // will only be either AN or DN
        print "T: -" + round(((AngToRAN() - windowOffset) / 360 * body:rotationperiod)) + "   " at (0, 2).
        return ((AngToRAN() - windowOffset) / 360 * body:rotationperiod).
    } else {
        print "T: -" + round(((AngToRDN() - windowOffset) / 360 * body:rotationperiod)) + "   " at (0, 2).
        return ((AngToRDN() - windowOffset) / 360 * body:rotationperiod).
    }
}