module keyboard;

import core.time;
import std.array;
import std.algorithm: canFind, filter, map;
import std.stdio;
import input;

immutable KeyboardKey[] MODIFIER_KEYS = [
    // right keyboard can suck it
    KeyboardKey.KEY_LEFT_SHIFT,
    KeyboardKey.KEY_LEFT_CONTROL,
    KeyboardKey.KEY_LEFT_ALT,
    KeyboardKey.KEY_LEFT_SUPER
];

bool isModifier(KeyboardKey key) {
    return MODIFIER_KEYS.canFind(key);
}

struct KeyState {
    KeyboardKey key;
    MonoTime pressTime;
    bool justPressed;
    bool hasBegunRepeating = false;
    bool isDown = false;
    MonoTime timeOfLastRepeat;

    long timeHeldMs() {
        return (MonoTime.currTime - pressTime).total!"msecs";
    }

    long timeSinceRepeatMs() {
        return (MonoTime.currTime - timeOfLastRepeat).total!"msecs";
    }
}

class Keyboard {
    bool capsLockIsControl = true;
    KeyState[KeyboardKey] keys;
    bool[KeyboardKey] modifiers;
    KeyState* mostRecentlyPressedKey;

    void update() {
        foreach(key, ref state; keys) {
            state.justPressed = false;
            if(!isKeyDown(key)) {
                registerKeyUp(key);
            }
        }

        foreach(key; modifiers.byKey) {
            if(!isKeyDown(key)) {
                registerKeyUp(key);
            }
        }

        foreach(key; getPressedKeys()) {
            if(key == KeyboardKey.KEY_CAPS_LOCK && capsLockIsControl) {
                key = KeyboardKey.KEY_LEFT_CONTROL;
            }
            registerKeyDown(key);
        }
    }

    KeyboardKey[] heldModifiers() {
        return modifiers.keys;
    }

    KeyboardKey[] justPressed() {
        return keys.byKeyValue.filter!(kv => kv.value.justPressed).map!(kv => kv.key).array;
    }

    private void registerKeyDown(KeyboardKey key) {
        if(key.isModifier) {
            modifiers[key] = true;
        } else {
            keys[key] = KeyState(key, MonoTime.currTime, true);
            keys[key].isDown = true;
            mostRecentlyPressedKey = &keys[key];
        }
    }

    private void registerKeyUp(KeyboardKey key) {
        if(key.isModifier) {
            modifiers.remove(key);
        } else {
            keys[key].isDown = false;
            keys.remove(key);
        }
    }
}
