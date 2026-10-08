// name: Pencil Sketch
// description: Drawn in pencil on off-white textured paper: grainy graphite
// description: outlines, with a light touch of charcoal only in the darkest
// description: parts, catching on the tooth of the paper.
// tags: art, drawing, pencil, charcoal, black and white

// How thick the pencil lines are, in pixels.
const float LineWidth = 1.2;

// How sharp a change in brightness must be to be drawn as a line.
const float LineFrom = 0.08;
const float LineTo = 0.28;

// How dark a part of the picture must be before it is shaded at all, from 0
// (everything) to 1 (nothing). Only the darkest parts reach past this.
const float ShadeFrom = 0.55;

// How heavy the charcoal is where it is used, 0 for none to 1 for black.
const float ShadeStrength = 0.35;

// How often the lines are redrawn, a little differently each time, as if
// every frame of the video were sketched afresh.
const float SketchRate = 8.0;

const vec3 Paper = vec3(0.96, 0.94, 0.89);
const vec3 Graphite = vec3(0.12, 0.12, 0.13);

float hash(float n)
{
    n = fract(n * 0.1031);
    n *= n + 33.33;
    n *= n + n;
    return fract(n);
}

float hash2(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth noise across the plane: a random height at each whole point,
// blended between the four around p.
float noise2(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + 1.0), u.x), u.y);
}

float brightness(vec2 uv)
{
    return dot(texture2D(iChannel0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
}

// The paper's tooth, 0 in its hollows to 1 on its peaks: blotches at a few
// sizes, the fine grain of its surface, and faint fibres running across it.
// It never moves, as a sheet of paper wouldn't.
float tooth(vec2 at)
{
    float blotches = noise2(at * 0.02) * 0.5 + noise2(at * 0.07) * 0.3 + noise2(at * 0.25) * 0.2;
    float grain = hash2(at);
    float fibres = noise2(vec2(at.x * 0.03, at.y * 0.9));
    return clamp(blotches * 0.5 + grain * 0.35 + fibres * 0.15, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;
    float sketch = mod(floor(iTime * SketchRate), 4096.0);
    float paper = tooth(fragCoord);

    // Shading comes from a softened picture, so it falls in broad areas the
    // way charcoal does rather than following every detail, and only where
    // the picture is darker than ShadeFrom, so most of it is left to the lines.
    float soft = 0.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            soft += brightness(uv + vec2(x, y) * 3.0 * pixel);
    soft /= 9.0;
    float shade = clamp((1.0 - soft - ShadeFrom) / (1.0 - ShadeFrom), 0.0, 1.0);

    // Charcoal: rubbed on lightly in long strokes at a slant, heavier in some
    // than others. It only catches the peaks of the paper, leaving the hollows
    // white, so even the darkest shading stays broken and grainy. Clean paper
    // is left alone where there is no shading at all.
    vec2 slant = mat2(0.866, -0.5, 0.5, 0.866) * fragCoord;
    float strokes = noise2(vec2(slant.x * 0.015, slant.y * 0.35));
    float rubbed = shade * (0.75 + 0.5 * strokes);
    float charcoal = smoothstep(paper, paper + 0.35, rubbed) * smoothstep(0.02, 0.2, shade);

    // Pencil lines: a Sobel filter on the brightness, finding where it
    // changes sharply. Each time the sketch is redrawn the lines shift by a
    // fraction of a pixel, so they have the slight life of a hand drawing.
    vec2 wobble = (vec2(hash(sketch), hash(sketch + 0.5)) - 0.5) * pixel;
    vec2 d = pixel * LineWidth;
    vec2 p = uv + wobble;
    float tl = brightness(p + vec2(-d.x, d.y));
    float t = brightness(p + vec2(0.0, d.y));
    float tr = brightness(p + d);
    float l = brightness(p - vec2(d.x, 0.0));
    float r = brightness(p + vec2(d.x, 0.0));
    float bl = brightness(p - d);
    float b = brightness(p - vec2(0.0, d.y));
    float br = brightness(p + vec2(d.x, -d.y));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float gy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
    float line = smoothstep(LineFrom, LineTo, length(vec2(gx, gy)));
    // Graphite skips over the paper's grain, so a line is never solid.
    line *= 0.55 + 0.45 * smoothstep(0.2, 0.7, hash2(fragCoord + sketch * 17.0) * 0.5 + paper * 0.5);

    // The paper, a little darker in its hollows, then charcoal, then pencil.
    vec3 color = Paper * (0.93 + 0.07 * paper);
    color = mix(color, Graphite, charcoal * ShadeStrength);
    color = mix(color, Graphite, line * 0.9);

    fragColor = vec4(color, 1.0);
}
