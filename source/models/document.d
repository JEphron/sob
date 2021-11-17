module models.document;

import std.path;
import std.conv;
import std.file;
import std.algorithm;
import std.stdio;
import std.string;

import models.cursor;
import std.array;
import std.conv;


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

    int opApply(scope int delegate(int, string) dg) {
        int result = 0;

        auto bottom = clamp(viewport.bottom, 0, document.lines.length);
        auto top = clamp(viewport.top, 0, document.lines.length);
        for(int i = top; i < bottom; i++) {
            auto right = clamp(viewport.right, 0, document.lines[i].length);
            string slice;
            if(viewport.left > right)
                slice = [];
            else
                slice = document.lines[i][viewport.left..right];
            result = dg(i, slice);
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

    int lineCount() {
        return lines.length.to!int;
    }

    int lineLength(int line) {
        assert(line < lines.length);
        return lines[line].length.to!int;
    }

    const ViewportIterator getViewport(Viewport viewport) {
        return ViewportIterator(viewport, this);
    }

    void deleteCharacter(int row, int column) {
        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
        arr = arr.remove(column);
        lines[row] = arr.to!string;
    }

    void insertCharacter(int row, int column, dchar ch) {
        if(row < 0 || column < 0) return;
        auto arr = lines[row].array;
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
