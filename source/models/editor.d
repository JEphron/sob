module models.editor;

import models.document;
import models.cursor;
import models.viewport;
import settings;
import graphics;
import utils;

class Editor {
    Document document;
    Cursor cursor;
    Viewport viewport;
    Vector2 rootPosition;

    private this(Document document) {
        this.document = document;
        this.cursor = new Cursor(document);
        this.viewport = Viewport(0, 0, Settings.windowWidth, Settings.windowHeight, document);
    }

    static Editor fromFilepath(string filepath) {
        auto document = Document.open(filepath);
        return new Editor(document);
    }

    ViewportIterator visibleLines() {
        return document.getViewport(viewport);
    }

    void insertCharacter(dchar c) {
        document.insertCharacter(cursor.row, cursor.column, c);
        cursor.moveHorizontally(1);
    }

    void insertNewLine() {
        document.insertNewLine(cursor.row, cursor.column);
        cursor.moveVertically(1);
        cursor.moveToBeginningOfLine();
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
    }

    void scrollToContain(Cursor cursor) {
        int deltaToRows(int delta) {
            return cast(int)(delta * Settings.lineHeight);
        }

        int deltaToColumns(int delta) {
            return delta * 12;
        }

        if(cursor.row > viewport.bottomRow - 1) {
            auto delta = cursor.row - viewport.bottomRow + 1;
            viewport.top += deltaToRows(delta);
        }

        if(cursor.row < viewport.topRow) {
            auto delta = viewport.topRow - cursor.row;
            viewport.top -= deltaToRows(delta);
        }

        auto rightColumn = viewport.rightColumn(cursor.row);
        import std.stdio;
        if(cursor.column > rightColumn - 1) {
            auto delta = cursor.column - rightColumn + 1;
            viewport.left += deltaToColumns(delta);
        }

        auto leftColumn = viewport.leftColumn(cursor.row);
        if(cursor.column < leftColumn + 1) {
            auto delta = leftColumn - cursor.column;
            if (leftColumn - delta >= 0)
                viewport.left -= deltaToColumns(delta);
        }
    }

    void draw() {
        import std.encoding;
        import std.conv;
        import std.ascii;
        import raylib : DrawTextCodepoint, GetFontDefault;

        Font font = Settings.font;
        auto fontSize = Settings.fontSize;

        float textHeight = textHeight(font, fontSize);
        float scaleFactor = cast(float)fontSize / font.baseSize;

        int defaultFontSize = 10;   // Default Font chars height in pixel
        if (fontSize < defaultFontSize) fontSize = defaultFontSize;
        int spacing = fontSize / defaultFontSize;

        float y = rootPosition.y;

        foreach(row, line; visibleLines) {
            auto tint = Colors.GREEN;
            float textOffsetX = rootPosition.x;
            auto isCursorRow = row == cursor.row;

            foreach(column, codepoint; line) {
                auto advance = getGlyphAdvance(font, codepoint) * scaleFactor + spacing;
                auto isCursorCell = isCursorRow && column == cursor.column;
                auto pos = Vector2(textOffsetX, y);
                if(!isWhite(codepoint)) {
                    DrawTextCodepoint(font, codepoint, pos, fontSize, tint);
                }

                if(isCursorCell) {
                    auto glyphRect = Rectangle(pos.x, pos.y, advance, textHeight);
                    cursor.draw(codepoint, glyphRect, tint);
                }
                textOffsetX += advance;
            }

            if(isCursorRow && cursor.isAtEndOfLine) {
                auto advance = getGlyphAdvance(font, ' ') * scaleFactor + spacing;
                auto rect = Rectangle(textOffsetX, y, advance, textHeight);
                cursor.draw(' ', rect, tint);
            }
            y += textHeight;
        }

        /* viewport.draw(rootPosition); */
    }
}

float textHeight(Font f, int fontSize) {
    return f.baseSize * fontSize/cast(float)f.baseSize;
}

float getGlyphAdvance(Font font, dchar codepoint) {
    import raylib: GetGlyphIndex;
    int index = GetGlyphIndex(font, codepoint);
    if (font.chars[index].advanceX == 0) {
        return cast(float)font.recs[index].width;
    }
    return cast(float)font.chars[index].advanceX;
}
