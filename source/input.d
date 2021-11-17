module input;

public import raylib: KeyboardKey;

KeyboardKey[] getPressedKeys() {
    import raylib: GetKeyPressed;
    auto keys = new KeyboardKey[0];

    KeyboardKey key = cast(KeyboardKey)GetKeyPressed();
    while(key) {
        keys ~= key;
        key = cast(KeyboardKey)GetKeyPressed();
    }

    return keys;
}

bool isKeyPressed(int key) {
    import raylib: IsKeyPressed;
    return IsKeyPressed(key);
}

bool isKeyDown(int key) {
    import raylib: IsKeyDown;
    return IsKeyDown(key);
}

bool isKeyReleased(int key) {
    import raylib: IsKeyReleased;
    return IsKeyReleased(key);
}

bool isKeyUp(int key) {
    import raylib: IsKeyUp;
    return IsKeyUp(key);
}
