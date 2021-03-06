// Elixer Space Tech - RTLS Part 1 [version 1.6]

// Created by Edwin Robert ~ Oscar Fleet 
// Using APACHE 2.0 License

// Landing Co-ordinates

set landingZone to latlng(11.9368650528175, -42.7576092270855).

// Variables

set boostbackGuidanceAngles to 5.
set overshootDistance to 1500.
set steeringManager:maxstoppingtime to 15.
set lngOff to (landingZone:lng - addons:tr:impactpos:lng) * 10472.
set latOff to (landingZone:lat - addons:tr:impactpos:lat) * 10472.
set runmode to 0.

// Throttle 

when throttle = 0 then {
    set steeringManager:pitchpid:kd to 2.
    set steeringManager:yawpid:kd to 2.
    preserve.
}

when throttle > 0 then {
    set steeringManager:pitchpid:kd to 1.
    set steeringManager:yawpid:kd to 1.
    preserve.
}

when altitude > 4000 then {
    set lngOff to (landingZone:lng - addons:tr:impactpos:lng) * 10472.
    set latOff to (landingZone:lat - addons:tr:impactpos:lat) * 10472.
    preserve.
}

// Boostback

rcs on.
toggle ag1.
lock steering to heading(landingZone:heading + 1, 0).

wait 12.

lock throttle to 1.
rcs off.

when throttle = 0 then {
    runOncePath("0:/E2/R.T.L.S.Landing.ks").
}

when lngOff > overshootDistance then {
    lock throttle to 0.
}

when throttle > 0 then {
    when latOff < -20 then {
        lock steering to heading(landingZone:heading - boostbackGuidanceAngles, 1).
        preserve.
    }
}

when latOff > 20 then {
    lock steering to heading(landingZone:heading + boostbackGuidanceAngles, 1).
    preserve.
}

wait until ship:verticalspeed < -5.
    set runmode to 1.