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

    private this(Document document) {
        this.document = document;
        this.cursor = new Cursor(document);
        this.viewport =  Viewport(0, 0, 400, 400);
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
        if(cursor.row > viewport.bottom - 1) {
            auto delta = cursor.row - viewport.bottom + 1;
            viewport.top += delta;
        }

        if(cursor.row < viewport.top) {
            auto delta = viewport.top - cursor.row;
            viewport.top -= delta;
        }

        if(cursor.column > viewport.right - 1) {
            auto delta = cursor.column - viewport.right + 1;
            viewport.left += delta;
        }

        if(cursor.column < viewport.left + 1) {
            auto delta = viewport.left - cursor.column;
            if (viewport.left - delta >= 0)
                viewport.left -= delta;
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

        float y = 0;

        foreach(row, line; visibleLines) {
            auto tint = Colors.GREEN;
            float textOffsetX = 0.0f;
            auto isCursorRow = row == cursor.row;

            foreach(i, codepoint; line.codePoints) {
                auto column = i + viewport.left;
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

        viewport.draw();
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
