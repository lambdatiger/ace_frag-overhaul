#include "..\script_component.hpp"
/*
 * Author: Jaynus, NouberNou, Lambda.Tiger,
 * This function creates spalling if a projectile penetrated a surface and was slowed down enough proportional to the caliber.
 * It is dissimilar in function from fnc_doSpall, but leveraging the "Penetrated" projectile EH to process faster.
 *
 * Arguments:
 * Arguments are the same as BI's "Penetratred" EH:
 * https://community.bistudio.com/wiki/Arma_3:_Event_Handlers#Penetrated
 *
 * Return Value:
 * None
 *
 * Example:
 * [BIS_PENETRATED_EH_ARGS] call ace_frag_fnc_doSpallPenetration;
 *
 * Public: No
 */
#define GLUE(g1,g2) g1##g2
#define EPSILON 0.1

TRACE_1("doSpallPenetration",_this);
if (CBA_missionTime < ace_frag_nextSpallAllowTime) exitWith {
    TRACE_1("timeExit",_this);
};
params ["_projectile", "_hitObject", "_surfaceType", "", "_spallPosASL", "_newVelocityVector"];

private _ammo = typeOf _projectile;
if (_spallPosASL isEqualTo [0,0,0] ||
    {_ammo isEqualTo ""} ||
    {_hitObject isKindOf "CAManBase"}) exitWith {
    TRACE_4("time/invalidHit",CBA_missionTime,GVAR(nextSpallAllowTime),_hitObject,_spallPosASL);
};

private _material = [_surfaceType] call FUNC(getMaterialInfo);
if (_material == "ground") exitWith {
    #ifdef DEBUG_MODE_FULL
    systemChat "ground spall";
    #endif
};

[_ammo] call FUNC(getSpallInfo) params ["_caliber", "_explosive", "_indirectHit"];
private _velocityChange = velocity _projectile vectorDiff _newVelocityVector;
private _speedChange = vectorMagnitude _velocityChange;
/*
 * This is all fudge factor since real spalling is too complex for calculation.
 * The equation takes taking a quasi scale of energy using caliber and change in speed.
 */
private _spallPower = ACE_FRAG_SPALL_CALIBER_COEF * _caliber * sqrt _speedChange * GVAR(spallIntensity);
TRACE_4("found speed",_velocityChange,_speedChange,_caliber,_spallPower);

if (_spallPower < 2) exitWith {
    TRACE_1("lowImpulse",_ammo);
};
// Passed all exitWiths
GVAR(nextSpallAllowTime) = CBA_missionTime + ACE_FRAG_SPALL_HOLDOFF;
private _spallDirection = vectorNormalized _velocityChange;

#ifdef DEBUG_MODE_DRAW
if GVAR(dbgSphere) then {
    [_spallPosASL, "green"] call FUNC(dev_sphereDraw);
};
#endif

private _spawnSize = switch (true) do
{
    case (_spallPower < 3): {"_spall_tiny"};
    case (_spallPower < 5): {"_spall_small"};
    case (_spallPower < 8): {"_spall_medium"};
    case (_spallPower < 12): {"_spall_large"} ;
    default {"_spall_huge"};
};

private _spallSpawner = createVehicle [
    QUOTE(GLUE(ADDON,_)) + _material + _spawnSize,
    ASLToATL _spallPosASL,
    [],
    0,
    "CAN_COLLIDE"
];

// Solve for one of the vectors normal to _spallVectorUp on y = 0 plane
private _spallVectorUp = [0, 0, 1];
if (_spallDirection#2 > EPSILON) then {
    private _newZ = _spallDirection#0 / _spallDirection#2;
    _spallVectorUp = vectorNormalized [1, 0, -_newZ];
};

_spallSpawner setVectorDirandUp [_spallDirection, _spallVectorUp];
_spallSpawner setVelocityModelSpace [0, _speedChange * ACE_FRAG_SPALL_VELOCITY_INHERIT_COEFF, 0];
_spallSpawner setShotParents getShotParents _projectile;
TRACE_4("dir&up",_spallDirection,vectorDir _spallSpawner,_spallVectorUp,vectorUp _spallSpawner);

#ifdef DEBUG_MODE_FULL
systemChat ("spd: " + str speed _spallSpawner + ", spawner: " + _fragSpawnType + ", spallPow: " + str _spallPower);
#endif
#ifdef DEBUG_MODE_DRAW
_spallSpawner addEventHandler [
    "SubmunitionCreated",
    {
        params ["", "_subProj"];
        [_subProj] call FUNC(dev_addRound);
    }
];
#endif
