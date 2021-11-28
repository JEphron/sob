module rope_viz;

import settings;
import std.stdio;
import raymathext;
import rope;
import graphics;
import input;
import random=std.random;
import std.array;
import std.conv;
import std.range;
import ascii=std.ascii;

auto stepDown = 100;
auto stepOver = 100;

void drawRope(Rope rope, int x=0, int y=0) {
    auto position = Vector2(x, y);
    if(auto substringRope = cast(SubstringRope) rope) {
        drawCircle(position, 30, Colors.RED);
        drawRope(substringRope.rope, x, y + stepDown);
    } else if(auto concatRope = cast(ConcatRope) rope) {
        drawCircle(position, 30, Colors.YELLOW);
        drawRope(concatRope.left, x - stepOver, y + stepDown);
        drawRope(concatRope.right, x + stepOver, y + stepDown);
    } else if(auto stringRope = cast(StringRope) rope) {
        drawCircle(position, 30, Colors.GREEN);
        drawText(stringRope.str, position, 30, Colors.WHITE);
        drawRectangleLines(position, measureText2d(stringRope.str, 30, 1), Colors.WHITE);
    }
}

void iterRopes(Rope rope, void delegate(Rope, Rope) dg) {
    if(auto substringRope = cast(SubstringRope) rope) {
        dg(rope, substringRope.rope);
        iterRopes(substringRope.rope, dg);
    } else if(auto concatRope = cast(ConcatRope) rope) {
        dg(rope, concatRope.left);
        dg(rope, concatRope.right);
        iterRopes(concatRope.left, dg);
        iterRopes(concatRope.right, dg);
    } else if(auto stringRope = cast(StringRope) rope) {
        dg(rope, null);
    }
}

class Runner {
    Rope root;
    Vector2[Rope] positions;
    Vector2* draggingPos;
    Vector2 dragStartPos;
    bool runningSim = true;

    this() {
        root = Rope.build("hello world");
        buildGraph();
    }

    void buildGraph() {
        positions.clear();
        iterRopes(root, (r, _r) {
            positions[r] = Vector2(600 + random.uniform(-10, 10), 600 + random.uniform(-10, 10));
        });
        writeln(positions.length);
    }

    void run() {
        import raylib;
        if(isKeyPressed(KeyboardKey.KEY_J)) {
            auto ix = random.choice(iota(0, root.length));
            auto letter = random.choice(ascii.letters.array).to!string;
            writeln("inserting ", letter, " at ", ix);
            root = root.insert(ix, letter);
            buildGraph();
        }
        if(isKeyPressed(KeyboardKey.KEY_H)) {
            runningSim = !runningSim;
        }


        if(runningSim) {
            foreach(rope1, ref position1; positions) {
                foreach(rope2, position2; positions) {
                    if(rope1 == rope2) continue;
                    auto outwardForce = 5 * (position1 - position2) / Vector2Length(position1 - position2);
                    position1.x += outwardForce.x;
                    position1.y += outwardForce.y;
                    auto centeringForce = 0.01f * (position1 - Vector2(Settings.windowWidth/2, Settings.windowHeight/2));
                    position1.x -= centeringForce.x;
                    position1.y -= centeringForce.y;
                }
            }

            iterRopes(root, (r1, r2) {
                if(r2) {
                    auto pos1 = positions[r1];
                    auto pos2 = positions[r2];
                    auto inwardForce = 0.1f * (pos2 - pos1);
                    pos1.x += inwardForce.x;
                    pos1.y += inwardForce.y;
                    positions[r1] = pos1;
                }
            });
        }

        iterRopes(root, (r1, r2) {
            if(r2) {
                auto pos1 = positions[r2];
                auto pos2 = positions[r1];
                auto dir = (pos2 - pos1).normal;
                drawArrow(pos1, pos2 - dir * 40, Colors.WHITE);
            }
        });

        foreach(rope, ref position; positions) {
            drawRopeNode(rope, position, rope == root);
            if(mousePressed() && getMousePosition().insideCircle(position, 30)) {
                draggingPos = &position;
            }
        }

        if(draggingPos) {
            if(mouseDown()) {
                draggingPos.x = getMouseX();
                draggingPos.y = getMouseY();
            } else {
                draggingPos = null;
            }
        }
    }
}

bool insideCircle(Vector2 p, Vector2 center, float radius) {
    import raymath: Vector2Distance;
    return Vector2Distance(p, center) <= radius;
}

void drawRopeNode(Rope node, Vector2 position, bool isRoot) {
    auto color = colorForRope(node);
    if(isRoot)
        color = Colors.YELLOW;
    auto name = nameForRope(node);
    drawCircle(position, 30, color);
    drawCenteredText(name, position, 20, Colors.WHITE);
    drawCenteredText(node.toString(), position + Vector2(0, 40), 20, Colors.WHITE);

}

string nameForRope(Rope rope) {
    if(cast(SubstringRope) rope) {
        return "<sub>";
    } else if(cast(ConcatRope) rope) {
        return "<con>";
    } else if(cast(StringRope) rope) {
        return "<str>";
    }
    assert(false);
}

Color colorForRope(Rope rope) {
    if(cast(SubstringRope) rope) {
        return Colors.BLUE;
    } else if(cast(ConcatRope) rope) {
        return Colors.GREEN;
    } else if(cast(StringRope) rope) {
        return Colors.RED;
    }
    assert(false);
}
