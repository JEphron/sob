module main;

import std.stdio;
import std.string;
import std.file;

import graphics;
import input;
import utils;
import keyboard;

import models.editor;
import models.document;
import models.cursor;
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
            import std.conv;

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

import d_tree_sitter : Language, Query, Parser, Tree, TreeVisitor, TreeCursor, Point;

extern(C) Language tree_sitter_json();
extern(C) Language tree_sitter_javascript();


void main(string[] args) {
    initWindow(Settings.windowWidth, Settings.windowHeight, ";_;");
    Settings.font = loadFont();
    setTargetFPS(60);

    auto editor = JSEditor.fromFile(resourcePath("smalljq.js"));

    while(!windowShouldClose()) {
        clearBackground(Colors.BLACK);
        beginDrawing();
        editor.draw();
        endDrawing();
    }

    closeWindow();
}

import std.conv;


struct Interval {
    Point start;
    Point end;
    string name;
}

bool pointBetween(Point a, Point b, Point c) {
    if(a.row == b.row && a.row == c.row) return a.column >= b.column && a.column < c.column;
    if(a.row >= b.row && a.row < c.row) return true;
    if(a.row == c.row) return a.column < c.column;
    return false;
}

class Highlighter {
    Interval[] intervals;

    this(Tree tree, Query* query) {
        foreach(match; query.exec(tree.root_node)) {
            foreach(capture; match.captures) {
                insert(Interval(capture.node.start_position, capture.node.end_position, capture.name));
            }
        }
    }

    void insert(Interval interval) {
        intervals ~= interval;
    }

    string[] find(Point point) {
        import std.algorithm;
        import std.array;
        // todo: investigate interval trees
        return intervals.filter!(it => pointBetween(point, it.start, it.end)).map!(it => it.name).array;
    }

    Color getColorForPoint(Point point) {
        auto categories = find(point);
        foreach(category; categories) {
            if(category == "comment") return Colors.GRAY;
            if(category == "keyword") return Colors.ORANGE;
            if(category == "constant") return Colors.GREEN;
            if(category == "property") return Colors.PINK;
            if(category == "function") return Colors.BLUE;
            if(category == "string") return Colors.YELLOW;
            if(category == "number") return Colors.PURPLE;
            if(category == "operator") return Colors.RED;
        }
        return Colors.WHITE;
    }
}

class TreeRenderer : TreeVisitor {
    string source;
    Vector2 cellSize;
    int h = 0;
    Highlighter highlighter;

    this(string source, Highlighter highlighter) {
        cellSize = measureText2d(" ", Settings.font, Settings.fontSize, 1);
        this.highlighter = highlighter;
        this.source = source;
    }

    extern(C) bool enter_node(TreeCursor* cursor) @trusted {
        auto node = cursor.node();
        if(node.child_count == 0) {
            /* auto str = source[node.start_byte..node.end_byte]; */
            auto startPoint = node.start_position();
            auto startVec = Vector2(10 + startPoint.column * cellSize.x, 10 + startPoint.row * cellSize.y);

            auto endPoint = node.end_position();
            auto endVec = Vector2(10 + endPoint.column * cellSize.x, 10 + endPoint.row * cellSize.y + cellSize.y);

            auto color = colorFromHSV(h%360, 1, 1);
            drawRectangle(Vector2(startVec.x, startVec.y), Vector2(endVec.x - startVec.x, cellSize.y), color.withAlpha(0.5f));

            h += 1000;
        }
        return true;
    }

    extern(C) void leave_node(TreeCursor* cursor) {
    }
}

void drawMonoTextLine(string str, Point point, Vector2 pos, Highlighter highlighter) {
    import std.encoding;
    import std.conv;
    import std.ascii;
    import raylib : DrawTextCodepoint, GetFontDefault;

    Font font = Settings.font;
    auto fontSize = Settings.fontSize;

    auto glyphWidth = Settings.glyphWidth;

    auto row = point.row;
    auto column = point.column;
    auto textOffsetX = pos.x;
    foreach(codepoint; str.codePoints) {
        if(!isWhite(codepoint)) {
            auto color = highlighter.getColorForPoint(Point(row, column));
            DrawTextCodepoint(font, codepoint, Vector2(textOffsetX, pos.y), fontSize, color);
        }
        textOffsetX += glyphWidth;
        column++;
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

    Vector2 mouseDragStart;
    Vector2 viewportDragStart;

    this(string source) {
        document = Document.fromString(source);
        viewport = Viewport(0, 0, 400, 400, document);
        language = tree_sitter_javascript();
        parser = Parser(language);
        highlightingQuery = Query(language, readResourceAsString("queries/js/highlights.scm"));
        tree = parser.tree_from(source);
        highlighter = new Highlighter(tree, &highlightingQuery);
    }

    static JSEditor fromFile(string filepath) {
        import std.file;
        auto source = filepath.readText();
        return new JSEditor(source);
    }

    void draw() {
        import std.algorithm;

        if(mousePressed()) {
            mouseDragStart = getMousePosition();
            viewportDragStart = Vector2(viewport.left, viewport.top);
        }

        if(mouseDown()) {
            auto mouseDelta = getMousePosition() - mouseDragStart;
            viewport.top = max(0, viewportDragStart.y + mouseDelta.y);
            viewport.left = max(0, viewportDragStart.x + mouseDelta.x);
        }

        drawText(format("(%s,%s)", viewport.left, viewport.top), Vector2(0, 0), 24, Colors.WHITE);

        auto root = Vector2(100,100);

        auto gutterPad = 5;
        auto gutterWidth = measureText2d(document.lineCount.to!string, Settings.font, Settings.fontSize, 1).x + gutterPad * 2;
        auto rect = Rectangle(root.x, root.y, viewport.width + gutterWidth, viewport.height);

        /* withScissors(rect, { */
            {
                auto pos = Vector2(root.x + gutterWidth - viewport.left, root.y - viewport.top);
                foreach(row, line; document.getViewport(viewport)) {
                    auto point = Point(row, 0);
                    drawMonoTextLine(line, point, pos, highlighter);
                    pos.y += Settings.lineHeight;
                }
            }

            // linenums
            {
                auto pos = Vector2(root.x + gutterWidth - viewport.left, root.y - viewport.top);
                drawRectangle(root.x, root.y, gutterWidth, viewport.height, Colors.BLACK);
                drawLine(root.x + gutterWidth, root.y, root.x + gutterWidth, root.y + viewport.height, Colors.RED);
                foreach(row, line; document.getViewport(viewport)) {
                    auto lineNum = (row + 1).to!string;
                    drawRightAlignedText(lineNum, Settings.font, Vector2(root.x + gutterWidth - gutterPad, pos.y), Settings.fontSize, Colors.GRAY);
                    pos.y += Settings.lineHeight;
                }
            }
        /* }); */

        drawRectangleLines(Rectangle(root.x, root.y, viewport.width + gutterWidth, viewport.height), Colors.RED);
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
