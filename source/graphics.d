public import raylib: Color, Colors, Vector2, Rectangle, Font, Vector3;
import std.conv;
import std.string : toStringz;

void initWindow(int width, int height, string title) {
    import raylib: InitWindow;
    InitWindow(width, height, title.toStringz);
}

void enableAntialiasing() {
    import raylib: SetConfigFlags, ConfigFlags;
    SetConfigFlags(ConfigFlags.FLAG_MSAA_4X_HINT);
}

Color colorFromHSV(float h, float s, float v) {
    import raylib: ColorFromHSV;
    return ColorFromHSV(h,s,v);
}

Vector3 colorToHSV(Color color) {
    import raylib: ColorToHSV;
    return ColorToHSV(color);
}

Color invertColor(Color color) {
    auto hsv = colorToHSV(color);
    return colorFromHSV((hsv.x + 180) % 360, 1 - hsv.y, 1 - hsv.z);
}

Vector2 getMousePosition() {
    import raylib: GetMousePosition;
    return GetMousePosition();
}

int getMouseY() {
    import raylib: GetMouseY;
    return GetMouseY();
}

bool mousePressed() {
    import raylib: IsMouseButtonPressed;
    return IsMouseButtonPressed(0);
}

bool mouseUp() {
    import raylib: IsMouseButtonUp;
    return IsMouseButtonUp(0);
}

bool mouseDown() {
    import raylib: IsMouseButtonDown;
    return IsMouseButtonDown(0);
}

bool rightMouseDown() {
    import raylib: IsMouseButtonDown;
    return IsMouseButtonDown(1);
}

bool middleMouseDown() {
    import raylib: IsMouseButtonDown;
    return IsMouseButtonDown(2);
}

int getMouseX() {
    import raylib: GetMouseX;
    return GetMouseX();
}

bool windowShouldClose() {
    import raylib: WindowShouldClose;
    return WindowShouldClose();
}

void closeWindow() {
    import raylib: CloseWindow;
    CloseWindow();
}

void clearBackground(ubyte r, ubyte g, ubyte b) {
    import raylib: ClearBackground;
    ClearBackground(Color(r, g, b));
}

void clearBackground(Color color) {
    import raylib: ClearBackground;
    ClearBackground(color);
}

void beginDrawing() {
    import raylib: BeginDrawing;
    BeginDrawing();
}

void endDrawing() {
    import raylib: EndDrawing;
    EndDrawing();
}

float getDeltaTime() {
    import raylib: GetFrameTime;
    return GetFrameTime();
}

double getTimeSeconds() {
    import raylib: GetTime;
    return GetTime();
}

void setTargetFPS(int targetFPS) {
    import raylib: SetTargetFPS;
    SetTargetFPS(targetFPS);
}

int getFPS() {
    import raylib: GetFPS;
    return GetFPS();
}

void pushMatrix() {
    import rlgl: rlPushMatrix;
    rlPushMatrix();
}

void popMatrix() {
    import rlgl: rlPopMatrix;
    rlPopMatrix();
}

void translateMatrix2D(float x, float y) {
    import rlgl: rlTranslatef;
    rlTranslatef(x, y, 0);
}

void rotateMatrix2D(float angle) {
    import rlgl: rlRotatef;
    rlRotatef(angle, 0, 0, 1);
}

void drawRectangleLines(Vector2 pos, float width, float height, Color c) {
    import raylib: DrawRectangleLines;
    DrawRectangleLines(pos.x.to!int, pos.y.to!int, width.to!int, height.to!int, c);
}

void drawRectangleLines(Vector2 pos, Vector2 dim, Color c) {
    import raylib: DrawRectangleLines;
    DrawRectangleLines(pos.x.to!int, pos.y.to!int, dim.x.to!int, dim.y.to!int, c);
}

void drawRectangleLines(Rectangle r, Color c) {
    import raylib: DrawRectangleLines;
    DrawRectangleLines(r.x.to!int, r.y.to!int, r.width.to!int, r.height.to!int, c);
}

void drawRectangleRounded(Rectangle r, float roundness, int segments, Color color) {
    import raylib: DrawRectangleRounded;
    DrawRectangleRounded(r, roundness, segments, color);
}

void drawRotatedRectangleRounded(Rectangle r, float angle, float roundness, int segments, Color color) {
    pushMatrix();
    translateMatrix2D(r.x, r.y);
    rotateMatrix2D(angle);
    drawRectangleRounded(Rectangle(0, 0, r.width, r.height), roundness, segments, Colors.WHITE);
    popMatrix();
}

void drawCircle(Vector2 center, float radius, Color color) {
    import raylib: DrawCircleV;
    DrawCircleV(center, radius, color);
}

void drawCircle(float x, float y, float radius, Color color) {
    import raylib: DrawCircle;
    DrawCircle(x.to!int, y.to!int, radius, color);
}

void drawLine(float start_x, float start_y, float end_x, float end_y, Color color) {
    import raylib: DrawLine;
    DrawLine(start_x.to!int, start_y.to!int, end_x.to!int, end_y.to!int, color);
}

void drawLine(float start_x, float start_y, float end_x, float end_y, float width, Color color) {
    import raylib: DrawLineEx;
    DrawLineEx(Vector2(start_x, start_y), Vector2(end_x, end_y), width, color);
}

void drawLine(Vector2 start, Vector2 end, Color color) {
    import raylib: DrawLineV;
    DrawLineV(start, end, color);
}

void drawLine(Vector2 start, Vector2 end, float width, Color color) {
    import raylib: DrawLineEx;
    DrawLineEx(start, end, width, color);
}

void drawRectangle(Vector2 start_corner, Vector2 dimensions, Color color) {
    import raylib: DrawRectangleV;
    DrawRectangleV(start_corner, dimensions, color);
}

void drawRectangle(int x, int y, int width, int height, Color color) {
    import raylib: DrawRectangle;
    DrawRectangle(x, y, width, height, color);
}

void drawRectangle(Vector2 start_corner, int width, int height, Color color) {
    import raylib: DrawRectangle;
    DrawRectangle(start_corner.x.to!int, start_corner.y.to!int, width, height, color);
}

void drawRectangle(Rectangle rect, Color color) {
    import raylib: DrawRectangleRec;
    DrawRectangleRec(rect, color);
}

void drawRectangleRotated(Rectangle rec, Vector2 origin, float rotation, Color color) {
    import raylib: DrawRectanglePro;
    DrawRectanglePro(rec, origin, rotation, color);
}

bool pointInCircle(Vector2 point, Vector2 circleCenter, float circleRadius) {
    import raylib: CheckCollisionPointCircle;
    return CheckCollisionPointCircle(point, circleCenter, circleRadius);
}

bool pointInRectangle(Vector2 point, Rectangle rect) {
    import raylib: CheckCollisionPointRec;
    return CheckCollisionPointRec(point, rect);
}

Rectangle rectFromTwoCorners(Vector2 corner_a, Vector2 corner_b) {
    auto dim = corner_a - corner_b;
    return Rectangle(corner_a.x, corner_a.y, dim.x, dim.y);
}

Rectangle rectFromTwoVectors(Vector2 pos, Vector2 dims) {
    return Rectangle(pos.x, pos.y, dims.x, dims.y);
}

void drawText(string str, Vector2 pos, int size, Color color) {
    import raylib: DrawText;
    DrawText(str.toStringz, pos.x.to!int, pos.y.to!int, size, color);
}

void drawText(string str, Font font, Vector2 pos, int size, Color color) {
    import raylib: DrawTextEx;
    auto spacing = 1f;
    DrawTextEx(font, str.toStringz, pos, size, spacing, color);
}

int measureText(string str, int fontSize) {
    import raylib: MeasureText;
    return MeasureText(str.toStringz, fontSize);
}

Vector2 measureText2d(string str, float fontSize, float spacing) {
    import raylib: MeasureTextEx, GetFontDefault;
    auto font = GetFontDefault();
    return MeasureTextEx(font, str.toStringz, fontSize, spacing);
}

Vector2 measureText2d(string str, Font font, float fontSize, float spacing) {
    import raylib: MeasureTextEx, GetFontDefault;
    return MeasureTextEx(font, str.toStringz, fontSize, spacing);
}

void drawCenteredText(string text, Vector2 position, int fontSize, Color color) {
    auto width = measureText(text, fontSize);
    drawText(text, position - Vector2(width/2, 0), fontSize, color);
}

Color withAlpha(Color c, float a) {
    import raylib: ColorAlpha;
    return ColorAlpha(c, a);
}

Font loadFont(string fileName) {
    import raylib: LoadFont;
    return LoadFont(fileName.toStringz);
}
