// name: Comic Book
// description: A printed comic: bold black outlines, strong flat colours, and
// description: shading in dots of ink, like the Ben-Day dots of old comics.
// tags: art, drawing, print, dots, outline

// The dot screen: the distance between dots, in pixels, and its angle.
const float DotSpacing = 7.0;

// How much stronger colours are made.
const float Saturation = 1.6;

// Outline thickness in pixels, and how sharp an edge must be to be inked.
const float LineWidth = 1.8;
const float LineFrom = 0.2;
const float LineTo = 0.4;

const vec3 Paper = vec3(0.98, 0.96, 0.9);

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 picture(vec2 uv)
{
    return texture2D(iChannel0, uv).rgb;
}

float outline(vec2 uv, vec2 pixel)
{
    vec2 d = pixel * LineWidth;
    float tl = brightness(picture(uv + vec2(-d.x, d.y)));
    float t = brightness(picture(uv + vec2(0.0, d.y)));
    float tr = brightness(picture(uv + d));
    float l = brightness(picture(uv - vec2(d.x, 0.0)));
    float r = brightness(picture(uv + vec2(d.x, 0.0)));
    float bl = brightness(picture(uv - d));
    float b = brightness(picture(uv - vec2(0.0, d.y)));
    float br = brightness(picture(uv + vec2(d.x, -d.y)));
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float gy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
    return smoothstep(LineFrom, LineTo, length(vec2(gx, gy)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;

    // The dot screen, turned 45 degrees as print screens are. Each dot's
    // cell takes one colour, from the picture at the cell's middle.
    mat2 turn = mat2(0.7071, 0.7071, -0.7071, 0.7071);
    mat2 back = mat2(0.7071, -0.7071, 0.7071, 0.7071);
    vec2 place = turn * fragCoord / DotSpacing;
    vec2 middle = back * ((floor(place) + 0.5) * DotSpacing);
    vec2 at = clamp(middle * pixel, 0.0, 1.0);

    // A little softened, so a dot's colour stands for its whole cell.
    vec3 color = (picture(at) * 2.0
        + picture(at + vec2(pixel.x * 2.0, 0.0)) + picture(at - vec2(pixel.x * 2.0, 0.0))
        + picture(at + vec2(0.0, pixel.y * 2.0)) + picture(at - vec2(0.0, pixel.y * 2.0))) / 6.0;
    float level = brightness(color);
    vec3 strong = clamp(vec3(level) + (color - vec3(level)) * Saturation, 0.0, 1.0);

    // Three kinds of area: highlights left as pale colour, shadows printed
    // solid, and everything between in dots, bigger the darker it is. Dots
    // are the strong colour, a little darkened, on the pale colour.
    vec3 pale = mix(Paper, strong, 0.45);
    vec3 ink = strong * 0.8;
    float dark = 1.0 - level;
    float radius = DotSpacing * 0.62 * sqrt(clamp((dark - 0.2) / 0.6, 0.0, 1.0));
    float apart = length(fract(place) - 0.5) * DotSpacing;
    // Faded out as it shrinks to nothing, so no dot is left in highlights.
    float spot = (1.0 - smoothstep(radius - 0.7, radius + 0.7, apart)) * smoothstep(0.0, 0.8, radius);
    vec3 result = mix(pale, ink, spot);
    result = mix(result, ink * 0.7, smoothstep(0.8, 0.9, dark));

    result *= 1.0 - outline(fragCoord * pixel, pixel);
    fragColor = vec4(result, 1.0);
}
