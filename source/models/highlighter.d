module models.highlighter;

import std.algorithm;
import std.array;

import intervaltree.avltree;
import d_tree_sitter : Query, Tree;

import graphics;
import models.point;

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
