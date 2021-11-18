module models.document;

import std.path;
import std.conv;
import std.file;
import std.algorithm;
import std.stdio;
import std.string;

import settings;
import models.cursor;
import std.array;
import std.conv;
import models.viewport;
import utils;

struct LineIterator {
    const Viewport viewport;
    const Document document;
    int row;

    int opApply(scope int delegate(ulong, dchar) dg) {
        import std.encoding;
        auto line = document.getLine(row);

        float totalWidth = 0;
        int result = 0;
        foreach(ix, codepoint; line.codePoints) {
            totalWidth += getGlyphWidth(codepoint);
            if(totalWidth > viewport.right) {
                break;
            }
            if(totalWidth > viewport.left) {
                result = dg(ix, codepoint);
                if (result)
                    break;
            }
        }

        return result;
    }
}

struct ViewportIterator {
    const Viewport viewport;
    const Document document;

    // right now these are in "cell" coordinates, so row/column
    // however, for correctness they should be in pixels
    // this means that the Editor must be able to determine which characters lie within
    // a given pixelspace rect
    // to do this, we'll start with the lineHeight (which is constant)
    // bottom > lineHeight * nLines > top
    // then we'll do codepoints, so for each line
    // start from the beginning, measuring each codepoint and summing the width
    // until we exceed 'left'. Then yield codepoints until the sum exceeds 'right'.

    int opApply(scope int delegate(int, LineIterator) dg) {
        import std.math;

        int result = 0;


        for(int row = viewport.topRow; row < viewport.bottomRow; row++) {
            if(row >= document.lineCount) break;
            auto lineIterator = LineIterator(viewport, document, row);
            result = dg(row, lineIterator);
            if (result)
                break;
        }

        return result;
    }
}

class Document {
    private this(string filepath) {
        this.filepath = filepath;
        this.lines = std.file.readText(filepath).split('\n');
    }

    static Document open(string filepath) {
        return new Document(filepath);
    }

    const string filepath;
    private string[] lines;

    string name() {
        return baseName(filepath);
    }

    const int lineCount() {
        return lines.length.to!int;
    }

    int lineLength(int line) {
        assert(line < lines.length);
        return getLine(line).length.to!int;
    }

    const ViewportIterator getViewport(Viewport viewport) {
        return ViewportIterator(viewport, this);
    }

    const string getLine(int row) {
        return lines[row];
    }

    void deleteCharacter(int row, int column) {
        if(row < 0 || column < 0) return;
        auto arr = getLine(row).array;
        arr = arr.remove(column);
        lines[row] = arr.to!string;
    }

    void insertCharacter(int row, int column, dchar ch) {
        if(row < 0 || column < 0) return;
        auto arr = getLine(row).array;
        arr.insertInPlace(column, ch);
        lines[row] = arr.to!string;
    }

    void insertNewLine(int row, int column) {
        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
        auto a1 = arr[0..column];
        auto a2 = arr[column..$];
        lines = lines.remove(row);
        lines.insertInPlace(row, a2.to!string);
        lines.insertInPlace(row, a1.to!string);
    }

    void joinLinesUpwards(int row) {
        auto line = lines[row];
        lines[row-1] = lines[row-1] ~ line;
        lines = lines.remove(row);
    }
}
