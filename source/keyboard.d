module keyboard;

import core.time;
import std.array;
import std.algorithm: canFind, filter, map;
import std.stdio;
import std.typecons;
import input;

immutable KeyboardKey[] MODIFIER_KEYS = [
    KeyboardKey.KEY_LEFT_SHIFT,
    KeyboardKey.KEY_LEFT_CONTROL,
    KeyboardKey.KEY_LEFT_ALT,
    KeyboardKey.KEY_LEFT_SUPER,
    KeyboardKey.KEY_RIGHT_SHIFT,
    KeyboardKey.KEY_RIGHT_CONTROL,
    KeyboardKey.KEY_RIGHT_ALT,
    KeyboardKey.KEY_RIGHT_SUPER
];

bool isModifier(KeyboardKey key) {
    return MODIFIER_KEYS.canFind(key);
}

enum KeyAction {
    RELEASE=0,
    PRESS,
    REPEAT
}

enum Modifier {
    NULL = 0x0000,
    SHIFT = 0x0001,
    CONTROL = 0x0002,
    ALT = 0x0004,
    SUPER = 0x0008,
    CAPS = 0x0010,
    NUM = 0x0020
}

Modifier toModifier(KeyboardKey key) {
    switch(key) {
        case KeyboardKey.KEY_LEFT_SHIFT:
            return Modifier.SHIFT;
        case KeyboardKey.KEY_RIGHT_SHIFT:
            return Modifier.SHIFT;
        case KeyboardKey.KEY_LEFT_CONTROL:
            return Modifier.CONTROL;
        case KeyboardKey.KEY_RIGHT_CONTROL:
            return Modifier.CONTROL;
        case KeyboardKey.KEY_LEFT_ALT:
            return Modifier.ALT;
        case KeyboardKey.KEY_RIGHT_ALT:
            return Modifier.ALT;
        case KeyboardKey.KEY_LEFT_SUPER:
            return Modifier.SUPER;
        case KeyboardKey.KEY_RIGHT_SUPER:
            return Modifier.SUPER;
        default:
            assert(false);
    }
}

struct KeyEvent {
    KeyboardKey key;
    dchar charValue;
    int modifiers;
    KeyAction action;

    bool hasModifier(Modifier mod) {
        return cast(bool)(modifiers & mod);
    }
}

bool isAnyMod(int flags, Modifier[] ms...) {
    foreach(m; ms)
        if(flags & m) return true;
    return false;
}

extern(C) alias KeyCallback = void function(void*, int, int, int, int);
extern(C) void glfwSetKeyCallback(void* window, KeyCallback callback);

extern(C) void handleKey(void* window, int key, int scancode, int action_, int mods) {
    import std.ascii;
    import std.conv;

    auto keyboardKey = cast(KeyboardKey)key;
    auto action = cast(KeyAction)action_;

    dchar charValue = 0;

    auto maybeShortcut = mods.isAnyMod(Modifier.CONTROL, Modifier.ALT, Modifier.SUPER);
    if(keyboardKey.isPrintable && !maybeShortcut) return;

    if(maybeShortcut && keyboardKey.isPrintable) {
        charValue = keyboardKey.to!dchar.toLower();
    }

    auto event = KeyEvent(keyboardKey, charValue, mods, action);
    Keyboard.get().handleKeyEvent(event);
}

extern(C) alias CharCallback = void function(void*, dchar);
extern(C) void glfwSetCharCallback(void* window, CharCallback callback);

extern(C) void handleChar(void* window, dchar c) {
    auto event = KeyEvent(KeyboardKey.KEY_NULL, c, 0, KeyAction.PRESS);
    Keyboard.get().handleKeyEvent(event);
}


class Keyboard {
    private static Keyboard keyboard;
    int heldModifiers;

    static Keyboard get() {
        if(!keyboard)
            keyboard = new Keyboard();
        return keyboard;
    }

    private this() {
        import raylib: GetWindowHandle;
        auto window = GetWindowHandle();
        glfwSetKeyCallback(window, &handleKey);
        glfwSetCharCallback(window, &handleChar);
        pendingEvents = new KeyEvent[0];
    }

    private KeyEvent[] pendingEvents;

    int opApply(scope int delegate(KeyEvent) dg) {
        int result = 0;
        foreach(event; pendingEvents) {
            result = dg(event);
            if (result)
                break;
        }
        pendingEvents = [];
        return result;
    }

    void handleKeyEvent(KeyEvent event) {
        if(event.key.isModifier) {
            if(event.action == KeyAction.PRESS)
                heldModifiers |= event.key.toModifier();
            if(event.action == KeyAction.RELEASE)
                heldModifiers ^= event.key.toModifier();
        }
        pendingEvents ~= event;
    }
}
