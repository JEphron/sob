module models.editor;

import std.conv;

import d_tree_sitter : Language, Query, Parser, Tree, TreeCursor;

import models.document;
import models.cursor;
import models.viewport;
import models.highlighter;
import settings;
import graphics;
import utils;

extern(C) Language tree_sitter_json();
extern(C) Language tree_sitter_javascript();

class JSEditor : Editor {
    this(Document document) {
        auto language = tree_sitter_javascript();
        super(document, language, readResourceAsString("queries/js/highlights.scm"));
    }
}

class JSONEditor : Editor {
    this(Document document) {
        auto language = tree_sitter_json();
        super(document, language, readResourceAsString("queries/json/highlights.scm"));
    }
}

class Editor {
    Cursor cursor;
    Parser parser;
    Language language;
    Query highlightingQuery;
    Tree tree;
    Highlighter highlighter;
    Document document;
    Viewport viewport;

    this(Document document, Language language, string highlightQueryFilePath) {
        this.document = document;
        this.cursor = new Cursor(document);
        viewport = Viewport(
            0,
            0,
            Settings.windowWidth,
            Settings.windowHeight,
            document
        );
        parser = Parser(language);
        highlightingQuery = Query(language, highlightQueryFilePath);
        tree = parser.parse_to_tree(document.textContent);
        highlighter = new Highlighter(tree, &highlightingQuery);
    }

    Vector2 root = Vector2(20, 20);

    Color backgroundColor = Color(8, 8, 8, 255);
    Color frameColor = Color(0, 128, 200, 255);
    float gutterPad = 5;

    Vector2 mouseDragStart;
    Vector2 viewportDragStart;

    static JSEditor fromFile(string filepath) {
        import std.file;
        auto document = Document.open(filepath);
        return new JSEditor(document);
    }

    void reparseDocument() {
        tree = parser.parse_to_tree(document.textContent);
        highlighter = new Highlighter(tree, &highlightingQuery);
    }

    void insertCharacter(dchar c) {
        document.insertCharacter(cursor.row, cursor.column, c);
        cursor.moveHorizontally(1);
        reparseDocument();
    }

    void insertNewLine() {
        document.insertNewLine(cursor.row, cursor.column);
        cursor.moveVertically(1);
        cursor.moveToBeginningOfLine();
        reparseDocument();
    }

    void insertNewLineAbove() {
        document.insertNewLine(cursor.row, 0);
        cursor.moveToBeginningOfLine();
        reparseDocument();
    }

    void insertNewLineBelow() {
        document.insertNewLine(cursor.row + 1, 0);
        cursor.moveVertically(1);
        cursor.moveToBeginningOfLine();
        reparseDocument();
    }

    void deleteBeforeCursor() {
        if (cursor.column == 0 && cursor.row > 0) {
            auto newColumn = document.lineLength(cursor.row-1);
            document.joinLinesUpwards(cursor.row);
            cursor.moveVertically(-1);
            cursor.setColumn(newColumn + 1);
        } else{
            document.deleteCharacter(cursor.row, cursor.column - 1);
        }
        reparseDocument();
    }

    void scrollToContain(Cursor cursor) {
        int deltaToRows(int delta) {
            return cast(int)(delta * Settings.lineHeight);
        }

        int deltaToColumns(int delta) {
            return cast(int)(delta * Settings.glyphWidth);
        }

        if(cursor.row > viewport.bottomRow - 1) {
            auto delta = cursor.row - viewport.bottomRow + 1;
            viewport.top += deltaToRows(delta);
        }

        if(cursor.row < viewport.topRow) {
            auto delta = viewport.topRow - cursor.row;
            viewport.top -= deltaToRows(delta);
        }
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

        /* drawBackground(rect); */

        withScissors(rect, {
            drawCodepointsInViewport();
            drawLineNums();
        });

        /* drawFrame(rect); */

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
        auto cursorColor = Colors.MAROON;

        foreach(point, codepoint; document.getCodepointsInViewport(viewport)) {
            auto pos = Vector2(
                point.column * glyphWidth + root.x + gutterWidth() + scrollX,
                point.row * lineHeight + root.y + scrollY
            );
            if(!isWhite(codepoint)) {
                auto color = highlighter.getColorForPoint(point);
                DrawTextCodepoint(font, codepoint, pos, fontSize, color);
            }
            if (cursor.row == point.row && cursor.column == point.column) {
                auto rect = Rectangle(pos.x, pos.y, glyphWidth, lineHeight);
                cursor.draw(codepoint, rect, cursorColor);
            }
        }

        if(cursor.isAtEndOfLine) {
            auto pos = Vector2(
                cursor.column * glyphWidth + root.x + gutterWidth() + scrollX,
                cursor.row * lineHeight + root.y + scrollY
            );
            auto rect = Rectangle(pos.x, pos.y, glyphWidth, lineHeight);
            cursor.draw(' ', rect, cursorColor);
        }
    }
}
