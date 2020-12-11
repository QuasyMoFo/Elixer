// Elixer Space Tech - MAVEN RENDEZVOUS & DOCKING SCRIPT [version 1.8]

// Station 

set target to vessel("Station Freedom").

// Variables

runOncePath("0:/LIBRARY/libGNC.ks").
set steeringManager:rollts to 20.
set steeringManager:maxstoppingtime to 10.
set isDocked to false.

rcs on.
lights on.
toggle ag5. // Docking Port Cover
// toggle ag3. // Trunk Decouple

mavenRendezvousProcedure().

// Functions

function mavenRendezvousProcedure {
    clearScreen.
    print "Maven Rendezvous Procedure | ACTIVE".
    wait 10.

    matchOrbitPlanes().
    hohmannTransferRaise().
    hohmannTransferCirc().
    
    wait 5.
    mavenDockingProcedure().
}

function mavenDockingProcedure {
    clearScreen.
    print "Maven Docking Procedure | ACTIVE".
    wait 10.
    rcs on.

    haltRendezvous(0.5). // Cancel relative velocity
    rendezvous(500, 15, 10). // Approach until physics bubble
    rendezvous(170, 7.5, 0.5). // Approach until unpacked

    set mavenPort to ship:partstagged("APAS")[0].
    set stationPort to target:partstagged("APAS")[0].

    toggle ag2.
    closeIn(50, 1.25).
    haltDock().
    closeIn(15, 1).
    haltDock().

    lock steering to lookdirup(-1 * stationPort:portfacing:vector, vcrs(ship:prograde:vector, body:position)).

    closeIn(0.5, 0.9).

    wait 2.
    unlock steering.
    set isDocked to true.
    if isDocked {
        toggle ag2.
        clearscreen.
        print "Maven Docking Procedure | COMPLETE".
        shutdown.
    }
}

function matchOrbitPlanes {
    local planeCorrection is 1.

    if (hastarget = false) {
        wait until hastarget = true.
    }

    if (abs(AngToRAN()) > abs(AngToRDN())) {
        set planeCorrection to 1.
    } else {
        set planeCorrection to -1.
    }

    set matchNode to node(time:seconds + timeToNode(), 0, (NodePlaneChange() * planeCorrection), 0).
    add matchNode.

    ExecNode(8, true, "top").
}

function hohmannTransferRaise {
    wait 10.
    set burn1Node to node(time:seconds + PhaseAngle(), 0, 0, Hohmann("raise")).
    add burn1Node.

    ExecNode(8, true).
}

function hohmannTransferCirc {
    wait 10.
    set burn1Node to node(time:seconds + eta:apoapsis, 0, 0, Hohmann("circ")).
    add burn1Node.

    ExecNode(8, true).
}

function haltRendezvous {
    parameter haltThreshold is 0.1.

    lock relVel to ship:velocity:orbit - target:velocity:orbit.
    until (relVel:mag < haltThreshold) {
        RCSTranslate(-1 * relVel).
    }
    RCSTranslate(v(0, 0, 0)).
}

function rendezvous {
    parameter tarDist, tarVel, vecThreshold is 0.1.

    local relVel is 0.1.
    local rendezvousVec is 0.

    lock relVel to ship:velocity:orbit - target:velocity:orbit.
    lock rendezvousVec to target:position - ship:position + (target:retrograde:vector:normalized * tarDist).

    set dockPID to pidloop(0.075, 0.00025, 0.05, 0.3, tarVel).
    set dockPID:setpoint to 0.
    lock dockOutput to dockPID:update(time:seconds, (-1 * rendezvousVec:mag)).

    until (rendezvousVec:mag < vecThreshold) {
        RCSTranslate((rendezvousVec:normalized * (dockOutput)) - relVel).
        print rendezvousVec:mag + "          " at (0, 10).
    }

    RCSTranslate(v(0, 0, 0)).
}

function closeIn {
    parameter tarDist, tarVel.

    local relVel is 0.
    local dockVec is 0.
    
    lock relVel to ship:velocity:orbit - stationPort:ship:velocity:orbit.
    lock dockVec to stationPort:nodeposition - mavenPort:nodeposition + (stationPort:portfacing:vector * tarDist).

    set dockPID to pidloop(0.1, 0.005, 0.0265, 0.3, tarVel).
    set dockPID:setpoint to 0.
    lock dockOutput to dockPID:update(time:seconds, (-1 * dockVec:mag)).

    until (dockVec:mag < 0.1) {
        RCSTranslate((dockVec:normalized * (dockOutput)) - relVel).
        print dockVec:mag + "          " at (0, 10).
    }

    RCSTranslate(v(0, 0, 0)).
}

function haltDock {
    parameter haltThreshold is 0.1.

    lock relVel to ship:velocity:orbit - stationPort:ship:velocity:orbit.
    until (relVel:mag < haltThreshold) {
        RCSTranslate(-1 * relVel).
    }

    RCSTranslate(v(0, 0, 0)).
}