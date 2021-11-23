module main;

import std.stdio;
import std.string;
import std.file;
import std.conv;

import intervaltree.avltree;

import graphics;
import input;
import utils;
import keyboard;

import models.editor;
import models.document;
import models.cursor;
import models.point;
import settings;


class TextEditorState {
    Editor editor;
    Keyboard keyboard;
    KeyMapContainer keyContainer;
    Font font;
    int fontSize = 30;
    bool shouldQuit;

    this() {
        keyboard = Keyboard.get();
    }
}

void draw(TextEditorState state) {
    clearBackground(16, 16, 16);
    if(state.editor) {
        state.editor.draw();
    }
}

abstract class KeyCommand {
    void run(TextEditorState state);
}

class NewlineCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLine();
    }
}

class QuitCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.shouldQuit = true;
    }
}

class MoveCursorKeyCommand : KeyCommand {
    int dx, dy;

    this(int dx, int dy) {
        this.dx = dx;
        this.dy = dy;
    }

    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        if(dy) state.editor.cursor.moveVertically(dy);
        if(dx) state.editor.cursor.moveHorizontally(dx);
        state.editor.scrollToContain(state.editor.cursor);
    }
}

class EnterModeCommand : KeyCommand {
    CursorMode mode;

    this(CursorMode mode) {
        this.mode = mode;
    }

    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        state.editor.cursor.mode = this.mode;
    }
}

class BackspaceCommand : KeyCommand {
    override void run(TextEditorState state) {
        if(!state.editor)
            return;
        auto needsMoveBack = !state.editor.cursor.isAtEndOfLine;
        state.editor.deleteBeforeCursor();
        if(needsMoveBack) {
            new MoveCursorKeyCommand(-1, 0).run(state);
        }
    }
}

class ChainedCommand : KeyCommand {
    KeyCommand[] commands;

    this(KeyCommand[] commands) {
        this.commands = commands;
    }

    override void run(TextEditorState state) {
        foreach(command; commands) {
            command.run(state);
        }
    }
}

class InsertNewlineAboveCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLineAbove();
    }
}

class InsertNewlineBelowCommand : KeyCommand {
    override void run(TextEditorState state) {
        state.editor.insertNewLineBelow();
    }
}

struct KeyBind {
    KeyboardKey key;
    char charValue = 0;
    Modifier mod1;
    Modifier mod2;

    this(KeyboardKey key) {
        this.key = key;
    }

    this(KeyboardKey key, Modifier mod1) {
        this.key = key;
        this.mod1 = mod1;
    }

    this(char charValue) {
        this.charValue = charValue;
    }

    this(char charValue, Modifier mod1) {
        this.charValue = charValue;
        this.mod1 = mod1;
    }

    bool hasModifier(Modifier mod) {
        return mod1 == mod || mod2 == mod;
    }
}

class KeyMap {
    private KeyCommand delegate()[KeyBind] keybinds;
    private void delegate(KeyEvent) defaultAction;

    void add(KeyBind bind, lazy KeyCommand command) {
        keybinds[bind] = () => command();
    }

    void setDefault(void delegate(KeyEvent) fn) {
        defaultAction = fn;
    }

    KeyCommand match(KeyEvent event) {
        import std.algorithm.searching: canFind;
        foreach(bind, fn; keybinds) {
            if(event.action == KeyAction.RELEASE) continue;

            if(bind.charValue) {
                if(!event.charValue) continue;
                if(bind.charValue != event.charValue) continue;
            }

            if(bind.key) {
                if(!event.key) continue;
                if(bind.key != event.key) continue;
            }

            if(bind.mod1 && !event.hasModifier(bind.mod1)) continue;
            if(bind.mod2 && !event.hasModifier(bind.mod2)) continue;
            return fn();
        }
        if(defaultAction) defaultAction(event);
        return null;
    }
}

class KeyMapContainer {
    private KeyMap[CursorMode] modalMaps;

    this() {
        import std.traits;
        static foreach(mode; EnumMembers!CursorMode) {
            modalMaps[mode] = new KeyMap();
        }
    }

    void modeMap(CursorMode mode, void delegate(KeyMap map) registerBindings) {
        registerBindings(modalMaps[mode]);
    }

    void global(void delegate(KeyMap map) registerBindings) {
        foreach(map; modalMaps) {
            registerBindings(map);
        }
    }

    KeyMap current(CursorMode mode) {
        return modalMaps[mode];
    }
}

KeyMapContainer registerKeyCommands(TextEditorState state) {
    auto container = new KeyMapContainer();

    container.global((map) {
        map.add(KeyBind('d', Modifier.CONTROL), new QuitCommand());
    });

    container.modeMap(CursorMode.INSERT, (map) {
        map.add(KeyBind(KeyboardKey.KEY_ESCAPE),
            new ChainedCommand([
                new MoveCursorKeyCommand(-1, 0),
                new EnterModeCommand(CursorMode.NORMAL)
            ]));
        map.add(KeyBind(KeyboardKey.KEY_BACKSPACE), new BackspaceCommand());
        map.add(KeyBind(KeyboardKey.KEY_ENTER), new NewlineCommand());
        map.setDefault((event) {
            import std.ascii;

            if(!event.charValue) return;

            state.editor.insertCharacter(event.charValue);
            state.editor.scrollToContain(state.editor.cursor);
        });
    });

    container.modeMap(CursorMode.NORMAL, (map) {
        map.add(KeyBind('h'), new MoveCursorKeyCommand(-1, 0));
        map.add(KeyBind('j'), new MoveCursorKeyCommand(0, 1));
        map.add(KeyBind('k'), new MoveCursorKeyCommand(0, -1));
        map.add(KeyBind('l'), new MoveCursorKeyCommand(1, 0));
        map.add(KeyBind('o'),
            new ChainedCommand([
                new InsertNewlineBelowCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('O'),
            new ChainedCommand([
                new InsertNewlineAboveCommand(),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
        map.add(KeyBind('i'), new EnterModeCommand(CursorMode.INSERT));
        map.add(KeyBind('a'),
            new ChainedCommand([
                new MoveCursorKeyCommand(1, 0),
                new EnterModeCommand(CursorMode.INSERT)
            ])
        );
    });

    return container;
}

void handleInput(TextEditorState state) {
    auto keymap = state.keyContainer.current(state.editor.cursor.mode);
    foreach(event; state.keyboard) {
        if(auto match = keymap.match(event))
            match.run(state);
    }
}

string resourcePath(string path) {
    import std.path;
    return buildNormalizedPath(dirName(__FILE_FULL_PATH__) ~ "/../res/" ~ path);
}

Font loadFont() {
    import raylib : LoadFontEx;
    import std.string;
    auto fontPath = resourcePath("FiraMono-Regular.otf");
    return LoadFontEx(fontPath.toStringz, Settings.fontSize, null, 250);
}


void runStuff() {
    import raylib: SetExitKey;
    initWindow(Settings.windowWidth, Settings.windowHeight, ";_;");

    Settings.font = loadFont();

    auto state = new TextEditorState();
    auto documentPath = resourcePath("sample.json");
    state.editor = Editor.fromFilepath(documentPath);
    state.keyContainer = registerKeyCommands(state);

    setTargetFPS(60);
    SetExitKey(KeyboardKey.KEY_NULL); // don't close on escape-key press

    while(!windowShouldClose() && !state.shouldQuit) {
        beginDrawing();
        handleInput(state);
        draw(state);
        endDrawing();
    }

    closeWindow();
}

import d_tree_sitter : Language, Query, Parser, Tree, TreeVisitor, TreeCursor;

extern(C) Language tree_sitter_json();
extern(C) Language tree_sitter_javascript();


void main(string[] args) {
    initWindow(Settings.windowWidth, Settings.windowHeight, ";_;");
    Settings.font = loadFont();
    setTargetFPS(60);

    auto editor = JSEditor.fromFile(resourcePath("jquery.js"));

    while(!windowShouldClose()) {
        clearBackground(Colors.BLACK);
        beginDrawing();
        editor.draw();
        drawFPS();
        endDrawing();
    }

    closeWindow();
}

void drawFPS() {
    drawText(getFPS().to!string, Vector2(0, 0), 10, Colors.WHITE);
}

struct Interval {
    Point start;
    Point end;

    @safe @nogc nothrow int opCmp(ref const Interval other) const {
        if(start < other.start) return -1;
		if(start > other.start) return 1;
		if(start == other.start && end < other.end) return -1;
		if(start == other.start && end > other.end) return 1;
		return 0;
    }

    @safe @nogc nothrow int opCmp(const Point other) const {
        return start.opCmp(other);
    }

    invariant {
        assert(this.start <= this.end);
    }
}

bool pointBetween(Point a, Point b, Point c) {
    if(a.row == b.row && a.row == c.row) return a.column >= b.column && a.column < c.column;
    if(a.row >= b.row && a.row < c.row) return true;
    if(a.row == c.row) return a.column < c.column;
    return false;
}

class Highlighter {
    Interval[] intervals;
    IntervalTree!Interval intervalTree;
    Color[string] colorMap;
    string[Interval] intervalToName;

    this(Tree tree, Query* query) {
        colorMap = [
            "comment": Colors.GRAY,
            "keyword": Colors.ORANGE,
            "constant": Colors.GREEN,
            "property": Colors.PINK,
            "function": Colors.BLUE,
            "string": Colors.YELLOW,
            "number": Colors.PURPLE,
            "operator": Colors.RED
        ];

        foreach(match; query.exec(tree.root_node)) {
            foreach(capture; match.captures) {
                if(capture.name !in colorMap) continue;
                auto tsStart = capture.node.start_position;
                auto startPoint = Point(tsStart.row, tsStart.column);
                auto tsEnd = capture.node.end_position;
                auto endPoint = Point(tsEnd.row, tsEnd.column);
                insert(Interval(startPoint, endPoint), capture.name);
            }
        }
    }

    void insert(Interval interval, string name) {
        uint d;
        intervalTree.insert(interval, d);
        intervalToName[interval] = name;
    }

    string[] find(Point point) {
        import std.algorithm;
        import std.array;
        auto target = Interval(point, Point(point.row, point.column + 1));
        auto result = new string[0];
        foreach(node; intervalTree.findOverlapsWith(target)) {
            result ~= intervalToName[node.interval];
        }
        return result;
    }

    Color getColorForPoint(Point point) {
        auto categories = find(point);
        foreach(category; categories) {
            if(auto color = category in colorMap)
                return *color;
        }
        return Colors.WHITE;
    }
}

import models.viewport;

class JSEditor {
    Parser parser;
    Language language;
    Query highlightingQuery;
    Tree tree;
    Highlighter highlighter;
    Document document;
    Viewport viewport;

    Vector2 root = Vector2(20, 20);

    Color backgroundColor = Color(8, 8, 8, 255);
    Color frameColor = Color(0, 128, 200, 255);
    float gutterPad = 5;

    Vector2 mouseDragStart;
    Vector2 viewportDragStart;

    this(Document document) {
        this.document = document;
        viewport = Viewport(
            0,
            0,
            Settings.windowWidth - 80,
            Settings.windowHeight - 40,
            document
        );
        language = tree_sitter_javascript();
        parser = Parser(language);
        highlightingQuery = Query(language, readResourceAsString("queries/js/highlights.scm"));
        tree = parser.tree_from(document.textContent);
        highlighter = new Highlighter(tree, &highlightingQuery);
    }

    static JSEditor fromFile(string filepath) {
        import std.file;
        auto document = Document.open(filepath);
        return new JSEditor(document);
    }

    void draw() {
        import std.algorithm: min, max;

        clearCachedGutterWidth();
        if(mousePressed()) {
            mouseDragStart = getMousePosition();
            viewportDragStart = Vector2(viewport.left, viewport.top);
        }

        if(mouseDown()) {
            auto mouseDelta = getMousePosition() - mouseDragStart;
            viewport.top = max(0, viewportDragStart.y + mouseDelta.y);
            viewport.left = max(0, viewportDragStart.x + mouseDelta.x);
        }

        auto rect = Rectangle(
            root.x,
            root.y,
            viewport.width + gutterWidth(),
            viewport.height
        );

        drawBackground(rect);
        withScissors(rect, {
            drawCodepointsInViewport();
            drawLineNums();
        });

        drawFrame(rect);

    }

    float _cachedGutterWidth = 0;

    void clearCachedGutterWidth() {
        _cachedGutterWidth = 0;
    }

    float gutterWidth() {
        if(_cachedGutterWidth) return _cachedGutterWidth;

        auto strWidth = measureText2d(
            document.lineCount.to!string,
            Settings.font,
            Settings.fontSize,
            1
        );
        _cachedGutterWidth = strWidth.x + gutterPad * 2;
        return _cachedGutterWidth;
    }

    void drawBackground(Rectangle rect) {
        drawRectangle(rect, backgroundColor);
    }

    void drawFrame(Rectangle rect) {
        auto frameThickness = 8;

        drawRectangleLines(rect, frameColor);

        drawRectangleLines(
            Rectangle(
                rect.x - frameThickness,
                rect.y - Settings.lineHeight,
                rect.width + frameThickness * 2,
                rect.height + Settings.lineHeight + frameThickness
            ),
            frameColor.fade(0.4f)
        );

        drawText(
            document.name,
            Settings.font,
            Vector2(rect.x, rect.y - Settings.lineHeight),
            Settings.fontSize,
            frameColor
        );
    }

    void drawLineNums() {
        auto lineHeight = Settings.lineHeight;
        auto gutterEdgeX = root.x + gutterWidth();
        auto scrollY = -viewport.top;

        drawRectangle(root.x, root.y, gutterWidth(), viewport.height, Colors.BLACK);
        drawLine(gutterEdgeX, root.y, gutterEdgeX, root.y + viewport.height, frameColor);

        foreach(row; viewport.topRow..viewport.bottomRow) {
            auto lineNum = (row + 1).to!string;
            auto textPos = Vector2(gutterEdgeX - gutterPad, row * lineHeight + root.y + scrollY);
            drawRightAlignedText(lineNum, Settings.font, textPos, Settings.fontSize, Colors.GRAY);
        }
    }

    void drawCodepointsInViewport() {
        import std.ascii : isWhite;
        import raylib : DrawTextCodepoint;

        Font font = Settings.font;
        auto fontSize = Settings.fontSize;
        auto lineHeight = Settings.lineHeight;
        auto glyphWidth = Settings.glyphWidth;

        auto scrollX = -viewport.left;
        auto scrollY = -viewport.top;
        foreach(point, codepoint; document.getCodepointsInViewport(viewport)) {
            if(!isWhite(codepoint)) {
                auto color = highlighter.getColorForPoint(point);
                auto pos = Vector2(
                    point.column * glyphWidth + root.x + gutterWidth() + scrollX,
                    point.row * lineHeight + root.y + scrollY
                );
                DrawTextCodepoint(font, codepoint, pos, fontSize, color);
            }
        }
    }
}

void withScissors(Rectangle scissor, scope void delegate() d) {
    import raylib: BeginScissorMode, EndScissorMode;
    BeginScissorMode(scissor.x.to!int, scissor.y.to!int, scissor.width.to!int, scissor.height.to!int);
    d();
    EndScissorMode();
}

string readResourceAsString(string path) {
    import std.file;
    return resourcePath(path).readText();
}

void testJson() {
    import d_tree_sitter : Parser;
    auto jsonLanguage = tree_sitter_json();
    auto parser = Parser(jsonLanguage);

    auto query = Query(jsonLanguage, readResourceAsString("queries/json/highlights.scm"));

    auto jsonSource = readResourceAsString("sample.json");
    dumpQueryResults(&parser, &query, jsonSource);
}


void dumpQueryResults(Parser* parser, Query* query, string source) {
    writeln("source:", source);
    auto tree = parser.tree_from(source);
    foreach(match; query.exec(tree.root_node)) {
        foreach(capture; match.captures) {
            auto codeSlice = source[capture.node.start_byte..capture.node.end_byte];
            writeln("pattern(", match.pattern_index, "): ", capture.name, " - ", codeSlice);
        }
    }
}
