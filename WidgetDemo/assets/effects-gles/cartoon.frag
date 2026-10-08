// name: Cartoon
// description: Cel shaded like a cartoon: smoothed into flat areas of colour,
// description: a few tones from shadow to highlight, and black outlines.
// tags: art, drawing, animation, outline

// How many tones from black to white. Fewer is more cartoon like.
const float Bands = 5.0;

// How much stronger colours are made, 1.0 leaving them as they were.
const float Saturation = 1.35;

// How far apart, in pixels, the outline finder looks. This sets how thick
// the lines are: about 1.5 gives medium lines at 1080p.
const float LineWidth = 1.5;

// How sharp a change in brightness must be to become a line. Higher leaves
// only the strong edges; lower draws in more detail, and more noise.
const float LineFrom = 0.18;
const float LineTo = 0.38;

// How different a neighbour's colour may be and still be smoothed in. Lower
// keeps more edges; higher flattens more.
const float Likeness = 0.12;

float brightness(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

// An edge preserving blur, a bilateral filter: the average of the 5 by 5
// around this point, weighted down with distance, and weighted down much
// more for colours unlike this one. Areas smooth out; the edges between
// them stay where they were. The samples fall between pixels, a pixel and
// a half apart, so each already averages four, reaching further for free.
vec3 smoothed(vec2 uv, vec2 pixel)
{
    vec3 centre = texture2D(iChannel0, uv).rgb;
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int y = -2; y <= 2; y++)
        for (int x = -2; x <= 2; x++)
        {
            vec2 offset = vec2(float(x), float(y));
            vec3 color = texture2D(iChannel0, uv + offset * 1.5 * pixel).rgb;
            vec3 difference = color - centre;
            float weight = exp(-dot(offset, offset) / 8.0 - dot(difference, difference) / (2.0 * Likeness * Likeness));
            sum += color * weight;
            total += weight;
        }
    return sum / total;
}

// How strongly this point is an outline, 0 to 1: a Sobel filter on the
// brightness around it, which measures how steeply brightness changes.
float outline(vec2 uv, vec2 pixel)
{
    vec2 d = pixel * LineWidth;
    float tl = brightness(texture2D(iChannel0, uv + vec2(-d.x, d.y)).rgb);
    float t = brightness(texture2D(iChannel0, uv + vec2(0.0, d.y)).rgb);
    float tr = brightness(texture2D(iChannel0, uv + d).rgb);
    float l = brightness(texture2D(iChannel0, uv - vec2(d.x, 0.0)).rgb);
    float r = brightness(texture2D(iChannel0, uv + vec2(d.x, 0.0)).rgb);
    float bl = brightness(texture2D(iChannel0, uv - d).rgb);
    float b = brightness(texture2D(iChannel0, uv - vec2(0.0, d.y)).rgb);
    float br = brightness(texture2D(iChannel0, uv + vec2(d.x, -d.y)).rgb);
    float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float gy = (tl + 2.0 * t + tr) - (bl + 2.0 * b + br);
    return smoothstep(LineFrom, LineTo, length(vec2(gx, gy)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 pixel = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * pixel;

    vec3 color = smoothed(uv, pixel);

    // Brightness is rounded to the nearest of the bands, with a short blend
    // across each step rather than a hard cut, so the steps don't crawl as
    // the video's noise moves them back and forth. The colour itself, what
    // is left once brightness is taken out, is kept and strengthened, so hues
    // stay true rather than shifting as they would if red, green and blue were
    // each banded on their own.
    float level = brightness(color);
    float scaled = level * Bands;
    float banded = (floor(scaled) + smoothstep(0.42, 0.58, fract(scaled))) / Bands;
    color = vec3(banded) + (color - vec3(level)) * Saturation;

    color *= 1.0 - outline(uv, pixel);
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
