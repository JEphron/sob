import raylib :
       Rectangle,
       ColorFromHSV,
       Vector2,
       Vector3,
       Color,
       Remap,
       DrawCircle,
       DrawCircleV,
       DrawLine,
       DrawLineV,
       DrawLineEx,
       Vector2Normalize,
       DrawRectangleLines,
       ColorToHSV;

import raymathext;
import std.algorithm;
import std.typecons;
import std.math;
import std.range;
import std.conv;

Color invert(Color color) {
    Vector3 hsv = ColorToHSV(color);
    return ColorFromHSV((hsv.x + 180) % 360, hsv.y, hsv.z);
}

bool get_line_intersection(
        float p0_x, float p0_y,
        float p1_x, float p1_y,
        float p2_x, float p2_y,
        float p3_x, float p3_y,
        float *i_x, float *i_y
) {
    float s1_x, s1_y, s2_x, s2_y;
    s1_x = p1_x - p0_x;     s1_y = p1_y - p0_y;
    s2_x = p3_x - p2_x;     s2_y = p3_y - p2_y;

    float s, t;
    s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y);
    t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y);

    if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
    {
        // Collision detected
        if (i_x != null)
            *i_x = p0_x + (t * s1_x);
        if (i_y != null)
            *i_y = p0_y + (t * s1_y);
        return true;
    }

    return false;
}

struct LineSegment {
    Vector2 a;
    Vector2 b;

    static LineSegment from_point_with_length_and_direction(
        Vector2 starting_point,
        float length,
        float direction
    ) {
        return LineSegment(
            starting_point,
            starting_point + Vector2(cos(direction), sin(direction)) * length
        );
    }

    static LineSegment[4] from_rectangle(Rectangle rect) {
        auto x = rect.x;
        auto y = rect.y;
        auto width = rect.width;
        auto height = rect.height;
        return [
            LineSegment(Vector2(x, y), Vector2(x + width, y)),
            LineSegment(Vector2(x, y), Vector2(x, y + height)),
            LineSegment(Vector2(x + width, y), Vector2(x + width, y + height)),
            LineSegment(Vector2(x, y + height), Vector2(x + width, y + height)),
        ];
    }

    Vector2 normal() {
        return Vector2Normalize((b - a).rotate(PI/2));
    }

    Vector2[] collision_points(Rectangle rect) {
        auto rect_segments = LineSegment.from_rectangle(rect);
        auto points = new Vector2[0];
        foreach(rect_segment; rect_segments) {
            auto maybe_vector = line_line_collision(rect_segment);
            if(!maybe_vector.isNull) {
                points ~= maybe_vector.get();
            }
        }
        return points;
    }

    Nullable!Vector2 line_line_collision(LineSegment other) {
        float x, y;
        auto ok = get_line_intersection(a.x, a.y, b.x, b.y, other.a.x, other.a.y, other.b.x, other.b.y, &x, &y);
        if(!ok)
            return Nullable!Vector2.init;
        return Vector2(x, y).nullable;
    }

    float length() {
        return a.distance(b);
    }

    void set_length_by_adjusting_b(float new_length) {
        float angle = atan2(b.y - a.y, b.x - a.x);
        b = a + Vector2(cos(angle), sin(angle)) * new_length;
    }

    void clamp_line_inside_rect(Rectangle rect) {
        auto true_end_points = collision_points(rect);
        if (true_end_points.empty) return;
        auto true_end_point = true_end_points[0];
        set_length_by_adjusting_b(a.distance(true_end_point));
    }
}

float lerp(float a, float b, float t) {
    import raylib : Lerp;
    return Lerp(a, b, t);
}

Vector2 lerp(Vector2 a, Vector2 b, float t) {
    import raylib : Vector2Lerp;
    return Vector2Lerp(a, b, t);
}

float remap(float x, float a0, float a1, float b0, float b1) {
    return Remap(x, a0, a1, b0, b1);
}

float remapClamp(float x, float a0, float a1, float b0, float b1) {
    return clamp(Remap(x, a0, a1, b0, b1), b0, b1);
}

float angle_lerp(float a, float b, float t) {
    float delta = b - a;
    if (delta > PI) {
        b -= 2 * PI;
    } else if (delta < -PI) {
        b += 2 * PI;
    }
    return lerp(a, b, t);
}

void DrawCircle(Vector2 center, float radius, Color c) {
    DrawCircleV(center, radius, c);
}

void DrawLine(LineSegment line, Color c) {
    DrawLineV(line.a, line.b, c);
}

void DrawLineEx(LineSegment line, float thickness, Color c) {
    DrawLineEx(line.a, line.b, thickness, c);
}

Vector2 rot90(Vector2 v) {
    return Vector2(
        v.y,
        -v.x
    );
}

Vector2 normalize(Vector2 v) {
    return Vector2Normalize(v);
}

Vector2 pos(Rectangle rect) {
    return Vector2(rect.x, rect.y);
}

float getGlyphWidth(dchar codepoint) {
    import settings;
    import raylib: GetGlyphIndex;
    auto font = Settings.font;
    int index = GetGlyphIndex(font, codepoint);
    if (font.chars[index].advanceX == 0) {
        return cast(float)font.recs[index].width;
    }

    auto fontSize = Settings.fontSize;
    float scaleFactor = cast(float)fontSize / font.baseSize;

    int defaultFontSize = 10;   // Default Font chars height in pixel
    if (fontSize < defaultFontSize) fontSize = defaultFontSize;
    int spacing = fontSize / defaultFontSize;

    return cast(float)font.chars[index].advanceX * scaleFactor + spacing;
}

string resourcePath(string path) {
    import std.path;
    return buildNormalizedPath(dirName(__FILE_FULL_PATH__) ~ "/../res/" ~ path);
}

string readResourceAsString(string path) {
    import std.file;
    return resourcePath(path).readText();
}
